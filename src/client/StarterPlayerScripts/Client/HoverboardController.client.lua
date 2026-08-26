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

	-- Leaderboard Card 1 (Current Player)
	local pCard1 = Instance.new("Frame")
	pCard1.Name = "PlayerCard1"
	pCard1.Size = UDim2.new(1, 0, 0, 26)
	pCard1.Position = UDim2.new(0, 0, 0, 54)
	pCard1.BackgroundColor3 = Color3.fromRGB(20, 25, 35)
	pCard1.BackgroundTransparency = 0.2
	pCard1.BorderSizePixel = 0
	pCard1.ZIndex = 11
	pCard1.Parent = topLeftFrame

	local card1Corner = Instance.new("UICorner")
	card1Corner.CornerRadius = UDim.new(0, 6)
	card1Corner.Parent = pCard1

	local card1Stroke = Instance.new("UIStroke")
	card1Stroke.Color = Color3.fromRGB(255, 200, 30)
	card1Stroke.Thickness = 1.5
	card1Stroke.Parent = pCard1

	leaderNameLabel1 = Instance.new("TextLabel")
	leaderNameLabel1.Name = "P1Name"
	leaderNameLabel1.Size = UDim2.new(1, -12, 1, 0)
	leaderNameLabel1.Position = UDim2.new(0, 8, 0, 0)
	leaderNameLabel1.BackgroundTransparency = 1
	leaderNameLabel1.Font = Enum.Font.GothamBold
	leaderNameLabel1.Text = "1  " .. LocalPlayer.DisplayName
	leaderNameLabel1.TextColor3 = Color3.fromRGB(255, 230, 120)
	leaderNameLabel1.TextSize = 13
	leaderNameLabel1.TextXAlignment = Enum.TextXAlignment.Left
	leaderNameLabel1.ZIndex = 12
	leaderNameLabel1.Parent = pCard1

	-- Leaderboard Card 2 (Rival)
	local pCard2 = Instance.new("Frame")
	pCard2.Name = "PlayerCard2"
	pCard2.Size = UDim2.new(0.9, 0, 0, 24)
	pCard2.Position = UDim2.new(0, 0, 0, 84)
	pCard2.BackgroundColor3 = Color3.fromRGB(15, 18, 26)
	pCard2.BackgroundTransparency = 0.3
	pCard2.BorderSizePixel = 0
	pCard2.ZIndex = 11
	pCard2.Parent = topLeftFrame

	local card2Corner = Instance.new("UICorner")
	card2Corner.CornerRadius = UDim.new(0, 6)
	card2Corner.Parent = pCard2

	local card2Label = Instance.new("TextLabel")
	card2Label.Name = "P2Name"
	card2Label.Size = UDim2.new(1, -12, 1, 0)
	card2Label.Position = UDim2.new(0, 8, 0, 0)
	card2Label.BackgroundTransparency = 1
	card2Label.Font = Enum.Font.GothamBold
	card2Label.Text = "2  Rival_Racer"
	card2Label.TextColor3 = Color3.fromRGB(180, 190, 205)
	card2Label.TextSize = 12
	card2Label.TextXAlignment = Enum.TextXAlignment.Left
	card2Label.ZIndex = 12
	card2Label.Parent = pCard2

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
	timerLabel.Font = Enum.Font.GothamBlack
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

createHUDUI()

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

		if playerControls and playerControls.Enable then
			playerControls:Enable()
		end

		if Camera then
			Camera.CameraType = Enum.CameraType.Custom
			TweenService:Create(Camera, TweenInfo.new(0.4), { FieldOfView = defaultFOV }):Play()
		end
	end
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

		local currentPos = hrp.Position
		hrp.CFrame = CFrame.new(currentPos) * CFrame.Angles(0, currentHeadingYaw, 0)

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
			local wDir = Vector3.zero
			if frontLED and rearLED then
				local forwardDir = (frontLED.Position - rearLED.Position).Unit
				wDir = CFrame.Angles(0, math.rad(-90), 0) * forwardDir
			else
				wDir = hrp.CFrame.RightVector
			end

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

	-- 1. Sine wave bobbing
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
			local baseStanceCFrame = CFrame.new(0, -3.25, 0)
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

		local wDir = Vector3.zero
		if frontLED and rearLED then
			local forwardDir = (frontLED.Position - rearLED.Position).Unit
			wDir = CFrame.Angles(0, math.rad(-90), 0) * forwardDir
		else
			wDir = hrp.CFrame.RightVector
		end

		local camDist = 16.0
		local camHeight = 6.5
		local desiredCamPos = hrp.Position - (wDir * camDist) + Vector3.new(0, camHeight, 0)
		local lookAtTarget = hrp.Position + (wDir * 25.0) + Vector3.new(0, 3.5, 0)

		local targetCamCFrame = CFrame.lookAt(desiredCamPos, lookAtTarget)
		Camera.CFrame = Camera.CFrame:Lerp(targetCamCFrame, math.clamp(deltaTime * 14, 0, 1))

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
		if raceStartTime > 0 then
			local elapsed = math.max(0, os.clock() - raceStartTime)
			local mins = math.floor(elapsed / 60)
			local secs = math.floor(elapsed % 60)
			local cs = math.floor((elapsed * 100) % 100)
			timerLabel.Text = string.format("TIME  %02d:%02d:%02d", mins, secs, cs)
		else
			timerLabel.Text = "TIME  00:00:00"
		end
	end

	if lapNumLabel then
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

		-- ⏱️ RECORD TIMER STARTS AT COUNT == 1!
		raceStartTime = os.clock()
	elseif count == 0 then
		label.Text = "GO! 🏁"
		label.TextColor3 = Color3.fromRGB(0, 240, 255) -- ⚡ Cyan/Gold GO!
		label.TextSize = 110

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
