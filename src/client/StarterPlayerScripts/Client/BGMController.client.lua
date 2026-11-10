--!strict
-- BGMController.client.luau
-- Manages Background Music based on Game Phase and chosen map.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local remotesFolder = ReplicatedStorage:WaitForChild("HoverboardRemotes") :: Folder
local phaseRemote = remotesFolder:WaitForChild("GamePhaseChanged") :: RemoteEvent

-- Configure Map BGM Sound IDs here
local BGM_IDS = {
	Lobby = "rbxassetid://1840383905", -- 🎵 로비/대기실 BGM (Happy Shoppers)
	OvalSpeedway = "rbxassetid://119805423797573", -- Oval Speedway 맵 BGM
	DesertTrack = "rbxassetid://70712183409265", -- Desert Track 맵 BGM
	MagmaRidge = "rbxassetid://0", -- Magma Ridge 맵 BGM
	CyberCity = "rbxassetid://0", -- Cyber City 맵 BGM
}

local currentPhase = "INTERMISSION"
local currentMap = "Oval Speedway"
local currentSound: Sound? = nil

-- BGM을 크로스페이드(부드럽게 전환)하면서 변경하는 함수
local function playBGM(soundId: string)
	if currentSound and currentSound.SoundId == soundId and currentSound.IsPlaying then
		return -- 이미 재생 중
	end

	local oldSound = currentSound
	if oldSound then
		local fadeOut = TweenService:Create(oldSound, TweenInfo.new(1), {Volume = 0})
		fadeOut:Play()
		fadeOut.Completed:Connect(function()
			oldSound:Destroy()
		end)
	end

	if soundId and soundId ~= "rbxassetid://0" and soundId ~= "" then
		local newSound = Instance.new("Sound")
		newSound.Name = "BGM_" .. (string.match(soundId, "%d+") or "Custom")
		newSound.SoundId = soundId
		newSound.Looped = true
		newSound.Volume = 0
		newSound.Parent = SoundService
		newSound:Play()
		
		local isBGMEnabled = LocalPlayer:GetAttribute("BGMEnabled") ~= false
		local targetVolume = isBGMEnabled and 0.45 or 0
		local fadeIn = TweenService:Create(newSound, TweenInfo.new(1), {Volume = targetVolume}) -- 기본 음악 볼륨 (0.45)
		fadeIn:Play()
		currentSound = newSound
	else
		currentSound = nil
	end
end

local function updateBGM()
	local isRacing = LocalPlayer:GetAttribute("IsRacing") == true
	local isAFK = LocalPlayer:GetAttribute("IsAFK") == true

	if currentPhase == "INTERMISSION" or currentPhase == "MAP_VOTING" then
		playBGM(BGM_IDS.Lobby)
	elseif currentPhase == "MAP_BUILDING" or currentPhase == "PLAYER_SYNC" then
		-- 맵 로딩 중일 때 BGM 부드럽게 정지
		playBGM("") 
	elseif currentPhase == "RACE_MATCH" then
		-- 대기실에 남아있거나 AFK 상태인 유저는 대기실 BGM 유지/재생!
		if not isRacing or isAFK then
			playBGM(BGM_IDS.Lobby)
			return
		end

		local mapBGM = BGM_IDS.Lobby -- 맵에 해당하는 브금이 없으면 로비 브금 재생
		if currentMap == "Oval Speedway" then
			mapBGM = BGM_IDS.OvalSpeedway
		elseif currentMap == "Desert Track" then
			mapBGM = BGM_IDS.DesertTrack
		elseif currentMap == "Magma Ridge" then
			mapBGM = BGM_IDS.MagmaRidge
		elseif currentMap == "Cyber City" then
			mapBGM = BGM_IDS.CyberCity
		end
		playBGM(mapBGM)
	end
end

-- Server Remote Phase Listener
phaseRemote.OnClientEvent:Connect(function(phase: string, timeLeft: number, mapVotes: any, chosenMap: string?)
	currentPhase = phase
	if chosenMap then
		currentMap = chosenMap
	end
	updateBGM()
end)

-- AFK 상태 변경 리스너
LocalPlayer:GetAttributeChangedSignal("IsAFK"):Connect(function()
	updateBGM()
end)

-- 레이싱 상태 변경 리스너 (레이스 종료 후 대기실 복귀 시 로비 BGM 즉시 복구)
LocalPlayer:GetAttributeChangedSignal("IsRacing"):Connect(function()
	updateBGM()
end)

-- BGM 활성화/비활성화 설정 리스너
LocalPlayer:GetAttributeChangedSignal("BGMEnabled"):Connect(function()
	local isEnabled = LocalPlayer:GetAttribute("BGMEnabled") ~= false
	if currentSound then
		local targetVol = isEnabled and 0.45 or 0
		TweenService:Create(currentSound, TweenInfo.new(0.5), {Volume = targetVol}):Play()
	else
		if isEnabled then
			updateBGM()
		end
	end
end)

-- 초기 실행
updateBGM()
print("🎵 [BGMController] 대기실 BGM(Happy Shoppers, 1840383905) 및 맵 BGM 시스템 가동 완료!")
