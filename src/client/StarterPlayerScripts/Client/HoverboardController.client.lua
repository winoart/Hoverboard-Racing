--!strict
-- HoverboardController.client.luau
-- Arcade Racing Style HUD (Top-Left Leaderboard, Top-Right Timer & Laps, Bottom-Right Tachometer Speedometer, Bottom-Center Booster Bar)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local StarterGui = game:GetService("StarterGui")
local GuiService = game:GetService("GuiService")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- Hide Roblox Default Backpack Tool Slot [1] UI
task.spawn(function()
	for i = 1, 10 do
		pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
		end)
		task.wait(0.2)
	end
end)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local HoverboardConfig = require(Shared:WaitForChild("HoverboardConfig") :: ModuleScript)
local SkillMessages = require(Shared:WaitForChild("SkillMessages") :: ModuleScript)
local RebirthConfig = require(Shared:WaitForChild("RebirthConfig") :: ModuleScript)

local remotesFolder = ReplicatedStorage:WaitForChild("HoverboardRemotes")
local mountRemote = remotesFolder:WaitForChild("MountRequest") :: RemoteEvent
local dismountRemote = remotesFolder:WaitForChild("DismountRequest") :: RemoteEvent
local stateRemote = remotesFolder:WaitForChild("StateChanged") :: RemoteEvent
local syncSpectatorRemote = remotesFolder:WaitForChild("SyncSpectatorState") :: any

local isMounted = false
local isRaceStarted = false
local isFinished = false
local currentBoardModel: Model? = nil
local engineSound: Sound? = nil
local boostSound: Sound? = nil
local currentBankAngle = 0
local currentHeadingYaw = 0
local defaultFOV = 70
local targetFOV = 70
local currentWalkSpeed = 0.0
local currentSteerRate = 0.0 -- Damped steering turn rate for smooth cornering and auto-straightening
local lastSafePosition: Vector3? = nil
local lastSafeYaw = 0.0
local fallCheckTimer = 0.0

-- Nitro Booster State Variables
local boosterGauge = 100.0 -- 0% to 100%
local isBoosting = false
local isMobileBoostDown = false

-- Race State Variables
local raceStartTime = 0.0
local currentLap = 1
local totalLaps = 2

-- Stun State (for Orbital Laser)
local isStunned = false
local stunTimer = 0.0
local stunLiftOffset = 0.0

local skillWarningRemote = ReplicatedStorage:WaitForChild("HoverboardRemotes"):WaitForChild("SkillWarning") :: RemoteEvent
skillWarningRemote.OnClientEvent:Connect(function(casterName: string, skillId: string)
	if skillId == "OrbitalStun" and casterName == "SYSTEM" then
		isStunned = true
		stunTimer = 2.0
	end
end)

-- PlayerModule Controls reference for disabling default movement
local playerScripts = LocalPlayer:WaitForChild("PlayerScripts")
local playerModuleScript = playerScripts:WaitForChild("PlayerModule", 5) :: ModuleScript?
local playerControls: any = nil
if playerModuleScript then
	local success, playerModule = pcall(require, playerModuleScript)
	if success and playerModule and playerModule.GetControls then
		playerControls = playerModule:GetControls()
	end
end

-- UI Elements
local playerGui = LocalPlayer:WaitForChild("PlayerGui")
local guiScreen: ScreenGui? = nil

-- Top-Left UI References
local rankBadgeLabel: TextLabel? = nil
local leaderNameLabel1: TextLabel? = nil

-- Top-Right UI References
local timerLabel: TextLabel? = nil
local lapNumLabel: TextLabel? = nil

-- Bottom-Right Speedometer References
local speedNumLabel: TextLabel? = nil
local speedModeLabel: TextLabel? = nil
local arcFillGradient: UIGradient? = nil

-- Bottom-Center Booster References
local boosterFillBar: Frame? = nil
local rebirthEffectLabel: TextLabel? = nil
local boosterTextLabel: TextLabel? = nil
local speedLinesFrame: Frame? = nil
local boosterGaugeStroke: UIStroke? = nil

-- Gold Animation Helpers
local function getGoldTarget(): GuiObject?
	if not playerGui then return nil end
	local hud = playerGui:FindFirstChild("GoldDisplayHUD")
	if hud then
		local frame = hud:FindFirstChild("GoldFrame")
		if frame then
			return frame:FindFirstChild("GoldIcon") or frame:FindFirstChild("GoldTextLabel")
		end
	end
	return nil
end

local function spawnGoldEffect(startPos: Vector2, target: GuiObject?, rank: number)
	if not target or not guiScreen then return end
	
	local targetPos = UDim2.new(0, target.AbsolutePosition.X + (target.AbsoluteSize.X / 2), 0, target.AbsolutePosition.Y + (target.AbsoluteSize.Y / 2))
	
	-- 순위에 따라 동전 개수 차등 지급 (1위: 15개, 2위: 10개, 3위: 7개, 4위 이하: 4개)
	local coinCount = 4
	if rank == 1 then
		coinCount = 15
	elseif rank == 2 then
		coinCount = 10
	elseif rank == 3 then
		coinCount = 7
	end
	
	for i = 1, coinCount do
		local icon = Instance.new("ImageLabel")
		icon.Size = UDim2.new(0, 50, 0, 50)
		icon.Position = UDim2.new(0, startPos.X, 0, startPos.Y)
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.BackgroundTransparency = 1
		icon.Image = "rbxassetid://17368060122"
		icon.ZIndex = 100
		
		icon.Parent = guiScreen
		
		-- 1단계: 주변으로 튀어나오기 (Pop-out)
		local randomX = startPos.X + math.random(-60, 60)
		local randomY = startPos.Y + math.random(-60, 60)
		local popPos = UDim2.new(0, randomX, 0, randomY)
		
		local popTweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local popTween = TweenService:Create(icon, popTweenInfo, {
			Position = popPos,
			Size = UDim2.new(0, 60, 0, 60),
			Rotation = math.random(-45, 45)
		})
		
		-- 2단계: 타겟으로 가속하며 날아가기 (Fly-in)
		local flyTweenInfo = TweenInfo.new(0.6, Enum.EasingStyle.Cubic, Enum.EasingDirection.In)
		local flyTween = TweenService:Create(icon, flyTweenInfo, {
			Position = targetPos,
			Size = UDim2.new(0, 30, 0, 30),
			Rotation = 0
		})
		
		popTween.Completed:Connect(function()
			flyTween:Play()
		end)
		
		flyTween.Completed:Connect(function()
			icon:Destroy()
			
			-- 타겟(골드 아이콘) 흔들림 효과 (무한 커짐 방지를 위해 UIScale 사용)
			if target and target.Parent then
				local uiScale = target:FindFirstChild("GoldBounceScale")
				if not uiScale then
					uiScale = Instance.new("UIScale")
					uiScale.Name = "GoldBounceScale"
					uiScale.Scale = 1.0
					uiScale.Parent = target
				end
				
				-- 이전 트윈이 진행 중이더라도 UIScale.Scale을 1.2로 목표로 설정하면 안전함
				local shakeTween = TweenService:Create(uiScale, TweenInfo.new(0.1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, true), {
					Scale = 1.3
				})
				shakeTween:Play()
				
				-- 안전장치: 혹시 트윈 꼬임을 대비해 잠시 후 1.0으로 강제 복구
				task.delay(0.25, function()
					if uiScale then
						uiScale.Scale = 1.0
					end
				end)
			end
		end)
		
		task.delay((i - 1) * 0.12, function()
			if icon.Parent then
				popTween:Play()
			end
		end)
	end
end

-- Create Authentic Arcade Racing Layout HUD UI
local function createHUDUI()
	if guiScreen then guiScreen:Destroy() end

	guiScreen = Instance.new("ScreenGui")
	guiScreen.Name = "HoverboardHUD"
	guiScreen.ResetOnSpawn = false
	guiScreen.DisplayOrder = 10
	guiScreen.IgnoreGuiInset = true
	guiScreen.Parent = playerGui

	-- =========================================================================
	-- 🏁 DYNAMIC LEADERBOARD SYSTEM (Top Center)
	-- =========================================================================
	local leaderboardContainer = Instance.new("Frame")
	leaderboardContainer.Name = "LeaderboardContainer"
	-- Responsive size for horizontal layout
	leaderboardContainer.Size = UDim2.new(0.4, 0, 0.06, 0)
	leaderboardContainer.Position = UDim2.new(0.5, 0, 0, 10)
	leaderboardContainer.AnchorPoint = Vector2.new(0.5, 0)
	leaderboardContainer.BackgroundTransparency = 1
	leaderboardContainer.ZIndex = 11
	leaderboardContainer.Parent = guiScreen

	-- Dictionary to hold player cards
	local playerCardFrames = {}

	local function getRankSuffix(rank)
		if rank == 1 then return "1st" end
		if rank == 2 then return "2nd" end
		if rank == 3 then return "3rd" end
		return rank .. "th"
	end

	local function createPlayerCard(playerName, isLocal)
		local pCard = Instance.new("ImageLabel")
		pCard.Name = "Card_" .. playerName
		-- Use Scale for size so it adjusts on mobile
		pCard.Size = UDim2.new(0.12, 0, 1, 0)
		pCard.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
		pCard.BorderSizePixel = 0
		pCard.ZIndex = 11
		pCard.Position = UDim2.new(0, 0, 0, 0)
		pCard.Parent = leaderboardContainer
		pCard.ScaleType = Enum.ScaleType.Crop
		
		-- Fetch avatar thumbnail
		task.spawn(function()
			local p = Players:FindFirstChild(playerName)
			if p then
				local content, isReady = Players:GetUserThumbnailAsync(p.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
				if isReady then pCard.Image = content end
			else
				pCard.Image = "rbxassetid://10492211918" -- Generic bot placeholder
			end
		end)

		local aspect = Instance.new("UIAspectRatioConstraint")
		aspect.AspectRatio = 1
		aspect.Parent = pCard

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = pCard

		local stroke = Instance.new("UIStroke")
		stroke.Color = isLocal and Color3.fromRGB(255, 200, 30) or Color3.fromRGB(0, 0, 0)
		stroke.Thickness = isLocal and 3.5 or 2
		stroke.Parent = pCard

		return { frame = pCard }
	end

	local function updateRankings(sortedPlayerNames, isStartingLine)
		-- [임시] UI 테스트를 위해 8명까지 가짜 플레이어 채우기
		local fakeSorted = {}
		for _, name in ipairs(sortedPlayerNames) do
			table.insert(fakeSorted, name)
		end
		for i = #fakeSorted + 1, 8 do
			table.insert(fakeSorted, "Bot_Test_" .. i)
		end

		for rank, pName in ipairs(fakeSorted) do
			if not playerCardFrames[pName] then
				playerCardFrames[pName] = createPlayerCard(pName, pName == LocalPlayer.DisplayName)
			end
			local cardData = playerCardFrames[pName]
			
			if rank <= 8 then
				cardData.frame.Visible = true
				
				-- Horizontal spacing (each takes ~12.5% of container width)
				local targetX = (rank - 1) * 0.125
				local targetPos = UDim2.new(targetX, 0, 0, 0)
				
				-- Smooth animation for horizontal swapping
				TweenService:Create(cardData.frame, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = targetPos }):Play()
			else
				cardData.frame.Visible = false
			end
		end
	end

	-- =========================================================================
	-- 🏁 REAL-TIME RANKING UPDATE LISTENER
	-- =========================================================================
	local updateRankingsRemote = remotesFolder:WaitForChild("UpdateRankings") :: RemoteEvent
	updateRankingsRemote.OnClientEvent:Connect(function(sortedPlayerNames, isStartingLine)
		if leaderboardContainer and leaderboardContainer.Parent then
			updateRankings(sortedPlayerNames, isStartingLine)
		end
	end)

	-- =========================================================================
	-- ⏱️ [2] TOP-RIGHT: RACE TIMER & LAPS COUNTER
	-- =========================================================================
	local topRightFrame = Instance.new("Frame")
	topRightFrame.Name = "TopRightRaceFrame"
	topRightFrame.Size = UDim2.new(0, 240, 0, 150)
	topRightFrame.Position = UDim2.new(0.98, -240, 0.03, 0)
	topRightFrame.BackgroundTransparency = 1
	topRightFrame.ZIndex = 10
	topRightFrame.Parent = guiScreen

	-- Timer Label (e.g., TIME 01:46:55)
	timerLabel = Instance.new("TextLabel")
	timerLabel.Name = "TimerText"
	timerLabel.Size = UDim2.new(1, 0, 0, 36)
	timerLabel.Position = UDim2.new(0, 0, 0, 0)
	timerLabel.BackgroundTransparency = 1
	timerLabel.Font = Enum.Font.RobotoMono
	timerLabel.Text = "TIME  00:00:00"
	timerLabel.TextColor3 = Color3.fromRGB(255, 235, 200)
	timerLabel.TextSize = 22
	timerLabel.TextXAlignment = Enum.TextXAlignment.Right
	timerLabel.ZIndex = 12
	timerLabel.Parent = topRightFrame

	local timerStroke = Instance.new("UIStroke")
	timerStroke.Color = Color3.fromRGB(0, 0, 0)
	timerStroke.Thickness = 2.5
	timerStroke.Parent = timerLabel

	-- Laps Display (e.g., 1 / 2 LAPS)
	lapNumLabel = Instance.new("TextLabel")
	lapNumLabel.Name = "LapText"
	lapNumLabel.Size = UDim2.new(1, 0, 0, 48)
	lapNumLabel.Position = UDim2.new(0, 0, 0, 38)
	lapNumLabel.BackgroundTransparency = 1
	lapNumLabel.Font = Enum.Font.GothamBlack
	lapNumLabel.Text = "1 / 2 LAPS"
	lapNumLabel.TextColor3 = Color3.fromRGB(255, 190, 30)
	lapNumLabel.TextSize = 34
	lapNumLabel.TextXAlignment = Enum.TextXAlignment.Right
	lapNumLabel.ZIndex = 12
	lapNumLabel.Parent = topRightFrame

	local lapStroke = Instance.new("UIStroke")
	lapStroke.Color = Color3.fromRGB(0, 0, 0)
	lapStroke.Thickness = 3.0
	lapStroke.Parent = lapNumLabel

	-- =========================================================================
	-- 🏎️ [3] BOTTOM-CENTER: NITRO GAUGE + SPEEDOMETER
	-- =========================================================================
	local bottomCenterHUD = Instance.new("Frame")
	bottomCenterHUD.Name = "BottomCenterHUD"
	bottomCenterHUD.Size = UDim2.new(0, 360, 0, 40)
	bottomCenterHUD.AnchorPoint = Vector2.new(0.5, 1)
	-- 스킬 버튼(높이 60 + 여백 10 = 70px)보다 무조건 위에 있도록 절대값 -85픽셀로 고정
	bottomCenterHUD.Position = UDim2.new(0.5, 0, 1, -85) 
	bottomCenterHUD.BackgroundTransparency = 1
	bottomCenterHUD.ZIndex = 10
	bottomCenterHUD.Parent = guiScreen

	local uiScale = Instance.new("UIScale")
	uiScale.Scale = 0.75 -- Reduce size by 25%
	uiScale.Parent = bottomCenterHUD

	-- 1. N2O Booster Gauge (Top part)
	local n2oLabel = Instance.new("TextLabel")
	n2oLabel.Size = UDim2.new(0, 40, 0, 20)
	n2oLabel.Position = UDim2.new(0, 10, 0, 0)
	n2oLabel.BackgroundTransparency = 1
	n2oLabel.Font = Enum.Font.GothamBlack
	n2oLabel.Text = "N2O"
	n2oLabel.TextColor3 = Color3.fromRGB(150, 150, 180)
	n2oLabel.TextSize = 16
	n2oLabel.TextXAlignment = Enum.TextXAlignment.Right
	n2oLabel.ZIndex = 11
	n2oLabel.Parent = bottomCenterHUD
	
	rebirthEffectLabel = Instance.new("TextLabel")
	rebirthEffectLabel.Size = UDim2.new(0, 150, 0, 20)
	-- 부스터 게이지 우측 끝(X: 320)에 맞춰 위쪽(Y: -15)으로 배치
	rebirthEffectLabel.AnchorPoint = Vector2.new(1, 1)
	rebirthEffectLabel.Position = UDim2.new(0, 320, 0, 0)
	rebirthEffectLabel.BackgroundTransparency = 1
	rebirthEffectLabel.Font = Enum.Font.GothamBlack
	rebirthEffectLabel.Text = "Rebirth +0.0 Km/s"
	rebirthEffectLabel.TextColor3 = Color3.fromRGB(150, 255, 100) -- 더 밝고 가시성 높은 연두색
	rebirthEffectLabel.TextSize = 20
	rebirthEffectLabel.TextXAlignment = Enum.TextXAlignment.Right
	rebirthEffectLabel.ZIndex = 11
	rebirthEffectLabel.Parent = bottomCenterHUD
	
	local rStroke = Instance.new("UIStroke")
	rStroke.Color = Color3.fromRGB(0, 0, 0) -- 완전한 검은색으로 대비 극대화
	rStroke.Thickness = 2.5 -- 훨씬 두꺼운 테두리
	rStroke.Parent = rebirthEffectLabel
	
	local boosterGaugeBg = Instance.new("Frame")
	boosterGaugeBg.Name = "BoosterGaugeBg"
	boosterGaugeBg.Size = UDim2.new(0, 260, 0, 12)
	boosterGaugeBg.Position = UDim2.new(0, 60, 0, 4)
	boosterGaugeBg.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	boosterGaugeBg.BackgroundTransparency = 0.5
	boosterGaugeBg.BorderSizePixel = 0
	boosterGaugeBg.ClipsDescendants = true
	boosterGaugeBg.ZIndex = 11
	boosterGaugeBg.Parent = bottomCenterHUD

	boosterGaugeStroke = Instance.new("UIStroke")
	boosterGaugeStroke.Color = Color3.fromRGB(255, 200, 100)
	boosterGaugeStroke.Thickness = 1.0
	boosterGaugeStroke.Transparency = 0.5
	boosterGaugeStroke.Parent = boosterGaugeBg

	boosterFillBar = Instance.new("Frame")
	boosterFillBar.Name = "FillBar"
	boosterFillBar.Size = UDim2.new(1, 0, 1, 0)
	boosterFillBar.Position = UDim2.new(0, 0, 0, 0)
	boosterFillBar.BackgroundColor3 = Color3.fromRGB(255, 230, 0)
	boosterFillBar.BorderSizePixel = 0
	boosterFillBar.ZIndex = 12
	boosterFillBar.Parent = boosterGaugeBg
	
	local boosterGradient = Instance.new("UIGradient")
	boosterGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 0)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 180, 0)),
	})
	boosterGradient.Parent = boosterFillBar

	-- Digital Speed Number
	speedNumLabel = Instance.new("TextLabel")
	speedNumLabel.Name = "DigitalSpeedNum"
	speedNumLabel.Size = UDim2.new(1, 0, 0, 48)
	speedNumLabel.Position = UDim2.new(0, 0, 0, 86)
	speedNumLabel.BackgroundTransparency = 1
	speedNumLabel.Font = Enum.Font.GothamBlack
	speedNumLabel.Text = "0.0 Km/s"
	speedNumLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	speedNumLabel.TextSize = 42
	speedNumLabel.TextXAlignment = Enum.TextXAlignment.Right
	speedNumLabel.ZIndex = 12
	speedNumLabel.Parent = topRightFrame

	local speedStroke = Instance.new("UIStroke")
	speedStroke.Color = Color3.fromRGB(0, 0, 0)
	speedStroke.Thickness = 3.0
	speedStroke.Parent = speedNumLabel
	
	-- Mode Badge Label
	speedModeLabel = Instance.new("TextLabel")
	speedModeLabel.Name = "ModeBadge"
	speedModeLabel.Size = UDim2.new(1, 0, 0, 15)
	speedModeLabel.Position = UDim2.new(0, 0, 1, 5)
	speedModeLabel.BackgroundTransparency = 1
	speedModeLabel.Font = Enum.Font.GothamBold
	speedModeLabel.Text = "⚡ READY"
	speedModeLabel.TextColor3 = Color3.fromRGB(0, 240, 255)
	speedModeLabel.TextSize = 14
	speedModeLabel.ZIndex = 12
	speedModeLabel.Parent = bottomCenterHUD

	-- =========================================================================
	-- 📱 MOBILE BOOST BUTTON (Only if TouchEnabled)
	-- Tracks the Roblox default JumpButton and overlays exactly on top of it
	-- =========================================================================
	if UserInputService.TouchEnabled then
		local mobileBoostBtn = Instance.new("TextButton")
		mobileBoostBtn.Name = "MobileBoostBtn"
		mobileBoostBtn.Size = UDim2.new(0, 70, 0, 70) -- default, will be updated
		mobileBoostBtn.Position = UDim2.new(1, -80, 1, -80) -- default fallback
		mobileBoostBtn.AnchorPoint = Vector2.new(0.5, 0.5)
		mobileBoostBtn.BackgroundColor3 = Color3.fromRGB(255, 180, 0)
		mobileBoostBtn.Font = Enum.Font.FredokaOne
		mobileBoostBtn.Text = "BOOST"
		mobileBoostBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
		mobileBoostBtn.TextSize = 20
		mobileBoostBtn.ZIndex = 20
		mobileBoostBtn.Parent = guiScreen
		
		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(1, 0)
		btnCorner.Parent = mobileBoostBtn

		-- 점프버튼 위치/크기를 찾아서 BOOST 버튼을 정확히 그 위에 올리는 함수
		local function snapToJumpButton()
			local pGui = LocalPlayer:FindFirstChild("PlayerGui")
			if not pGui then return end
			local touchGui = pGui:FindFirstChild("TouchGui")
			if not touchGui then return end
			local controlFrame = touchGui:FindFirstChild("TouchControlFrame")
			if not controlFrame then return end
			local jumpBtn = controlFrame:FindFirstChild("JumpButton")
			if not jumpBtn then return end
			
			local absPos = jumpBtn.AbsolutePosition
			local absSize = jumpBtn.AbsoluteSize
			if absPos.X <= 10 or absPos.Y <= 10 then return end
			
			-- GuiInset 보정: TouchGui는 IgnoreGuiInset=false, guiScreen은 true이므로 Y 오프셋 필요
			local guiInset = GuiService:GetGuiInset()
			
			-- 화면 크기 대비 스케일 좌표로 변환
			local screenSize = guiScreen.AbsoluteSize
			if screenSize.X == 0 or screenSize.Y == 0 then return end
			
			local centerX = absPos.X + absSize.X / 2
			local centerY = absPos.Y + absSize.Y / 2 + guiInset.Y -- 점프버튼 중심에 정확히 일치
			
			mobileBoostBtn.Position = UDim2.new(centerX / screenSize.X, 0, centerY / screenSize.Y, 0)
			mobileBoostBtn.Size = UDim2.new(absSize.X / screenSize.X, 0, absSize.Y / screenSize.Y, 0)
		end
		
		-- 0.5초마다 위치 동기화 (레이아웃이 바뀔 수 있으므로)
		task.spawn(function()
			while mobileBoostBtn and mobileBoostBtn.Parent do
				snapToJumpButton()
				task.wait(0.5)
			end
		end)
		
		local tweenInfo = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		mobileBoostBtn.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				isMobileBoostDown = true
				TweenService:Create(mobileBoostBtn, tweenInfo, {
					BackgroundColor3 = Color3.fromRGB(255, 220, 50),
					BackgroundTransparency = 0.15
				}):Play()
			end
		end)
		
		mobileBoostBtn.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				isMobileBoostDown = false
				TweenService:Create(mobileBoostBtn, tweenInfo, {
					BackgroundColor3 = Color3.fromRGB(255, 180, 0),
					BackgroundTransparency = 0
				}):Play()
			end
		end)
	end

	-- (Bottom-Center Booster Gauge has been removed and replaced by the Arc Ring Gauge)
	guiScreen.Enabled = false
end

createHUDUI()

local skaterJointsCache = {}

-- Handle Server State Changes & Steering Initialization
stateRemote.OnClientEvent:Connect(function(mounted: boolean, boardModel: Model?, savedPos: Vector3?, forceIsRacing: boolean?)
	if forceIsRacing then
		LocalPlayer:SetAttribute("OnTreadmill", false)
		_G.wasOnTreadmill = false
		lastSafePosition = nil -- Reset Fall Recovery to allow vertical teleport!
		_G.introCamDist = 50.0
		_G.introCamHeight = 30.0
	else
		-- 레이스가 아닐 때(대기실 등)는 점프 복구
		local character = LocalPlayer.Character
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.UseJumpPower = true
			hum.JumpPower = 50 -- 기본 점프 파워
		end
	end

	isMounted = mounted
	currentBoardModel = boardModel
	boosterGauge = 0.0 -- 초기 부스터는 0%에서 시작
	isBoosting = false
	currentWalkSpeed = 0.0
	currentSteerRate = 0.0
	isRaceStarted = false
	raceStartTime = 0.0 -- Timer will start when countdown reaches 1!

	if guiScreen then
		guiScreen.Enabled = mounted and not LocalPlayer:GetAttribute("OnTreadmill")
	end

	if mounted then
		local character = LocalPlayer.Character
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		if hum then
			-- 기존에 Jumping 상태를 false로 꺼버려서 로블록스 모바일 기본 점프 버튼이 강제로 사라지는 문제가 있었습니다.
			-- 점프 버튼을 살려두되 점프를 못하게(부스터로만 쓰게) 하려면, 상태는 켜두고 JumpPower를 0으로 만듭니다.
			hum.UseJumpPower = true
			hum.JumpPower = 0
		end
		
		if not engineSound then
			engineSound = Instance.new("Sound")
			engineSound.Name = "HoverboardEngineSound"
			engineSound.SoundId = "rbxassetid://75876120873511"
			engineSound.Looped = true
			engineSound.Volume = 0.2
			engineSound.PlaybackSpeed = 0.8
			
			local hrp = character and character:FindFirstChild("HumanoidRootPart")
			if hrp then
				engineSound.Parent = hrp
				engineSound:Play()
			end
		end

		if not boostSound then
			boostSound = Instance.new("Sound")
			boostSound.Name = "HoverboardBoostSound"
			boostSound.SoundId = "rbxassetid://122292120519645"
			boostSound.Looped = true
			boostSound.Volume = 0.8
			boostSound.PlaybackSpeed = 1.0
			
			local hrp = character and character:FindFirstChild("HumanoidRootPart")
			if hrp then
				boostSound.Parent = hrp
			end
		end

		task.defer(function()
			local char = LocalPlayer.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			
			if hrp then
				local currentPos = hrp.Position
				-- Keep the orientation set by the Server's GameLoopManager teleport
				local _, ry, _ = hrp.CFrame:ToOrientation()
				currentHeadingYaw = ry
				
				-- Initialize safe position
				lastSafePosition = currentPos
				lastSafeYaw = ry
				
				local trackForwardDir = Vector3.new(0, 0, 1)

				if Camera and not LocalPlayer:GetAttribute("OnTreadmill") then
					Camera.CameraType = Enum.CameraType.Scriptable
					if forceIsRacing then
						local initDist = _G.introCamDist or 50.0
						local initHeight = _G.introCamHeight or 30.0
						Camera.CFrame = CFrame.lookAt(currentPos - trackForwardDir * initDist + Vector3.new(0, initHeight, 0), currentPos + trackForwardDir * 25 + Vector3.new(0, -4.0, 0))
					else
						Camera.CFrame = CFrame.lookAt(currentPos - trackForwardDir * 16 + Vector3.new(0, 6.5, 0), currentPos + trackForwardDir * 25 + Vector3.new(0, -4.0, 0))
					end
				end
				
				-- 💨 Attach "wind force 3" VFX to Camera (so it surrounds the screen)
				local existingVFX = Camera:FindFirstChild("CameraBoostVFX")
				if existingVFX then existingVFX:Destroy() end
				
				local vfxSource = ReplicatedStorage:FindFirstChild("wind force 3")
				if vfxSource and vfxSource:IsA("BasePart") then
					local vfxClone = vfxSource:Clone()
					vfxClone.Name = "CameraBoostVFX"
					vfxClone.Massless = true
					vfxClone.CanCollide = false
					vfxClone.Anchored = true
					
					-- 원본 에셋이 워크스페이스에 배치되어 있던 '오리지널 회전값'을 저장해둡니다.
					vfxClone:SetAttribute("OriginalRotation", vfxSource.CFrame - vfxSource.Position)
					
					-- Ensure it starts disabled/invisible
					vfxClone.Transparency = 1
					for _, desc in ipairs(vfxClone:GetDescendants()) do
						if desc:IsA("ParticleEmitter") or desc:IsA("Trail") or desc:IsA("Beam") then
							desc.Enabled = false
						end
					end
					vfxClone.Parent = Camera
				end
			end
		end)
	else
		if engineSound then
			engineSound:Destroy()
			engineSound = nil
		end
		if boostSound then
			boostSound:Destroy()
			boostSound = nil
		end
		isBoosting = false
		isRaceStarted = false
		_G.wasOnTreadmill = false
		local character = LocalPlayer.Character
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.AutoRotate = true
			hum.WalkSpeed = 16
			hum.HipHeight = 2.0 -- Reset to default R15 HipHeight to prevent floating in lounge
			hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
		end
		
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if hrp then
			local gyro = hrp:FindFirstChild("SteeringGyro")
			if gyro then gyro:Destroy() end
		end

		if playerControls and playerControls.Enable then
			playerControls:Enable()
		end

		if Camera then
			Camera.CameraType = Enum.CameraType.Custom
			TweenService:Create(Camera, TweenInfo.new(0.4), { FieldOfView = defaultFOV }):Play()
		end
	end
end)

-- 🛹 PROCEDURAL ANIMATION: Dynamic Skater Stance (Runs after Animator)
RunService.Stepped:Connect(function(_, deltaTime)
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if not character then continue end
		
		local hasBoard = character:FindFirstChild("EquippedHoverboard") ~= nil
		if not hasBoard then continue end
		
		if player == LocalPlayer and not isMounted then continue end

		local joints = skaterJointsCache[player.UserId]
		if not joints or joints.CharacterModel ~= character then
			joints = {
				CharacterModel = character,
				Waist = character:FindFirstChild("Waist", true),
				RightShoulder = character:FindFirstChild("RightShoulder", true),
				LeftShoulder = character:FindFirstChild("LeftShoulder", true),
				RightElbow = character:FindFirstChild("RightElbow", true),
				LeftElbow = character:FindFirstChild("LeftElbow", true),
				RightHip = character:FindFirstChild("RightHip", true),
				LeftHip = character:FindFirstChild("LeftHip", true),
				RightKnee = character:FindFirstChild("RightKnee", true),
				LeftKnee = character:FindFirstChild("LeftKnee", true),
			}
			skaterJointsCache[player.UserId] = joints
		end

		local leanFactor = 0
		if player == LocalPlayer then
			leanFactor = currentSteerRate * 0.35 
		else
			local hrp = character:FindFirstChild("HumanoidRootPart")
			if hrp then
				leanFactor = math.clamp(hrp.AssemblyAngularVelocity.Y * -0.05, -0.35, 0.35)
			end
		end

		-- Apply custom Transform to joints to override Idle animation
		if joints.Waist then joints.Waist.Transform = CFrame.Angles(math.rad(-18), leanFactor, leanFactor * 0.5) end
		if joints.RightShoulder then joints.RightShoulder.Transform = CFrame.Angles(math.rad(45), 0, math.rad(20)) end
		if joints.LeftShoulder then joints.LeftShoulder.Transform = CFrame.Angles(math.rad(45), 0, math.rad(-20)) end
		if joints.RightElbow then joints.RightElbow.Transform = CFrame.Angles(math.rad(25), 0, 0) end
		if joints.LeftElbow then joints.LeftElbow.Transform = CFrame.Angles(math.rad(25), 0, 0) end
		
		if joints.RightHip then joints.RightHip.Transform = CFrame.Angles(math.rad(35), 0, math.rad(12)) end
		if joints.LeftHip then joints.LeftHip.Transform = CFrame.Angles(math.rad(35), 0, math.rad(-12)) end
		if joints.RightKnee then joints.RightKnee.Transform = CFrame.Angles(math.rad(-65), 0, 0) end
		if joints.LeftKnee then joints.LeftKnee.Transform = CFrame.Angles(math.rad(-65), 0, 0) end
	end
end)

-- Main Render Loop for Arcade Racing HUD, Hovering Physics, Speedometer, Booster Gauge & Wind FX
RunService:BindToRenderStep("HoverboardControllerRender", Enum.RenderPriority.Camera.Value, function(deltaTime: number)
	local isSpectating = LocalPlayer:GetAttribute("IsSpectating") or false
	local character = LocalPlayer.Character
	if not character then return end
	local hasBoard = character:FindFirstChild("EquippedHoverboard") ~= nil

	if hasBoard and not isMounted and not isSpectating then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			local animator = humanoid:FindFirstChildOfClass("Animator")
			if animator then
				for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
					if track.Name:lower():find("run") or track.Name:lower():find("walk") then
						track:Stop()
					end
				end
			end
			-- Only animate HipHeight if they are NOT in Freefall.
			-- Modifying HipHeight every frame while in Freefall prevents Roblox from detecting the ground!
			if humanoid:GetState() == Enum.HumanoidStateType.Freefall then
				humanoid.HipHeight = HoverboardConfig.HOVER_HEIGHT
			else
				local clockTime = os.clock()
				local bobOffset = math.sin(clockTime * HoverboardConfig.BOB_FREQUENCY) * HoverboardConfig.BOB_AMPLITUDE
				humanoid.HipHeight = HoverboardConfig.HOVER_HEIGHT + bobOffset
			end
		end
		return
	end

	if not hasBoard and not isSpectating then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.HipHeight > 2.5 then
			humanoid.HipHeight = 2.0
			-- Also make sure they are not stuck in Freefall when getting off
			if humanoid:GetState() == Enum.HumanoidStateType.Freefall then
				humanoid:ChangeState(Enum.HumanoidStateType.Running)
			end
		end
	end

	if not isMounted and not isSpectating then return end

	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not hrp or not humanoid then return end

	local velocity = hrp.AssemblyLinearVelocity
	local horizontalVelocity = Vector3.new(velocity.X, 0, velocity.Z)
	local currentSpeed = horizontalVelocity.Magnitude

	if engineSound and engineSound.IsPlaying then
		local maxSpeed = HoverboardConfig.MAX_SPEED or 150
		local speedRatio = math.clamp(currentSpeed / maxSpeed, 0, 1)
		-- 중저음을 위해 피치(PlaybackSpeed)를 전체적으로 낮춤 (최고속도 시 피치 증가폭 감소)
		engineSound.PlaybackSpeed = 0.6 + (speedRatio * 0.4) -- 0.6 ~ 1.0
		-- 호버보드 주행 소리가 묻히지 않도록 기존 대비 2배 더 증폭 (매우 큼)
		engineSound.Volume = 0.8 + (speedRatio * 2.4) -- 0.8 ~ 3.2
		
		if isBoosting then
			engineSound.PlaybackSpeed = engineSound.PlaybackSpeed + 0.3
			engineSound.Volume = engineSound.Volume + 0.4
		end
	end

	if boostSound then
		if isBoosting and not boostSound.IsPlaying then
			boostSound:Play()
		elseif not isBoosting and boostSound.IsPlaying then
			boostSound:Stop()
		end
	end

	if not isSpectating then
		humanoid.AutoRotate = false

		-- 🛡️ Fall Recovery Logic (레이스 중 트랙 이탈 즉시 복구)
		if isRaceStarted then
			if not lastSafePosition then
				-- Initialize if not set
				lastSafePosition = hrp.Position
				lastSafeYaw = currentHeadingYaw
			end

			-- 공통적으로 사용할 RaycastParams 생성
			local rayParams = RaycastParams.new()
			rayParams.FilterDescendantsInstances = {character}
			rayParams.FilterType = Enum.RaycastFilterType.Exclude

			if hrp.Position.Y < lastSafePosition.Y - 30 then
				-- 고저차가 심한 트랙(사막 등)에서 점프 후 떨어질 때를 대비하여,
				-- 현재 위치에서 150 스터드 아래까지 트랙(땅)이 있는지 확인합니다.
				local groundCheckRay = Workspace:Raycast(hrp.Position, Vector3.new(0, -150, 0), rayParams)
				
				if not groundCheckRay then
					print("[DEBUG-FR] 트랙 이탈 감지! 뒤로 물러난 안전지대로 복구합니다.")
					
					-- 1. 방향(lastSafeYaw)을 기준으로 뒤로 25스터드 물러난 벡터 계산
					-- 호버보드의 전진 방향은 RightVector(우측 벡터) 입니다.
					local forwardDir = CFrame.Angles(0, lastSafeYaw, 0).RightVector
					local spawnPos = lastSafePosition - (forwardDir * 25)
					
					-- 2. 뒤로 물러난 위치가 허공일 수도 있으니 바닥을 한 번 더 찾습니다.
					local spawnRay = Workspace:Raycast(spawnPos + Vector3.new(0, 10, 0), Vector3.new(0, -100, 0), rayParams)
					if spawnRay then
						spawnPos = spawnRay.Position
					else
						-- 뒤로 물러난 곳도 허공이라면 원래 안전지대를 씁니다.
						spawnPos = lastSafePosition
					end
					
					hrp.CFrame = CFrame.new(spawnPos + Vector3.new(0, 8, 0))
					hrp.AssemblyLinearVelocity = Vector3.zero
					hrp.AssemblyAngularVelocity = Vector3.zero
					currentHeadingYaw = lastSafeYaw
					currentWalkSpeed = 0.0
					isBoosting = false
				else
					-- 아래에 트랙이 있다면, 단순히 경사를 따라 내려가는 중이므로 기준점을 갱신합니다.
					lastSafePosition = groundCheckRay.Position
				end
			else
				fallCheckTimer += deltaTime
				if fallCheckTimer >= 0.5 then
					fallCheckTimer = 0.0
					local rayOrigin = hrp.Position
					local rayDirection = Vector3.new(0, -15, 0)
					local result = Workspace:Raycast(rayOrigin, rayDirection, rayParams)
					if result then
						-- hrp.Position(공중 위치)가 아닌, 실제 바닥 위치(result.Position)를 저장해야 무한 낙하를 방지합니다.
						lastSafePosition = result.Position
						lastSafeYaw = currentHeadingYaw
					end
				end
			end
		end

		-- Stop leg flailing animations
		local hasBoard = character:FindFirstChild("EquippedHoverboard") ~= nil
		if hasBoard and humanoid:GetState() == Enum.HumanoidStateType.Running then
			-- Instead of checking string names every frame, we just disable the Run/Walk states or rely on HipHeight
			-- Actually, stopping animations by name every frame is very expensive. 
			-- We will only stop tracks once, or just let the default animate script handle it since WalkSpeed is overwritten.
			-- Alternatively, we only check if velocity changed, but a cheaper way:
			local animator = humanoid:FindFirstChildOfClass("Animator")
			if animator then
				-- Optimization: Only check if WalkSpeed > 0 but we want them hovering
				for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
					if track.IsPlaying and (track.Priority == Enum.AnimationPriority.Movement or track.Priority == Enum.AnimationPriority.Core) then
						track:Stop()
					end
				end
			end
		end

		-- velocity and currentSpeed are now calculated above the if block

		-- Prevent Movement & Steering during Start Countdown (레이스 시작 전 대기 상태)
		if not isRaceStarted and not isFinished then
			humanoid.WalkSpeed = 0
			humanoid:Move(Vector3.zero, false)
			currentWalkSpeed = 0.0
			isBoosting = false
		else
			-- Movement Inputs (Keyboard + Mobile Thumbstick via Camera-relative dot product)
			-- Humanoid.MoveDirection is world-space, so we dot it with Camera vectors to get camera-relative input
			local hMoveDir = humanoid and humanoid.MoveDirection or Vector3.zero
			local camLook = Camera.CFrame.LookVector
			local camRight = Camera.CFrame.RightVector
			local fwdDot = hMoveDir:Dot(Vector3.new(camLook.X, 0, camLook.Z).Unit)
			local rightDot = hMoveDir:Dot(Vector3.new(camRight.X, 0, camRight.Z).Unit)
			
			local isW = UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up) or fwdDot > 0.3
			local isS = UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down) or fwdDot < -0.3
			local isBoostKey = UserInputService:IsKeyDown(HoverboardConfig.BOOSTER_KEY) or UserInputService:IsKeyDown(Enum.KeyCode.Space) or isMobileBoostDown
			
			-- 레이스를 완주한 경우 조작을 막아 자연스럽게 감속되도록 유도
			if isFinished then
				isW = false
				isS = false
				isBoostKey = false
				isBoosting = false
			end
			
			-- 모바일 부스터 버튼: isBoostKey 로 부스터 발동 (InputBegan 없이도 작동하도록)
			if isBoostKey and not isBoosting and boosterGauge >= HoverboardConfig.BOOSTER_MIN_TO_USE then
				isBoosting = true
			end
			
			if isStunned then
				stunTimer -= deltaTime
				if stunTimer <= 0 then
					isStunned = false
				end
				-- 강제로 조작 불가 상태 및 급정거
				isW = false
				isS = false
				isBoostKey = false
				isBoosting = false
				currentWalkSpeed = math.max(0, currentWalkSpeed - (200 * deltaTime)) -- 급격한 감속
				
				-- 🛰️ 빙글빙글 돌며 공중에 뜨는 기절 연출
				currentHeadingYaw += math.rad(720) * deltaTime -- 1초에 2바퀴 회전
				stunLiftOffset = math.min(6, stunLiftOffset + (30 * deltaTime)) -- 위로 6스터드까지 상승
			else
				stunLiftOffset = math.max(0, stunLiftOffset - (40 * deltaTime)) -- 스턴 종료 시 부드럽게 착지
				
				-- Steering Controls
				local isA = UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) or rightDot < -0.3
				local isD = UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) or rightDot > 0.3

				local targetSteerRate = 0.0
				
				-- EMP 해킹 시 조작 방향 반전
				if _G.isEMPHacked then
					local temp = isA
					isA = isD
					isD = temp
				end
				
				if isA then
					targetSteerRate = isBoosting and math.rad(115) or math.rad(85)
				elseif isD then
					targetSteerRate = isBoosting and -math.rad(115) or -math.rad(85)
				end

				local dampFactor = (targetSteerRate == 0) and 25.0 or 15.0
				currentSteerRate += (targetSteerRate - currentSteerRate) * math.clamp(deltaTime * dampFactor, 0, 1)
				currentHeadingYaw += currentSteerRate * deltaTime
			end

			local currentRebirths = 0
			local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
			if leaderstats then
				local rebirthsVal = leaderstats:FindFirstChild("Rebirths") :: IntValue
				if rebirthsVal then
					currentRebirths = rebirthsVal.Value
				end
			end
			local rebirthData = RebirthConfig.GetRebirthData(currentRebirths)
			
			if rebirthEffectLabel then
				rebirthEffectLabel.Text = string.format("Rebirth +%.1f Km/s", rebirthData.BoostSpeedBonus)
			end
			
			local currentMaxBoosterSpeed = HoverboardConfig.BOOSTER_WALKSPEED + rebirthData.BoostSpeedBonus

			local gyro = hrp:FindFirstChild("SteeringGyro") :: BodyGyro?
			if not gyro then
				gyro = Instance.new("BodyGyro")
				gyro.Name = "SteeringGyro"
				gyro.MaxTorque = Vector3.new(0, 400000, 0)
				gyro.P = 50000
				gyro.D = 500
				gyro.Parent = hrp
			end
			gyro.CFrame = CFrame.Angles(0, currentHeadingYaw, 0)

			if isBoosting then
				boosterGauge = math.max(0, boosterGauge - (HoverboardConfig.BOOSTER_DRAIN_RATE * deltaTime))
				currentWalkSpeed = currentMaxBoosterSpeed
				if boosterGauge <= 0 then
					isBoosting = false
				end
			else
				local targetSpeed = (isW or isS) and HoverboardConfig.RIDE_WALKSPEED or 0

				if currentWalkSpeed < targetSpeed then
					local accelRate = 36
					currentWalkSpeed = math.min(targetSpeed, currentWalkSpeed + (accelRate * deltaTime))
				elseif currentWalkSpeed > targetSpeed then
					local decelRate = 60 -- 48에서 60으로 약간 상향하여 부드럽지만 너무 미끄러지지 않게 감속
					currentWalkSpeed = math.max(targetSpeed, currentWalkSpeed - (decelRate * deltaTime))
				end

				if (isW or isS) or currentSpeed > 1 then
					boosterGauge = math.min(HoverboardConfig.BOOSTER_MAX_GAUGE, boosterGauge + (HoverboardConfig.BOOSTER_CHARGE_RATE * deltaTime))
				end
			end

			humanoid.WalkSpeed = currentWalkSpeed
			
			-- 가속도 디버깅 (속도가 변하는 동안 0.1초마다 콘솔에 출력)
			if not _G.debugPrintTimer then _G.debugPrintTimer = 0 end
			_G.debugPrintTimer += deltaTime
			if _G.debugPrintTimer >= 0.1 then
				_G.debugPrintTimer = 0
				local maxR = HoverboardConfig.RIDE_WALKSPEED or 110
				if currentWalkSpeed > 0.1 and currentWalkSpeed < (maxR - 0.1) then
					print(string.format("[DEBUG-ACCEL] 🕒 WalkSpeed(목표): %.1f | 실제물리속도: %.1f", currentWalkSpeed, currentSpeed))
				end
			end

			-- Execute Movement
			local boardModel = character:FindFirstChild("EquippedHoverboard") :: Model?
			local rootPart = boardModel and boardModel.PrimaryPart
			local frontLED = boardModel and boardModel:FindFirstChild("FrontLED") :: BasePart?
			local rearLED = boardModel and boardModel:FindFirstChild("RearLED") :: BasePart?

			if rootPart and currentWalkSpeed > 0.1 then
				local wDir = hrp.CFrame.RightVector

				local moveVector = wDir
				if isS and not isW then
					moveVector = -wDir
				end

				-- W나 S를 떼더라도 currentWalkSpeed가 남아있는 동안 관성으로 계속 미끄러집니다.
				humanoid:Move(moveVector, false)
			else
				humanoid:Move(Vector3.zero, false)
			end
		end

		-- 1. Sine wave bobbing (Re-enabled!) + Stun Lift FX
		local clockTime = os.clock()
		local bobOffset = math.sin(clockTime * HoverboardConfig.BOB_FREQUENCY) * HoverboardConfig.BOB_AMPLITUDE
		humanoid.HipHeight = HoverboardConfig.HOVER_HEIGHT + bobOffset + stunLiftOffset
		
		local treadmillSwayOffset = 0
		local treadmillBankSway = 0
		if LocalPlayer:GetAttribute("OnTreadmill") then
			treadmillSwayOffset = math.sin(clockTime * HoverboardConfig.BOB_FREQUENCY * 0.5) * 1.5
			treadmillBankSway = math.cos(clockTime * HoverboardConfig.BOB_FREQUENCY * 0.5) * 10
			
			if not _G.treadmillBaseCFrame then
				_G.treadmillBaseCFrame = hrp.CFrame
			end
			
			-- 플레이어 캐릭터 기준의 좌우(RightVector) 방향으로 흔들리게 수정
			local swayWorld = _G.treadmillBaseCFrame.RightVector * treadmillSwayOffset
			
			-- 다른 플레이어에게도 무빙이 보이도록 물리 제어기(AlignPosition)를 사용합니다.
			local alignPos = hrp:FindFirstChild("TreadmillSwayPos") :: AlignPosition?
			local targetAttach = Workspace.Terrain:FindFirstChild("TreadmillSwayTarget") :: Attachment?
			
			if not alignPos or not targetAttach then
				-- 기존 찌꺼기 제거
				if hrp:FindFirstChild("TreadmillSwayPos") then hrp.TreadmillSwayPos:Destroy() end
				if hrp:FindFirstChild("TreadmillSwayOri") then hrp.TreadmillSwayOri:Destroy() end
				if hrp:FindFirstChild("SwayAttach0") then hrp.SwayAttach0:Destroy() end
				if Workspace.Terrain:FindFirstChild("TreadmillSwayTarget") then Workspace.Terrain.TreadmillSwayTarget:Destroy() end
				
				local attach0 = Instance.new("Attachment")
				attach0.Name = "SwayAttach0"
				attach0.Parent = hrp
				
				targetAttach = Instance.new("Attachment")
				targetAttach.Name = "TreadmillSwayTarget"
				targetAttach.Parent = Workspace.Terrain
				
				alignPos = Instance.new("AlignPosition")
				alignPos.Name = "TreadmillSwayPos"
				alignPos.Attachment0 = attach0
				alignPos.Attachment1 = targetAttach
				alignPos.Mode = Enum.PositionAlignmentMode.TwoAttachment
				alignPos.ForceLimitMode = Enum.ForceLimitMode.PerAxis
				-- Y축(위아래)은 힘을 0으로 줘서 HipHeight 바운스를 방해하지 않게 합니다.
				alignPos.MaxAxesForce = Vector3.new(10000000, 0, 10000000) 
				alignPos.Responsiveness = 200
				alignPos.Parent = hrp
				
				local alignOri = Instance.new("AlignOrientation")
				alignOri.Name = "TreadmillSwayOri"
				alignOri.Attachment0 = attach0
				alignOri.Attachment1 = targetAttach
				alignOri.Mode = Enum.OrientationAlignmentMode.TwoAttachment
				alignOri.MaxTorque = 10000000
				alignOri.Responsiveness = 200
				alignOri.Parent = hrp
			end
			
			targetAttach.WorldCFrame = _G.treadmillBaseCFrame + swayWorld
			hrp.Anchored = false -- 물리 엔진이 타 유저에게 동기화되도록 반드시 언앵커!
		else
			if _G.treadmillBaseCFrame then
				hrp.Anchored = false
				_G.treadmillBaseCFrame = nil
				if hrp:FindFirstChild("TreadmillSwayPos") then hrp.TreadmillSwayPos:Destroy() end
				if hrp:FindFirstChild("TreadmillSwayOri") then hrp.TreadmillSwayOri:Destroy() end
				if hrp:FindFirstChild("SwayAttach0") then hrp.SwayAttach0:Destroy() end
				if Workspace.Terrain:FindFirstChild("TreadmillSwayTarget") then Workspace.Terrain.TreadmillSwayTarget:Destroy() end
			end
		end

		-- 2. Banking physics
		local localVel = hrp.CFrame:VectorToObjectSpace(horizontalVelocity)
		local sideSpeed = localVel.X
		local forwardSpeed = -localVel.Z

		local targetBank = -(sideSpeed / HoverboardConfig.RIDE_WALKSPEED) * HoverboardConfig.MAX_BANK_ANGLE
		targetBank = math.clamp(targetBank, -HoverboardConfig.MAX_BANK_ANGLE, HoverboardConfig.MAX_BANK_ANGLE)
		currentBankAngle += (targetBank - currentBankAngle) * math.clamp(deltaTime * HoverboardConfig.BANK_SMOOTHNESS, 0, 1)

		local pitchAngleDeg = (forwardSpeed / HoverboardConfig.RIDE_WALKSPEED) * HoverboardConfig.PITCH_ANGLE
		pitchAngleDeg = math.clamp(pitchAngleDeg, -HoverboardConfig.PITCH_ANGLE, HoverboardConfig.PITCH_ANGLE)

		-- Apply Synchronized Feet Weld C0 Offset & Pitch/Bank Dynamic Lean Physics
		if boardModel and rootPart then
			local weld = rootPart:FindFirstChild("HoverWeld") :: Weld?
			
			if weld then
				local pitchRad = math.rad(-pitchAngleDeg)
				local bankRad = math.rad(currentBankAngle + treadmillBankSway)
				local baseStanceCFrame = CFrame.new(0, -2.5, 0) 
				weld.C0 = baseStanceCFrame * CFrame.Angles(pitchRad, 0, bankRad)
			end
			
			-- Aerodynamic Wind Breaking Particles Control
			local windAttachment = rootPart:FindFirstChild("WindAttachment") :: Attachment?
			local windParticles = windAttachment and windAttachment:FindFirstChild("WindParticles") :: ParticleEmitter?
			if windParticles then
				if _G.lastWindBoostState ~= isBoosting then
					_G.lastWindBoostState = isBoosting
					if isBoosting then
						windParticles.Rate = 110
						windParticles.Speed = NumberRange.new(40, 65)
					else
						windParticles.Rate = 0
					end
				end
			end

			-- Steady non-flashing thruster lighting (Optimized to assign properties only once)
			if not _G.boardLightsCached or _G.boardLightsCachedModel ~= boardModel then
				_G.boardLightsCached = {}
				_G.boardLightsCachedModel = boardModel
				for _, desc in ipairs(boardModel:GetDescendants()) do
					if desc:IsA("PointLight") then
						desc.Brightness = 2.5
						desc.Range = 8
						table.insert(_G.boardLightsCached, desc)
					end
				end
			end
		end
	end

	local targetChar = nil
	if isSpectating then
		if Camera and Camera.CameraSubject then
			local subj = Camera.CameraSubject
			if subj:IsA("Humanoid") and subj.Parent then
				targetChar = subj.Parent
			elseif subj:IsA("BasePart") and subj.Parent then
				targetChar = subj.Parent
			end
		end
	else
		targetChar = Character
	end

	local displaySpeed = currentSpeed or 0
	local displayBoost = isBoosting
	local displayGauge = boosterGauge
	
	if isSpectating and targetChar then
		local tHrp = targetChar:FindFirstChild("HumanoidRootPart") :: BasePart?
		if tHrp then
			hrp = tHrp
			local vel = tHrp.AssemblyLinearVelocity
			displaySpeed = Vector3.new(vel.X, 0, vel.Z).Magnitude
		end
		displayBoost = targetChar:GetAttribute("IsBoosting") or false
		displayGauge = targetChar:GetAttribute("BoosterGauge") or 0
		
		-- Synchronize target's hoverboard wind particle emitter
		local targetWind = targetChar:FindFirstChild("WindParticles", true) :: ParticleEmitter?
		if targetWind then
			if displayBoost then
				targetWind.Rate = 110
				targetWind.Speed = NumberRange.new(40, 65)
			else
				targetWind.Rate = 0
			end
		end

		if guiScreen then
			guiScreen.Enabled = true
		end
	else
		-- Sync our local state to server
		if isMounted and syncSpectatorRemote then
			pcall(function()
				syncSpectatorRemote:FireServer(isBoosting, boosterGauge, currentSpeed)
			end)
		end
	end

	-- 3. Dynamic Arcade Chase Camera facing forward down track towards Signal Lights Arch
	if Camera then
		local targetOnTreadmill = false
		if isSpectating and targetChar then
			local tPlayer = Players:GetPlayerFromCharacter(targetChar)
			if tPlayer then
				targetOnTreadmill = tPlayer:GetAttribute("OnTreadmill")
			end
		else
			targetOnTreadmill = LocalPlayer:GetAttribute("OnTreadmill")
		end

		if targetOnTreadmill then
			if not _G.wasOnTreadmill then
				_G.wasOnTreadmill = true
				Camera.CameraType = Enum.CameraType.Custom
				
				-- 트레드밀 카메라: 초기 탑승 시에만 카메라 각도를 강제로 한 번 잡아줍니다.
				-- 이후에는 Custom 모드이므로 유저가 마우스 우클릭으로 자유롭게 화면을 돌릴 수 있습니다.
				local hrpPos = hrp.Position
				local baseCamPos = hrpPos + Vector3.new(0, 4, 12)
				local targetLook = hrpPos + Vector3.new(0, 2, -10)
				Camera.CFrame = CFrame.lookAt(baseCamPos, targetLook)
			end
		else
			_G.wasOnTreadmill = false
			Camera.CameraType = Enum.CameraType.Scriptable
			local targetCameraFOV = displayBoost and HoverboardConfig.BOOSTER_FOV or defaultFOV + (math.clamp(displaySpeed / HoverboardConfig.RIDE_WALKSPEED, 0, 1) * 10)
			Camera.FieldOfView += (targetCameraFOV - Camera.FieldOfView) * math.clamp(deltaTime * 8, 0, 1)

		-- 카메라와 캐릭터의 위치가 어긋나면서 발생하는 시각적 떨림(Lerp Jitter) 해결
		-- 위치는 정확히 고정하고, 바라보는 방향(wDir)만 부드럽게 보간(Lerp)합니다.
		local targetWDir = hrp.CFrame.RightVector
		if isSpectating then
			-- Spectators just use the target's raw look direction to avoid getting stuck if physics replicates weirdly
			targetWDir = hrp.CFrame.LookVector:Cross(Vector3.new(0,1,0)).Unit
		end
		
		-- 스턴 상태일 때는 캐릭터가 회전하더라도 시점이 같이 돌아가지 않도록 고정
		if isStunned and not isSpectating then
			if not _G.stunCamDir then _G.stunCamDir = _G.smoothCamDir or targetWDir end
			targetWDir = _G.stunCamDir
		else
			_G.stunCamDir = nil
		end
		
		if not _G.smoothCamDir then _G.smoothCamDir = targetWDir end
		_G.smoothCamDir = _G.smoothCamDir:Lerp(targetWDir, math.clamp(deltaTime * 10, 0, 1)).Unit
		
		local wDir = _G.smoothCamDir

		local baseCamDist = 16.0 + (_G.userZoomOffset or 0)
		local targetCamDist = baseCamDist
		local targetCamHeight = 6.5 + ((_G.userZoomOffset or 0) * 0.3) -- 줌아웃 할수록 시야가 살짝 높아짐
		
		if _G.introCamDist then
			local lerpSpeed = 1.2
			_G.introCamDist = _G.introCamDist + (targetCamDist - _G.introCamDist) * math.clamp(deltaTime * lerpSpeed, 0, 1)
			_G.introCamHeight = _G.introCamHeight + (targetCamHeight - _G.introCamHeight) * math.clamp(deltaTime * lerpSpeed, 0, 1)
			
			if math.abs(_G.introCamDist - targetCamDist) < 0.1 then
				_G.introCamDist = nil
				_G.introCamHeight = nil
			end
		end

		local camDist = _G.introCamDist or targetCamDist
		local camHeight = _G.introCamHeight or targetCamHeight
		
		local desiredCamPos = hrp.Position - (wDir * camDist) + Vector3.new(0, camHeight, 0)
		
		-- 🛡️ 벽 충돌 방지 (Raycast)
		local headPos = hrp.Position + Vector3.new(0, 1.5, 0)
		local rayDir = desiredCamPos - headPos
		
		local ignoreList = {character}
		if targetChar then table.insert(ignoreList, targetChar) end
		-- 다른 플레이어들과 겹칠 때 시점이 튀지 않도록 모두 예외 처리
		for _, p in ipairs(Players:GetPlayers()) do
			if p.Character then table.insert(ignoreList, p.Character) end
		end

		local maxPierces = 5
		local currentOrigin = headPos
		local currentDir = rayDir
		
		for i = 1, maxPierces do
			local rayParams = RaycastParams.new()
			rayParams.FilterDescendantsInstances = ignoreList
			rayParams.FilterType = Enum.RaycastFilterType.Exclude
			rayParams.IgnoreWater = true
			
			local wallCheck = Workspace:Raycast(currentOrigin, currentDir, rayParams)
			if wallCheck then
				local hitPart = wallCheck.Instance
				-- 투명벽(가이드라인)이거나 충돌이 없는 이펙트/장식 등은 무시합니다.
				if hitPart.Transparency >= 0.9 or not hitPart.CanCollide then
					table.insert(ignoreList, hitPart)
					-- 뚫고 지나가서 남은 거리만큼 다시 레이캐스트
					currentOrigin = wallCheck.Position + (currentDir.Unit * 0.01)
					currentDir = desiredCamPos - currentOrigin
					if currentDir.Magnitude < 0.1 then break end
				else
					-- 시야를 가리는 진짜 벽에 부딪힘
					desiredCamPos = wallCheck.Position - (rayDir.Unit * 0.5)
					break
				end
			else
				break
			end
		end
		
		local lookAtTarget = hrp.Position + (wDir * 25.0) + Vector3.new(0, -7.0, 0)

		Camera.CFrame = CFrame.lookAt(desiredCamPos, lookAtTarget)

		if isBoosting then
			local shakeIntensity = 1.2 -- Increased amplitude!
			local shakeX = (math.random() - 0.5) * shakeIntensity
			local shakeY = (math.random() - 0.5) * shakeIntensity
			local shakeZ = (math.random() - 0.5) * (shakeIntensity * 0.5)
			Camera.CFrame = Camera.CFrame * CFrame.Angles(math.rad(shakeX), math.rad(shakeY), math.rad(shakeZ))
		end
		end
	end

	-- ----------------------------------------------------
	-- ⏱️ 4. UPDATE RACE TIMER & LAPS (TOP-RIGHT)
	-- ----------------------------------------------------
	if timerLabel then
		if raceStartTime > 0 and not isFinished then
			local elapsed = math.max(0, os.clock() - raceStartTime)
			local mins = math.floor(elapsed / 60)
			local secs = math.floor(elapsed % 60)
			local cs = math.floor((elapsed * 100) % 100)
			timerLabel.Text = string.format("TIME  %02d:%02d:%02d", mins, secs, cs)
		elseif raceStartTime == 0 then
			timerLabel.Text = "TIME  00:00:00"
		end
	end

	if lapNumLabel and not isFinished then
		lapNumLabel.Text = string.format("%d / %d LAPS", currentLap, totalLaps)
	end

	-- ----------------------------------------------------
	-- 🏎️ 5. UPDATE BOTTOM-CENTER SPEEDOMETER
	-- ----------------------------------------------------
	local displayKmh = displaySpeed

	if speedNumLabel then
		speedNumLabel.Text = string.format("%.1f Km/s", displayKmh)
		if displayBoost then
			speedNumLabel.TextColor3 = Color3.fromRGB(255, 215, 0) -- Gold Number during Boost!
		else
			speedNumLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		end
	end

	-- ----------------------------------------------------
	-- 🚀 6. UPDATE NITRO BOOSTER BAR & MODE LABEL
	-- ----------------------------------------------------
	if boosterFillBar then
		local pct = math.clamp(boosterGauge / HoverboardConfig.BOOSTER_MAX_GAUGE, 0, 1)
		boosterFillBar.Size = boosterFillBar.Size:Lerp(UDim2.new(pct, 0, 1, 0), math.clamp(deltaTime * 15, 0, 1))
	end

	if speedModeLabel then
		if displayBoost then
			speedModeLabel.Text = "🔥 BOOSTING! 🔥"
			speedModeLabel.TextColor3 = Color3.fromRGB(255, 100, 50)
			if boosterGaugeStroke then boosterGaugeStroke.Color = Color3.fromRGB(255, 100, 50) end
		elseif displayGauge >= HoverboardConfig.BOOSTER_MAX_GAUGE then
			-- Flash effect
			local flash = (math.floor(os.clock() * 8) % 2 == 0)
			if flash then
				speedModeLabel.Text = "⚡ SPACE ⚡"
				speedModeLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
				if boosterGaugeStroke then boosterGaugeStroke.Color = Color3.fromRGB(255, 255, 0) end
			else
				speedModeLabel.Text = "⚡ READY"
				speedModeLabel.TextColor3 = Color3.fromRGB(0, 240, 255)
				if boosterGaugeStroke then boosterGaugeStroke.Color = Color3.fromRGB(255, 200, 100) end
			end
		else
			speedModeLabel.Text = ""
			if boosterGaugeStroke then boosterGaugeStroke.Color = Color3.fromRGB(255, 200, 100) end
		end
	end
	
	-- 7. "wind force 3" Camera VFX Toggle
	local cameraVFX = Camera:FindFirstChild("CameraBoostVFX")
	if not cameraVFX and (isMounted or isSpectating) then
		local vfxSource = ReplicatedStorage:FindFirstChild("wind force 3")
		if vfxSource and vfxSource:IsA("BasePart") then
			local vfxClone = vfxSource:Clone()
			vfxClone.Name = "CameraBoostVFX"
			vfxClone.Massless = true
			vfxClone.CanCollide = false
			vfxClone.Anchored = true
			vfxClone:SetAttribute("OriginalRotation", vfxSource.CFrame - vfxSource.Position)
			vfxClone.Transparency = 1
			for _, desc in ipairs(vfxClone:GetDescendants()) do
				if desc:IsA("ParticleEmitter") or desc:IsA("Trail") or desc:IsA("Beam") then
					desc.Enabled = false
				end
			end
			vfxClone.Parent = Camera
			cameraVFX = vfxClone
		end
	end

	if cameraVFX then
		local activeBoost = displayBoost
		if activeBoost then
			local origRot = cameraVFX:GetAttribute("OriginalRotation")
			if origRot then
				cameraVFX.CFrame = Camera.CFrame * origRot
			else
				cameraVFX.CFrame = Camera.CFrame
			end
		end
		
		if activeBoost ~= _G.lastBoostingState then
			_G.lastBoostingState = activeBoost
			for _, desc in ipairs(cameraVFX:GetDescendants()) do
				if desc:IsA("ParticleEmitter") or desc:IsA("Beam") or desc:IsA("Trail") then
					desc.Enabled = activeBoost
				end
			end
		end
	end
	
	-- 8. 🐛 UPDATE PHYSICS DEBUG HUD (Jitter Spike Detector)
	if not _G.lastVel then _G.lastVel = hrp.AssemblyLinearVelocity end
	
	local pos = hrp.Position
	local vel = hrp.AssemblyLinearVelocity
	local deltaVel = vel - _G.lastVel
	
	-- Jitter logging removed
	
	_G.lastVel = vel
end)

-- 📡 Handle spectator mode exit: restore Camera and disable HUD
LocalPlayer:GetAttributeChangedSignal("IsSpectating"):Connect(function()
	local isSpec = LocalPlayer:GetAttribute("IsSpectating") == true
	if not isSpec and not isMounted then
		if Camera then
			Camera.CameraType = Enum.CameraType.Custom
			local char = LocalPlayer.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hum then
				Camera.CameraSubject = hum
			end
			local cameraVFX = Camera:FindFirstChild("CameraBoostVFX")
			if cameraVFX then
				for _, desc in ipairs(cameraVFX:GetDescendants()) do
					if desc:IsA("ParticleEmitter") or desc:IsA("Beam") or desc:IsA("Trail") then
						desc.Enabled = false
					end
				end
			end
		end
		if guiScreen then
			guiScreen.Enabled = false
		end
	end
end)

-- 📡 Handle IsRacing attribute changes: if race ends or player retired (DNF), return to Lounge mode cleanly
LocalPlayer:GetAttributeChangedSignal("IsRacing"):Connect(function()
	local isRacing = LocalPlayer:GetAttribute("IsRacing") == true
	if not isRacing then
		isMounted = false
		isBoosting = false
		isRaceStarted = false
		currentBoardModel = nil
		if guiScreen then
			guiScreen.Enabled = false
		end
		if Camera then
			Camera.CameraType = Enum.CameraType.Custom
			local char = LocalPlayer.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hum then
				Camera.CameraSubject = hum
				hum.AutoRotate = true
				hum.WalkSpeed = 16
				hum.HipHeight = 2.0
				hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
			end
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp then
				local gyro = hrp:FindFirstChild("SteeringGyro")
				if gyro then gyro:Destroy() end
			end
			local cameraVFX = Camera:FindFirstChild("CameraBoostVFX")
			if cameraVFX then
				for _, desc in ipairs(cameraVFX:GetDescendants()) do
					if desc:IsA("ParticleEmitter") or desc:IsA("Beam") or desc:IsA("Trail") then
						desc.Enabled = false
					end
				end
			end
			TweenService:Create(Camera, TweenInfo.new(0.3), { FieldOfView = defaultFOV }):Play()
		end
		if playerControls and playerControls.Enable then
			playerControls:Enable()
		end
	end
end)

LocalPlayer.CharacterAdded:Connect(function(newChar)
	if not LocalPlayer:GetAttribute("IsRacing") then
		isMounted = false
		isBoosting = false
		isRaceStarted = false
		currentBoardModel = nil
		if guiScreen then
			guiScreen.Enabled = false
		end
		if Camera then
			Camera.CameraType = Enum.CameraType.Custom
			local hum = newChar:WaitForChild("Humanoid", 5) :: Humanoid?
			if hum then
				Camera.CameraSubject = hum
				hum.AutoRotate = true
				hum.WalkSpeed = 16
				hum.HipHeight = 2.0
				hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
			end
			local hrp = newChar:WaitForChild("HumanoidRootPart", 5) :: BasePart?
			if hrp then
				local gyro = hrp:FindFirstChild("SteeringGyro")
				if gyro then gyro:Destroy() end
			end
			TweenService:Create(Camera, TweenInfo.new(0.3), { FieldOfView = defaultFOV }):Play()
		end
		if playerControls and playerControls.Enable then
			playerControls:Enable()
		end
	end
end)

local function showBoosterToast()
	-- 부스터 발동 메시지는 더 이상 표시하지 않습니다. (유저 요청)
end

-- Trigger One-Tap Continuous Booster on Spacebar press
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or not isMounted then return end
	if input.KeyCode == HoverboardConfig.BOOSTER_KEY or input.KeyCode == Enum.KeyCode.Space then
		if not isBoosting and boosterGauge >= HoverboardConfig.BOOSTER_MIN_TO_USE then
			isBoosting = true
			showBoosterToast()
		end
	end
end)

local mobileBoosterEvent = remotesFolder:FindFirstChild("MobileBoosterEvent")
if not mobileBoosterEvent then
	mobileBoosterEvent = Instance.new("BindableEvent")
	mobileBoosterEvent.Name = "MobileBoosterEvent"
	mobileBoosterEvent.Parent = remotesFolder
end

mobileBoosterEvent.Event:Connect(function()
	if not isMounted then return end
	if not isBoosting and boosterGauge >= HoverboardConfig.BOOSTER_MIN_TO_USE then
		isBoosting = true
		showBoosterToast()
	end
end)

-- ----------------------------------------------------
-- 🚦 5-SECOND RACE START COUNTDOWN UI OVERLAY (3, 2, 1, GO!)
-- ----------------------------------------------------
local countdownRemote = remotesFolder:WaitForChild("StartCountdownSignal") :: RemoteEvent
local countdownTextLabel: TextLabel? = nil

local function getOrCreateCountdownUI(): TextLabel
	if countdownTextLabel and countdownTextLabel.Parent then
		return countdownTextLabel
	end

	if not guiScreen then
		createHUDUI()
	end

	countdownTextLabel = Instance.new("TextLabel")
	countdownTextLabel.Name = "RaceStartCountdownLabel"
	countdownTextLabel.Size = UDim2.new(0, 400, 0, 150)
	countdownTextLabel.Position = UDim2.new(0.5, -200, 0.32, 0)
	countdownTextLabel.BackgroundTransparency = 1
	countdownTextLabel.Font = Enum.Font.GothamBlack
	countdownTextLabel.Text = ""
	countdownTextLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	countdownTextLabel.TextSize = 110
	countdownTextLabel.ZIndex = 50
	countdownTextLabel.Parent = guiScreen

	local cStroke = Instance.new("UIStroke")
	cStroke.Name = "CountStroke"
	cStroke.Color = Color3.fromRGB(0, 0, 0)
	cStroke.Thickness = 5.0
	cStroke.Parent = countdownTextLabel

	return countdownTextLabel
end

countdownRemote.OnClientEvent:Connect(function(count: number)
	if count == 5 then
		isFinished = false
		-- Also clear any existing FINISHED text if it exists
		local existingFinish = guiScreen and guiScreen:FindFirstChild("FinishText")
		if existingFinish then existingFinish:Destroy() end
	end
	
	local label = getOrCreateCountdownUI()
	label.Visible = true
	label.TextTransparency = 0

	local cStroke = label:FindFirstChildOfClass("UIStroke")
	if cStroke then
		cStroke.Enabled = true
		cStroke.Transparency = 0
	end

	if count == 5 or count == 4 then
		label.Text = "GET READY!"
		label.TextColor3 = Color3.fromRGB(255, 215, 0)
		label.TextSize = 65
	elseif count == 3 then
		label.Text = "3"
		label.TextColor3 = Color3.fromRGB(255, 40, 40) -- 🔴 Red
		label.TextSize = 130
	elseif count == 2 then
		label.Text = "2"
		label.TextColor3 = Color3.fromRGB(255, 200, 30) -- 🟡 Yellow
		label.TextSize = 130
	elseif count == 1 then
		label.Text = "1"
		label.TextColor3 = Color3.fromRGB(40, 255, 80) -- 🟢 Green
		label.TextSize = 130

	elseif count == 0 then
		label.Text = "GO! 🏁"
		label.TextColor3 = Color3.fromRGB(0, 240, 255) -- ⚡ Cyan/Gold GO!
		label.TextSize = 110

		-- ⏱️ RECORD TIMER STARTS AT GO!
		raceStartTime = os.clock()
		-- 🏁 UNLOCK MOVEMENT AT GO!
		isRaceStarted = true

		-- Fade out GO! text after 1.5 seconds
		task.delay(1.5, function()
			if label and label.Text == "GO! 🏁" then
				TweenService:Create(label, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
				if cStroke then
					TweenService:Create(cStroke, TweenInfo.new(0.5), { Transparency = 1 }):Play()
				end
			end
		end)
	end

	-- Scale Pop Animation on each second tick
	label.Size = UDim2.new(0, 460, 0, 170)
	TweenService:Create(label, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 400, 0, 150)
	}):Play()
end)

-- Handle MouseWheel Zoom
UserInputService.InputChanged:Connect(function(input, gameProcessed)
	if gameProcessed or not isMounted then return end
	if input.UserInputType == Enum.UserInputType.MouseWheel then
		if not _G.userZoomOffset then _G.userZoomOffset = 0 end
		-- Scroll up (Position.Z > 0) -> Zoom In (negative offset)
		-- Scroll down (Position.Z < 0) -> Zoom Out (positive offset)
		_G.userZoomOffset = math.clamp(_G.userZoomOffset - (input.Position.Z * 2.5), -6, 20)
	end
end)

-- Trigger One-Tap Continuous Booster on Spacebar press
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or not isMounted or not isRaceStarted then return end
	if input.KeyCode == HoverboardConfig.BOOSTER_KEY or input.KeyCode == Enum.KeyCode.Space then
		if not isBoosting and boosterGauge >= HoverboardConfig.BOOSTER_MIN_TO_USE then
			isBoosting = true
		end
	end
end)

print("🏁 [HoverboardController] 신호등 3, 2, 1, GO! 카운트다운 UI 및 연출 구축 완료!")

-- Setup LapUpdated listener
local lapUpdatedRemote = remotesFolder:WaitForChild("LapUpdated") :: RemoteEvent
if lapUpdatedRemote then
	lapUpdatedRemote.OnClientEvent:Connect(function(newLap, newTotal)
		currentLap = newLap
		totalLaps = newTotal
		if lapNumLabel then
			lapNumLabel.Text = string.format("%d / %d LAPS", currentLap, totalLaps)
		end
	end)
end

-- Setup RaceFinished listener
local raceFinishedRemote = remotesFolder:WaitForChild("RaceFinished") :: RemoteEvent
if raceFinishedRemote then
	raceFinishedRemote.OnClientEvent:Connect(function(finishTime, finalLap, totalLaps, finalRank)
		isRaceStarted = false
		isFinished = true
		currentLap = totalLaps
		totalLaps = totalLaps
		
		if lapNumLabel then
			lapNumLabel.Text = string.format("%d / %d LAPS", totalLaps, totalLaps)
		end
		
		-- [DEBUG] Track player state to find out why WASD breaks!
		task.spawn(function()
			for i = 1, 15 do
				task.wait(1)
				local char = LocalPlayer.Character
				if char then
					local hum = char:FindFirstChildOfClass("Humanoid")
					local hrp = char:FindFirstChild("HumanoidRootPart")
					if hum and hrp then
						print(string.format("[DEBUG-WASD] Time: %d | WalkSpeed: %.1f | State: %s | HipHeight: %.1f | Anchored: %s | isMounted: %s | hasBoard: %s | IsRacing: %s",
							i, hum.WalkSpeed, tostring(hum:GetState()), hum.HipHeight, tostring(hrp.Anchored), tostring(isMounted), 
							tostring(char:FindFirstChild("EquippedHoverboard") ~= nil), tostring(LocalPlayer:GetAttribute("IsRacing"))
						))
					end
				end
			end
		end)
		
		if timerLabel and finalRank ~= 999 then
			local mins = math.floor(finishTime / 60)
			local secs = math.floor(finishTime % 60)
			local cs = math.floor((finishTime * 100) % 100)
			timerLabel.Text = string.format("TIME  %02d:%02d:%02d", mins, secs, cs)
		end
		
		-- Show brief personal rank UI for 2 seconds
		local myRankLabel = Instance.new("TextLabel")
		myRankLabel.Name = "MyRankPopUp"
		myRankLabel.Size = UDim2.new(1, 0, 0, 100)
		myRankLabel.Position = UDim2.new(0, 0, 0.4, 0)
		myRankLabel.BackgroundTransparency = 1
		myRankLabel.Font = Enum.Font.GothamBlack
		
		if finalRank == 999 then
			myRankLabel.Text = "DNF"
			myRankLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
		else
			local rankStr = finalRank .. "st"
			if finalRank == 2 then rankStr = "2nd"
			elseif finalRank == 3 then rankStr = "3rd"
			elseif finalRank > 3 then rankStr = finalRank .. "th" end
			myRankLabel.Text = "YOUR RANK: " .. rankStr
			myRankLabel.TextColor3 = Color3.fromRGB(255, 200, 50)
		end
		
		myRankLabel.TextSize = 60
		myRankLabel.ZIndex = 100
		
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(0, 0, 0)
		stroke.Thickness = 4
		stroke.Parent = myRankLabel
		
		if guiScreen then
			myRankLabel.Parent = guiScreen
		end
		
		TweenService:Create(myRankLabel, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.new(1, 0, 0, 120),
			TextSize = 80
		}):Play()
		
		task.delay(2, function()
			if myRankLabel then
				local tw = TweenService:Create(myRankLabel, TweenInfo.new(0.3), {TextTransparency = 1})
				if stroke then
					TweenService:Create(stroke, TweenInfo.new(0.3), {Transparency = 1}):Play()
				end
				tw:Play()
				tw.Completed:Connect(function()
					myRankLabel:Destroy()
				end)
			end
		end)		
		-- Stop movement by dismounting and locking ONLY for active racers finishing on track
		if LocalPlayer:GetAttribute("IsRacing") and finalRank ~= 999 then
			dismountRemote:FireServer()
			local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.WalkSpeed = 0
				hum.JumpPower = 0
			end
		end
	end)
end

-- =========================================================================
-- 🚨 SUDDEN DEATH & SCOREBOARD UI
-- =========================================================================
local suddenDeathLabel = nil

local suddenDeathRemote = remotesFolder:WaitForChild("SuddenDeathUpdate") :: RemoteEvent
if suddenDeathRemote then
	suddenDeathRemote.OnClientEvent:Connect(function(timeLeft)
		if not suddenDeathLabel then
			suddenDeathLabel = Instance.new("TextLabel")
			suddenDeathLabel.Name = "SuddenDeathText"
			suddenDeathLabel.Size = UDim2.new(1, 0, 0, 100)
			suddenDeathLabel.Position = UDim2.new(0, 0, 0.7, 0)
			suddenDeathLabel.BackgroundTransparency = 1
			suddenDeathLabel.Font = Enum.Font.GothamBlack
			suddenDeathLabel.TextColor3 = Color3.fromRGB(255, 60, 60)
			suddenDeathLabel.TextSize = 60
			suddenDeathLabel.ZIndex = 20
			
			local stroke = Instance.new("UIStroke")
			stroke.Color = Color3.fromRGB(0, 0, 0)
			stroke.Thickness = 4
			stroke.Parent = suddenDeathLabel
			
			if guiScreen then
				suddenDeathLabel.Parent = guiScreen
			end
		end
		
		if timeLeft > 0 then
			suddenDeathLabel.Text = "SUDDEN DEATH: " .. timeLeft
		else
			suddenDeathLabel:Destroy()
			suddenDeathLabel = nil
		end
	end)
end

local showScoreboardRemote = remotesFolder:WaitForChild("ShowScoreboard") :: RemoteEvent
if showScoreboardRemote then
	showScoreboardRemote.OnClientEvent:Connect(function(results)
		if suddenDeathLabel then
			suddenDeathLabel:Destroy()
			suddenDeathLabel = nil
		end
		
		-- Background Darken
		local bg = Instance.new("Frame")
		bg.Size = UDim2.new(1, 0, 1, 0)
		bg.BackgroundColor3 = Color3.new(0, 0, 0)
		bg.BackgroundTransparency = 0.5
		bg.ZIndex = 50
		bg.Parent = guiScreen
		
		local panel = Instance.new("Frame")
		panel.Size = UDim2.new(0, 600, 0, 520)
		panel.AnchorPoint = Vector2.new(0.5, 0.5)
		panel.Position = UDim2.new(0.5, 0, 0.5, 0)
		panel.BackgroundColor3 = Color3.fromRGB(150, 240, 255)
		panel.BackgroundTransparency = 0.5
		panel.ZIndex = 51
		panel.Parent = bg
		
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = panel
		
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(0, 0, 0)
		stroke.Thickness = 4
		stroke.Parent = panel
		
		-- Title
		local title = Instance.new("TextLabel")
		title.Size = UDim2.new(1, 0, 0, 60)
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.GothamBlack
		title.Text = "RACE RESULTS"
		title.TextColor3 = Color3.fromRGB(40, 180, 255)
		title.TextSize = 36
		title.ZIndex = 52
		title.Parent = panel
		
		local titleStroke = Instance.new("UIStroke")
		titleStroke.Color = Color3.fromRGB(0, 0, 0)
		titleStroke.Thickness = 3
		titleStroke.Parent = title
		
		-- Scroll Frame for results
		local scroll = Instance.new("ScrollingFrame")
		scroll.Size = UDim2.new(1, -20, 1, -80)
		scroll.Position = UDim2.new(0, 10, 0, 70)
		scroll.BackgroundTransparency = 1
		scroll.ScrollBarThickness = 6
		scroll.ZIndex = 52
		scroll.Parent = panel
		
		local layout = Instance.new("UIListLayout")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Padding = UDim.new(0, 5)
		layout.Parent = scroll
		
		for i, data in ipairs(results) do
			local item = Instance.new("Frame")
			item.Size = UDim2.new(1, -10, 0, 40)
			item.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			item.BackgroundTransparency = 0.2
			item.ZIndex = 53
			item.Parent = scroll
			
			local itemCorner = Instance.new("UICorner")
			itemCorner.CornerRadius = UDim.new(0, 6)
			itemCorner.Parent = item
			
			local itemStroke = Instance.new("UIStroke")
			itemStroke.Color = Color3.fromRGB(0, 0, 0)
			itemStroke.Thickness = 2
			itemStroke.Parent = item
			
			local rankText = "DNF"
			local rankColor = Color3.fromRGB(150, 150, 150)
			if data.rank ~= 999 then
				rankText = data.rank .. "st"
				if data.rank == 2 then rankText = "2nd"
				elseif data.rank == 3 then rankText = "3rd"
				elseif data.rank > 3 then rankText = data.rank .. "th" end
				
				if data.rank == 1 then 
					rankColor = Color3.fromRGB(255, 200, 50)
					item.BackgroundColor3 = Color3.fromRGB(255, 250, 200)
				elseif data.rank == 2 then 
					rankColor = Color3.fromRGB(210, 220, 230)
					item.BackgroundColor3 = Color3.fromRGB(240, 245, 255)
				elseif data.rank == 3 then 
					rankColor = Color3.fromRGB(205, 127, 50)
				else 
					rankColor = Color3.fromRGB(255, 255, 255) 
				end
			end
			
			-- Highlight local player's row
			local isMe = (data.name == LocalPlayer.Name or data.name == LocalPlayer.DisplayName)
			if isMe then
				itemStroke.Color = Color3.fromRGB(255, 80, 80)
				itemStroke.Thickness = 3
				item.BackgroundColor3 = Color3.fromRGB(255, 240, 180)
				item.BackgroundTransparency = 0.1
			end
			
			local rLabel = Instance.new("TextLabel")
			rLabel.Size = UDim2.new(0, 60, 1, 0)
			rLabel.Position = UDim2.new(0, 10, 0, 0)
			rLabel.BackgroundTransparency = 1
			rLabel.Font = Enum.Font.GothamBold
			rLabel.Text = rankText
			rLabel.TextColor3 = rankColor
			rLabel.TextSize = 20
			rLabel.TextXAlignment = Enum.TextXAlignment.Left
			rLabel.ZIndex = 54
			rLabel.Parent = item
			
			local rStroke = Instance.new("UIStroke")
			rStroke.Color = Color3.fromRGB(0, 0, 0)
			rStroke.Thickness = 2
			rStroke.Parent = rLabel
			
			local nLabel = Instance.new("TextLabel")
			nLabel.Size = UDim2.new(0, 180, 1, 0)
			nLabel.Position = UDim2.new(0, 80, 0, 0)
			nLabel.BackgroundTransparency = 1
			nLabel.Font = Enum.Font.GothamSemibold
			nLabel.Text = data.name
			nLabel.TextColor3 = Color3.new(1, 1, 1)
			nLabel.TextSize = 20
			nLabel.TextXAlignment = Enum.TextXAlignment.Left
			nLabel.ZIndex = 54
			nLabel.Parent = item
			
			local nStroke = Instance.new("UIStroke")
			nStroke.Color = Color3.fromRGB(0, 0, 0)
			nStroke.Thickness = 2
			nStroke.Parent = nLabel
			
			local tLabel = Instance.new("TextLabel")
			tLabel.Size = UDim2.new(0, 100, 1, 0)
			tLabel.Position = UDim2.new(0, 270, 0, 0)
			tLabel.BackgroundTransparency = 1
			tLabel.Font = Enum.Font.RobotoMono
			tLabel.Text = data.time
			tLabel.TextColor3 = Color3.new(1, 1, 1)
			tLabel.TextSize = 18
			tLabel.TextXAlignment = Enum.TextXAlignment.Right
			tLabel.ZIndex = 54
			tLabel.Parent = item
			
			local tStroke = Instance.new("UIStroke")
			tStroke.Color = Color3.fromRGB(0, 0, 0)
			tStroke.Thickness = 2
			tStroke.Parent = tLabel
			
			local gLabel = Instance.new("TextLabel")
			gLabel.Size = UDim2.new(0, 80, 1, 0)
			gLabel.Position = UDim2.new(0, 390, 0, 0)
			gLabel.BackgroundTransparency = 1
			gLabel.Font = Enum.Font.GothamBold
			gLabel.Text = (data.gold > 0) and ("+" .. data.gold .. "G") or "-"
			gLabel.TextColor3 = Color3.fromRGB(255, 200, 50)
			gLabel.TextSize = 20
			gLabel.TextXAlignment = Enum.TextXAlignment.Right
			gLabel.ZIndex = 54
			gLabel.Parent = item
			
			local gStroke = Instance.new("UIStroke")
			gStroke.Color = Color3.fromRGB(0, 0, 0)
			gStroke.Thickness = 2
			gStroke.Parent = gLabel
			
			-- 획득 골드가 있을 경우 본인이면 애니메이션 예약
			if isMe and data.gold > 0 then
				local hud = playerGui:FindFirstChild("GoldDisplayHUD")
				if hud then
					-- 즉시 업데이트를 막기 위해 일시정지 플래그 설정
					hud:SetAttribute("PauseGoldUpdate", true)
				end
				
				task.delay(1.5, function()
					-- 결과창이 열리고 1.5초 뒤에 튀어나오기 시작
					if gLabel and gLabel.Parent then
						local goldTarget = getGoldTarget()
						if goldTarget then
							local startPos = Vector2.new(gLabel.AbsolutePosition.X + (gLabel.AbsoluteSize.X / 2), gLabel.AbsolutePosition.Y + (gLabel.AbsoluteSize.Y / 2))
							spawnGoldEffect(startPos, goldTarget, data.rank)
						end
					end
					
					-- 튀어나온 뒤 날아가기 시작하는 타이밍(0.5초 후)에 골드 올라가는 애니메이션 시작 (언포즈)
					task.delay(0.5, function()
						if hud then
							hud:SetAttribute("PauseGoldUpdate", false)
						end
					end)
				end)
			end
		end
		
		scroll.CanvasSize = UDim2.new(0, 0, 0, #results * 45)
		
		-- =========================================================================
		-- 📱 RESPONSIVE UI SCALING
		-- =========================================================================
		local uiScale = Instance.new("UIScale", panel)
		local function updateResponsiveScale()
			local viewport = workspace.CurrentCamera.ViewportSize
			if viewport.X == 0 or viewport.Y == 0 then return end
			local scale = math.min(viewport.X / 1280, viewport.Y / 720)
			uiScale.Scale = math.clamp(scale, 0.4, 1.1)
		end
		local resizeConn = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveScale)
		updateResponsiveScale()
		
		-- Destroy after 7 seconds
		task.delay(7.5, function()
			if resizeConn then resizeConn:Disconnect() end
			if bg and bg.Parent then
				bg:Destroy()
			end
		end)
	end)
end
