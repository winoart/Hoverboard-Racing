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

local openHoverboardShopRemote = remotesFolder:FindFirstChild("OpenHoverboardShop") :: RemoteEvent
if not openHoverboardShopRemote then
	openHoverboardShopRemote = Instance.new("RemoteEvent")
	openHoverboardShopRemote.Name = "OpenHoverboardShop"
	openHoverboardShopRemote.Parent = remotesFolder
end

local buyHoverboardRemote = remotesFolder:FindFirstChild("BuyHoverboard") :: RemoteFunction
if not buyHoverboardRemote then
	buyHoverboardRemote = Instance.new("RemoteFunction")
	buyHoverboardRemote.Name = "BuyHoverboard"
	buyHoverboardRemote.Parent = remotesFolder
end

local getKioskItemsRemote = remotesFolder:FindFirstChild("GetKioskItems") :: RemoteFunction
if not getKioskItemsRemote then
	getKioskItemsRemote = Instance.new("RemoteFunction")
	getKioskItemsRemote.Name = "GetKioskItems"
	getKioskItemsRemote.Parent = remotesFolder
end

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StoreConfig = require(Shared:WaitForChild("StoreConfig") :: ModuleScript)

-- 직접 스튜디오에 배치된 정적 ProximityPrompt 연결
local waitingRoom = Workspace:FindFirstChild("WaitingRoom")

local function getCenterPart(target: Instance): BasePart?
	if target:IsA("BasePart") then return target end
	if target:IsA("Model") and target.PrimaryPart then return target.PrimaryPart end
	if target:IsA("Model") then
		local anchor = target:FindFirstChild("PromptAnchor")
		if anchor and anchor:IsA("BasePart") then return anchor end
		anchor = Instance.new("Part")
		anchor.Name = "PromptAnchor"
		anchor.Size = Vector3.new(1, 1, 1)
		anchor.Transparency = 1
		anchor.CanCollide = false
		anchor.Anchored = true
		local cf, _ = target:GetBoundingBox()
		anchor.CFrame = cf
		anchor.Parent = target
		return anchor
	end
	return target:FindFirstChildWhichIsA("BasePart", true)
end

if waitingRoom then
	-- 1. 상점 (룰렛) 키오스크
	local shopStand = waitingRoom:FindFirstChild("HoverboardShopStand")
	if shopStand then
		local shopPrompt = shopStand:FindFirstChild("ProximityPrompt", true)
		if not shopPrompt then
			local promptPart = getCenterPart(shopStand)
			if promptPart then
				shopPrompt = Instance.new("ProximityPrompt")
				shopPrompt.ActionText = "룰렛 열기"
				shopPrompt.ObjectText = "호버보드 뽑기"
				shopPrompt.KeyboardKeyCode = Enum.KeyCode.E
				shopPrompt.RequiresLineOfSight = false
				shopPrompt.MaxActivationDistance = 15
				shopPrompt.Parent = promptPart
			end
		end
		
		if shopPrompt and shopPrompt:IsA("ProximityPrompt") then
			shopPrompt.Triggered:Connect(function(player)
				openStoreRemote:FireClient(player)
			end)
			print("🛒 [StoreServer] Bound static ProximityPrompt for HoverboardShopStand")
		end
	end
	
	-- 2. 호버보드 상점 (일반 키오스크)
	local kioskStand = waitingRoom:FindFirstChild("HoverboardKiosk")
	if kioskStand then
		local kioskPrompt = kioskStand:FindFirstChild("ProximityPrompt", true)
		if not kioskPrompt then
			local promptPart = getCenterPart(kioskStand)
			if promptPart then
				kioskPrompt = Instance.new("ProximityPrompt")
				kioskPrompt.ActionText = "상점 열기"
				kioskPrompt.ObjectText = "호버보드 키오스크"
				kioskPrompt.KeyboardKeyCode = Enum.KeyCode.E
				kioskPrompt.RequiresLineOfSight = false
				kioskPrompt.MaxActivationDistance = 15
				kioskPrompt.Parent = promptPart
			end
		end
		
		if kioskPrompt and kioskPrompt:IsA("ProximityPrompt") then
			kioskPrompt.Triggered:Connect(function(player)
				openHoverboardShopRemote:FireClient(player)
			end)
			print("🛒 [StoreServer] Bound static ProximityPrompt for HoverboardKiosk")
		end
	end
end

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
	
	-- Quest: Spend Gold
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local QuestBindables = ReplicatedStorage:FindFirstChild("QuestBindables")
	local addProgress = QuestBindables and QuestBindables:FindFirstChild("AddQuestProgress")
	if addProgress then
		addProgress:Fire(player.UserId, "_spend", StoreConfig.RouletteCost)
	end
	
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

-- 3. Handle Direct Board Purchase with Gold
buyHoverboardRemote.OnServerInvoke = function(player: Player, boardId: string)
	local leaderstats = player:FindFirstChild("leaderstats")
	local gold = leaderstats and leaderstats:FindFirstChild("Gold") :: IntValue
	local ownedFolder = player:FindFirstChild("OwnedHoverboards")
	
	if not gold or not ownedFolder then
		return false, "데이터 오류"
	end
	
	local targetItem = nil
	for _, item in ipairs(StoreConfig.Items) do
		if item.id == boardId then
			targetItem = item
			break
		end
	end
	
	if not targetItem then
		return false, "존재하지 않는 호버보드입니다."
	end
	
	if ownedFolder:FindFirstChild(targetItem.id) then
		return false, "이미 보유중인 호버보드입니다."
	end
	
	local price = targetItem.price or 0
	if gold.Value < price then
		return false, "골드가 부족합니다."
	end
	
	-- Deduct Gold
	gold.Value -= price
	
	-- Quest: Spend Gold
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local QuestBindables = ReplicatedStorage:FindFirstChild("QuestBindables")
	local addProgress = QuestBindables and QuestBindables:FindFirstChild("AddQuestProgress")
	if addProgress then
		addProgress:Fire(player.UserId, "_spend", price)
	end
	
	-- Add to inventory
	local owned = Instance.new("StringValue")
	owned.Name = targetItem.id
	owned.Parent = ownedFolder
	print("🛒 [StoreServer] " .. player.Name .. " bought " .. targetItem.name .. " for " .. price .. "G")
	
	return true, targetItem.name .. " 구매 완료!"
end

-- 4. Hoverboard Kiosk Rotation Logic
local currentKioskItems = {}
local nextRefreshTime = 0
local REFRESH_INTERVAL = 60 -- 1 minute (테스트용: 60초, 완료 후 15 * 60으로 복구)

local restockRemote = remotesFolder:FindFirstChild("ShopRestocked") :: RemoteEvent?
if not restockRemote then
	restockRemote = Instance.new("RemoteEvent")
	restockRemote.Name = "ShopRestocked"
	restockRemote.Parent = remotesFolder
end

local function refreshKioskItems(isInitial: boolean?)
	currentKioskItems = {}
	
	local function pickRarity()
		local rand = math.random(1, 100)
		local current = 0
		for rarity, rate in pairs(StoreConfig.ShopRarityRates) do
			current += rate
			if rand <= current then
				return rarity
			end
		end
		return "Common"
	end
	
	for i = 1, 3 do
		local rarity = pickRarity()
		local pool = {}
		
		-- Try to find items of the picked rarity that aren't already selected
		for _, item in ipairs(StoreConfig.Items) do
			if item.rarity == rarity and not table.find(currentKioskItems, item.id) then
				table.insert(pool, item)
			end
		end
		
		-- Fallback: if no items available in this rarity, take any available item
		if #pool == 0 then
			for _, item in ipairs(StoreConfig.Items) do
				if not table.find(currentKioskItems, item.id) then
					table.insert(pool, item)
				end
			end
		end
		
		if #pool > 0 then
			local picked = pool[math.random(1, #pool)]
			table.insert(currentKioskItems, picked.id)
		end
	end
	
	nextRefreshTime = os.time() + REFRESH_INTERVAL
	print("🔄 [StoreServer] Hoverboard Kiosk items refreshed:", table.concat(currentKioskItems, ", "))
	
	if not isInitial and restockRemote then
		restockRemote:FireAllClients(currentKioskItems)
	end
end

-- Initialize first rotation
refreshKioskItems(true)

task.spawn(function()
	while true do
		local waitTime = nextRefreshTime - os.time()
		if waitTime <= 0 then
			refreshKioskItems(false)
		else
			task.wait(1)
		end
	end
end)

getKioskItemsRemote.OnServerInvoke = function(player: Player)
	-- Return current items and remaining seconds
	local remaining = math.max(0, nextRefreshTime - os.time())
	return currentKioskItems, remaining
end
