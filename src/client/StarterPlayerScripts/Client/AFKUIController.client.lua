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
local afkGui = PlayerGui:WaitForChild("AFKGui")

local afkBtn = afkGui:WaitForChild("AFKButton") :: ImageButton
local bgSquare = afkGui:WaitForChild("BgSquare") :: Frame
local startSpectateBtn = afkGui:WaitForChild("StartSpectateButton") :: ImageButton
local specBgSquare = afkGui:WaitForChild("SpecBgSquare") :: Frame
local specControlsFrame = afkGui:WaitForChild("SpecControlsFrame") :: Frame
local prevBtn = specControlsFrame:WaitForChild("PrevBtn") :: TextButton
local nextBtn = specControlsFrame:WaitForChild("NextBtn") :: TextButton
local exitSpecBtn = specControlsFrame:WaitForChild("ExitBtn") :: TextButton
local watermark = afkGui:WaitForChild("AFKWatermark") :: TextLabel
local specText = afkGui:WaitForChild("SpectatorStatus") :: TextLabel

local function updateAFKUI()
	local isRacing = LocalPlayer:GetAttribute("IsRacing")
	if isRacing then
		afkBtn.Visible = false
		bgSquare.Visible = false
		startSpectateBtn.Visible = false
		specBgSquare.Visible = false
		return
	end
	
	afkBtn.Visible = true
	bgSquare.Visible = true

	if isAFK then
		afkBtn.Image = "rbxassetid://94850212812337"
		bgSquare.BackgroundColor3 = Color3.fromRGB(255, 255, 0) -- Yellow
		watermark.Visible = true
		watermark.TextTransparency = 0
		
		-- 관전 버튼은 레이스 중에만 노출
		if currentPhase == "RACE_MATCH" then
			startSpectateBtn.Visible = not LocalPlayer:GetAttribute("IsSpectating")
			specBgSquare.Visible = startSpectateBtn.Visible
		else
			startSpectateBtn.Visible = false
			specBgSquare.Visible = false
		end
	else
		afkBtn.Image = "rbxassetid://101189590468168"
		bgSquare.BackgroundColor3 = Color3.fromRGB(0, 0, 0) -- Black
		watermark.Visible = false
		watermark.TextTransparency = 1
		startSpectateBtn.Visible = false
		specBgSquare.Visible = false
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
		if #activeRacers == 0 then
			-- 관전 도중 모든 유저가 나가거나 끝난 경우
			if LocalPlayer:GetAttribute("IsSpectating") then
				-- 잠시 안내 후 stopSpectating을 직접 호출하는 것보다는 
				-- 루프나 stopSpectating 함수를 호출해 종료시킴.
				-- 여기서는 stopSpectating()이 위쪽에 선언되지 않아 나중에 아래쪽에서 처리
			end
		else
			applyCameraToTarget()
		end
	end
end

local function stopSpectating()
	print("[Spectator] stopSpectating called! Exiting spectator mode.")
	LocalPlayer:SetAttribute("IsSpectating", false)
	specControlsFrame.Visible = false
	specText.Visible = false
	startSpectateBtn.Visible = isAFK and (currentPhase == "RACE_MATCH")
	specBgSquare.Visible = startSpectateBtn.Visible
	
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
	
	refreshRacersList()
	
	if #activeRacers == 0 then
		-- 관전할 유저가 없을 때는 관전 모드로 들어가지 않음
		specText.Text = "관전할 유저가 없습니다."
		specText.Visible = true
		task.delay(2, function()
			-- 만약 그 사이에 실제 관전 모드로 들어간 게 아니라면 텍스트 숨김
			if not LocalPlayer:GetAttribute("IsSpectating") then
				specText.Visible = false
			end
		end)
		return
	end
	
	LocalPlayer:SetAttribute("IsSpectating", true)
	startSpectateBtn.Visible = false
	specBgSquare.Visible = false
	specControlsFrame.Visible = true
	specText.Visible = true
	
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
				if #activeRacers == 0 then
					-- 관전 도중 마지막 유저가 나가면 강제로 관전 종료
					stopSpectating()
					specText.Text = "관전할 유저가 없습니다."
					specText.Visible = true
					task.delay(2, function()
						if not LocalPlayer:GetAttribute("IsSpectating") then
							specText.Visible = false
						end
					end)
				else
					applyCameraToTarget()
				end
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
