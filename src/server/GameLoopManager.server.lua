--!strict
-- GameLoopManager.server.luau
-- 16-Player Server Game Loop State Machine:
-- WaitingRoom Lounge -> 15s Map Voting -> Majority Vote Selection -> 5s Map Loading Screen -> 110s Track Race -> Return to Lounge

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local HoverboardConfig = require(Shared:WaitForChild("HoverboardConfig") :: ModuleScript)
local MapManager = require(Shared:WaitForChild("MapManager") :: ModuleScript)

local remotesFolder = ReplicatedStorage:FindFirstChild("HoverboardRemotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "HoverboardRemotes"
	remotesFolder.Parent = ReplicatedStorage
end

local function getOrCreateRemote(name: string): RemoteEvent
	local remote = remotesFolder:FindFirstChild(name) :: RemoteEvent?
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = remotesFolder
	end
	return remote
end

local phaseRemote = getOrCreateRemote("GamePhaseChanged")
local voteRemote = getOrCreateRemote("VoteMapRequest")
local mountRemote = getOrCreateRemote("MountRequest")
local dismountRemote = getOrCreateRemote("DismountRequest")
local stateRemote = getOrCreateRemote("StateChanged")
local lapUpdatedRemote = getOrCreateRemote("LapUpdated")
local raceFinishedRemote = getOrCreateRemote("RaceFinished")
local updateRankingsRemote = getOrCreateRemote("UpdateRankings")
local suddenDeathRemote = getOrCreateRemote("SuddenDeathUpdate")
local showScoreboardRemote = getOrCreateRemote("ShowScoreboard")

local toggleAFKRemote = getOrCreateRemote("ToggleAFK")
toggleAFKRemote.OnServerEvent:Connect(function(player, isAFK)
	player:SetAttribute("IsAFK", isAFK)
	print("💤 " .. player.Name .. " is now AFK: " .. tostring(isAFK))
end)

local LapManager = require(script.Parent:WaitForChild("LapManager") :: ModuleScript)

-- Server Configuration
local MAX_PLAYERS = 16

-- Phase Durations (seconds)
local DURATION_INTERMISSION = 30
local DURATION_VOTING = 15
local DURATION_BUILDING = 5
local DURATION_RACE = 110

-- Game State Variables
local currentPhase = "MAP_VOTING" -- "MAP_VOTING", "MAP_BUILDING", "RACE_MATCH"
local phaseTimeLeft = DURATION_VOTING
local chosenMapName = "Oval Speedway"

type VoterInfo = { userId: number, name: string }
local mapVoteData: { [string]: { VoterInfo } } = {
	["Oval Speedway"] = {},
	["Desert Track"] = {},
	["Magma Ridge"] = {},
}

-- Broadcast Phase Updates to All Connected Clients
local function broadcastPhaseUpdate()
	phaseRemote:FireAllClients(currentPhase, math.max(0, phaseTimeLeft), mapVoteData, chosenMapName)
end

-- Find User's Custom WaitingRoom / Floating Platform CFrame Position
local function getLoungeCFrame(): CFrame
	return MapManager.getLoungeCFrame() * CFrame.new(0, 3.5, 0)
end

-- Teleport Player to Position with Assembly Velocity Reset
local function teleportPlayer(player: Player, cframe: CFrame)
	task.spawn(function()
		for attempt = 1, 3 do
			local character = player.Character
			local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")

			if hrp and humanoid and humanoid.Health > 0 then
				hrp.AssemblyLinearVelocity = Vector3.zero
				hrp.AssemblyAngularVelocity = Vector3.zero
				hrp.CFrame = cframe
				break
			end
			task.wait(0.1)
		end
	end)
end

-- Teleport All Connected Players to Lounge (WaitingRoom)
local function teleportAllToLounge()
	local loungeCFrame = getLoungeCFrame()

	for _, player in ipairs(Players:GetPlayers()) do
		-- Only return players who were participating in the race to the lounge.
		if player:GetAttribute("IsRacing") then
			local boardModel = player.Character and player.Character:FindFirstChild("EquippedHoverboard")
			if boardModel then
				boardModel:Destroy()
			end
			player:SetAttribute("IsRacing", false)
			stateRemote:FireClient(player, false, nil)
			teleportPlayer(player, loungeCFrame)
		end
	end
end

-- Get Track Starting Grid Base CFrame safely facing FORWARD down the track (+Z direction towards signal lights!)
local function getTrackStartGridCFrame(): CFrame
	local activeMap = Workspace:FindFirstChild("ActiveMap") :: Model?
	if activeMap then
		local gridPart = activeMap:FindFirstChild("TrackStartGridPart", true) :: BasePart?
		if gridPart then
			return gridPart.CFrame * CFrame.new(0, 10.0, 0)
		end

		local startModel = activeMap:FindFirstChild("StartingPoint", true) :: Model?
		if startModel then
			return startModel:GetPivot() * CFrame.new(0, 15.0, -3)
		end
	end

	local fallbackPart = Workspace:FindFirstChild("TrackStartGridPart") :: BasePart?
	if fallbackPart then
		return fallbackPart.CFrame * CFrame.new(0, 10.0, 0)
	end

	local defaultStartPos = MapManager.getLoungeCFrame().Position + Vector3.new(280, -60, 0)
	return CFrame.lookAt(defaultStartPos, defaultStartPos + Vector3.new(0, 0, 1))
end

-- Teleport All Lounge Players to Track Start Grid & Auto-Mount Hoverboards
local function teleportAllToTrackAndMount()
	local trackCFrame = getTrackStartGridCFrame()
	print("[DEBUG-GLM] teleportAllToTrackAndMount started. trackCFrame: " .. tostring(trackCFrame.Position))
	local hoverboardModels = ReplicatedStorage:FindFirstChild("HoverboardModels")

	local activeIdx = 0
	for _, player in ipairs(Players:GetPlayers()) do
		print("[DEBUG-GLM] Checking player: " .. player.Name .. " | IsAFK: " .. tostring(player:GetAttribute("IsAFK")) .. " | OnTreadmill: " .. tostring(player:GetAttribute("OnTreadmill")))
		if player:GetAttribute("IsAFK") then
			player:SetAttribute("IsRacing", false)
			print("[DEBUG-GLM] Skipped " .. player.Name .. " due to IsAFK")
			continue
		end
		
		activeIdx += 1
		local col = (activeIdx - 1) % 4
		local row = math.floor((activeIdx - 1) / 4)
		local gridOffset = CFrame.new((col - 1.5) * 8, 0, -row * 10)
		local sideProfileRotation = CFrame.Angles(0, math.rad(-90), 0)
		local targetCFrame = trackCFrame * gridOffset * sideProfileRotation

		player:SetAttribute("IsRacing", true)
		player:SetAttribute("OnTreadmill", false)
		player:SetAttribute("PreTreadmillPosition", nil)

		local equippedId = player:FindFirstChild("EquippedHoverboardId")
		local boardName = equippedId and equippedId.Value or "DefaultHoverboard"
		local boardTemplate = hoverboardModels and hoverboardModels:FindFirstChild(boardName)
		if not boardTemplate and hoverboardModels then
			boardTemplate = hoverboardModels:FindFirstChild("DefaultHoverboard") or hoverboardModels:GetChildren()[1]
		end

		if player.Character and boardTemplate then
			local hrp = player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
			
			print("[DEBUG-GLM] Player " .. player.Name .. " has Character. HRP: " .. tostring(hrp ~= nil) .. ", HumHealth: " .. tostring(humanoid and humanoid.Health))
			
			if hrp and humanoid and humanoid.Health > 0 then
				print("[DEBUG-GLM] Destroying old boards for " .. player.Name)
				-- 1. DESTROY old boards BEFORE moving
				for _, child in ipairs(player.Character:GetChildren()) do
					if child.Name == "EquippedHoverboard" or child.Name:lower():find("hoverboard") then
						child:Destroy()
					end
				end

				print("[DEBUG-GLM] Teleporting " .. player.Name .. " to " .. tostring(targetCFrame.Position))
				-- 2. RESET physics and TELEPORT
				hrp.AssemblyLinearVelocity = Vector3.zero
				hrp.AssemblyAngularVelocity = Vector3.zero
				hrp.CFrame = targetCFrame

				-- 3. CLONE and WELD new board
				local boardClone = boardTemplate:Clone()
				boardClone.Name = "EquippedHoverboard"

				for _, part in ipairs(boardClone:GetDescendants()) do
					if part:IsA("BasePart") then
						part.Anchored = false
						part.CanCollide = false
						part.Massless = true
					end
				end

				local rootPart = boardClone.PrimaryPart
				if rootPart then
					local rotationOffset = CFrame.new()
					if boardName == "MagicBroom" then
						rotationOffset = CFrame.Angles(0, math.rad(180), 0)
					end

					boardClone:PivotTo(hrp.CFrame * CFrame.new(0, -3.25, 0) * rotationOffset)

					for _, part in ipairs(boardClone:GetDescendants()) do
						if part:IsA("BasePart") and part ~= rootPart then
							local wc = Instance.new("WeldConstraint")
							wc.Part0 = rootPart
							wc.Part1 = part
							wc.Parent = rootPart
						end
					end
					
					boardClone.Parent = player.Character

					local weld = Instance.new("Weld")
					weld.Name = "HoverWeld"
					weld.Part0 = hrp
					weld.Part1 = rootPart
					weld.C0 = CFrame.new(0, -3.25, 0) * rotationOffset
					weld.Parent = rootPart

					print("[DEBUG-GLM] Firing stateRemote for " .. player.Name .. " with forceIsRacing=true")
					-- Force client to realize it's racing so it doesn't snap back to treadmill
					stateRemote:FireClient(player, true, boardClone, nil, true)
				else
					print("[DEBUG-GLM] FAILED to find PrimaryPart in board template for " .. player.Name)
				end
			end
		else
			print("[DEBUG-GLM] Missing Character or BoardTemplate for " .. player.Name)
		end
	end
end

-- Handle Client Map Vote Submissions
voteRemote.OnServerEvent:Connect(function(player: Player, mapName: string)
	if currentPhase ~= "MAP_VOTING" then return end
	if not mapVoteData[mapName] then
		mapName = "Oval Speedway"
	end

	for mName, voterList in pairs(mapVoteData) do
		for idx = #voterList, 1, -1 do
			if voterList[idx].userId == player.UserId then
				table.remove(voterList, idx)
			end
		end
	end

	table.insert(mapVoteData[mapName], {
		userId = player.UserId,
		name = player.DisplayName or player.Name,
	})

	broadcastPhaseUpdate()
end)

-- New Player Joining & Character Lifecycle Logic:
local function setupPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		local hum = character:WaitForChild("Humanoid", 5)
		if hum then
			hum.Died:Connect(function()
				print(string.format("[DEATH_DEBUG] %s Humanoid.Died | Health=%.1f | Phase=%s", player.Name, hum.Health, currentPhase))
				if currentPhase == "RACE_MATCH" and player:GetAttribute("IsRacing") then
					print(string.format("🏁 [GameLoop] %s died during race! Marking DNF.", player.Name))
					player:SetAttribute("IsRacing", false)
					player:SetAttribute("IsHoverboarding", false)
					LapManager.retirePlayer(player.UserId)
					dismountRemote:FireClient(player)
					stateRemote:FireClient(player, false, nil)
				end
			end)
		end

		if currentPhase == "RACE_MATCH" then
			if player:GetAttribute("IsRacing") then
				print(string.format("🏁 [GameLoop] %s died/respawned during race! Transitioning to DNF Lounge mode.", player.Name))
				player:SetAttribute("IsRacing", false)
				player:SetAttribute("IsHoverboarding", false)
				LapManager.retirePlayer(player.UserId)
			end

			local boardModel = character:FindFirstChild("EquippedHoverboard")
			if boardModel then
				boardModel:Destroy()
			end

			dismountRemote:FireClient(player)
			stateRemote:FireClient(player, false, nil)

			task.wait(0.3)
			local loungeCFrame = getLoungeCFrame()
			teleportPlayer(player, loungeCFrame)
			task.wait(0.1)
			phaseRemote:FireClient(player, currentPhase, phaseTimeLeft, mapVoteData, chosenMapName)
			return
		end

		task.wait(0.3)
		local loungeCFrame = getLoungeCFrame()
		teleportPlayer(player, loungeCFrame)
		task.wait(0.1)
		phaseRemote:FireClient(player, currentPhase, phaseTimeLeft, mapVoteData, chosenMapName)
	end)

	if player.Character then
		local hum = player.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.Died:Connect(function()
				print(string.format("[DEATH_DEBUG] %s Humanoid.Died | Health=%.1f | Phase=%s", player.Name, hum.Health, currentPhase))
				if currentPhase == "RACE_MATCH" and player:GetAttribute("IsRacing") then
					print(string.format("🏁 [GameLoop] %s died during race! Marking DNF.", player.Name))
					player:SetAttribute("IsRacing", false)
					player:SetAttribute("IsHoverboarding", false)
					LapManager.retirePlayer(player.UserId)
					dismountRemote:FireClient(player)
					stateRemote:FireClient(player, false, nil)
				end
			end)
		end
	end
end

Players.PlayerAdded:Connect(setupPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	setupPlayer(player)
end

local countdownRemote = getOrCreateRemote("StartCountdownSignal")

-- Helper: Set physical signal light states on StartingPoint arch
local function setSignalLightsState(redOn: boolean, yellowOn: boolean, greenOn: boolean)
	local activeMap = Workspace:FindFirstChild("ActiveMap") :: Model?
	local startModel = activeMap and activeMap:FindFirstChild("StartingPoint", true) or Workspace:FindFirstChild("StartingPoint")
	if not startModel then return end

	local redPart = startModel:FindFirstChild("RedLight") :: BasePart?
	local yellowPart = startModel:FindFirstChild("YellowLight") :: BasePart?
	local greenPart = startModel:FindFirstChild("GreenLight") :: BasePart?

	local function updateLight(part: BasePart?, isOn: boolean, defaultColor: Color3)
		if not part then return end
		part.Material = isOn and Enum.Material.Neon or Enum.Material.SmoothPlastic
		part.Color = isOn and defaultColor or Color3.fromRGB(30, 35, 45)
		local pLight = part:FindFirstChildOfClass("PointLight")
		if pLight then
			pLight.Brightness = isOn and 5.0 or 0.0
		end
	end

	updateLight(redPart, redOn, Color3.fromRGB(255, 40, 40))
	updateLight(yellowPart, yellowOn, Color3.fromRGB(255, 200, 30))
	updateLight(greenPart, greenOn, Color3.fromRGB(40, 255, 80))
end

-- Helper: Freeze player movement during countdown
local function lockAllPlayersMovement()
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character and player:GetAttribute("IsRacing") then
			local hum = player.Character:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.WalkSpeed = 0
			end
		end
	end
end

-- Helper: Unlock player movement at GO!
local function unlockAllPlayersMovement()
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character and player:GetAttribute("IsRacing") then
			local hum = player.Character:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.WalkSpeed = HoverboardConfig.RIDE_WALKSPEED
			end
		end
	end
end

-- Main Infinite Game Loop Server Manager Thread
task.spawn(function()
	task.wait(0.5) -- Fast server startup

	-- Pre-build default template model in ReplicatedStorage.Maps (do not load into Workspace yet)
	MapManager.ensureMapTemplate("Oval Speedway")

	while true do
		-- ---------------------------------------------------------------------
		-- STEP 1: INTERMISSION / LOUNGE (30 Seconds)
		-- ---------------------------------------------------------------------
		currentPhase = "INTERMISSION"
		phaseTimeLeft = DURATION_INTERMISSION
		
		MapManager.UnloadCurrentMap()
		teleportAllToLounge()
		setSignalLightsState(false, false, false)
		
		print("🛋️ [GameLoop] 30 seconds Intermission starting...")
		while phaseTimeLeft > 0 do
			broadcastPhaseUpdate()
			task.wait(1)
			phaseTimeLeft -= 1
		end

		-- ---------------------------------------------------------------------
		-- STEP 2: MAP VOTING FOR ALL LOUNGE PLAYERS (15 Seconds)
		-- ---------------------------------------------------------------------
		currentPhase = "MAP_VOTING"
		phaseTimeLeft = DURATION_VOTING
		chosenMapName = "Oval Speedway"
		mapVoteData = {
			["Oval Speedway"] = {},
			["Desert Track"] = {},
			["Magma Ridge"] = {},
		}

		print("🗳️ [GameLoop] 15 seconds Map Voting starting...")
		while phaseTimeLeft > 0 do
			broadcastPhaseUpdate()
			task.wait(1)
			phaseTimeLeft -= 1
		end

		-- ---------------------------------------------------------------------
		-- STEP 2: CALCULATE MAJORITY VOTE WINNING MAP
		-- ---------------------------------------------------------------------
		local winningMap = "Oval Speedway"
		local highestVotes = -1

		for mName, voterList in pairs(mapVoteData) do
			if #voterList > highestVotes then
				highestVotes = #voterList
				winningMap = mName
			end
		end
		chosenMapName = winningMap
		print("🏆 [GameLoop] Map Voting Finished! Winning Map:", chosenMapName, " (Votes:", highestVotes, ")")

		-- ---------------------------------------------------------------------
		-- STEP 3: MAP LOADING SCREEN & STRUCTURE BUILDING (5 Seconds)
		-- ---------------------------------------------------------------------
		currentPhase = "MAP_BUILDING"
		phaseTimeLeft = DURATION_BUILDING

		-- Load selected Studio Model map from ReplicatedStorage.Maps directly under WaitingRoom!
		MapManager.LoadMap(chosenMapName)

		while phaseTimeLeft > 0 do
			broadcastPhaseUpdate()
			task.wait(1)
			phaseTimeLeft -= 1
		end

		-- ---------------------------------------------------------------------
		-- STEP 4: MAIN RACE MATCH ON TRACK (110 Seconds)
		-- ---------------------------------------------------------------------
		currentPhase = "RACE_MATCH"
		phaseTimeLeft = DURATION_RACE
		print("🏁 [GameLoop] 110 seconds Main Race Started!")

		broadcastPhaseUpdate()
		teleportAllToTrackAndMount()
		lockAllPlayersMovement()
		
		-- Setup Laps Display for Countdown
		local totalLaps = MapManager.getTotalLaps(chosenMapName)
		local lapUpdatedRemote = getOrCreateRemote("LapUpdated")
		lapUpdatedRemote:FireAllClients(0, totalLaps)

		setSignalLightsState(false, false, false)

		for count = 5, 0, -1 do
			broadcastPhaseUpdate()
			countdownRemote:FireAllClients(count)

			if count == 5 or count == 4 then
				setSignalLightsState(false, false, false)
			elseif count == 3 then
				setSignalLightsState(true, false, false)
			elseif count == 2 then
				setSignalLightsState(true, true, false)
			elseif count == 1 then
				setSignalLightsState(true, true, true)
			elseif count == 0 then
				setSignalLightsState(true, true, true)
				unlockAllPlayersMovement()
				print("🏁 [Countdown] GO! Race Started!")
				LapManager.startTracking(chosenMapName, os.clock())
			end

			task.wait(1)
			phaseTimeLeft -= 1
		end

		local suddenDeathStarted = false
		local suddenDeathTimer = 10
		local suddenDeathRemote = getOrCreateRemote("SuddenDeathUpdate")
		local showScoreboardRemote = getOrCreateRemote("ShowScoreboard")
		
		while phaseTimeLeft > 0 do
			local activePlayers = LapManager.getActivePlayersCount()
			local finishedPlayers = LapManager.getFinishedCount()
			
			if activePlayers > 0 and finishedPlayers >= activePlayers then
				print("🏁 [GameLoop] All active players finished! Ending race early.")
				break
			end
			
			if finishedPlayers > 0 and not suddenDeathStarted then
				suddenDeathStarted = true
				print("🚨 [GameLoop] 1st Place Finished! Sudden Death Countdown started!")
				suddenDeathRemote:FireAllClients(suddenDeathTimer)
			end
			
			if suddenDeathStarted then
				suddenDeathTimer -= 1
				suddenDeathRemote:FireAllClients(suddenDeathTimer)
				if suddenDeathTimer <= 0 then
					print("🚨 [GameLoop] Sudden Death Ended! Forcing retire for unfinished players.")
					break
				end
			end
			
			broadcastPhaseUpdate()
			task.wait(1)
			if not suddenDeathStarted then
				phaseTimeLeft -= 1
			end
		end
		
		-- Force retire players who didn't finish
		LapManager.retireUnfinishedPlayers()

		-- ---------------------------------------------------------------------
		-- STEP 5: POST-RACE SCOREBOARD (10 Seconds)
		-- ---------------------------------------------------------------------
		print("🏆 [GameLoop] Race Ended! Showing results in 3 seconds (7s display)")
		currentPhase = "POST_RACE"
		phaseTimeLeft = 10
		broadcastPhaseUpdate()
		
		task.wait(3)
		
		local scoreboardData = LapManager.getFinalScoreboardData()
		showScoreboardRemote:FireAllClients(scoreboardData)
		
		task.wait(7)
		
		-- ---------------------------------------------------------------------
		-- STEP 6: RETURN ALL PARTICIPANTS TO WAITINGROOM LOUNGE
		-- ---------------------------------------------------------------------
		print("🏁 [GameLoop] Returning all participants to Lounge...")
		LapManager.stopTracking()
		teleportAllToLounge()
		MapManager.UnloadCurrentMap()
		task.wait(2)
	end
end)

print("🏁 [GameLoopManager] Game Loop and Map Loader Initialized!")
