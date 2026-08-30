--!strict
-- SkillStoreServer.server.luau
-- Handles Skill Store Part ClickDetector and Purchase Logic

print("🚀 [SkillStoreServer] 스크립트 가동 시작!")

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SkillStoreConfig = require(Shared:WaitForChild("SkillStoreConfig") :: ModuleScript)

-- RemoteEvents for Skill Store
local remotesFolder = ReplicatedStorage:FindFirstChild("SkillRemotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "SkillRemotes"
	remotesFolder.Parent = ReplicatedStorage
end

local openStoreRemote = remotesFolder:FindFirstChild("OpenSkillStore") :: RemoteEvent
if not openStoreRemote then
	openStoreRemote = Instance.new("RemoteEvent")
	openStoreRemote.Name = "OpenSkillStore"
	openStoreRemote.Parent = remotesFolder
end

local purchaseItemRemote = remotesFolder:FindFirstChild("PurchaseSkill") :: RemoteFunction
if not purchaseItemRemote then
	purchaseItemRemote = Instance.new("RemoteFunction")
	purchaseItemRemote.Name = "PurchaseSkill"
	purchaseItemRemote.Parent = remotesFolder
end

-- 1. Setup SkillStore ClickDetector
local function setupStorePart(storeObj: Instance)
	if storeObj:FindFirstChildOfClass("ClickDetector") then return end
	
	local clickDetector = Instance.new("ClickDetector")
	clickDetector.MaxActivationDistance = 32
	clickDetector.CursorIcon = "rbxasset://textures/DragCursor.png"
	clickDetector.Parent = storeObj
	
	clickDetector.MouseClick:Connect(function(player)
		openStoreRemote:FireClient(player)
	end)
	
	if storeObj:IsA("BasePart") then
		storeObj.CanQuery = true
	end
	
	print("🔮 [SkillStoreServer] SkillStore ClickDetector successfully attached to:", storeObj.Name, "(", storeObj.ClassName, ")")
end

local function checkAndSetup(obj: Instance)
	local function isTargetName(name)
		return name:lower():gsub("%s+", "") == "skillstore"
	end
	
	if isTargetName(obj.Name) then
		if obj:IsA("BasePart") or obj:IsA("Model") then
			setupStorePart(obj)
		end
	end
end

-- Check existing parts
for _, child in ipairs(Workspace:GetDescendants()) do
	checkAndSetup(child)
end

-- Listen for dynamically added parts
Workspace.DescendantAdded:Connect(checkAndSetup)

-- 2. Handle Purchase Logic
purchaseItemRemote.OnServerInvoke = function(player: Player, skillId: string, currencyType: string)
	local itemInfo = nil
	for _, item in ipairs(SkillStoreConfig.Skills) do
		if item.id == skillId then
			itemInfo = item
			break
		end
	end
	
	if not itemInfo then return false, "Skill not found" end
	
	local leaderstats = player:FindFirstChild("leaderstats")
	local gold = leaderstats and leaderstats:FindFirstChild("Gold") :: IntValue
	local ownedFolder = player:FindFirstChild("OwnedSkills")
	
	if ownedFolder and ownedFolder:FindFirstChild(skillId) then
		return false, "Already owned!"
	end
	
	if currencyType == "Gold" then
		if gold and gold.Value >= itemInfo.goldPrice then
			gold.Value -= itemInfo.goldPrice
			print("💸 [SkillStoreServer] " .. player.Name .. " bought " .. itemInfo.name .. " for " .. itemInfo.goldPrice .. " Gold!")
			
			local owned = Instance.new("StringValue")
			owned.Name = skillId
			owned.Parent = ownedFolder
			
			return true, "Successfully purchased " .. itemInfo.name .. "!"
		else
			return false, "Not enough Gold!"
		end
	end
	
	return false, "Invalid currency"
end
