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
	table.clear(playerLaps)

	for _, player in ipairs(Players:GetPlayers()) do
		playerLaps[player.UserId] = {
			currentLap = 0,
			nextCheckpoint = 1,
			finished = false,
			finishTime = 0,
		}
		
		if player.Character and player.Character.PrimaryPart then
			playerStartPositions[player.UserId] = player.Character.PrimaryPart.Position
		end
		
		-- Initialize UI
		lapUpdatedRemote:FireClient(player, 0, totalLapsForMap)
	end

	-- Hook up Checkpoints
	local activeMap = Workspace:FindFirstChild("ActiveMap") :: Model?
	if not activeMap then return end

	-- Collect Checkpoint parts
	local checkpoints = {}
	
	for _, child in ipairs(activeMap:GetDescendants()) do
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

	for index, cpPartsList in pairs(checkpoints) do
		for _, cpPart in ipairs(cpPartsList) do
			local conn = cpPart.Touched:Connect(function(hit)
				print("🚨 [LapManager Debug] Checkpoint " .. index .. " touched by: " .. hit.Name .. " (Parent: " .. (hit.Parent and hit.Parent.Name or "nil") .. ")")
				local player = Players:GetPlayerFromCharacter(hit.Parent)
				if not player and hit.Parent then
					player = Players:GetPlayerFromCharacter(hit.Parent.Parent)
				end
				if not player then 
					print("🚨 [LapManager Debug] Checkpoint " .. index .. " ignored: No player found for touch.")
					return 
				end
	
				local data = playerLaps[player.UserId]
				if not data or data.finished then 
					print("🚨 [LapManager Debug] Checkpoint " .. index .. " ignored: No data or player already finished.")
					return 
				end
	
				print("🏁 [LapManager Debug] " .. player.Name .. " hit Checkpoint " .. index .. "! (Expected: " .. data.nextCheckpoint .. ")")
				
				-- Check if they hit the correct next checkpoint
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
							print("🏆 " .. player.Name .. " finished the race in " .. string.format("%.2f", data.finishTime) .. "s! Rank: " .. data.finalRank)
							
							-- Award Gold
							local leaderstats = player:FindFirstChild("leaderstats")
							if leaderstats then
								local gold = leaderstats:FindFirstChild("Gold")
								if gold then
									local reward = 100
									if data.finalRank == 1 then reward = 1000
									elseif data.finalRank == 2 then reward = 600
									elseif data.finalRank == 3 then reward = 300
									end
									gold.Value += reward
									print("💰 Awarded " .. reward .. " Gold to " .. player.Name)
								end
							end
						else
							-- Next Lap
							data.currentLap += 1
							data.nextCheckpoint = 1
							lapUpdatedRemote:FireClient(player, data.currentLap, totalLapsForMap)
						end
					else
						-- Next checkpoint in the same lap
						data.nextCheckpoint = index + 1
					end
				end
			end)
			table.insert(checkpointConnections, conn)
		end
	end
	
	-- Start real-time ranking loop
	heartbeatConnection = RunService.Heartbeat:Connect(function()
		local sortedPlayers = {}
		local maxDistTraveled = 0
		
		for userId, data in pairs(playerLaps) do
			local p = Players:GetPlayerByUserId(userId)
			if p and p.Character and p.Character.PrimaryPart then
				local distPenalty = 0
				
				if data.currentLap == 0 and data.nextCheckpoint == 1 then
					-- 첫 번째 체크포인트를 향해 갈 때는 시작 위치로부터 '이동한 거리'를 사용하여 출발선 불균형 해결
					local startPos = playerStartPositions[userId]
					if startPos then
						local distTraveled = (p.Character.PrimaryPart.Position - startPos).Magnitude
						-- 미세한 대기 모션(Idle) 등으로 인한 거리 떨림을 무시하기 위해 1.0 미만은 0으로 고정
						if distTraveled < 1.0 then
							distTraveled = 0
						end
						distPenalty = -distTraveled -- 빼주었을 때 점수가 더해지도록 음수로 설정
						if distTraveled > maxDistTraveled then
							maxDistTraveled = distTraveled
						end
					end
				else
					local targetCpPos = checkpointPositions[data.nextCheckpoint]
					if targetCpPos then
						distPenalty = (p.Character.PrimaryPart.Position - targetCpPos).Magnitude
					end
					maxDistTraveled = 9999 -- 이미 출발선을 꽤 벗어남
				end
				
				local score = 0
				if data.finished then
					score = 10000000000 + (10000 - data.finishTime) -- faster finish time = higher score
				else
					score = (data.currentLap * 100000000) + (data.nextCheckpoint * 1000000) - distPenalty
				end
				
				table.insert(sortedPlayers, {
					userId = userId,
					name = p.DisplayName,
					score = score
				})
			end
		end
		
		table.sort(sortedPlayers, function(a, b)
			-- 점수(거리) 차이가 거의 없을 때는 이름순으로 정렬하여 UI가 미친듯이 떨리는 현상(Flickering) 방지
			if math.abs(a.score - b.score) < 0.01 then
				return a.name < b.name
			end
			return a.score > b.score
		end)
		
		currentRankings = sortedPlayers
		
		local sortedNames = {}
		local namesStr = ""
		for _, pData in ipairs(sortedPlayers) do
			table.insert(sortedNames, pData.name)
			namesStr ..= pData.name .. ","
		end
		
		local isStartingLine = maxDistTraveled < 1.0
		namesStr ..= tostring(isStartingLine)
		
		if namesStr ~= lastRankingsStr and #sortedNames > 0 then
			lastRankingsStr = namesStr
			local updateRankingsRemote = remotesFolder:FindFirstChild("UpdateRankings")
			if updateRankingsRemote and updateRankingsRemote:IsA("RemoteEvent") then
				updateRankingsRemote:FireAllClients(sortedNames, isStartingLine)
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

function LapManager.retireUnfinishedPlayers()
	for userId, data in pairs(playerLaps) do
		if not data.finished then
			data.finished = true
			data.finalRank = 999
			local p = Players:GetPlayerByUserId(userId)
			if p then
				raceFinishedRemote:FireClient(p, 0, data.currentLap, totalLapsForMap, data.finalRank)
				
				local leaderstats = p:FindFirstChild("leaderstats")
				if leaderstats then
					local gold = leaderstats:FindFirstChild("Gold")
					if gold then
						gold.Value += 10
						print("💰 Awarded 10 Gold (Retire) to " .. p.Name)
					end
				end
			end
		end
	end
end

function LapManager.getFinalScoreboardData()
	local results = {}
	for userId, data in pairs(playerLaps) do
		local p = Players:GetPlayerByUserId(userId)
		if p then
			local timeStr = "RETIRE"
			if data.finalRank ~= 999 then
				timeStr = string.format("%.2fs", data.finishTime)
			end
			local reward = 10
			if data.finalRank == 1 then reward = 1000
			elseif data.finalRank == 2 then reward = 600
			elseif data.finalRank == 3 then reward = 300
			elseif data.finalRank ~= 999 then reward = 100
			end
			
			table.insert(results, {
				name = p.DisplayName,
				rank = data.finalRank,
				time = timeStr,
				gold = reward
			})
		end
	end
	
	table.sort(results, function(a, b)
		return a.rank < b.rank
	end)
	
	return results
end

return LapManager
