--!strict
-- StoreServer.server.luau
-- Handles Leaderstats, Store Part ClickDetector, and Purchase Logic

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotesFolder = ReplicatedStorage:WaitForChild("HoverboardRemotes")

-- Create RemoteEvents for Store
local openStoreRemote = Instance.new("RemoteEvent")
openStoreRemote.Name = "OpenStore"
openStoreRemote.Parent = remotesFolder

local purchaseItemRemote = Instance.new("RemoteFunction")
purchaseItemRemote.Name = "PurchaseItem"
purchaseItemRemote.Parent = remotesFolder

local equipItemRemote = Instance.new("RemoteFunction")
equipItemRemote.Name = "EquipItem"
equipItemRemote.Parent = remotesFolder

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StoreConfig = require(Shared:WaitForChild("StoreConfig") :: ModuleScript)

-- 1. Setup Leaderstats & Inventory
Players.PlayerAdded:Connect(function(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player
	
	local gold = Instance.new("IntValue")
	gold.Name = "Gold"
	gold.Value = 1000 -- Give some initial gold for testing
	gold.Parent = leaderstats

	local ownedFolder = Instance.new("Folder")
	ownedFolder.Name = "OwnedHoverboards"
	ownedFolder.Parent = player
	
	local defaultOwned = Instance.new("StringValue")
	defaultOwned.Name = "DefaultHoverboard"
	defaultOwned.Parent = ownedFolder
	
	local equippedId = Instance.new("StringValue")
	equippedId.Name = "EquippedHoverboardId"
	equippedId.Value = "DefaultHoverboard"
	equippedId.Parent = player
end)

-- 2. Setup BoardStore ClickDetector
local function setupStorePart()
	-- The user created a part named 'BoardStore'
	-- Search for it in Workspace (especially in WaitingRoom)
	local function findStorePart(): BasePart?
		for _, child in ipairs(Workspace:GetDescendants()) do
			if child:IsA("BasePart") and child.Name == "BoardStore" then
				return child
			end
		end
		return nil
	end
	
	local storePart = findStorePart()
	if storePart then
		local clickDetector = storePart:FindFirstChildOfClass("ClickDetector")
		if not clickDetector then
			clickDetector = Instance.new("ClickDetector")
			clickDetector.MaxActivationDistance = 15
			clickDetector.CursorIcon = "rbxasset://textures/DragCursor.png"
			clickDetector.Parent = storePart
		end
		
		clickDetector.MouseClick:Connect(function(player)
			openStoreRemote:FireClient(player)
		end)
		print("🛒 [StoreServer] BoardStore ClickDetector set up!")
	else
		warn("⚠️ [StoreServer] Could not find 'BoardStore' part in Workspace. Store clicking disabled.")
	end
end

-- Wait a moment for map/workspace to load, then setup
task.spawn(function()
	task.wait(2)
	setupStorePart()
end)

-- 3. Handle Purchase Logic
purchaseItemRemote.OnServerInvoke = function(player: Player, itemId: string, currencyType: string)
	-- find item in config
	local itemInfo = nil
	for _, item in ipairs(StoreConfig.Items) do
		if item.id == itemId then
			itemInfo = item
			break
		end
	end
	
	if not itemInfo then return false, "Item not found" end
	
	local leaderstats = player:FindFirstChild("leaderstats")
	local gold = leaderstats and leaderstats:FindFirstChild("Gold") :: IntValue
	local ownedFolder = player:FindFirstChild("OwnedHoverboards")
	
	if ownedFolder and ownedFolder:FindFirstChild(itemId) then
		return false, "Already owned!"
	end
	
	if currencyType == "Gold" then
		if gold and gold.Value >= itemInfo.goldPrice then
			gold.Value -= itemInfo.goldPrice
			print("💸 [StoreServer] " .. player.Name .. " bought " .. itemInfo.name .. " for " .. itemInfo.goldPrice .. " Gold!")
			
			local owned = Instance.new("StringValue")
			owned.Name = itemId
			owned.Parent = ownedFolder
			
			return true, "Successfully purchased " .. itemInfo.name .. "!"
		else
			return false, "Not enough Gold!"
		end
	elseif currencyType == "Robux" then
		-- Mock Robux Purchase
		print("💸 [StoreServer] " .. player.Name .. " bought " .. itemInfo.name .. " for " .. itemInfo.robuxPrice .. " Robux (MOCK)!")
		
		local owned = Instance.new("StringValue")
		owned.Name = itemId
		owned.Parent = ownedFolder
		
		return true, "Successfully purchased " .. itemInfo.name .. " with Robux!"
	end
	
	return false, "Invalid currency"
end

-- 4. Handle Equip Logic
equipItemRemote.OnServerInvoke = function(player: Player, itemId: string)
	local ownedFolder = player:FindFirstChild("OwnedHoverboards")
	if ownedFolder and ownedFolder:FindFirstChild(itemId) then
		local equippedId = player:FindFirstChild("EquippedHoverboardId") :: StringValue?
		if equippedId then
			equippedId.Value = itemId
			return true, "Equipped " .. itemId
		end
	end
	return false, "Item not owned!"
end
