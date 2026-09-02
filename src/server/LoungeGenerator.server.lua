--!strict
-- LoungeGenerator.server.luau
-- Finds user's floating WaitingRoom platform ("스폰장소") and attaches LoungeSpawnLocation to it

local Workspace = game:GetService("Workspace")

-- Destroy any temporary generated Sky Lounge models
local tempLounge = Workspace:FindFirstChild("WaitingRoomLounge")
if tempLounge then
	tempLounge:Destroy()
end

-- Find User's Custom WaitingRoom Part/Model ("스폰장소" or "WaitingRoom" floating platform)
local function getContainerBoundingBox(container: Instance): (CFrame, Vector3)
	if container:IsA("Model") then
		return container:GetBoundingBox()
	elseif container:IsA("BasePart") then
		return container.CFrame, container.Size
	end

	-- Calculate manually for Folders or Models without proper bounds
	local minX, minY, minZ = math.huge, math.huge, math.huge
	local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge
	local parts = {}
	for _, desc in ipairs(container:GetDescendants()) do
		if desc:IsA("BasePart") then
			table.insert(parts, desc)
		end
	end
	if #parts == 0 then
		return CFrame.new(), Vector3.new(60, 2, 60)
	end
	
	for _, part in ipairs(parts) do
		local size = part.Size
		local cf = part.CFrame
		local corners = {
			cf * CFrame.new(size.X/2, size.Y/2, size.Z/2),
			cf * CFrame.new(size.X/2, size.Y/2, -size.Z/2),
			cf * CFrame.new(size.X/2, -size.Y/2, size.Z/2),
			cf * CFrame.new(size.X/2, -size.Y/2, -size.Z/2),
			cf * CFrame.new(-size.X/2, size.Y/2, size.Z/2),
			cf * CFrame.new(-size.X/2, size.Y/2, -size.Z/2),
			cf * CFrame.new(-size.X/2, -size.Y/2, size.Z/2),
			cf * CFrame.new(-size.X/2, -size.Y/2, -size.Z/2),
		}
		for _, corner in ipairs(corners) do
			local pos = corner.Position
			minX = math.min(minX, pos.X)
			minY = math.min(minY, pos.Y)
			minZ = math.min(minZ, pos.Z)
			maxX = math.max(maxX, pos.X)
			maxY = math.max(maxY, pos.Y)
			maxZ = math.max(maxZ, pos.Z)
		end
	end
	
	local center = Vector3.new((minX + maxX)/2, (minY + maxY)/2, (minZ + maxZ)/2)
	local size = Vector3.new(maxX - minX, maxY - minY, maxZ - minZ)
	return CFrame.new(center), size
end

local function findUserWaitingRoom(): (Instance?, CFrame?, CFrame?, Vector3?)
	-- Helper to find the largest floor part in a folder/model
	local function getLargestFloorPart(container: Instance): BasePart?
		local bestPart = nil
		local maxArea = 0
		for _, child in ipairs(container:GetDescendants()) do
			if child:IsA("BasePart") and child.Name ~= "Model1" then
				local area = child.Size.X * child.Size.Z
				if area > maxArea then
					maxArea = area
					bestPart = child
				end
			end
		end
		return bestPart
	end

	-- 1. Search for named objects
	for _, child in ipairs(Workspace:GetChildren()) do
		local nameLower = child.Name:lower():gsub("%s+", "")
		if nameLower:find("waitingroom") or nameLower:find("lounge") or nameLower:find("대기실") or nameLower:find("스폰장소") or nameLower:find("스폰") then
			if child:IsA("BasePart") then
				return child, child.CFrame * CFrame.new(0, (child.Size.Y / 2) + 1.5, 0), child.CFrame, child.Size
			elseif child:IsA("Model") or child:IsA("Folder") then
				local primary = child:IsA("Model") and child.PrimaryPart or nil
				local targetPart = primary or getLargestFloorPart(child)
				
				local wallCFrame, wallSize = getContainerBoundingBox(child)
				
				if targetPart then
					return child, targetPart.CFrame * CFrame.new(0, (targetPart.Size.Y / 2) + 1.5, 0), wallCFrame, wallSize
				else
					local pivot = child:IsA("Model") and child:GetPivot() or CFrame.new(0, 85, 0)
					return child, pivot * CFrame.new(0, 2, 0), wallCFrame, wallSize
				end
			end
		end
	end

	-- 2. Search for any floating platform part high in the air (Y > 30 studs)
	for _, child in ipairs(Workspace:GetChildren()) do
		if child:IsA("BasePart") and child.Position.Y > 30 and child.Size.X > 20 then
			return child, child.CFrame * CFrame.new(0, (child.Size.Y / 2) + 1.5, 0), child.CFrame, child.Size
		end
	end

	return nil, nil, nil, nil
end

local roomObj, targetCFrame, wallCFrame, wallSize = findUserWaitingRoom()

local function createInvisibleWalls(centerCFrame: CFrame, size: Vector3, spawnCFrame: CFrame)
	local wallFolder = Workspace:FindFirstChild("LoungeWalls")
	if wallFolder then wallFolder:Destroy() end
	wallFolder = Instance.new("Folder")
	wallFolder.Name = "LoungeWalls"
	wallFolder.Parent = Workspace

	local wallHeight = 100
	local wallThickness = 5
	local halfX = size.X / 2
	local halfZ = size.Z / 2
	local padding = 2

	local basePos = Vector3.new(centerCFrame.Position.X, spawnCFrame.Position.Y, centerCFrame.Position.Z)
	local baseCFrame = CFrame.new(basePos) * (centerCFrame - centerCFrame.Position)

	local function makeWall(name, sizeVec, offsetCFrame)
		local wall = Instance.new("Part")
		wall.Name = name
		wall.Size = sizeVec
		wall.CFrame = offsetCFrame
		wall.Anchored = true
		wall.CanCollide = true
		wall.Transparency = 0.6 -- 반투명하게 해서 눈에 보이게 렌더링
		wall.Material = Enum.Material.ForceField
		wall.Color = Color3.fromRGB(0, 200, 255)
		wall.Parent = wallFolder
	end

	makeWall("WallNorth", Vector3.new(size.X + padding*2 + wallThickness*2, wallHeight, wallThickness), baseCFrame * CFrame.new(0, wallHeight/2, -halfZ - padding - wallThickness/2))
	makeWall("WallSouth", Vector3.new(size.X + padding*2 + wallThickness*2, wallHeight, wallThickness), baseCFrame * CFrame.new(0, wallHeight/2, halfZ + padding + wallThickness/2))
	makeWall("WallEast", Vector3.new(wallThickness, wallHeight, size.Z + padding*2), baseCFrame * CFrame.new(halfX + padding + wallThickness/2, wallHeight/2, 0))
	makeWall("WallWest", Vector3.new(wallThickness, wallHeight, size.Z + padding*2), baseCFrame * CFrame.new(-halfX - padding - wallThickness/2, wallHeight/2, 0))
	
	-- 천장은 보이지 않게 처리
	local ceiling = Instance.new("Part")
	ceiling.Name = "Ceiling"
	ceiling.Size = Vector3.new(size.X + padding*2 + wallThickness*2, wallThickness, size.Z + padding*2 + wallThickness*2)
	ceiling.CFrame = baseCFrame * CFrame.new(0, wallHeight, 0)
	ceiling.Anchored = true
	ceiling.CanCollide = true
	ceiling.Transparency = 1
	ceiling.Parent = wallFolder

	-- 낙하 시 스폰으로 올려보내는 거대한 캐치 플로어 추가
	local catchFloor = Instance.new("Part")
	catchFloor.Name = "CatchFloor"
	catchFloor.Size = Vector3.new(2000, 10, 2000)
	catchFloor.CFrame = CFrame.new(centerCFrame.Position.X, spawnCFrame.Position.Y - 15, centerCFrame.Position.Z)
	catchFloor.Anchored = true
	catchFloor.CanCollide = false
	catchFloor.Transparency = 1
	catchFloor.Parent = wallFolder

	catchFloor.Touched:Connect(function(hit)
		local character = hit.Parent
		if character and character:FindFirstChild("Humanoid") then
			local hrp = character:FindFirstChild("HumanoidRootPart")
			if hrp then
				hrp.CFrame = spawnCFrame * CFrame.new(0, 5, 0)
			end
		end
	end)
end

-- Ensure LoungeSpawnLocation is created at the user's floating platform
local existingSpawn = Workspace:FindFirstChild("LoungeSpawnLocation")
if existingSpawn then
	existingSpawn:Destroy()
end

if targetCFrame then
	local loungeSpawn = Instance.new("SpawnLocation")
	loungeSpawn.Name = "LoungeSpawnLocation"
	loungeSpawn.Anchored = true
	loungeSpawn.Locked = true
	loungeSpawn.CanCollide = false
	loungeSpawn.Neutral = true
	loungeSpawn.Duration = 0
	loungeSpawn.Transparency = 1.0
	loungeSpawn.Size = Vector3.new(30, 1, 30)
	loungeSpawn.CFrame = targetCFrame
	loungeSpawn.Parent = Workspace

	print("✅ 사용자 대기실 공중 플래그십 파트('스폰장소') 상단에 스폰지점 100% 동기화 완료!")
	
	if wallCFrame and wallSize then
		createInvisibleWalls(wallCFrame, wallSize, targetCFrame)
		print("✅ 대기실 낙하 방지용 투명 벽 생성 완료!")
	end
else
	-- Fallback default floating spawn high in the air if no part found
	local loungeSpawn = Instance.new("SpawnLocation")
	loungeSpawn.Name = "LoungeSpawnLocation"
	loungeSpawn.Anchored = true
	loungeSpawn.Locked = true
	loungeSpawn.CanCollide = true
	loungeSpawn.Neutral = true
	loungeSpawn.Duration = 0
	loungeSpawn.Transparency = 0.5
	loungeSpawn.Color = Color3.fromRGB(150, 160, 175)
	loungeSpawn.Size = Vector3.new(60, 2, 60)
	loungeSpawn.Position = Vector3.new(0, 85, 0)
	loungeSpawn.Parent = Workspace

	print("✅ 대기실 스폰지점 (Position Y=85) 자동 동기화 완료!")
	
	createInvisibleWalls(CFrame.new(0, 85, 0), Vector3.new(60, 2, 60), CFrame.new(0, 85, 0))
	print("✅ 기본 대기실 낙하 방지용 투명 벽 생성 완료!")
end
