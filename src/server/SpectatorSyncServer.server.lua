--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local remotesFolder = ReplicatedStorage:WaitForChild("HoverboardRemotes")

local syncRemote = remotesFolder:FindFirstChild("SyncSpectatorState")
if not syncRemote then
	syncRemote = Instance.new("UnreliableRemoteEvent")
	syncRemote.Name = "SyncSpectatorState"
	syncRemote.Parent = remotesFolder
end

syncRemote.OnServerEvent:Connect(function(player, isBoosting, boosterGauge, currentSpeed)
	local character = player.Character
	if character then
		-- Use Attributes to replicate state to all clients automatically
		character:SetAttribute("IsBoosting", isBoosting)
		character:SetAttribute("BoosterGauge", boosterGauge)
		-- Speed is also synced for UI, though we can calculate it from velocity, this ensures exact matching if needed.
		character:SetAttribute("CurrentSpeed", currentSpeed)
	end
end)

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(char)
		char:SetAttribute("IsBoosting", false)
		char:SetAttribute("BoosterGauge", 0)
		char:SetAttribute("CurrentSpeed", 0)
	end)
end)
for _, player in ipairs(Players:GetPlayers()) do
	if player.Character then
		player.Character:SetAttribute("IsBoosting", false)
		player.Character:SetAttribute("BoosterGauge", 0)
		player.Character:SetAttribute("CurrentSpeed", 0)
	end
end
