--!strict
-- LapManager.lua
-- Tracks laps for players using checkpoints.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MapManager = require(Shared:WaitForChild("MapManager") :: ModuleScript)

local remotesFolder = ReplicatedStorage:WaitForChild("HoverboardRemotes")
local lapUpdatedRemote = remotesFolder:WaitForChild("LapUpdated") :: RemoteEvent
local raceFinishedRemote = remotesFolder:WaitForChild("RaceFinished") :: RemoteEvent

local LapManager = {}

export type PlayerLapData = {
	currentLap: number,
	nextCheckpoint: number,
	finished: boolean,
	finishTime: number,
	player: Player?,
	lastScore: number?,
}

local playerLaps: { [number]: PlayerLapData } = {}
local totalLapsForMap = 3
local raceStartTime = 0
local finishedCount = 0
local checkpointConnections: { RBXScriptConnection } = {}

local RunService = game:GetService("RunService")

-- Clean up any existing `.Touched` events
local lastRankingsStr = ""
local heartbeatConnection: RBXScriptConnection? = nil
local checkpointPositions: { [number]: Vector3 } = {}
local playerStartPositions: { [number]: Vector3 } = {}
local currentRankings: { {userId: number, name: string, score: number} } = {}

local function cleanupCheckpoints()
	for _, conn in ipairs(checkpointConnections) do
		if conn.Connected then
			conn:Disconnect()
		end
	end
	table.clear(checkpointConnections)
	
	if heartbeatConnection then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end
	table.clear(checkpointPositions)
end

function LapManager.startTracking(mapName: string, startTime: number)
	cleanupCheckpoints()
	totalLapsForMap = MapManager.getTotalLaps(mapName)
	raceStartTime = startTime
	finishedCount = 0
	lastRankingsStr = ""
	table.clear(playerLaps)

	local initialRacers = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player:GetAttribute("IsRacing") then
			playerLaps[player.UserId] = {
				currentLap = 0,
				nextCheckpoint = 1,
				finished = false,
				finishTime = 0,
				player = player,
				lastScore = 1000000,
			}
			
			local char = player.Character
			local root = char and (char.PrimaryPart or char:FindFirstChild("HumanoidRootPart") :: BasePart?)
			if root then
				playerStartPositions[player.UserId] = root.Position
			end
			
			table.insert(initialRacers, {
				userId = player.UserId,
				name = player.Name,
				displayName = player.DisplayName,
			})

			-- Initialize UI
			lapUpdatedRemote:FireClient(player, 0, totalLapsForMap)
		end
	end

	if #initialRacers > 0 then
		table.sort(initialRacers, function(a, b)
			return a.userId < b.userId
		end)
		local namesStr = ""
		for _, r in ipairs(initialRacers) do
			namesStr ..= tostring(r.userId) .. ","
		end
		lastRankingsStr = namesStr .. "true"
		local updateRankingsRemote = remotesFolder:FindFirstChild("UpdateRankings")
		if updateRankingsRemote and updateRankingsRemote:IsA("RemoteEvent") then
			updateRankingsRemote:FireAllClients(initialRacers, true)
		end
	end

	-- Hook up Checkpoints
	local activeMap = Workspace:FindFirstChild("ActiveMap") :: Model?
	if not activeMap then return end

	-- Collect Checkpoint parts (Prioritize dedicated Checkpoints folder to avoid false matches with decorative asset parts named "1", "2", etc.)
	local checkpoints = {}
	local cpFolder = activeMap:FindFirstChild("Checkpoints")
	local searchList = cpFolder and cpFolder:GetChildren() or activeMap:GetDescendants()
	
	for _, child in ipairs(searchList) do
		local cpIndex = tonumber(child.Name)
		if cpIndex then
			if child:IsA("BasePart") then
				if not checkpoints[cpIndex] then checkpoints[cpIndex] = {} end
				table.insert(checkpoints[cpIndex], child)
				print("👀 [LapManager Init] Found checkpoint " .. cpIndex .. " (BasePart) inside " .. child.Parent.Name)
			elseif child:IsA("Model") or child:IsA("Folder") then
				-- If the user grouped the checkpoint into a Model or Folder named "1", "2", etc.
				-- Find all parts inside it.
				for _, subPart in ipairs(child:GetDescendants()) do
					if subPart:IsA("BasePart") then
						if not checkpoints[cpIndex] then checkpoints[cpIndex] = {} end
						table.insert(checkpoints[cpIndex], subPart)
					end
				end
				print("👀 [LapManager Init] Found checkpoint " .. cpIndex .. " (Model/Folder) containing parts.")
			end
		end
	end
	
	print("👀 [LapManager Init] Finished scanning map. Found " .. #activeMap:GetChildren() .. " direct children in " .. activeMap.Name)

	local maxCheckpoints = 0
	for i, cpList in pairs(checkpoints) do
		if i > maxCheckpoints then
			maxCheckpoints = i
		end
		
		-- Calculate average position for this checkpoint
		local posSum = Vector3.zero
		local count = 0
		for _, cpPart in ipairs(cpList) do
			posSum += cpPart.Position
			count += 1
		end
		if count > 0 then
			checkpointPositions[i] = posSum / count
		end
	end

	if maxCheckpoints == 0 then
		warn("🚨 [LapManager] Checkpoints folder is empty! Lap tracking disabled.")
		return
	end

	print("🏁 [LapManager] Tracking " .. maxCheckpoints .. " checkpoints for " .. totalLapsForMap .. " laps.")

	local function handleCheckpointReached(player: Player, index: number)
		local data = playerLaps[player.UserId]
		if not data or data.finished then return end

		if index == data.nextCheckpoint then
			if index == maxCheckpoints then
				-- Finished a lap!
				if data.currentLap + 1 >= totalLapsForMap then
					-- Finished the race!
					data.currentLap += 1
					data.finished = true
					data.finishTime = os.clock() - raceStartTime
					
					finishedCount += 1
					data.finalRank = finishedCount
					
					raceFinishedRemote:FireClient(player, data.finishTime, data.currentLap, totalLapsForMap, data.finalRank)
					print("🏆 [LapManager] " .. player.Name .. " finished the race in " .. string.format("%.2f", data.finishTime) .. "s! Rank: " .. data.finalRank)
					
					local leaderstats = player:FindFirstChild("leaderstats")
					if leaderstats then
						local gold = leaderstats:FindFirstChild("Gold")
						if gold then
							local reward = 100
							if data.finalRank == 1 then 
								reward = 1000
							elseif data.finalRank == 2 then 
								reward = 600
							elseif data.finalRank == 3 then 
								reward = 300
							end
							local hasX2 = player:GetAttribute("OwnsPass_33333333") == true or player:GetAttribute("OwnsPass_x2RacePrize") == true
							if hasX2 then
								reward *= 2
								print("✨ [DEBUG] " .. player.Name .. " has X2 Race Prize GamePass! Reward doubled to " .. reward)
							end
							
							data.earnedGold = reward
							print("💰 " .. player.Name .. " earned " .. reward .. " Gold")
						end
					end
				else
					-- Next Lap
					data.currentLap += 1
					data.nextCheckpoint = 1
					lapUpdatedRemote:FireClient(player, data.currentLap, totalLapsForMap)
					print(string.format("🏁 [LapManager] %s completed Lap %d/%d!", player.Name, data.currentLap, totalLapsForMap))
				end
			else
				-- Next checkpoint in the same lap
				data.nextCheckpoint = index + 1
				print(string.format("📍 [LapManager] %s hit Checkpoint %d! Next: %d", player.Name, index, data.nextCheckpoint))
			end
		end
	end

	local function getPlayerFromHit(hit: Instance?): Player?
		local current: Instance? = hit
		while current and current ~= Workspace and current ~= game do
			if current:IsA("Model") then
				local p = Players:GetPlayerFromCharacter(current)
				if p then return p end
			end
			current = current.Parent
		end
		return nil
	end

	for index, cpPartsList in pairs(checkpoints) do
		for _, cpPart in ipairs(cpPartsList) do
			local conn = cpPart.Touched:Connect(function(hit)
				local player = getPlayerFromHit(hit)
				if player then
					handleCheckpointReached(player, index)
				end
			end)
			table.insert(checkpointConnections, conn)
		end
	end
	
	-- Start real-time ranking loop (checkpoint checks every frame, ranking sort/broadcast throttled to 0.15s)
	local rankingTimer = 0.0
	heartbeatConnection = RunService.Heartbeat:Connect(function(dt: number)
		-- 혹시 레이스 시작 이후 지연 로딩 등으로 playerLaps에 누락된 활성 레이서가 있다면 자동 등록
		for _, p in ipairs(Players:GetPlayers()) do
			if p:GetAttribute("IsRacing") and not playerLaps[p.UserId] then
				playerLaps[p.UserId] = {
					currentLap = 0,
					nextCheckpoint = 1,
					finished = false,
					finishTime = 0,
					player = p,
					lastScore = 1000000,
				}
				local char = p.Character
				local root = char and (char.PrimaryPart or char:FindFirstChild("HumanoidRootPart") :: BasePart?)
				if root then
					playerStartPositions[p.UserId] = root.Position
				end
			end
		end

		-- 실시간 체크포인트 근접/통과 판정 (고속 주행 및 Touched 물리 누락 방지용)
		for userId, data in pairs(playerLaps) do
			if not data.finished then
				local p = data.player or Players:GetPlayerByUserId(userId)
				local char = p and p.Character
				local root = char and (char.PrimaryPart or char:FindFirstChild("HumanoidRootPart") :: BasePart?)
				if p and char and root then
					local targetIdx = data.nextCheckpoint
					local cpParts = checkpoints[targetIdx]
					if cpParts and #cpParts > 0 then
						for _, cpPart in ipairs(cpParts) do
							local relPos = cpPart.CFrame:PointToObjectSpace(root.Position)
							local halfSize = cpPart.Size / 2 + Vector3.new(16, 8, 20)
							if math.abs(relPos.X) <= halfSize.X and math.abs(relPos.Y) <= halfSize.Y and math.abs(relPos.Z) <= halfSize.Z then
								handleCheckpointReached(p, targetIdx)
								break
							end
						end
					end
				end
			end
		end

		rankingTimer += dt
		if rankingTimer < 0.15 then
			return
		end
		rankingTimer = 0.0

		local sortedPlayers = {}
		local maxDistTraveled = 0
		
		for userId, data in pairs(playerLaps) do
			local p = data.player or Players:GetPlayerByUserId(userId)
			if not p or p.Parent ~= Players then
				playerLaps[userId] = nil
				continue
			end

			local char = p.Character
			local root = char and (char.PrimaryPart or char:FindFirstChild("HumanoidRootPart") :: BasePart?)
			local score = 0

			if data.finished then
				if data.finalRank == 999 then
					score = -999999999 + (data.lastScore or 0) -- DNF 유저는 랭킹 하단으로 유지
				else
					score = 10000000000 + math.round((10000 - data.finishTime) * 100) -- faster finish time = higher score
				end
				maxDistTraveled = 9999
			elseif char and root then
				if data.currentLap == 0 and data.nextCheckpoint == 1 then
					local startPos = playerStartPositions[userId]
					if startPos then
						local distTraveled = (root.Position - startPos).Magnitude
						if distTraveled >= 1.0 and distTraveled > maxDistTraveled then
							maxDistTraveled = distTraveled
						end
					end
				else
					maxDistTraveled = 9999
				end

				local targetCpPos = checkpointPositions[data.nextCheckpoint]
				local distPenalty = targetCpPos and math.round((root.Position - targetCpPos).Magnitude * 0.5) or 0
				score = (data.currentLap * 100000000) + (data.nextCheckpoint * 1000000) - distPenalty
				data.lastScore = score
			else
				-- 캐릭터/루트 일시 누락 시 직전 점수를 유지해 순위표에서 깜빡이며 사라지지 않게 보호
				score = data.lastScore or 0
			end

			table.insert(sortedPlayers, {
				userId = userId,
				name = p.Name,
				displayName = p.DisplayName,
				score = score,
				isDNF = (data.finalRank == 999),
			})
		end
		
		table.sort(sortedPlayers, function(a, b)
			if a.score ~= b.score then
				return a.score > b.score
			end
			return a.userId < b.userId
		end)
		
		currentRankings = sortedPlayers
		
		local sortedRacers = {}
		local namesStr = ""
		for _, pData in ipairs(sortedPlayers) do
			table.insert(sortedRacers, {
				userId = pData.userId,
				name = pData.name,
				displayName = pData.displayName,
			})
			namesStr ..= tostring(pData.userId) .. ","
		end
		
		local isStartingLine = maxDistTraveled < 1.0
		namesStr ..= tostring(isStartingLine)
		
		if namesStr ~= lastRankingsStr and #sortedRacers > 0 then
			lastRankingsStr = namesStr
			local updateRankingsRemote = remotesFolder:FindFirstChild("UpdateRankings")
			if updateRankingsRemote and updateRankingsRemote:IsA("RemoteEvent") then
				updateRankingsRemote:FireAllClients(sortedRacers, isStartingLine)
			end
		end
	end)
end

function LapManager.stopTracking()
	cleanupCheckpoints()
	table.clear(playerLaps)
	table.clear(currentRankings)
end

function LapManager.getPlayerAhead(userId: number)
	for i, rankData in ipairs(currentRankings) do
		if rankData.userId == userId then
			if i > 1 then
				local aheadUserId = currentRankings[i - 1].userId
				return Players:GetPlayerByUserId(aheadUserId)
			end
			return nil
		end
	end
	return nil
end

function LapManager.getFinishedCount()
	return finishedCount
end

function LapManager.getActivePlayersCount()
	local count = 0
	for _, _ in pairs(playerLaps) do
		count += 1
	end
	return count
end

function LapManager.retirePlayer(userId: number)
	local data = playerLaps[userId]
	if data and not data.finished then
		data.finished = true
		data.finalRank = 999
		data.finishTime = 0
		finishedCount += 1
		local p = Players:GetPlayerByUserId(userId)
		if p then
			raceFinishedRemote:FireClient(p, 0, data.currentLap, totalLapsForMap, data.finalRank)
		end
		print(string.format("🏁 Player %d retired (DNF) without gold.", userId))
	end
end

function LapManager.retireUnfinishedPlayers()
	for userId, data in pairs(playerLaps) do
		if not data.finished then
			data.finished = true
			data.finalRank = 999
			data.finishTime = 0
			finishedCount += 1
			local p = Players:GetPlayerByUserId(userId)
			if p then
				raceFinishedRemote:FireClient(p, 0, data.currentLap, totalLapsForMap, data.finalRank)
			end
			print(string.format("🏁 Player %d retired (DNF at end) without gold.", userId))
		end
	end
end

function LapManager.getFinalScoreboardData()
	local results = {}
	for userId, data in pairs(playerLaps) do
		local p = Players:GetPlayerByUserId(userId)
		if p then
			local timeStr = "DNF"
			if data.finalRank ~= 999 then
				timeStr = string.format("%.2fs", data.finishTime)
			end
			local reward = data.earnedGold or 0
			local hasX2Prize = p:GetAttribute("OwnsPass_33333333") == true or p:GetAttribute("OwnsPass_x2RacePrize") == true
			
			if reward > 0 then
				task.delay(0.5, function()
					local leaderstats = p:FindFirstChild("leaderstats")
					if leaderstats then
						local gold = leaderstats:FindFirstChild("Gold")
						if gold then
							gold.Value += reward
							print("💰 Actually Paid " .. reward .. " Gold to " .. p.Name .. "!")
							
							-- 지연된 퀘스트 및 승리 처리
							local ReplicatedStorage = game:GetService("ReplicatedStorage")
							local QuestBindables = ReplicatedStorage:FindFirstChild("QuestBindables")
							local addProgress = QuestBindables and QuestBindables:FindFirstChild("AddQuestProgress")
							if addProgress then
								addProgress:Fire(p.UserId, "_play", 1)
								addProgress:Fire(p.UserId, "_gold", reward)
								if data.finalRank == 1 then
									addProgress:Fire(p.UserId, "_win", 1)
								end
							end
							
							if data.finalRank == 1 then
								local winEvent = ReplicatedStorage:FindFirstChild("UpdateWinsEvent")
								if winEvent then winEvent:Fire(p) end
							end
						end
					end
				end)
			end
			
			table.insert(results, {
				name = p.DisplayName,
				rank = data.finalRank,
				time = timeStr,
				gold = reward,
				hasX2Prize = hasX2Prize
			})
		end
	end
	
	table.sort(results, function(a, b)
		return a.rank < b.rank
	end)
	
	return results
end

return LapManager
