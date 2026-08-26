--!strict
-- InitMaps.server.luau
-- Ensures ReplicatedStorage.Maps folder and Oval Speedway model are initialized on server startup

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local MapManager = require(Shared:WaitForChild("MapManager") :: ModuleScript)

task.spawn(function()
	task.wait(0.2)
	MapManager.ensureMapTemplate("Oval Speedway")
end)
