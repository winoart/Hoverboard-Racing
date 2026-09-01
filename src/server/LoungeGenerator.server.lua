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
local function findUserWaitingRoom(): (Instance?, CFrame?)
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
				return child, child.CFrame * CFrame.new(0, (child.Size.Y / 2) + 1.5, 0)
			elseif child:IsA("Model") or child:IsA("Folder") then
				local primary = child:IsA("Model") and child.PrimaryPart or nil
				local targetPart = primary or getLargestFloorPart(child)
				
				if targetPart then
					return child, targetPart.CFrame * CFrame.new(0, (targetPart.Size.Y / 2) + 1.5, 0)
				else
					local pivot = child:IsA("Model") and child:GetPivot() or CFrame.new(0, 85, 0)
					return child, pivot * CFrame.new(0, 2, 0)
				end
			end
		end
	end

	-- 2. Search for any floating platform part high in the air (Y > 30 studs)
	for _, child in ipairs(Workspace:GetChildren()) do
		if child:IsA("BasePart") and child.Position.Y > 30 and child.Size.X > 20 then
			return child, child.CFrame * CFrame.new(0, (child.Size.Y / 2) + 1.5, 0)
		end
	end

	return nil, nil
end

local roomObj, targetCFrame = findUserWaitingRoom()

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
end
