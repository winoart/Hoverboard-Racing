--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local remotesFolder = ReplicatedStorage:WaitForChild("HoverboardRemotes")

local toggleAFKRemote = remotesFolder:WaitForChild("ToggleAFK") :: RemoteEvent
local phaseRemote = remotesFolder:WaitForChild("GamePhaseChanged") :: RemoteEvent

local isAFK = false
local isSpectating = false
local currentPhase = "INTERMISSION"

-- 1. Setup AFK UI
local afkGui = Instance.new("ScreenGui")
afkGui.Name = "AFKGui"
afkGui.ResetOnSpawn = false
afkGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
afkGui.DisplayOrder = 100 -- Ensure it's on top of other GUIs
afkGui.Parent = PlayerGui

-- Toggle Button (Bottom Right)
local afkBtn = Instance.new("TextButton")
afkBtn.Name = "AFKButton"
afkBtn.Size = UDim2.new(0, 80, 0, 45)
afkBtn.Position = UDim2.new(1, -20, 1, -100) -- Moved above settings gear
afkBtn.AnchorPoint = Vector2.new(1, 1)
afkBtn.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
afkBtn.Font = Enum.Font.GothamBlack
afkBtn.Text = "AFK OFF"
afkBtn.TextColor3 = Color3.new(1, 1, 1)
afkBtn.TextSize = 18
afkBtn.ZIndex = 1000
afkBtn.Parent = afkGui

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 8)
btnCorner.Parent = afkBtn

local btnStroke = Instance.new("UIStroke")
btnStroke.Color = Color3.new(0, 0, 0)
btnStroke.Thickness = 3
btnStroke.Parent = afkBtn

-- Central Watermark UI
local watermark = Instance.new("TextLabel")
watermark.Name = "AFKWatermark"
watermark.Size = UDim2.new(1, 0, 0, 100)
watermark.Position = UDim2.new(0, 0, 0, 120)
watermark.BackgroundTransparency = 1
watermark.Font = Enum.Font.GothamBlack
watermark.Text = "A.F.K"
watermark.TextColor3 = Color3.fromRGB(255, 255, 255)
watermark.TextTransparency = 1
watermark.TextSize = 120
watermark.ZIndex = 10
watermark.Visible = false
watermark.Parent = afkGui

local wmStroke = Instance.new("UIStroke")
wmStroke.Color = Color3.fromRGB(0, 0, 0)
wmStroke.Thickness = 6
wmStroke.Transparency = 1
wmStroke.Parent = watermark

-- Spectator Status Text
local specText = Instance.new("TextLabel")
specText.Name = "SpectatorStatus"
specText.Size = UDim2.new(1, 0, 0, 50)
specText.Position = UDim2.new(0, 0, 0.1, 0)
specText.BackgroundTransparency = 1
specText.Font = Enum.Font.GothamBold
specText.Text = "관전 중 (Spectating...)"
specText.TextColor3 = Color3.fromRGB(255, 200, 50)
specText.TextSize = 30
specText.Visible = false
specText.ZIndex = 20
specText.Parent = afkGui

local specStroke = Instance.new("UIStroke")
specStroke.Color = Color3.fromRGB(0, 0, 0)
specStroke.Thickness = 3
specStroke.Parent = specText

-- Breathing Animation for Watermark
RunService.RenderStepped:Connect(function()
	if isAFK then
		local time = tick()
		watermark.TextTransparency = 0.4 + math.sin(time * 2) * 0.2
		wmStroke.Transparency = watermark.TextTransparency
	end
end)

-- Update Button Style
local function updateAFKUI()
	if isAFK then
		afkBtn.Text = "AFK ON"
		afkBtn.BackgroundColor3 = Color3.fromRGB(80, 255, 80) -- Bright Green
		watermark.Visible = true
	else
		afkBtn.Text = "AFK OFF"
		afkBtn.BackgroundColor3 = Color3.fromRGB(150, 150, 150) -- Grey
		watermark.Visible = false
		watermark.TextTransparency = 1
		wmStroke.Transparency = 1
	end
end

-- Toggle Event
afkBtn.MouseButton1Click:Connect(function()
	isAFK = not isAFK
	updateAFKUI()
	toggleAFKRemote:FireServer(isAFK)
end)

-- 2. Spectator Logic
local function updateSpectatorMode()
	if currentPhase == "COUNTDOWN" or currentPhase == "RACE" then
		local isRacing = LocalPlayer:GetAttribute("IsRacing")
		if not isRacing then
			-- Start Spectating
			isSpectating = true
			specText.Visible = true
			
			-- Find an active player to spectate
			local targetPlayer = nil
			for _, p in ipairs(Players:GetPlayers()) do
				if p ~= LocalPlayer and p:GetAttribute("IsRacing") and p.Character then
					targetPlayer = p
					break
				end
			end
			
			if targetPlayer and targetPlayer.Character then
				local hum = targetPlayer.Character:FindFirstChildOfClass("Humanoid")
				if hum and Workspace.CurrentCamera then
					Workspace.CurrentCamera.CameraSubject = hum
					specText.Text = "관전 중: " .. targetPlayer.Name
				end
			else
				specText.Text = "관전할 유저가 없습니다."
			end
		else
			isSpectating = false
			specText.Visible = false
			if Workspace.CurrentCamera and LocalPlayer.Character then
				local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
				if hum then
					Workspace.CurrentCamera.CameraSubject = hum
				end
			end
		end
	else
		-- Reset Camera to self when race ends
		isSpectating = false
		specText.Visible = false
		if Workspace.CurrentCamera and LocalPlayer.Character then
			local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
			if hum then
				Workspace.CurrentCamera.CameraSubject = hum
			end
		end
	end
end

phaseRemote.OnClientEvent:Connect(function(phase, timeLeft)
	currentPhase = phase
	updateSpectatorMode()
end)

-- Detect late joining during a race
LocalPlayer:GetAttributeChangedSignal("IsRacing"):Connect(updateSpectatorMode)

-- Periodic Spectator Check in case target player leaves or dies
task.spawn(function()
	while true do
		task.wait(2)
		if isSpectating then
			updateSpectatorMode()
		end
	end
end)

-- 3. Anti-Kick (Jump every 60s while AFK)
task.spawn(function()
	while true do
		task.wait(60)
		if isAFK and LocalPlayer.Character then
			local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
			if hum and hum:GetState() ~= Enum.HumanoidStateType.Dead then
				-- Small jump to bypass anti-idle
				hum.Jump = true
			end
		end
	end
end)

-- 4. Dismount Treadmill with Spacebar
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if input.KeyCode == Enum.KeyCode.Space then
		if LocalPlayer:GetAttribute("OnTreadmill") then
			local exitRemote = remotesFolder:FindFirstChild("ExitTreadmill") :: RemoteEvent?
			if exitRemote then
				exitRemote:FireServer()
			end
		end
	end
end)
