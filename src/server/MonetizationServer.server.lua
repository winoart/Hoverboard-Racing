--!strict
-- MonetizationServer.server.lua
-- 로블록스 결제 승인(ProcessReceipt) 및 상점 상품 지급을 담당하는 서버 스크립트

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MessagingService = game:GetService("MessagingService")

local MonetizationConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MonetizationConfig"))
local ShopStockDataStore = DataStoreService:GetDataStore("RobuxShopStock_v1")
local AdminConfigStore = DataStoreService:GetDataStore("AdminConfig_v1")

-- 클라이언트용 원격 통신 (Remotes)
local remotesFolder = ReplicatedStorage:FindFirstChild("HoverboardRemotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "HoverboardRemotes"
	remotesFolder.Parent = ReplicatedStorage
end

local getShopStockFunc = remotesFolder:FindFirstChild("GetShopStockInfo") :: RemoteFunction?
if not getShopStockFunc then
	getShopStockFunc = Instance.new("RemoteFunction")
	getShopStockFunc.Name = "GetShopStockInfo"
	getShopStockFunc.Parent = remotesFolder
end

local getActivePromosFunc = remotesFolder:FindFirstChild("GetActivePromotions") :: RemoteFunction?
if not getActivePromosFunc then
	getActivePromosFunc = Instance.new("RemoteFunction")
	getActivePromosFunc.Name = "GetActivePromotions"
	getActivePromosFunc.Parent = remotesFolder
end

-- 캐시된 수량 및 프로모션 정보
local cachedPromotions = {}
local cachedStocks = {}

local function reloadPromotions()
	local success, result = pcall(function()
		return AdminConfigStore:GetAsync("RobuxPromotions")
	end)
	if success and result and type(result) == "table" and #result > 0 then
		cachedPromotions = result
		print("🔄 [MonetizationServer] DataStore에서 최신 프로모션 데이터를 로드했습니다.")
	else
		-- DataStore가 비어있으면 기본 하드코딩된 Config로 초기화 (최초 세팅)
		cachedPromotions = MonetizationConfig.RobuxPromotions
	end
end

-- 서버 시작 시 프로모션 로드
reloadPromotions()

-- 타 서버에서 프로모션 변경 시 알림 수신
pcall(function()
	MessagingService:SubscribeAsync("RobuxPromotionsUpdated", function(message)
		print("📡 [MonetizationServer] 타 서버 변경 알림 수신, 프로모션 데이터를 새로고침합니다.")
		reloadPromotions()
	end)
end)

getActivePromosFunc.OnServerInvoke = function(player)
	return cachedPromotions
end

local function fetchAllStocks()
	for _, product in ipairs(cachedPromotions) do
		if product.maxQuantity then
			local success, result = pcall(function()
				return ShopStockDataStore:GetAsync(tostring(product.id))
			end)
			if success then
				local sold = (result :: number) or 0
				local remaining = product.maxQuantity - sold
				cachedStocks[tostring(product.id)] = math.max(0, remaining)
			end
		end
	end
end

-- 주기적으로 스톡 정보를 갱신 (서버 1분마다)
task.spawn(function()
	while true do
		fetchAllStocks()
		task.wait(60)
	end
end)

getShopStockFunc.OnServerInvoke = function(player)
	return cachedStocks
end

-- 결제 승인 콜백 함수
local function processReceipt(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	
	local purchasedProductId = receiptInfo.ProductId
	
	-- 슬롯 잠금 해제 처리 (이건 고정 상품이라 MonetizationConfig 참고)
	if purchasedProductId == MonetizationConfig.SlotUnlockProducts.Slot3.id then
		local maxSkillSlots = player:FindFirstChild("MaxSkillSlots")
		if maxSkillSlots and maxSkillSlots.Value < 3 then
			maxSkillSlots.Value = 3
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		return Enum.ProductPurchaseDecision.PurchaseGranted
	elseif purchasedProductId == MonetizationConfig.SlotUnlockProducts.Slot4.id then
		local maxSkillSlots = player:FindFirstChild("MaxSkillSlots")
		if maxSkillSlots and maxSkillSlots.Value < 4 then
			maxSkillSlots.Value = 4
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	
	-- 프로모션 상품 탐색 (라이브 데이터 기준)
	local purchasedProduct = nil
	for _, product in ipairs(cachedPromotions) do
		if product.id == purchasedProductId then
			purchasedProduct = product
			break
		end
	end
	
	if purchasedProduct then
		-- 한정 수량 체크
		if purchasedProduct.maxQuantity then
			local purchaseSuccess = false
			local dsSuccess, err = pcall(function()
				ShopStockDataStore:UpdateAsync(tostring(purchasedProductId), function(currentSold)
					local sold = (currentSold :: number) or 0
					if sold >= purchasedProduct.maxQuantity then
						return currentSold -- 변경 안 함 (품절)
					else
						purchaseSuccess = true
						return sold + 1
					end
				end)
			end)
			
			if not dsSuccess then
				warn("🚨 DataStore 오류로 인해 구매 처리 실패:", err)
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
			
			if not purchaseSuccess then
				-- 품절되었지만 결제가 진행된 경우 대체 골드 지급
				local leaderstats = player:FindFirstChild("leaderstats")
				if leaderstats then
					local goldValue = leaderstats:FindFirstChild("Gold")
					if goldValue and goldValue:IsA("IntValue") then
						goldValue.Value += 1000
						warn("🚨 품절된 한정 상품을 구매하여 임시로 골드를 지급함:", player.Name)
					end
				end
				return Enum.ProductPurchaseDecision.PurchaseGranted
			end
			
			-- 재고 갱신 캐시
			if purchaseSuccess then
				local currentStock = cachedStocks[tostring(purchasedProductId)] or purchasedProduct.maxQuantity
				cachedStocks[tostring(purchasedProductId)] = math.max(0, currentStock - 1)
			end
		end

		-- 보상 일괄 지급 로직
		if purchasedProduct.rewards then
			for _, reward in ipairs(purchasedProduct.rewards) do
				if reward.type == "Gold" then
					local leaderstats = player:FindFirstChild("leaderstats")
					if leaderstats then
						local goldValue = leaderstats:FindFirstChild("Gold")
						if goldValue and goldValue:IsA("IntValue") then
							goldValue.Value += reward.value
							print("💰 " .. player.Name .. " obtained " .. reward.value .. " Gold from " .. purchasedProduct.promotionName)
						end
					end
				elseif reward.type == "Hoverboard" then
					local inventory = player:FindFirstChild("Inventory")
					local ownedBoards = inventory and inventory:FindFirstChild("OwnedHoverboards")
					if ownedBoards then
						local hasBoard = ownedBoards:FindFirstChild(tostring(reward.value))
						if not hasBoard then
							local newTag = Instance.new("BoolValue")
							newTag.Name = tostring(reward.value)
							newTag.Parent = ownedBoards
							print("🏄 " .. player.Name .. " obtained Hoverboard: " .. reward.value .. " from " .. purchasedProduct.promotionName)
						else
							print("🏄 " .. player.Name .. " already owns Hoverboard: " .. reward.value)
						end
					end
				elseif reward.type == "Skill" then
					local ownedSkills = player:FindFirstChild("OwnedSkills")
					if ownedSkills then
						local hasSkill = ownedSkills:FindFirstChild(tostring(reward.value))
						if not hasSkill then
							local newTag = Instance.new("BoolValue")
							newTag.Name = tostring(reward.value)
							newTag.Parent = ownedSkills
							print("⭐ " .. player.Name .. " obtained Premium Skill: " .. reward.value .. " from " .. purchasedProduct.promotionName)
						else
							print("⭐ " .. player.Name .. " already owns Premium Skill: " .. reward.value)
						end
					end
				end
			end
		end
		
		return Enum.ProductPurchaseDecision.PurchaseGranted
	else
		warn("🚨 Unknown Product ID purchased: " .. purchasedProductId)
	end
	
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

MarketplaceService.ProcessReceipt = processReceipt
print("🛒 [MonetizationServer] Started processing receipts.")
