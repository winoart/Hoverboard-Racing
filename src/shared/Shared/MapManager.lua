--!strict
-- MapManager.luau
-- Studio Model Map Loader: Loads/Unloads maps from ReplicatedStorage.Maps and positions them directly below WaitingRoom Lounge

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local MapBuilder = require(script.Parent:WaitForChild("MapBuilder") :: ModuleScript)

local MapManager = {}

MapManager.MapLaps = {
	["Oval Speedway"] = 5,
	["Cyber City"] = 3,
	["Magma Ridge"] = 3,
	["Desert Track"] = 4,
}

function MapManager.getTotalLaps(mapName: string): number
	return MapManager.MapLaps[mapName] or 3
end

-- 1. Ensure ReplicatedStorage.Maps folder exists
function MapManager.getMapsFolder(): Folder
	local mapsFolder: Folder? = nil
	for _, child in ipairs(ReplicatedStorage:GetChildren()) do
		if child:IsA("Folder") and (child.Name:lower() == "maps" or child.Name:lower() == "map") then
			mapsFolder = child
			break
		end
	end
	if not mapsFolder then
		mapsFolder = Instance.new("Folder")
		mapsFolder.Name = "Maps"
		mapsFolder.Parent = ReplicatedStorage
	end
	return mapsFolder
end

-- 2. Find WaitingRoom Lounge CFrame in Workspace
function MapManager.getLoungeCFrame(): CFrame
	-- Helper to find the largest floor part in a folder/model
	local function getLargestFloorPart(container: Instance): BasePart?
		local bestPart = nil
		local maxArea = 0
		for _, child in ipairs(container:GetDescendants()) do
			if child:IsA("BasePart") and child.Name ~= "BoardStore" then
				local area = child.Size.X * child.Size.Z
				if area > maxArea then
					maxArea = area
					bestPart = child
				end
			end
		end
		return bestPart
	end

	for _, child in ipairs(Workspace:GetChildren()) do
		local nameLower = child.Name:lower():gsub("%s+", "")
		if nameLower:find("waitingroom") or nameLower:find("lounge") or nameLower:find("대기실") or nameLower:find("스폰장소") or nameLower:find("스폰") then
			if child:IsA("BasePart") then
				return child.CFrame
			elseif child:IsA("Model") or child:IsA("Folder") then
				local primary = child:IsA("Model") and child.PrimaryPart or nil
				local targetPart = primary or getLargestFloorPart(child)
				
				if targetPart then
					return targetPart.CFrame
				else
					return child:IsA("Model") and child:GetPivot() or CFrame.new(0, 85, 0)
				end
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

	local function isValidTemplate(model: Instance?): boolean
		if not model or not model:IsA("Model") then return false end
		return model:FindFirstChildWhichIsA("BasePart", true) ~= nil
	end

	if isValidTemplate(existingTemplate) then
		return existingTemplate
	end

	local workspaceTemplate = Workspace:FindFirstChild(mapName) :: Model?
	if isValidTemplate(workspaceTemplate) then
		return workspaceTemplate
	end

	warn("🚨 [MapManager] Could not find a VALID map template '" .. mapName .. "' with physical parts in ReplicatedStorage.Maps or Workspace! Generating fallback map...")
	return MapBuilder.buildOvalSpeedwayModel()
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

	-- Find StartGrid to use as the center of our pivot
	local startGridPart = activeMap:FindFirstChild("TrackStartGridPart", true) :: BasePart?
	
	if startGridPart then
		-- Pivot map so that the startGrid is exactly at targetMapPos
		local mapPivot = activeMap:GetPivot()
		local offset = mapPivot:ToObjectSpace(startGridPart.CFrame)
		
		local targetCFrame = CFrame.new(targetMapPos) * mapPivot.Rotation
		activeMap:PivotTo(targetCFrame * offset:Inverse())
	else
		-- Fallback to BoundingBox if no StartGrid exists
		local originalPivot = activeMap:GetPivot()
		local bbCFrame = activeMap:GetBoundingBox()
		local pivotOffset = originalPivot.Position - bbCFrame.Position
		activeMap:PivotTo(CFrame.new(targetMapPos + pivotOffset) * originalPivot.Rotation)
	end
	
	activeMap.Parent = Workspace

	-- Locate start grid CFrame inside loaded map model
	local startGridCFrame: CFrame

	if startGridPart then
		startGridCFrame = startGridPart.CFrame
		
		local startModel = activeMap:FindFirstChild("StartingPoint", true) :: Model?
		if startModel then
			-- Generate missing CheckerTiles if user forgot to copy them
			local startLineBase = startModel:FindFirstChild("StartLineBase") :: BasePart?
			local hasChecker = startModel:FindFirstChild("CheckerTile")
			if startLineBase and not hasChecker then
				local lineWidth = startLineBase.Size.X
				local lineLength = startLineBase.Size.Z
				local sCFrame = startLineBase.CFrame
				
				local rows, cols = 2, 10
				local tileW, tileL = lineWidth / cols, lineLength / rows
				
				for r = 1, rows do
					for c = 1, cols do
						local isWhite = ((r + c) % 2 == 0)
						local offsetX = - (lineWidth / 2) + (c - 0.5) * tileW
						local offsetZ = - (lineLength / 2) + (r - 0.5) * tileL
						local tile = Instance.new("Part")
						tile.Name = "CheckerTile"
						tile.Anchored = true
						tile.CanCollide = false
						tile.Material = Enum.Material.SmoothPlastic
						tile.Color = isWhite and Color3.fromRGB(245, 245, 250) or Color3.fromRGB(25, 25, 30)
						tile.Size = Vector3.new(tileW, 0.18, tileL)
						tile.CFrame = sCFrame * CFrame.new(offsetX, 0.02, offsetZ)
						tile.TopSurface = Enum.SurfaceType.Smooth
						tile.Parent = startModel
					end
				end
			end
		end
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
