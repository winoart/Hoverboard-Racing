--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local remotesFolder = ReplicatedStorage:WaitForChild("HoverboardRemotes")

local toggleAFKRemote = remotesFolder:WaitForChild("ToggleAFK") :: RemoteEvent
local phaseRemote = remotesFolder:WaitForChild("GamePhaseChanged") :: RemoteEvent

local isAFK = false
local currentPhase = "INTERMISSION"

-- 1. Setup AFK & Spectator UI
local afkGui = Instance.new("ScreenGui")
afkGui.Name = "AFKGui"
afkGui.ResetOnSpawn = false
afkGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
afkGui.DisplayOrder = 100
afkGui.Parent = PlayerGui

-- Toggle Button
local afkBtn = Instance.new("TextButton")
afkBtn.Name = "AFKButton"
afkBtn.Size = UDim2.new(0, 80, 0, 45)
afkBtn.Position = UDim2.new(1, -20, 1, -100)
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

-- Start Spectate Button
local startSpectateBtn = Instance.new("TextButton")
startSpectateBtn.Name = "StartSpectateButton"
startSpectateBtn.Size = UDim2.new(0, 120, 0, 45)
startSpectateBtn.Position = UDim2.new(1, -110, 1, -100) -- Next to AFK button
startSpectateBtn.AnchorPoint = Vector2.new(1, 1)
startSpectateBtn.BackgroundColor3 = Color3.fromRGB(255, 150, 50)
startSpectateBtn.Font = Enum.Font.GothamBlack
startSpectateBtn.Text = "관전하기"
startSpectateBtn.TextColor3 = Color3.new(1, 1, 1)
startSpectateBtn.TextSize = 18
startSpectateBtn.ZIndex = 1000
startSpectateBtn.Visible = false
startSpectateBtn.Parent = afkGui

local specBtnCorner = Instance.new("UICorner")
specBtnCorner.CornerRadius = UDim.new(0, 8)
specBtnCorner.Parent = startSpectateBtn
local specBtnStroke = Instance.new("UIStroke")
specBtnStroke.Color = Color3.new(0, 0, 0)
specBtnStroke.Thickness = 3
specBtnStroke.Parent = startSpectateBtn

-- Spectator Controls ( < , > , X )
local specControlsFrame = Instance.new("Frame")
specControlsFrame.Name = "SpecControlsFrame"
specControlsFrame.Size = UDim2.new(0, 200, 0, 60)
specControlsFrame.Position = UDim2.new(0.5, -100, 1, -135)
specControlsFrame.BackgroundTransparency = 1
specControlsFrame.ZIndex = 2000
specControlsFrame.Visible = false
specControlsFrame.Parent = afkGui

local prevBtn = Instance.new("TextButton")
prevBtn.Size = UDim2.new(0, 50, 0, 50)
prevBtn.Position = UDim2.new(0, 0, 0, 5)
prevBtn.Text = "<"
prevBtn.TextSize = 24
prevBtn.Font = Enum.Font.GothamBlack
prevBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
prevBtn.TextColor3 = Color3.new(1, 1, 1)
prevBtn.ZIndex = 2001
prevBtn.Parent = specControlsFrame

local nextBtn = Instance.new("TextButton")
nextBtn.Size = UDim2.new(0, 50, 0, 50)
nextBtn.Position = UDim2.new(0, 60, 0, 5)
nextBtn.Text = ">"
nextBtn.TextSize = 24
nextBtn.Font = Enum.Font.GothamBlack
nextBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
nextBtn.TextColor3 = Color3.new(1, 1, 1)
nextBtn.ZIndex = 2001
nextBtn.Parent = specControlsFrame

local exitSpecBtn = Instance.new("TextButton")
exitSpecBtn.Size = UDim2.new(0, 50, 0, 50)
exitSpecBtn.Position = UDim2.new(0, 150, 0, 5)
exitSpecBtn.Text = "X"
exitSpecBtn.TextSize = 24
exitSpecBtn.Font = Enum.Font.GothamBlack
exitSpecBtn.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
exitSpecBtn.TextColor3 = Color3.new(1, 1, 1)
exitSpecBtn.ZIndex = 2001
exitSpecBtn.Parent = specControlsFrame

-- Central Watermark UI
local watermark = Instance.new("TextLabel")
watermark.Name = "AFKWatermark"
watermark.Size = UDim2.new(1, 0, 0, 50)
watermark.Position = UDim2.new(0, 0, 0, 120)
watermark.BackgroundTransparency = 1
watermark.Font = Enum.Font.GothamBlack
watermark.Text = "A.F.K"
watermark.TextColor3 = Color3.fromRGB(255, 255, 255)
watermark.TextTransparency = 1
watermark.TextSize = 60
watermark.ZIndex = 10
watermark.Visible = false
watermark.Parent = afkGui

local wmStroke = Instance.new("UIStroke")
wmStroke.Color = Color3.fromRGB(0, 0, 0)
wmStroke.Thickness = 3
wmStroke.Transparency = 1
wmStroke.Parent = watermark

-- Spectator Status Text
local specText = Instance.new("TextLabel")
specText.Name = "SpectatorStatus"
specText.Size = UDim2.new(1, 0, 0, 50)
specText.Position = UDim2.new(0, 0, 0.1, 0)
specText.BackgroundTransparency = 1
specText.Font = Enum.Font.GothamBold
specText.Text = "관전 중..."
specText.TextColor3 = Color3.fromRGB(255, 200, 50)
specText.TextSize = 30
specText.Visible = false
specText.ZIndex = 20
specText.Parent = afkGui
local specStroke = Instance.new("UIStroke")
specStroke.Color = Color3.fromRGB(0, 0, 0)
specStroke.Thickness = 3
specStroke.Parent = specText

RunService.RenderStepped:Connect(function()
	if isAFK then
		local time = tick()
		watermark.TextTransparency = 0.4 + math.sin(time * 2) * 0.2
		wmStroke.Transparency = watermark.TextTransparency
	end
end)

local function updateAFKUI()
	local isRacing = LocalPlayer:GetAttribute("IsRacing")
	if isRacing then
		afkBtn.Visible = false
		startSpectateBtn.Visible = false
		return
	end
	
	afkBtn.Visible = true

	if isAFK then
		afkBtn.Text = "AFK ON"
		afkBtn.BackgroundColor3 = Color3.fromRGB(80, 255, 80)
		watermark.Visible = true
		
		-- 관전 버튼은 레이스 중에만 노출
		if currentPhase == "RACE_MATCH" then
			startSpectateBtn.Visible = not LocalPlayer:GetAttribute("IsSpectating")
		else
			startSpectateBtn.Visible = false
		end
	else
		afkBtn.Text = "AFK OFF"
		afkBtn.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
		watermark.Visible = false
		watermark.TextTransparency = 1
		wmStroke.Transparency = 1
		startSpectateBtn.Visible = false
	end
end

afkBtn.MouseButton1Click:Connect(function()
	isAFK = not isAFK
	updateAFKUI()
	toggleAFKRemote:FireServer(isAFK)
end)

LocalPlayer:GetAttributeChangedSignal("IsRacing"):Connect(updateAFKUI)

-- 2. Spectator Logic
local activeRacers = {}
local currentSpectateIndex = 1

local function refreshRacersList()
	activeRacers = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LocalPlayer and p:GetAttribute("IsRacing") and p.Character then
			table.insert(activeRacers, p)
		end
	end
end

local function applyCameraToTarget()
	if #activeRacers == 0 then
		specText.Text = "관전할 유저가 없습니다."
		if Workspace.CurrentCamera and LocalPlayer.Character then
			local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
			if hum then Workspace.CurrentCamera.CameraSubject = hum end
		end
		return
	end
	
	if currentSpectateIndex > #activeRacers then
		currentSpectateIndex = 1
	elseif currentSpectateIndex < 1 then
		currentSpectateIndex = #activeRacers
	end
	
	local targetPlayer = activeRacers[currentSpectateIndex]
	if targetPlayer and targetPlayer.Character then
		local hum = targetPlayer.Character:FindFirstChildOfClass("Humanoid")
		if hum and Workspace.CurrentCamera then
			Workspace.CurrentCamera.CameraSubject = hum
			specText.Text = "관전 중: " .. targetPlayer.Name
		end
	else
		-- 타겟이 유효하지 않으면 갱신 후 다시 시도
		refreshRacersList()
		applyCameraToTarget()
	end
end

local function stopSpectating()
	print("[Spectator] stopSpectating called! Exiting spectator mode.")
	LocalPlayer:SetAttribute("IsSpectating", false)
	specControlsFrame.Visible = false
	specText.Visible = false
	startSpectateBtn.Visible = isAFK and (currentPhase == "RACE_MATCH")
	
	if Workspace.CurrentCamera then
		Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
		if LocalPlayer.Character then
			local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
			if hum then
				Workspace.CurrentCamera.CameraSubject = hum
			end
		end
	end
end

local function startSpectating()
	if not isAFK then return end
	if currentPhase ~= "RACE_MATCH" then return end
	
	LocalPlayer:SetAttribute("IsSpectating", true)
	startSpectateBtn.Visible = false
	specControlsFrame.Visible = true
	specText.Visible = true
	
	refreshRacersList()
	currentSpectateIndex = 1
	applyCameraToTarget()
end

startSpectateBtn.MouseButton1Click:Connect(startSpectating)
startSpectateBtn.Activated:Connect(startSpectating)

prevBtn.MouseButton1Click:Connect(function()
	refreshRacersList()
	currentSpectateIndex -= 1
	applyCameraToTarget()
end)
prevBtn.Activated:Connect(function()
	refreshRacersList()
	currentSpectateIndex -= 1
	applyCameraToTarget()
end)

nextBtn.MouseButton1Click:Connect(function()
	refreshRacersList()
	currentSpectateIndex += 1
	applyCameraToTarget()
end)
nextBtn.Activated:Connect(function()
	refreshRacersList()
	currentSpectateIndex += 1
	applyCameraToTarget()
end)

exitSpecBtn.MouseButton1Click:Connect(stopSpectating)
exitSpecBtn.Activated:Connect(stopSpectating)

phaseRemote.OnClientEvent:Connect(function(phase, timeLeft)
	currentPhase = phase
	if phase ~= "RACE_MATCH" then
		-- 레이스가 끝나면 강제로 관전 종료
		if LocalPlayer:GetAttribute("IsSpectating") then
			stopSpectating()
		end
	end
	updateAFKUI()
end)

-- 주기적으로 관전 대상 업데이트
task.spawn(function()
	while true do
		task.wait(2)
		if LocalPlayer:GetAttribute("IsSpectating") then
			-- 만약 현재 타겟이 없어지면 갱신
			local targetPlayer = activeRacers[currentSpectateIndex]
			if not targetPlayer or not targetPlayer.Character or not targetPlayer:GetAttribute("IsRacing") then
				refreshRacersList()
				applyCameraToTarget()
			end
		end
	end
end)



-- 4. Dismount Treadmill with Spacebar
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.Space then
		-- 레이스 중일 때는 이 조작 무시 (Side-effect 방지)
		if LocalPlayer:GetAttribute("IsRacing") then return end
		
		if LocalPlayer:GetAttribute("OnTreadmill") then
			local exitRemote = remotesFolder:FindFirstChild("ExitTreadmill") :: RemoteEvent?
			if exitRemote then
				exitRemote:FireServer()
			end
		end
	end
end)
