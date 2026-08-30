--!strict
-- StoreServer.server.luau
-- Handles BoardStore ClickDetector and Roulette Spin Logic

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotesFolder = ReplicatedStorage:WaitForChild("HoverboardRemotes")

local openStoreRemote = remotesFolder:FindFirstChild("OpenStore") :: RemoteEvent
if not openStoreRemote then
	openStoreRemote = Instance.new("RemoteEvent")
	openStoreRemote.Name = "OpenStore"
	openStoreRemote.Parent = remotesFolder
end

-- We create SpinRoulette if it doesn't exist (or just use a new one)
local spinRouletteRemote = remotesFolder:FindFirstChild("SpinRoulette") :: RemoteFunction
if not spinRouletteRemote then
	spinRouletteRemote = Instance.new("RemoteFunction")
	spinRouletteRemote.Name = "SpinRoulette"
	spinRouletteRemote.Parent = remotesFolder
end

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StoreConfig = require(Shared:WaitForChild("StoreConfig") :: ModuleScript)

-- 1. Setup BoardStore ClickDetector
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
	
	print("🛒 [StoreServer] BoardStore ClickDetector successfully attached to:", storeObj.Name, "(", storeObj.ClassName, ")")
end

local function checkAndSetup(obj: Instance)
	local function isTargetName(name)
		return name:lower():gsub("%s+", "") == "boardstore"
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

-- 2. Handle Roulette Spin Logic
spinRouletteRemote.OnServerInvoke = function(player: Player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local gold = leaderstats and leaderstats:FindFirstChild("Gold") :: IntValue
	local ownedFolder = player:FindFirstChild("OwnedHoverboards")
	
	if not gold or not ownedFolder then
		return false, "데이터 오류", false
	end
	
	if gold.Value < StoreConfig.RouletteCost then
		return false, "골드가 부족합니다.", false
	end
	
	-- Calculate total weight
	local totalWeight = 0
	local pool = {}
	for _, item in ipairs(StoreConfig.Items) do
		if item.weight and item.weight > 0 then
			totalWeight += item.weight
			table.insert(pool, item)
		end
	end
	
	-- Spin
	local randomVal = math.random(1, totalWeight)
	local currentWeight = 0
	local wonItem = nil
	
	for _, item in ipairs(pool) do
		currentWeight += item.weight
		if randomVal <= currentWeight then
			wonItem = item
			break
		end
	end
	
	if not wonItem then
		return false, "뽑기 실패 (풀 오류)", false
	end
	
	-- Deduct Gold
	gold.Value -= StoreConfig.RouletteCost
	
	local isDuplicate = (ownedFolder:FindFirstChild(wonItem.id) ~= nil)
	
	if isDuplicate then
		-- Refund 1/3
		gold.Value += StoreConfig.RefundAmount
		print("🎰 [StoreServer] " .. player.Name .. " spun and got DUPLICATE " .. wonItem.name .. ". Refunded " .. StoreConfig.RefundAmount .. "G")
	else
		-- Add to inventory
		local owned = Instance.new("StringValue")
		owned.Name = wonItem.id
		owned.Parent = ownedFolder
		print("🎰 [StoreServer] " .. player.Name .. " spun and WON " .. wonItem.name .. "!")
	end
	
	return true, wonItem, isDuplicate
end
