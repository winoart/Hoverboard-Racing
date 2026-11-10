--!strict
-- LevelBarController.client.luau
-- 하단 레벨 프로그레스 바 (게이지 차오름 연출, 레이싱/대기실 가시성 제어, 레벨업 축포 및 사운드)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RebirthConfig = require(Shared:WaitForChild("RebirthConfig"))

local hoverRemotes = ReplicatedStorage:WaitForChild("HoverboardRemotes")
local requestRebirthRemote = hoverRemotes:WaitForChild("RequestRebirth") :: RemoteFunction

-- 사운드 에셋 프리로드 (즉시 반응형 재생)
task.spawn(function()
	local preloadSound = Instance.new("Sound")
	preloadSound.SoundId = "rbxassetid://8156890810"
	pcall(function()
		ContentProvider:PreloadAsync({ preloadSound })
	end)
	preloadSound:Destroy()
end)

-- =========================================================================
-- 1. UI 생성 (ScreenGui: LevelBarHUD)
-- =========================================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "LevelBarHUD"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 15
screenGui.IgnoreGuiInset = false
screenGui.Parent = PlayerGui

-- 메인 컨테이너 (하단 중앙)
local barContainer = Instance.new("Frame")
barContainer.Name = "BarContainer"
barContainer.Size = UDim2.new(0, 680, 0, 48)
barContainer.Position = UDim2.new(0.5, 0, 1, -22)
barContainer.AnchorPoint = Vector2.new(0.5, 1)
barContainer.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
barContainer.BackgroundTransparency = 0.15
barContainer.Parent = screenGui

local barCorner = Instance.new("UICorner")
barCorner.CornerRadius = UDim.new(0, 16)
barCorner.Parent = barContainer

local barStroke = Instance.new("UIStroke")
barStroke.Color = Color3.fromRGB(0, 0, 0)
barStroke.Thickness = 4
barStroke.Parent = barContainer

-- 내부 게이지 영역 프레임 (여백 4px)
local gaugeTrack = Instance.new("Frame")
gaugeTrack.Name = "GaugeTrack"
gaugeTrack.Size = UDim2.new(1, -8, 1, -8)
gaugeTrack.Position = UDim2.new(0, 4, 0, 4)
gaugeTrack.BackgroundColor3 = Color3.fromRGB(12, 14, 20)
gaugeTrack.BackgroundTransparency = 0.3
gaugeTrack.Parent = barContainer
Instance.new("UICorner", gaugeTrack).CornerRadius = UDim.new(0, 12)

-- 실제 차오르는 게이지 바 (Fill)
local gaugeFill = Instance.new("Frame")
gaugeFill.Name = "GaugeFill"
gaugeFill.Size = UDim2.new(0, 0, 1, 0)
gaugeFill.BackgroundColor3 = Color3.fromRGB(0, 220, 255)
gaugeFill.BorderSizePixel = 0
gaugeFill.ClipsDescendants = true
gaugeFill.Parent = gaugeTrack

local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(0, 12)
fillCorner.Parent = gaugeFill

-- 화려한 그라데이션 (시안 -> 에메랄드 그린 -> 골드)
local fillGradient = Instance.new("UIGradient")
fillGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 210, 255)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(40, 235, 130)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 215, 50)),
})
fillGradient.Parent = gaugeFill

-- 광택/빗살 패턴 이펙트
local patternOverlay = Instance.new("Frame")
patternOverlay.Name = "PatternOverlay"
patternOverlay.Size = UDim2.new(1, 0, 1, 0)
patternOverlay.BackgroundTransparency = 0.85
patternOverlay.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
patternOverlay.BorderSizePixel = 0
patternOverlay.Parent = gaugeFill
Instance.new("UICorner", patternOverlay).CornerRadius = UDim.new(0, 12)

-- 🏷️ 좌측 레벨 배지 (뱃지 스타일)
local levelBadge = Instance.new("Frame")
levelBadge.Name = "LevelBadge"
levelBadge.Size = UDim2.new(0, 116, 1, 6)
levelBadge.Position = UDim2.new(0, -6, 0.5, 0)
levelBadge.AnchorPoint = Vector2.new(0, 0.5)
levelBadge.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
levelBadge.ZIndex = 5
levelBadge.Parent = barContainer

local badgeCorner = Instance.new("UICorner")
badgeCorner.CornerRadius = UDim.new(0, 14)
badgeCorner.Parent = levelBadge

local badgeStroke = Instance.new("UIStroke")
badgeStroke.Color = Color3.fromRGB(0, 0, 0)
badgeStroke.Thickness = 3.5
badgeStroke.Parent = levelBadge

local badgeGradient = Instance.new("UIGradient")
badgeGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 200, 50)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 130, 0)),
})
badgeGradient.Rotation = 90
badgeGradient.Parent = levelBadge

local levelLabel = Instance.new("TextLabel")
levelLabel.Name = "LevelLabel"
levelLabel.Size = UDim2.new(1, 0, 1, 0)
levelLabel.BackgroundTransparency = 1
levelLabel.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
levelLabel.Text = "LV. 1"
levelLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
levelLabel.TextSize = 20
levelLabel.ZIndex = 6
levelLabel.Parent = levelBadge

local lvlTextStroke = Instance.new("UIStroke")
lvlTextStroke.Color = Color3.fromRGB(0, 0, 0)
lvlTextStroke.Thickness = 3
lvlTextStroke.Parent = levelLabel

-- 📊 중앙 퍼센트 라벨
local percentLabel = Instance.new("TextLabel")
percentLabel.Name = "PercentLabel"
percentLabel.Size = UDim2.new(0, 140, 1, 0)
percentLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
percentLabel.AnchorPoint = Vector2.new(0.5, 0.5)
percentLabel.BackgroundTransparency = 1
percentLabel.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
percentLabel.Text = "0%"
percentLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
percentLabel.TextSize = 20
percentLabel.ZIndex = 4
percentLabel.Parent = barContainer

local pctStroke = Instance.new("UIStroke")
pctStroke.Color = Color3.fromRGB(0, 0, 0)
pctStroke.Thickness = 3
pctStroke.Parent = percentLabel

-- 📏 우측 현재거리 / 필요거리 라벨
local distanceLabel = Instance.new("TextLabel")
distanceLabel.Name = "DistanceLabel"
distanceLabel.Size = UDim2.new(0, 240, 1, 0)
distanceLabel.Position = UDim2.new(1, -16, 0.5, 0)
distanceLabel.AnchorPoint = Vector2.new(1, 0.5)
distanceLabel.BackgroundTransparency = 1
distanceLabel.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
distanceLabel.Text = "0 m / 5.0 km"
distanceLabel.TextColor3 = Color3.fromRGB(255, 235, 140)
distanceLabel.TextSize = 17
distanceLabel.TextXAlignment = Enum.TextXAlignment.Right
distanceLabel.ZIndex = 4
distanceLabel.Parent = barContainer

local distStroke = Instance.new("UIStroke")
distStroke.Color = Color3.fromRGB(0, 0, 0)
distStroke.Thickness = 3
distStroke.Parent = distanceLabel

-- 📱 반응형 UI 스케일링
local uiScale = Instance.new("UIScale", barContainer)
local function updateResponsiveScale()
	local camera = workspace.CurrentCamera
	if not camera then return end
	local viewport = camera.ViewportSize
	if viewport.X == 0 or viewport.Y == 0 then return end
	local scale = math.min(viewport.X / 1280, viewport.Y / 720)
	uiScale.Scale = math.clamp(scale, 0.55, 1.1)
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveScale)
task.delay(0.1, updateResponsiveScale)

-- =========================================================================
-- 2. 헬퍼 함수 (포맷팅 & 데이터 조회)
-- =========================================================================
local function formatDistance(meters: number): string
	if meters >= 1000 then
		return string.format("%.1f km", meters / 1000)
	else
		return string.format("%d m", math.floor(meters))
	end
end

local function getPlayerData(): (number, number)
	local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
	if not leaderstats then return 0, 0 end
	local lvlVal = (leaderstats:FindFirstChild("Level") or leaderstats:FindFirstChild("Rebirths")) :: IntValue?
	local distVal = leaderstats:FindFirstChild("Distance") :: IntValue?
	local lvl = lvlVal and lvlVal.Value or 0
	local dist = distVal and distVal.Value or 0
	return lvl, dist
end

-- =========================================================================
-- 3. 축포 & LEVEL UP 알림 연출 시스템 (Confetti & Fireworks)
-- =========================================================================
local isLevelingUp = false

local function playCelebration(newLevel: number)
	-- 사운드 재생 (레벨업 축하 효과음)
	pcall(function()
		local snd = Instance.new("Sound")
		snd.Name = "LevelUpSound"
		snd.SoundId = "rbxassetid://8156890810"
		snd.Volume = 1.0
		snd.Parent = SoundService
		snd:Play()
		snd.Ended:Connect(function() snd:Destroy() end)
	end)

	local celebrateGui = Instance.new("ScreenGui")
	celebrateGui.Name = "LevelUpCelebrationHUD"
	celebrateGui.ResetOnSpawn = false
	celebrateGui.DisplayOrder = 100
	celebrateGui.Parent = PlayerGui

	local rootFrame = Instance.new("Frame")
	rootFrame.Size = UDim2.new(1, 0, 1, 0)
	rootFrame.BackgroundTransparency = 1
	rootFrame.Parent = celebrateGui

	-- 1. 대형 LEVEL UP 팝업 배너
	local banner = Instance.new("Frame")
	banner.Name = "Banner"
	banner.Size = UDim2.new(0, 520, 0, 180)
	banner.Position = UDim2.new(0.5, 0, 0.38, 0)
	banner.AnchorPoint = Vector2.new(0.5, 0.5)
	banner.BackgroundColor3 = Color3.fromRGB(15, 20, 32)
	banner.BackgroundTransparency = 0.1
	banner.Parent = rootFrame
	Instance.new("UICorner", banner).CornerRadius = UDim.new(0, 24)

	local bStroke = Instance.new("UIStroke")
	bStroke.Color = Color3.fromRGB(255, 215, 0)
	bStroke.Thickness = 5
	bStroke.Parent = banner

	local titleTxt = Instance.new("TextLabel")
	titleTxt.Size = UDim2.new(1, 0, 0, 60)
	titleTxt.Position = UDim2.new(0, 0, 0, 18)
	titleTxt.BackgroundTransparency = 1
	titleTxt.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	titleTxt.Text = "✨ LEVEL UP! ✨"
	titleTxt.TextColor3 = Color3.fromRGB(255, 230, 60)
	titleTxt.TextSize = 44
	titleTxt.Parent = banner
	local tSt = Instance.new("UIStroke", titleTxt)
	tSt.Color = Color3.fromRGB(0, 0, 0)
	tSt.Thickness = 4

	local subTxt = Instance.new("TextLabel")
	subTxt.Size = UDim2.new(1, 0, 0, 40)
	subTxt.Position = UDim2.new(0, 0, 0, 80)
	subTxt.BackgroundTransparency = 1
	subTxt.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	subTxt.Text = string.format("Level %d 달성!", newLevel)
	subTxt.TextColor3 = Color3.fromRGB(255, 255, 255)
	subTxt.TextSize = 28
	subTxt.Parent = banner
	local sSt = Instance.new("UIStroke", subTxt)
	sSt.Color = Color3.fromRGB(0, 0, 0)
	sSt.Thickness = 3

	local speedBonusTxt = Instance.new("TextLabel")
	speedBonusTxt.Size = UDim2.new(1, 0, 0, 32)
	speedBonusTxt.Position = UDim2.new(0, 0, 0, 126)
	speedBonusTxt.BackgroundTransparency = 1
	speedBonusTxt.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	speedBonusTxt.Text = string.format("⚡ 부스터 속도 +%.1f km/h 보너스!", newLevel * 1.0)
	speedBonusTxt.TextColor3 = Color3.fromRGB(0, 240, 255)
	speedBonusTxt.TextSize = 20
	speedBonusTxt.Parent = banner
	local spSt = Instance.new("UIStroke", speedBonusTxt)
	spSt.Color = Color3.fromRGB(0, 0, 0)
	spSt.Thickness = 2.5

	-- 배너 바운스 등장 애니메이션
	banner.Size = UDim2.new(0, 0, 0, 0)
	TweenService:Create(banner, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 520, 0, 180)
	}):Play()

	-- 2. 🎊 2D Confetti (색종이 축포) 생성
	local confettiColors = {
		Color3.fromRGB(255, 70, 70),
		Color3.fromRGB(255, 200, 40),
		Color3.fromRGB(40, 230, 120),
		Color3.fromRGB(0, 200, 255),
		Color3.fromRGB(180, 70, 255),
		Color3.fromRGB(255, 120, 220),
	}

	for i = 1, 65 do
		task.spawn(function()
			local piece = Instance.new("Frame")
			local startX = math.random()
			local sizeW = math.random(8, 14)
			local sizeH = math.random(14, 22)
			piece.Size = UDim2.new(0, sizeW, 0, sizeH)
			piece.Position = UDim2.new(startX, 0, -0.05, 0)
			piece.BackgroundColor3 = confettiColors[math.random(1, #confettiColors)]
			piece.BorderSizePixel = 0
			piece.Rotation = math.random(0, 360)
			piece.Parent = rootFrame
			Instance.new("UICorner", piece).CornerRadius = UDim.new(0, 3)

			local fallDuration = math.random(20, 35) / 10
			local endXOffset = (math.random() - 0.5) * 0.25
			local targetX = math.clamp(startX + endXOffset, 0, 1)

			local tweenFall = TweenService:Create(piece, TweenInfo.new(fallDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.new(targetX, 0, 1.05, 0),
				Rotation = piece.Rotation + math.random(360, 720) * (math.random() > 0.5 and 1 or -1)
			})
			tweenFall:Play()
			tweenFall.Completed:Connect(function()
				piece:Destroy()
			end)
		end)
	end

	-- 3. 🎆 화면 좌우 폭죽 스파클 연출
	for burstIdx = 1, 4 do
		task.delay(burstIdx * 0.35, function()
			if not rootFrame.Parent then return end
			local burstX = (burstIdx % 2 == 1) and (0.15 + math.random() * 0.15) or (0.7 + math.random() * 0.15)
			local burstY = 0.25 + math.random() * 0.25
			
			for p = 1, 14 do
				local spark = Instance.new("Frame")
				spark.Size = UDim2.new(0, 10, 0, 10)
				spark.Position = UDim2.new(burstX, 0, burstY, 0)
				spark.AnchorPoint = Vector2.new(0.5, 0.5)
				spark.BackgroundColor3 = confettiColors[math.random(1, #confettiColors)]
				spark.BorderSizePixel = 0
				spark.Parent = rootFrame
				Instance.new("UICorner", spark).CornerRadius = UDim.new(1, 0)
				
				local angle = (p / 14) * math.pi * 2
				local dist = math.random(60, 120)
				local targetX = burstX + (math.cos(angle) * dist) / 1280
				local targetY = burstY + (math.sin(angle) * dist) / 720
				
				TweenService:Create(spark, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Position = UDim2.new(targetX, 0, targetY, 0),
					Size = UDim2.new(0, 0, 0, 0),
					BackgroundTransparency = 1
				}):Play()
				
				task.delay(0.65, function() spark:Destroy() end)
			end
		end)
	end

	-- 3.5초 후 배너 축소 및 전체 GUI 삭제
	task.delay(3.2, function()
		if not banner.Parent then return end
		local fadeTween = TweenService:Create(banner, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, 0, 0.25, 0),
			BackgroundTransparency = 1
		})
		fadeTween:Play()
		fadeTween.Completed:Connect(function()
			celebrateGui:Destroy()
		end)
	end)
end

-- =========================================================================
-- 4. 게이지 차오름 및 실시간 렌더링 컨트롤러
-- =========================================================================
local displayedDist = 0
local isInitialized = false

local function updateLevelBarUI(level: number, currentDist: number, reqDist: number)
	levelLabel.Text = string.format("LV. %d", level)
	
	if reqDist <= 0 then
		-- 최대 레벨
		percentLabel.Text = "MAX"
		distanceLabel.Text = "MAX LEVEL REACHED"
		gaugeFill.Size = UDim2.new(1, 0, 1, 0)
		return
	end
	
	local ratio = math.clamp(currentDist / reqDist, 0, 1)
	local pct = math.floor(ratio * 100)
	percentLabel.Text = string.format("%d%%", pct)
	distanceLabel.Text = string.format("%s / %s", formatDistance(currentDist), formatDistance(reqDist))
	gaugeFill.Size = UDim2.new(ratio, 0, 1, 0)
end

-- 부드러운 거리 카운트업 & 게이지 차오름 애니메이션
local function animateProgressTo(targetDist: number, onComplete: (() -> ())?)
	local level, _ = getPlayerData()
	local nextData = RebirthConfig.GetNextLevelData(level)
	local reqDist = nextData and nextData.RequiredDistance or 5000
	
	local startDist = displayedDist
	local distDiff = targetDist - startDist
	
	if distDiff <= 0 then
		displayedDist = targetDist
		updateLevelBarUI(level, displayedDist, reqDist)
		if onComplete then onComplete() end
		return
	end
	
	local duration = math.clamp(distDiff / 1000 * 0.35, 1.0, 2.8) -- 거리에 비례한 1~2.8초 애니메이션
	local startTime = os.clock()
	
	local connection: RBXScriptConnection? = nil
	connection = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - startTime
		local alpha = math.clamp(elapsed / duration, 0, 1)
		-- 부드러운 OutQuad 이징
		local easedAlpha = 1 - (1 - alpha) * (1 - alpha)
		
		displayedDist = startDist + (distDiff * easedAlpha)
		updateLevelBarUI(level, displayedDist, reqDist)
		
		if alpha >= 1 then
			if connection then connection:Disconnect() end
			displayedDist = targetDist
			updateLevelBarUI(level, displayedDist, reqDist)
			if onComplete then onComplete() end
		end
	end)
end

-- 대기실 진입 시 레벨업 검사 및 게이지 차오름 프로세스
local function processLoungeSync()
	if isLevelingUp then return end
	
	local curLvl, curDist = getPlayerData()
	local nextData = RebirthConfig.GetNextLevelData(curLvl)
	local reqDist = nextData and nextData.RequiredDistance or 5000
	
	-- 1. 현재 축적된 거리까지 스르륵 차오르는 애니메이션 실행
	animateProgressTo(curDist, function()
		-- 2. 애니메이션이 끝난 후, 필요 거리를 채웠는지 확인
		if nextData and curDist >= reqDist then
			isLevelingUp = true
			task.wait(0.3)
			
			-- 서버에 레벨업 요청
			local success, newLevelOrMsg = requestRebirthRemote:InvokeServer()
			if success and type(newLevelOrMsg) == "number" then
				local newLevel = newLevelOrMsg
				print(string.format("🎉 [LevelBar] 레벨업 성공! 새로운 레벨: %d", newLevel))
				
				-- 축포 & 축하 연출
				playCelebration(newLevel)
				
				-- 다음 레벨 데이터로 갱신
				task.wait(0.8)
				local updatedLvl, updatedDist = getPlayerData()
				local updatedNext = RebirthConfig.GetNextLevelData(updatedLvl)
				local updatedReq = updatedNext and updatedNext.RequiredDistance or 5000
				
				-- 새 레벨에서 0부터 잔여 거리까지 다시 부드럽게 세팅
				displayedDist = 0
				updateLevelBarUI(updatedLvl, 0, updatedReq)
				isLevelingUp = false
				
				-- 잔여 거리가 있다면 다음 레벨 게이지로 부드럽게 이어서 차오름!
				if updatedDist > 0 then
					processLoungeSync()
				end
			else
				warn("❌ [LevelBar] 레벨업 실패:", newLevelOrMsg)
				isLevelingUp = false
			end
		end
	end)
end

-- =========================================================================
-- 5. 레이싱 모드 vs 대기실 가시성 감지
-- =========================================================================
local function onGameStateChanged()
	local isRacing = LocalPlayer:GetAttribute("IsRacing") == true
	local isSpectating = LocalPlayer:GetAttribute("IsSpectating") == true
	local inLounge = not (isRacing or isSpectating)
	
	if inLounge then
		screenGui.Enabled = true
		-- 대기실로 돌아왔을 때 부드럽게 아래에서 쓱 올라오는 트윈
		barContainer.Position = UDim2.new(0.5, 0, 1, 40)
		TweenService:Create(barContainer, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, 0, 1, -22)
		}):Play()
		
		-- 대기실 복귀 후 0.4초 딜레이 뒤 게이지 차오름 시작!
		task.delay(0.4, function()
			processLoungeSync()
		end)
	else
		-- 레이싱 진입 시 즉시 숨김
		screenGui.Enabled = false
		local _, curDist = getPlayerData()
		displayedDist = curDist -- 레이싱 시작 시점 거리 기준점 동기화
	end
end

LocalPlayer:GetAttributeChangedSignal("IsRacing"):Connect(onGameStateChanged)
LocalPlayer:GetAttributeChangedSignal("IsSpectating"):Connect(onGameStateChanged)

-- 초기 셋업
task.spawn(function()
	local leaderstats = LocalPlayer:WaitForChild("leaderstats", 15)
	if leaderstats then
		local distVal = leaderstats:WaitForChild("Distance", 10) :: IntValue?
		local lvlVal = (leaderstats:WaitForChild("Level", 10) or leaderstats:WaitForChild("Rebirths", 10)) :: IntValue?
		
		task.wait(0.5)
		local curLvl, curDist = getPlayerData()
		displayedDist = curDist
		local nextData = RebirthConfig.GetNextLevelData(curLvl)
		local reqDist = nextData and nextData.RequiredDistance or 5000
		updateLevelBarUI(curLvl, curDist, reqDist)
		isInitialized = true
		
		-- 리더스탯 변경 감지 (대기실에 있을 때 실시간 업데이트)
		if distVal then
			distVal.Changed:Connect(function(newVal)
				local isRacing = LocalPlayer:GetAttribute("IsRacing") == true
				if not isRacing and isInitialized and not isLevelingUp then
					processLoungeSync()
				end
			end)
		end
		
		if lvlVal then
			lvlVal.Changed:Connect(function(newVal)
				if not isLevelingUp then
					local _, d = getPlayerData()
					local nData = RebirthConfig.GetNextLevelData(newVal)
					local rDist = nData and nData.RequiredDistance or 5000
					updateLevelBarUI(newVal, d, rDist)
				end
			end)
		end
	end
	
	onGameStateChanged()
end)
