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

local DataStoreService = game:GetService("DataStoreService")
local PlayerDataStore = DataStoreService:GetDataStore("HoverboardData_v1")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StoreConfig = require(Shared:WaitForChild("StoreConfig") :: ModuleScript)

-- 1. Setup Leaderstats & Inventory with DataStore
Players.PlayerAdded:Connect(function(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player
	
	local gold = Instance.new("IntValue")
	gold.Name = "Gold"
	
	local ownedFolder = Instance.new("Folder")
	ownedFolder.Name = "OwnedHoverboards"
	ownedFolder.Parent = player
	
	local equippedId = Instance.new("StringValue")
	equippedId.Name = "EquippedHoverboardId"
	
	-- Load Data
	local success, data = pcall(function()
		return PlayerDataStore:GetAsync(tostring(player.UserId))
	end)

	if success and data then
		gold.Value = data.Gold or 1000
		equippedId.Value = data.EquippedHoverboardId or "DefaultHoverboard"
		local ownedList = data.OwnedHoverboards or {"DefaultHoverboard"}
		for _, boardId in ipairs(ownedList) do
			local owned = Instance.new("StringValue")
			owned.Name = boardId
			owned.Parent = ownedFolder
		end
		print("💾 [StoreServer] Data loaded for " .. player.Name)
	else
		-- Default new player data
		gold.Value = 1000 -- Give some initial gold for testing
		equippedId.Value = "DefaultHoverboard"
		local defaultOwned = Instance.new("StringValue")
		defaultOwned.Name = "DefaultHoverboard"
		defaultOwned.Parent = ownedFolder
		print("🆕 [StoreServer] New player profile created for " .. player.Name)
	end

	gold.Parent = leaderstats
	equippedId.Parent = player
end)

Players.PlayerRemoving:Connect(function(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local gold = leaderstats and leaderstats:FindFirstChild("Gold") :: IntValue
	local ownedFolder = player:FindFirstChild("OwnedHoverboards")
	local equippedId = player:FindFirstChild("EquippedHoverboardId") :: StringValue

	if gold and ownedFolder and equippedId then
		local ownedList = {}
		for _, child in ipairs(ownedFolder:GetChildren()) do
			table.insert(ownedList, child.Name)
		end

		local dataToSave = {
			Gold = gold.Value,
			OwnedHoverboards = ownedList,
			EquippedHoverboardId = equippedId.Value
		}

		local success, err = pcall(function()
			PlayerDataStore:SetAsync(tostring(player.UserId), dataToSave)
		end)

		if not success then
			warn("🚨 [StoreServer] Failed to save data for " .. player.Name .. ": " .. tostring(err))
		else
			print("💾 [StoreServer] Data saved for " .. player.Name)
		end
	end
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
