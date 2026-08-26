--!strict
-- MapManager.luau
-- Studio Model Map Loader: Loads/Unloads maps from ReplicatedStorage.Maps and positions them directly below WaitingRoom Lounge

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local MapBuilder = require(script.Parent:WaitForChild("MapBuilder") :: ModuleScript)

local MapManager = {}

-- 1. Ensure ReplicatedStorage.Maps folder exists
function MapManager.getMapsFolder(): Folder
	local mapsFolder = ReplicatedStorage:FindFirstChild("Maps") :: Folder?
	if not mapsFolder then
		mapsFolder = Instance.new("Folder")
		mapsFolder.Name = "Maps"
		mapsFolder.Parent = ReplicatedStorage
	end
	return mapsFolder
end

-- 2. Find WaitingRoom Lounge CFrame in Workspace
function MapManager.getLoungeCFrame(): CFrame
	for _, child in ipairs(Workspace:GetChildren()) do
		local nameLower = child.Name:lower():gsub("%s+", "")
		if nameLower:find("waitingroom") or nameLower:find("lounge") or nameLower:find("대기실") or nameLower:find("스폰장소") or nameLower:find("스폰") then
			if child:IsA("BasePart") then
				return child.CFrame
			elseif child:IsA("Model") then
				return child:GetPivot()
			end
		end
	end

	local loungeSpawn = Workspace:FindFirstChild("LoungeSpawnLocation") :: BasePart?
	if loungeSpawn then
		return loungeSpawn.CFrame
	end

	return CFrame.new(0, 85, 0)
end

-- 3. Ensure template map model exists in ReplicatedStorage.Maps
function MapManager.ensureMapTemplate(mapName: string): Model
	local mapsFolder = MapManager.getMapsFolder()
	local existingTemplate = mapsFolder:FindFirstChild(mapName) :: Model?

	if existingTemplate then
		return existingTemplate
	end

	local workspaceTemplate = Workspace:FindFirstChild(mapName) :: Model?
	if workspaceTemplate then
		return workspaceTemplate
	end

	-- If template is missing in ReplicatedStorage.Maps, build Oval Speedway default template
	if mapName == "Oval Speedway" or mapName == "Default" or not existingTemplate then
		local newModel = MapBuilder.buildOvalSpeedwayModel()
		newModel.Parent = mapsFolder
		print("🏗️ [MapManager] Built initial 'Oval Speedway' model template in ReplicatedStorage.Maps")
		return newModel
	end

	return mapsFolder:FindFirstChild("Oval Speedway") :: Model or MapBuilder.buildOvalSpeedwayModel()
end

-- 4. Unload current active map from Workspace
function MapManager.UnloadCurrentMap()
	local activeMap = Workspace:FindFirstChild("ActiveMap")
	if activeMap then
		activeMap:Destroy()
		print("🧹 [MapManager] Cleaned up active map from Workspace")
	end

	-- Clean up legacy un-grouped map parts if any lingering
	for _, name in ipairs({ "HoverboardTrack", "InfieldGrass", "TrackBarrier", "InnerTrackBarrier", "Grandstands", "StartingPoint" }) do
		local legacy = Workspace:FindFirstChild(name)
		if legacy then
			legacy:Destroy()
		end
	end
end

-- 5. Load map model from ReplicatedStorage.Maps right below WaitingRoom
function MapManager.LoadMap(mapName: string): (Model, CFrame)
	MapManager.UnloadCurrentMap()

	local template = MapManager.ensureMapTemplate(mapName)
	local activeMap = template:Clone()
	activeMap.Name = "ActiveMap"

	-- Get Lounge position & position map right below Lounge (Y - 80 studs)
	local loungeCFrame = MapManager.getLoungeCFrame()
	local targetMapPos = Vector3.new(loungeCFrame.Position.X, loungeCFrame.Position.Y - 80, loungeCFrame.Position.Z)

	-- Pivot active map to target position directly under WaitingRoom
	activeMap:PivotTo(CFrame.new(targetMapPos))
	activeMap.Parent = Workspace

	-- Locate start grid CFrame inside loaded map model
	local startGridPart = activeMap:FindFirstChild("TrackStartGridPart", true) :: BasePart?
	local startGridCFrame: CFrame

	if startGridPart then
		startGridCFrame = startGridPart.CFrame
	else
		local startModel = activeMap:FindFirstChild("StartingPoint", true) :: Model?
		if startModel then
			startGridCFrame = startModel:GetPivot() * CFrame.new(0, 15, -3)
		else
			startGridCFrame = CFrame.new(targetMapPos + Vector3.new(280, 20, 0))
		end
	end

	print("🗺️ [MapManager] Successfully loaded map '" .. mapName .. "' directly below WaitingRoom!")
	return activeMap, startGridCFrame
end

return MapManager
