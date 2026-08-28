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
local checkpointConnections: { RBXScriptConnection } = {}

-- Clean up any existing `.Touched` events
local function cleanupCheckpoints()
	for _, conn in ipairs(checkpointConnections) do
		if conn.Connected then
			conn:Disconnect()
		end
	end
	table.clear(checkpointConnections)
end

function LapManager.startTracking(mapName: string, startTime: number)
	cleanupCheckpoints()
	totalLapsForMap = MapManager.getTotalLaps(mapName)
	raceStartTime = startTime
	table.clear(playerLaps)

	for _, player in ipairs(Players:GetPlayers()) do
		playerLaps[player.UserId] = {
			currentLap = 0,
			nextCheckpoint = 1,
			finished = false,
			finishTime = 0,
		}
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
	for i, _ in pairs(checkpoints) do
		if i > maxCheckpoints then
			maxCheckpoints = i
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
							raceFinishedRemote:FireClient(player, data.finishTime, data.currentLap, totalLapsForMap)
							print("🏆 " .. player.Name .. " finished the race in " .. string.format("%.2f", data.finishTime) .. "s!")
							
							-- Award Gold
							local leaderstats = player:FindFirstChild("leaderstats")
							if leaderstats then
								local gold = leaderstats:FindFirstChild("Gold")
								if gold then
									gold.Value += 50
									print("💰 Awarded 50 Gold to " .. player.Name)
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
end

function LapManager.stopTracking()
	cleanupCheckpoints()
	table.clear(playerLaps)
end

return LapManager
