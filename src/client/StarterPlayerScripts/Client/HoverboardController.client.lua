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

local remotesFolder = ReplicatedStorage:WaitForChild("HoverboardRemotes")
local mountRemote = remotesFolder:WaitForChild("MountRequest") :: RemoteEvent
local dismountRemote = remotesFolder:WaitForChild("DismountRequest") :: RemoteEvent
local stateRemote = remotesFolder:WaitForChild("StateChanged") :: RemoteEvent

local isMounted = false
local isRaceStarted = false
local isFinished = false
local currentBoardModel: Model? = nil
local currentBankAngle = 0
local currentHeadingYaw = 0
local defaultFOV = 70
local targetFOV = 70
local currentWalkSpeed = 0.0
local currentSteerRate = 0.0 -- Damped steering turn rate for smooth cornering and auto-straightening

-- Nitro Booster State Variables
local boosterGauge = 100.0 -- 0% to 100%
local isBoosting = false

-- Race State Variables
local raceStartTime = 0.0
local currentLap = 1
local totalLaps = 2

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
local boosterTextLabel: TextLabel? = nil
local speedLinesFrame: Frame? = nil
local boosterGaugeStroke: UIStroke? = nil

-- Create Authentic Arcade Racing Layout HUD UI
local function createHUDUI()
	if guiScreen then guiScreen:Destroy() end

	guiScreen = Instance.new("ScreenGui")
	guiScreen.Name = "HoverboardHUD"
	guiScreen.ResetOnSpawn = false
	guiScreen.DisplayOrder = 10
	guiScreen.Parent = playerGui

	-- 1. FullScreen Radial Speed Lines Frame for Wind FX
	speedLinesFrame = Instance.new("Frame")
	speedLinesFrame.Name = "SpeedLinesFX"
	speedLinesFrame.Size = UDim2.new(1, 0, 1, 0)
	speedLinesFrame.Position = UDim2.new(0, 0, 0, 0)
	speedLinesFrame.BackgroundTransparency = 1
	speedLinesFrame.BorderSizePixel = 0
	speedLinesFrame.ZIndex = 1
	speedLinesFrame.Parent = guiScreen

	local speedStroke = Instance.new("UIStroke")
	speedStroke.Color = Color3.fromRGB(220, 245, 255)
	speedStroke.Thickness = 14
	speedStroke.Transparency = 1.0
	speedStroke.Parent = speedLinesFrame

	-- =========================================================================
	-- 🏁 [1] TOP-LEFT: RANK BADGE & LEADERBOARD LIST
	-- =========================================================================
	local topLeftFrame = Instance.new("Frame")
	topLeftFrame.Name = "TopLeftRankFrame"
	topLeftFrame.Size = UDim2.new(0, 260, 0, 120)
	topLeftFrame.Position = UDim2.new(0.02, 0, 0.03, 0)
	topLeftFrame.BackgroundTransparency = 1
	topLeftFrame.ZIndex = 10
	topLeftFrame.Parent = guiScreen

	-- Giant Gold 3D "1st" Rank Badge
	rankBadgeLabel = Instance.new("TextLabel")
	rankBadgeLabel.Name = "RankBadge"
	rankBadgeLabel.Size = UDim2.new(0, 120, 0, 50)
	rankBadgeLabel.Position = UDim2.new(0, 0, 0, 0)
	rankBadgeLabel.BackgroundTransparency = 1
	rankBadgeLabel.Font = Enum.Font.GothamBlack
	rankBadgeLabel.Text = "1st"
	rankBadgeLabel.TextColor3 = Color3.fromRGB(255, 205, 30)
	rankBadgeLabel.TextSize = 48
	rankBadgeLabel.TextXAlignment = Enum.TextXAlignment.Left
	rankBadgeLabel.ZIndex = 12
	rankBadgeLabel.Parent = topLeftFrame

	local rankStroke = Instance.new("UIStroke")
	rankStroke.Color = Color3.fromRGB(0, 0, 0)
	rankStroke.Thickness = 3.0
	rankStroke.Parent = rankBadgeLabel

	-- =========================================================================
	-- 🏁 DYNAMIC LEADERBOARD SYSTEM
	-- =========================================================================
	local leaderboardContainer = Instance.new("Frame")
	leaderboardContainer.Name = "LeaderboardContainer"
	leaderboardContainer.Size = UDim2.new(1, 0, 0, 300)
	leaderboardContainer.Position = UDim2.new(0, 0, 0, 54)
	leaderboardContainer.BackgroundTransparency = 1
	leaderboardContainer.ZIndex = 11
	leaderboardContainer.Parent = topLeftFrame

	-- Dictionary to hold player cards
	local playerCardFrames = {}

	local function getRankSuffix(rank)
		if rank == 1 then return "1st" end
		if rank == 2 then return "2nd" end
		if rank == 3 then return "3rd" end
		return rank .. "th"
	end

	local function createPlayerCard(playerName, isLocal)
		local pCard = Instance.new("Frame")
		pCard.Name = "Card_" .. playerName
		pCard.Size = UDim2.new(isLocal and 1 or 0.9, 0, 0, isLocal and 26 or 24)
		pCard.BackgroundColor3 = isLocal and Color3.fromRGB(20, 25, 35) or Color3.fromRGB(15, 18, 26)
		pCard.BackgroundTransparency = isLocal and 0.2 or 0.3
		pCard.BorderSizePixel = 0
		pCard.ZIndex = 11
		-- Initialize position off-screen or at 0
		pCard.Position = UDim2.new(0, 0, 0, 0)
		pCard.Parent = leaderboardContainer

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = pCard

		if isLocal then
			local stroke = Instance.new("UIStroke")
			stroke.Color = Color3.fromRGB(255, 200, 30)
			stroke.Thickness = 1.5
			stroke.Parent = pCard
		end

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "NameLabel"
		nameLabel.Size = UDim2.new(1, -12, 1, 0)
		nameLabel.Position = UDim2.new(0, 8, 0, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextColor3 = isLocal and Color3.fromRGB(255, 230, 120) or Color3.fromRGB(180, 190, 205)
		nameLabel.TextSize = isLocal and 13 or 12
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.ZIndex = 12
		nameLabel.Parent = pCard

		return { frame = pCard, label = nameLabel }
	end

	local function updateRankings(sortedPlayerNames, isStartingLine)
		for rank, pName in ipairs(sortedPlayerNames) do
			if not playerCardFrames[pName] then
				playerCardFrames[pName] = createPlayerCard(pName, pName == LocalPlayer.DisplayName)
			end
			local cardData = playerCardFrames[pName]
			
			local displayRank = isStartingLine and "-" or tostring(rank)
			cardData.label.Text = displayRank .. "  " .. pName
			
			local targetY = (rank - 1) * 30
			local targetPos = UDim2.new(0, 0, 0, targetY)
			
			-- Smooth animation
			TweenService:Create(cardData.frame, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = targetPos }):Play()
			
			-- Update top badge if it's me
			if pName == LocalPlayer.DisplayName then
				rankBadgeLabel.Text = isStartingLine and "-" or getRankSuffix(rank)
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
	topRightFrame.Size = UDim2.new(0, 240, 0, 100)
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
	-- 🏎️ [3] BOTTOM-RIGHT: TACHOMETER ARC GAUGE + DIGITAL SPEEDOMETER
	-- =========================================================================
	local bottomRightFrame = Instance.new("Frame")
	bottomRightFrame.Name = "BottomRightSpeedometer"
	bottomRightFrame.Size = UDim2.new(0, 200, 0, 170)
	bottomRightFrame.Position = UDim2.new(0.97, -200, 0.95, -170)
	bottomRightFrame.BackgroundColor3 = Color3.fromRGB(10, 14, 22)
	bottomRightFrame.BackgroundTransparency = 0.12
	bottomRightFrame.BorderSizePixel = 0
	bottomRightFrame.ZIndex = 10
	bottomRightFrame.Parent = guiScreen

	local bCorner = Instance.new("UICorner")
	bCorner.CornerRadius = UDim.new(0, 22)
	bCorner.Parent = bottomRightFrame

	local bStroke = Instance.new("UIStroke")
	bStroke.Color = Color3.fromRGB(0, 230, 255)
	bStroke.Thickness = 2.5
	bStroke.Parent = bottomRightFrame

	-- Speedometer Outer Circular Arc Ring Frame
	local arcRing = Instance.new("Frame")
	arcRing.Name = "ArcRing"
	arcRing.Size = UDim2.new(0.86, 0, 0.86, 0)
	arcRing.Position = UDim2.new(0.07, 0, 0.07, 0)
	arcRing.BackgroundTransparency = 1
	arcRing.ZIndex = 11
	arcRing.Parent = bottomRightFrame

	local arcRingStroke = Instance.new("UIStroke")
	arcRingStroke.Color = Color3.fromRGB(0, 240, 255)
	arcRingStroke.Thickness = 6.0
	arcRingStroke.Transparency = 0.1
	arcRingStroke.Parent = arcRing

	arcFillGradient = Instance.new("UIGradient")
	arcFillGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 240, 255)),
		ColorSequenceKeypoint.new(0.7, Color3.fromRGB(255, 200, 0)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 50, 50)),
	})
	arcFillGradient.Parent = arcRingStroke

	-- Unit Label: km/h
	local unitLabel = Instance.new("TextLabel")
	unitLabel.Name = "KmLabel"
	unitLabel.Size = UDim2.new(1, 0, 0, 20)
	unitLabel.Position = UDim2.new(0, 0, 0.22, 0)
	unitLabel.BackgroundTransparency = 1
	unitLabel.Font = Enum.Font.GothamBold
	unitLabel.Text = "km/h"
	unitLabel.TextColor3 = Color3.fromRGB(160, 230, 255)
	unitLabel.TextSize = 14
	unitLabel.ZIndex = 12
	unitLabel.Parent = bottomRightFrame

	-- Digital Speed Number in Center (e.g., 90)
	speedNumLabel = Instance.new("TextLabel")
	speedNumLabel.Name = "DigitalSpeedNum"
	speedNumLabel.Size = UDim2.new(1, 0, 0, 56)
	speedNumLabel.Position = UDim2.new(0, 0, 0.35, 0)
	speedNumLabel.BackgroundTransparency = 1
	speedNumLabel.Font = Enum.Font.GothamBlack
	speedNumLabel.Text = "0"
	speedNumLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	speedNumLabel.TextSize = 44
	speedNumLabel.ZIndex = 13
	speedNumLabel.Parent = bottomRightFrame

	local dNumStroke = Instance.new("UIStroke")
	dNumStroke.Color = Color3.fromRGB(0, 0, 0)
	dNumStroke.Thickness = 2.5
	dNumStroke.Parent = speedNumLabel

	-- Mode Badge Label below number
	speedModeLabel = Instance.new("TextLabel")
	speedModeLabel.Name = "ModeBadge"
	speedModeLabel.Size = UDim2.new(1, 0, 0, 20)
	speedModeLabel.Position = UDim2.new(0, 0, 0.74, 0)
	speedModeLabel.BackgroundTransparency = 1
	speedModeLabel.Font = Enum.Font.GothamBold
	speedModeLabel.Text = "⚡ READY"
	speedModeLabel.TextColor3 = Color3.fromRGB(0, 240, 255)
	speedModeLabel.TextSize = 12
	speedModeLabel.ZIndex = 12
	speedModeLabel.Parent = bottomRightFrame

	-- =========================================================================
	-- 🚀 [4] BOTTOM-CENTER: HORIZONTAL NITRO BOOSTER GAUGE BAR
	-- =========================================================================
	local boosterGaugeBg = Instance.new("Frame")
	boosterGaugeBg.Name = "BottomCenterBoosterGauge"
	boosterGaugeBg.Size = UDim2.new(0, 380, 0, 34)
	boosterGaugeBg.Position = UDim2.new(0.5, -190, 0.91, 0) -- Bottom-Center horizontal bar!
	boosterGaugeBg.BackgroundColor3 = Color3.fromRGB(8, 12, 18)
	boosterGaugeBg.BackgroundTransparency = 0.1
	boosterGaugeBg.BorderSizePixel = 0
	boosterGaugeBg.ClipsDescendants = true
	boosterGaugeBg.ZIndex = 11
	boosterGaugeBg.Parent = guiScreen

	local gaugeCorner = Instance.new("UICorner")
	gaugeCorner.CornerRadius = UDim.new(0, 10)
	gaugeCorner.Parent = boosterGaugeBg

	boosterGaugeStroke = Instance.new("UIStroke")
	boosterGaugeStroke.Color = Color3.fromRGB(0, 240, 255)
	boosterGaugeStroke.Thickness = 2.0
	boosterGaugeStroke.Transparency = 0.0
	boosterGaugeStroke.Parent = boosterGaugeBg

	-- High-Contrast Gradient Booster Fill Bar
	boosterFillBar = Instance.new("Frame")
	boosterFillBar.Name = "FillBar"
	boosterFillBar.Size = UDim2.new(1, 0, 1, 0)
	boosterFillBar.Position = UDim2.new(0, 0, 0, 0)
	boosterFillBar.BackgroundColor3 = Color3.fromRGB(0, 240, 255)
	boosterFillBar.BackgroundTransparency = 0
	boosterFillBar.BorderSizePixel = 0
	boosterFillBar.ZIndex = 12
	boosterFillBar.Parent = boosterGaugeBg

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 10)
	fillCorner.Parent = boosterFillBar

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 215, 0)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 240, 255)),
	})
	gradient.Parent = boosterFillBar

	-- Bold High-Contrast Text Overlay
	boosterTextLabel = Instance.new("TextLabel")
	boosterTextLabel.Name = "BoosterText"
	boosterTextLabel.Size = UDim2.new(1, 0, 1, 0)
	boosterTextLabel.Position = UDim2.new(0, 0, 0, 0)
	boosterTextLabel.BackgroundTransparency = 1
	boosterTextLabel.Font = Enum.Font.GothamBlack
	boosterTextLabel.Text = "⚡ BOOST READY 100% [PRESS SPACE]"
	boosterTextLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	boosterTextLabel.TextSize = 13
	boosterTextLabel.ZIndex = 15
	boosterTextLabel.Parent = boosterGaugeBg

	local textStroke = Instance.new("UIStroke")
	textStroke.Color = Color3.fromRGB(0, 0, 0)
	textStroke.Thickness = 2.0
	textStroke.Transparency = 0.0
	textStroke.Parent = boosterTextLabel

	guiScreen.Enabled = false
end

-- =========================================================================
-- 🐛 REALTIME PHYSICS DEBUGGER HUD
-- =========================================================================
local debugLabel: TextLabel? = nil

local function getOrCreateDebugUI()
	if debugLabel and debugLabel.Parent then return debugLabel end
	if not guiScreen then return nil end
	
	debugLabel = Instance.new("TextLabel")
	debugLabel.Name = "PhysicsDebugLabel"
	debugLabel.Size = UDim2.new(0, 400, 0, 100)
	debugLabel.Position = UDim2.new(0, 10, 0.4, 0)
	debugLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	debugLabel.BackgroundTransparency = 0.5
	debugLabel.Font = Enum.Font.RobotoMono
	debugLabel.Text = "Awaiting Debug Data..."
	debugLabel.TextColor3 = Color3.fromRGB(0, 255, 100)
	debugLabel.TextSize = 14
	debugLabel.TextXAlignment = Enum.TextXAlignment.Left
	debugLabel.TextYAlignment = Enum.TextYAlignment.Top
	debugLabel.ZIndex = 100
	debugLabel.Parent = guiScreen
	return debugLabel
end

createHUDUI()
getOrCreateDebugUI()

local skaterJoints = {}

-- Handle Server State Changes & Steering Initialization
stateRemote.OnClientEvent:Connect(function(mounted: boolean, boardModel: Model?)
	isMounted = mounted
	currentBoardModel = boardModel
	boosterGauge = 100.0
	isBoosting = false
	currentWalkSpeed = 0.0
	currentSteerRate = 0.0
	isRaceStarted = false
	raceStartTime = 0.0 -- Timer will start when countdown reaches 1!

	if guiScreen then
		guiScreen.Enabled = mounted
	end

	if mounted then
		local character = LocalPlayer.Character
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		if hum then
			hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
		end

		task.defer(function()
			local char = LocalPlayer.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			
			-- Cache joints for procedural skater animation
			if char then
				skaterJoints.Waist = char:FindFirstChild("Waist", true)
				skaterJoints.RightShoulder = char:FindFirstChild("RightShoulder", true)
				skaterJoints.LeftShoulder = char:FindFirstChild("LeftShoulder", true)
				skaterJoints.RightElbow = char:FindFirstChild("RightElbow", true)
				skaterJoints.LeftElbow = char:FindFirstChild("LeftElbow", true)
				skaterJoints.RightHip = char:FindFirstChild("RightHip", true)
				skaterJoints.LeftHip = char:FindFirstChild("LeftHip", true)
				skaterJoints.RightKnee = char:FindFirstChild("RightKnee", true)
				skaterJoints.LeftKnee = char:FindFirstChild("LeftKnee", true)
			end
			
			if hrp then
				local currentPos = hrp.Position
				-- Keep the orientation set by the Server's GameLoopManager teleport
				local _, ry, _ = hrp.CFrame:ToOrientation()
				currentHeadingYaw = ry
				local trackForwardDir = Vector3.new(0, 0, 1)

				if Camera then
					Camera.CameraType = Enum.CameraType.Scriptable
					Camera.CFrame = CFrame.lookAt(currentPos - trackForwardDir * 16 + Vector3.new(0, 6.5, 0), currentPos + trackForwardDir * 25 + Vector3.new(0, 3.5, 0))
				end
			end
		end)
	else
		isBoosting = false
		isRaceStarted = false
		local character = LocalPlayer.Character
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.AutoRotate = true
			hum.WalkSpeed = 16
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
	if not isMounted then return end

	-- Lean into turns dynamically based on steer rate
	local leanFactor = currentSteerRate * 0.35 

	-- Apply custom Transform to joints to override Idle animation
	if skaterJoints.Waist then skaterJoints.Waist.Transform = CFrame.Angles(math.rad(-18), leanFactor, leanFactor * 0.5) end
	if skaterJoints.RightShoulder then skaterJoints.RightShoulder.Transform = CFrame.Angles(math.rad(45), 0, math.rad(20)) end
	if skaterJoints.LeftShoulder then skaterJoints.LeftShoulder.Transform = CFrame.Angles(math.rad(45), 0, math.rad(-20)) end
	if skaterJoints.RightElbow then skaterJoints.RightElbow.Transform = CFrame.Angles(math.rad(25), 0, 0) end
	if skaterJoints.LeftElbow then skaterJoints.LeftElbow.Transform = CFrame.Angles(math.rad(25), 0, 0) end
	
	if skaterJoints.RightHip then skaterJoints.RightHip.Transform = CFrame.Angles(math.rad(35), 0, math.rad(12)) end
	if skaterJoints.LeftHip then skaterJoints.LeftHip.Transform = CFrame.Angles(math.rad(35), 0, math.rad(-12)) end
	if skaterJoints.RightKnee then skaterJoints.RightKnee.Transform = CFrame.Angles(math.rad(-65), 0, 0) end
	if skaterJoints.LeftKnee then skaterJoints.LeftKnee.Transform = CFrame.Angles(math.rad(-65), 0, 0) end
end)

-- Main Render Loop for Arcade Racing HUD, Hovering Physics, Speedometer, Booster Gauge & Wind FX
RunService.RenderStepped:Connect(function(deltaTime: number)
	if not isMounted then return end

	local character = LocalPlayer.Character
	if not character then return end

	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not hrp or not humanoid then return end

	humanoid.AutoRotate = false

	-- Stop leg flailing animations
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
			if track.Name:lower():find("run") or track.Name:lower():find("walk") then
				track:Stop()
			end
		end
	end

	local velocity = hrp.AssemblyLinearVelocity
	local horizontalVelocity = Vector3.new(velocity.X, 0, velocity.Z)
	local currentSpeed = horizontalVelocity.Magnitude

	-- Prevent Movement & Steering during Start Countdown
	if not isRaceStarted then
		humanoid.WalkSpeed = 0
		humanoid:Move(Vector3.zero, false)
		currentWalkSpeed = 0.0
		isBoosting = false
	else
		-- Movement Inputs
		local isW = UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up)
		local isS = UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down)
		local isBoostKey = UserInputService:IsKeyDown(HoverboardConfig.BOOSTER_KEY) or UserInputService:IsKeyDown(Enum.KeyCode.Space)

		-- Steering Controls
		local isA = UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left)
		local isD = UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right)

		local targetSteerRate = 0.0
		if isA then
			targetSteerRate = isBoosting and math.rad(115) or math.rad(85)
		elseif isD then
			targetSteerRate = isBoosting and -math.rad(115) or -math.rad(85)
		end

		local dampFactor = (targetSteerRate == 0) and 25.0 or 15.0
		currentSteerRate += (targetSteerRate - currentSteerRate) * math.clamp(deltaTime * dampFactor, 0, 1)
		currentHeadingYaw += currentSteerRate * deltaTime

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
			currentWalkSpeed = HoverboardConfig.BOOSTER_WALKSPEED
			if boosterGauge <= 0 then
				isBoosting = false
			end
		else
			local targetSpeed = (isW or isS) and HoverboardConfig.RIDE_WALKSPEED or 0

			if currentWalkSpeed < targetSpeed then
				local accelRate = 36
				currentWalkSpeed = math.min(targetSpeed, currentWalkSpeed + (accelRate * deltaTime))
			elseif currentWalkSpeed > targetSpeed then
				local decelRate = 48
				currentWalkSpeed = math.max(targetSpeed, currentWalkSpeed - (decelRate * deltaTime))
			end

			if (isW or isS) or currentSpeed > 1 then
				boosterGauge = math.min(HoverboardConfig.BOOSTER_MAX_GAUGE, boosterGauge + (HoverboardConfig.BOOSTER_CHARGE_RATE * deltaTime))
			end
		end

		humanoid.WalkSpeed = currentWalkSpeed

		-- Execute Movement
		local boardModel = character:FindFirstChild("EquippedHoverboard") :: Model?
		local rootPart = boardModel and boardModel.PrimaryPart
		local frontLED = boardModel and boardModel:FindFirstChild("FrontLED") :: BasePart?
		local rearLED = boardModel and boardModel:FindFirstChild("RearLED") :: BasePart?

		if rootPart and (isW or isS) then
			local wDir = hrp.CFrame.RightVector

			local moveVector = Vector3.zero
			if isW then
				moveVector = wDir
			elseif isS then
				moveVector = -wDir
			end

			if moveVector.Magnitude > 0 then
				humanoid:Move(moveVector, false)
			end
		else
			humanoid:Move(Vector3.zero, false)
		end
	end

	-- 1. Sine wave bobbing (Re-enabled!)
	local clockTime = os.clock()
	local bobOffset = math.sin(clockTime * HoverboardConfig.BOB_FREQUENCY) * HoverboardConfig.BOB_AMPLITUDE
	humanoid.HipHeight = HoverboardConfig.HOVER_HEIGHT + bobOffset

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
			local bankRad = math.rad(currentBankAngle)
			local baseStanceCFrame = CFrame.new(0, -2.5, 0) -- Adjusted for bent skater knees!
			weld.C0 = baseStanceCFrame * CFrame.Angles(pitchRad, 0, bankRad)
		end
		-- Aerodynamic Wind Breaking Particles Control
		local windAttachment = rootPart:FindFirstChild("WindAttachment") :: Attachment?
		local windParticles = windAttachment and windAttachment:FindFirstChild("WindParticles") :: ParticleEmitter?
		if windParticles then
			if isBoosting then
				windParticles.Rate = 110
				windParticles.Speed = NumberRange.new(40, 65)
			else
				windParticles.Rate = 0
			end
		end

		-- Steady non-flashing thruster lighting
		for _, desc in ipairs(boardModel:GetDescendants()) do
			if desc:IsA("PointLight") then
				desc.Brightness = 2.5
				desc.Range = 8
			end
		end
	end

	-- 3. Dynamic Arcade Chase Camera facing forward down track towards Signal Lights Arch
	if Camera then
		Camera.CameraType = Enum.CameraType.Scriptable
		local targetCameraFOV = isBoosting and HoverboardConfig.BOOSTER_FOV or defaultFOV + (math.clamp(currentSpeed / HoverboardConfig.RIDE_WALKSPEED, 0, 1) * 10)
		Camera.FieldOfView += (targetCameraFOV - Camera.FieldOfView) * math.clamp(deltaTime * 8, 0, 1)

		-- 카메라와 캐릭터의 위치가 어긋나면서 발생하는 시각적 떨림(Lerp Jitter) 해결
		-- 위치는 정확히 고정하고, 바라보는 방향(wDir)만 부드럽게 보간(Lerp)합니다.
		local targetWDir = hrp.CFrame.RightVector
		if not _G.smoothCamDir then _G.smoothCamDir = targetWDir end
		_G.smoothCamDir = _G.smoothCamDir:Lerp(targetWDir, math.clamp(deltaTime * 10, 0, 1)).Unit
		
		local wDir = _G.smoothCamDir

		local camDist = 16.0
		local camHeight = 6.5
		local desiredCamPos = hrp.Position - (wDir * camDist) + Vector3.new(0, camHeight, 0)
		local lookAtTarget = hrp.Position + (wDir * 25.0) + Vector3.new(0, 3.5, 0)

		Camera.CFrame = CFrame.lookAt(desiredCamPos, lookAtTarget)

		if isBoosting then
			local shakeX = (math.random() - 0.5) * 0.08
			local shakeY = (math.random() - 0.5) * 0.08
			Camera.CFrame = Camera.CFrame * CFrame.Angles(math.rad(shakeX), math.rad(shakeY), 0)
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
	-- 🏎️ 5. UPDATE BOTTOM-RIGHT TACHOMETER SPEEDOMETER
	-- ----------------------------------------------------
	local displayKmh = math.floor(currentSpeed * 1.5)

	if speedNumLabel then
		speedNumLabel.Text = tostring(displayKmh)
		if isBoosting then
			speedNumLabel.TextColor3 = Color3.fromRGB(255, 215, 0) -- Gold Number during Boost!
		else
			speedNumLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		end
	end

	if speedModeLabel then
		if isBoosting then
			speedModeLabel.Text = "🔥 NITRO BURST"
			speedModeLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
		elseif displayKmh > 5 then
			speedModeLabel.Text = "🛹 CRUISING"
			speedModeLabel.TextColor3 = Color3.fromRGB(0, 240, 255)
		else
			speedModeLabel.Text = "⚡ READY"
			speedModeLabel.TextColor3 = Color3.fromRGB(180, 240, 255)
		end
	end

	-- ----------------------------------------------------
	-- 🚀 6. UPDATE BOTTOM-CENTER NITRO BOOSTER GAUGE
	-- ----------------------------------------------------
	if boosterFillBar and boosterTextLabel then
		local pct = math.clamp(boosterGauge / HoverboardConfig.BOOSTER_MAX_GAUGE, 0, 1)
		boosterFillBar.Size = UDim2.new(pct, 0, 1, 0)

		if isBoosting then
			boosterTextLabel.Text = string.format("🔥 WIND BURSTING! %d%%", math.floor(boosterGauge))
			boosterTextLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
			if boosterGaugeStroke then
				boosterGaugeStroke.Color = Color3.fromRGB(255, 215, 0)
			end
		elseif boosterGauge >= 99.9 then
			boosterTextLabel.Text = "⚡ BOOST READY 100% [PRESS SPACE]"
			boosterTextLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
			if boosterGaugeStroke then
				boosterGaugeStroke.Color = Color3.fromRGB(0, 240, 255)
			end
		else
			boosterTextLabel.Text = string.format("⚡ CHARGING BOOST... %d%%", math.floor(boosterGauge))
			boosterTextLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
			if boosterGaugeStroke then
				boosterGaugeStroke.Color = Color3.fromRGB(0, 180, 240)
			end
		end
	end

	-- 7. Screen Edge Wind Lines Overlay
	if speedLinesFrame then
		local stroke = speedLinesFrame:FindFirstChildOfClass("UIStroke")
		if stroke then
			local targetTrans = isBoosting and 0.25 or 1.0
			stroke.Transparency += (targetTrans - stroke.Transparency) * math.clamp(deltaTime * 10, 0, 1)
		end
	end
	
	-- 8. 🐛 UPDATE PHYSICS DEBUG HUD (Jitter Spike Detector)
	if not _G.lastVel then _G.lastVel = hrp.AssemblyLinearVelocity end
	
	local pos = hrp.Position
	local vel = hrp.AssemblyLinearVelocity
	local deltaVel = vel - _G.lastVel
	
	-- 만약 1프레임(약 0.016초) 만에 속도가 비정상적으로 튀면(가속도 스파이크) 콘솔에 즉시 출력!
	if deltaVel.Magnitude > 10.0 and currentWalkSpeed > 5 then
		print(string.format(
			"🚨 [JITTER DETECTED!] DeltaVel: %.1f | Pos(X:%.1f, Z:%.1f) | Vel(X:%.1f, Z:%.1f) | Spd:%.1f (Tgt:%.1f) | HipHeight:%.2f",
			deltaVel.Magnitude,
			pos.X, pos.Z,
			vel.X, vel.Z,
			currentSpeed, currentWalkSpeed,
			humanoid.HipHeight
		))
	end
	
	_G.lastVel = vel
end)

-- Trigger One-Tap Continuous Booster on Spacebar press
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or not isMounted then return end
	if input.KeyCode == HoverboardConfig.BOOSTER_KEY or input.KeyCode == Enum.KeyCode.Space then
		if not isBoosting and boosterGauge >= HoverboardConfig.BOOSTER_MIN_TO_USE then
			isBoosting = true
		end
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
		
		if timerLabel and finalRank ~= 999 then
			local mins = math.floor(finishTime / 60)
			local secs = math.floor(finishTime % 60)
			local cs = math.floor((finishTime * 100) % 100)
			timerLabel.Text = string.format("TIME  %02d:%02d:%02d", mins, secs, cs)
		end
		
		-- Show FINISHED or RETIRED UI
		local finishLabel = Instance.new("TextLabel")
		finishLabel.Name = "FinishText"
		finishLabel.Size = UDim2.new(1, 0, 1, 0)
		finishLabel.Position = UDim2.new(0, 0, 0, 0)
		finishLabel.BackgroundTransparency = 1
		finishLabel.Font = Enum.Font.GothamBlack
		
		if finalRank == 999 then
			finishLabel.Text = "RETIRED!\nTime Over"
			finishLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
		else
			finishLabel.Text = "FINISHED!\nRank: " .. finalRank .. "\nTime: " .. string.format("%.2f", finishTime) .. "s"
			finishLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
		end
		
		finishLabel.TextSize = 80
		finishLabel.TextWrapped = true
		
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(0, 0, 0)
		stroke.Thickness = 5
		stroke.Parent = finishLabel
		
		if guiScreen then
			finishLabel.Parent = guiScreen
		end
		
		-- Animate UI
		finishLabel.Size = UDim2.new(1, 0, 0, 0)
		finishLabel.Position = UDim2.new(0, 0, 0.5, 0)
		TweenService:Create(finishLabel, TweenInfo.new(0.5, Enum.EasingStyle.Bounce), {
			Size = UDim2.new(1, 0, 1, 0),
			Position = UDim2.new(0, 0, 0, 0)
		}):Play()
		
		-- Stop movement by dismounting and locking
		dismountRemote:FireServer()
		local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.WalkSpeed = 0
			hum.JumpPower = 0
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
		
		-- Scoreboard Panel
		local panel = Instance.new("Frame")
		panel.Size = UDim2.new(0, 500, 0, 400)
		panel.Position = UDim2.new(0.5, -250, 0.5, -200)
		panel.BackgroundColor3 = Color3.fromRGB(25, 30, 40)
		panel.ZIndex = 51
		panel.Parent = bg
		
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = panel
		
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(255, 200, 0)
		stroke.Thickness = 3
		stroke.Parent = panel
		
		-- Title
		local title = Instance.new("TextLabel")
		title.Size = UDim2.new(1, 0, 0, 60)
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.GothamBlack
		title.Text = "RACE RESULTS"
		title.TextColor3 = Color3.fromRGB(255, 200, 0)
		title.TextSize = 36
		title.ZIndex = 52
		title.Parent = panel
		
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
			item.BackgroundColor3 = Color3.fromRGB(40, 45, 55)
			item.ZIndex = 53
			item.Parent = scroll
			
			local itemCorner = Instance.new("UICorner")
			itemCorner.CornerRadius = UDim.new(0, 6)
			itemCorner.Parent = item
			
			local rankText = "RETIRE"
			local rankColor = Color3.fromRGB(150, 150, 150)
			if data.rank ~= 999 then
				rankText = data.rank .. "st"
				if data.rank == 2 then rankText = "2nd"
				elseif data.rank == 3 then rankText = "3rd"
				elseif data.rank > 3 then rankText = data.rank .. "th" end
				
				if data.rank == 1 then rankColor = Color3.fromRGB(255, 215, 0)
				elseif data.rank == 2 then rankColor = Color3.fromRGB(192, 192, 192)
				elseif data.rank == 3 then rankColor = Color3.fromRGB(205, 127, 50)
				else rankColor = Color3.fromRGB(255, 255, 255) end
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
			
			local tLabel = Instance.new("TextLabel")
			tLabel.Size = UDim2.new(0, 100, 1, 0)
			tLabel.Position = UDim2.new(0, 270, 0, 0)
			tLabel.BackgroundTransparency = 1
			tLabel.Font = Enum.Font.RobotoMono
			tLabel.Text = data.time
			tLabel.TextColor3 = Color3.new(0.8, 0.8, 0.8)
			tLabel.TextSize = 18
			tLabel.TextXAlignment = Enum.TextXAlignment.Right
			tLabel.ZIndex = 54
			tLabel.Parent = item
			
			local gLabel = Instance.new("TextLabel")
			gLabel.Size = UDim2.new(0, 80, 1, 0)
			gLabel.Position = UDim2.new(0, 390, 0, 0)
			gLabel.BackgroundTransparency = 1
			gLabel.Font = Enum.Font.GothamBold
			gLabel.Text = "+" .. data.gold .. "G"
			gLabel.TextColor3 = Color3.fromRGB(255, 230, 0)
			gLabel.TextSize = 20
			gLabel.TextXAlignment = Enum.TextXAlignment.Right
			gLabel.ZIndex = 54
			gLabel.Parent = item
		end
		
		scroll.CanvasSize = UDim2.new(0, 0, 0, #results * 45)
		
		-- Destroy after 7 seconds
		task.delay(7.5, function()
			if bg and bg.Parent then
				bg:Destroy()
			end
		end)
	end)
end
