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

-- 1. Setup SkillStore & SkillKiosk Interaction (ClickDetector + ProximityPrompt)
local function setupStorePart(storeObj: Instance)
	if storeObj:FindFirstChildOfClass("ClickDetector") then return end
	
	local clickDetector = Instance.new("ClickDetector")
	clickDetector.MaxActivationDistance = 32
	clickDetector.CursorIcon = "rbxasset://textures/DragCursor.png"
	clickDetector.Parent = storeObj
	
	clickDetector.MouseClick:Connect(function(player)
		openStoreRemote:FireClient(player)
	end)

	local prompt = storeObj:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Parent = storeObj
	end
	
	prompt.ActionText = "상점 열기"
	prompt.ObjectText = "스킬 상점"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false

	-- 항상 Triggered 이벤트를 연결합니다. (기존에 연결된 함수가 없다면)
	-- 중복 연결을 방지하기 위해 태그를 사용
	if not prompt:GetAttribute("BoundToStore") then
		prompt:SetAttribute("BoundToStore", true)
		prompt.Triggered:Connect(function(player)
			openStoreRemote:FireClient(player)
		end)
	end
	
	if storeObj:IsA("BasePart") then
		storeObj.CanQuery = true
	end
	
	print("🔮 [SkillStoreServer] SkillStore ClickDetector & ProximityPrompt attached to:", storeObj.Name, "(", storeObj.ClassName, ")")
end

local function setupSkillKiosk(kioskObj: Instance)
	-- If cloned from HoverboardKiosk, remove any old lingering effect boxes or prompts
	for _, child in ipairs(kioskObj:GetChildren()) do
		if child.Name == "KioskEffectBox" or child.Name == "SkillKioskEffectBox" then
			child:Destroy()
		end
	end
	
	local cf, sz
	if kioskObj:IsA("Model") then
		cf, sz = kioskObj:GetBoundingBox()
	elseif kioskObj:IsA("BasePart") then
		cf, sz = kioskObj.CFrame, kioskObj.Size
	else
		return
	end
	
	local effectPart = Instance.new("Part")
	effectPart.Name = "SkillKioskEffectBox"
	effectPart.Size = sz
	effectPart.CFrame = cf
	effectPart.Transparency = 1
	effectPart.CanCollide = false
	effectPart.Anchored = true
	effectPart.CanQuery = true
	effectPart.Parent = kioskObj
	
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "상점 열기"
	prompt.ObjectText = "스킬 상점"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = effectPart
	
	prompt.Triggered:Connect(function(player)
		openStoreRemote:FireClient(player)
	end)
	
	local clickDetector = Instance.new("ClickDetector")
	clickDetector.MaxActivationDistance = 32
	clickDetector.CursorIcon = "rbxasset://textures/DragCursor.png"
	clickDetector.Parent = effectPart
	clickDetector.MouseClick:Connect(function(player)
		openStoreRemote:FireClient(player)
	end)
	
	print("🔮 [SkillStoreServer] SkillKiosk ProximityPrompt & ClickDetector successfully attached to:", kioskObj.Name)
end

local function checkAndSetup(obj: Instance)
	local function cleanName(name: string)
		return name:lower():gsub("%s+", "")
	end
	
	local cName = cleanName(obj.Name)
	if cName == "skillstore" then
		if obj:IsA("BasePart") or obj:IsA("Model") then
			setupStorePart(obj)
		end
	elseif cName == "skillkiosk" then
		if obj:IsA("BasePart") or obj:IsA("Model") then
			setupSkillKiosk(obj)
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
			
			-- Quest: Spend Gold
			local ReplicatedStorage = game:GetService("ReplicatedStorage")
			local QuestBindables = ReplicatedStorage:FindFirstChild("QuestBindables")
			local addProgress = QuestBindables and QuestBindables:FindFirstChild("AddQuestProgress")
			if addProgress then
				addProgress:Fire(player.UserId, "_spend", itemInfo.goldPrice)
			end
			
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
