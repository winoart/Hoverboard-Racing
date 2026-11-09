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

local simulatePassPurchaseEvent = remotesFolder:FindFirstChild("SimulatePassPurchase") :: RemoteEvent?
if not simulatePassPurchaseEvent then
	simulatePassPurchaseEvent = Instance.new("RemoteEvent")
	simulatePassPurchaseEvent.Name = "SimulatePassPurchase"
	simulatePassPurchaseEvent.Parent = remotesFolder
end

local simulatePurchaseFunc = remotesFolder:FindFirstChild("SimulatePurchase") :: RemoteFunction?
if not simulatePurchaseFunc then
	simulatePurchaseFunc = Instance.new("RemoteFunction")
	simulatePurchaseFunc.Name = "SimulatePurchase"
	simulatePurchaseFunc.Parent = remotesFolder
end

-- =========================================================================
-- 보상 지급 공통 함수
-- =========================================================================
local function grantProductRewards(player: Player, product: any)
	if not player or not product then return end
	
	-- 1. 보상 일괄 지급 로직 (골드, 호버보드, 스킬)
	if product.rewards then
		for _, reward in ipairs(product.rewards) do
			if reward.type == "Gold" then
				local leaderstats = player:FindFirstChild("leaderstats")
				if leaderstats then
					local goldValue = leaderstats:FindFirstChild("Gold")
					if goldValue and goldValue:IsA("IntValue") then
						goldValue.Value += reward.value
						print("💰 " .. player.Name .. " obtained " .. reward.value .. " Gold from " .. (product.promotionName or product.name or "Product"))
					end
				end
			elseif reward.type == "Hoverboard" then
				local ownedBoards = player:FindFirstChild("OwnedHoverboards") or (player:FindFirstChild("Inventory") and player.Inventory:FindFirstChild("OwnedHoverboards"))
				if ownedBoards then
					local hasBoard = ownedBoards:FindFirstChild(tostring(reward.value))
					if not hasBoard then
						local newTag = Instance.new("BoolValue")
						newTag.Name = tostring(reward.value)
						newTag.Parent = ownedBoards
						print("🏄 " .. player.Name .. " obtained Hoverboard: " .. reward.value .. " from " .. (product.promotionName or product.name or "Product"))
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
						print("⭐ " .. player.Name .. " obtained Premium Skill: " .. reward.value .. " from " .. (product.promotionName or product.name or "Product"))
					else
						print("⭐ " .. player.Name .. " already owns Premium Skill: " .. reward.value)
					end
				end
			end
		end
	end

	-- 2. 패스 특수 처리 로직 (이름 기반 또는 ID 기반)
	if product.name == "R 슬롯 잠금 해제" then
		local maxSkillSlots = player:FindFirstChild("MaxSkillSlots")
		if maxSkillSlots and maxSkillSlots.Value < 3 then
			maxSkillSlots.Value = 3
		end
	elseif product.name == "T 슬롯 잠금 해제" then
		local maxSkillSlots = player:FindFirstChild("MaxSkillSlots")
		if maxSkillSlots and maxSkillSlots.Value < 4 then
			maxSkillSlots.Value = 4
		end
	end

	-- 3. 구매 완료 영구 태그 및 Attribute 세팅 (스타터팩 및 일회성 패키지 중복 구매 방지)
	if product.id then
		local peFolder = player:FindFirstChild("PurchasedEvents")
		if not peFolder then
			peFolder = Instance.new("Folder")
			peFolder.Name = "PurchasedEvents"
			peFolder.Parent = player
		end
		if not peFolder:FindFirstChild(tostring(product.id)) then
			local val = Instance.new("BoolValue")
			val.Name = tostring(product.id)
			val.Value = true
			val.Parent = peFolder
		end
		player:SetAttribute("PurchasedEvent_" .. tostring(product.id), true)
		player:SetAttribute("OwnsPass_" .. tostring(product.id), true)
	end
end

-- 가상/테스트 구매 시뮬레이션 핸들러 (패스 및 골드 모두 지원)
simulatePurchaseFunc.OnServerInvoke = function(player: Player, productId: any, category: string)
	local pIdNum = tonumber(productId) or 0
	print(string.format("🛠️ [MonetizationServer] %s 구매 요청 처리: ID=%s, Cat=%s", player.Name, tostring(productId), tostring(category)))
	
	local foundProduct = nil
	local catList = {cachedShopData.Events, cachedShopData.Passes, cachedShopData.Golds}
	for _, list in ipairs(catList) do
		if list then
			for _, item in ipairs(list) do
				if item.id == pIdNum or tostring(item.id) == tostring(productId) then
					foundProduct = item
					break
				end
			end
		end
		if foundProduct then break end
	end
	
	if foundProduct then
		local isPass = (category == "Passes" or foundProduct.isGamePass == true)
		if isPass then
			player:SetAttribute("OwnsPass_" .. tostring(foundProduct.id), true)
			if foundProduct.name == "x2 Distance" then
				player:SetAttribute("OwnsPass_x2Distance", true)
				player:SetAttribute("OwnsPass_11111111", true)
			elseif foundProduct.name == "x2 Acceleration" then
				player:SetAttribute("OwnsPass_x2Acceleration", true)
				player:SetAttribute("OwnsPass_22222222", true)
			elseif foundProduct.name == "x2 Race Prize" then
				player:SetAttribute("OwnsPass_x2RacePrize", true)
				player:SetAttribute("OwnsPass_33333333", true)
			end
			grantProductRewards(player, foundProduct)
			return true, "패스 구매 완료!", foundProduct
		else
			grantProductRewards(player, foundProduct)
			return true, "골드 충전 완료!", foundProduct
		end
	else
		if category == "Passes" then
			player:SetAttribute("OwnsPass_" .. tostring(productId), true)
			return true, "패스 활성화 완료!", { name = "Pass", id = productId }
		end
	end
	
	return false, "상품을 찾을 수 없습니다."
end

simulatePassPurchaseEvent.OnServerEvent:Connect(function(player: Player, passId: number)
	player:SetAttribute("OwnsPass_" .. tostring(passId), true)
	if passId == 11111111 then player:SetAttribute("OwnsPass_x2Distance", true) end
	if passId == 22222222 then player:SetAttribute("OwnsPass_x2Acceleration", true) end
	if passId == 33333333 then player:SetAttribute("OwnsPass_x2RacePrize", true) end
	print("🛠️ [MonetizationServer] " .. player.Name .. " 테스트 게임패스 서버 동기화 완료: " .. tostring(passId))
end)

-- 캐시된 수량 및 상점 전체 데이터
local cachedShopData = {}
local cachedStocks = {}

local function reloadPromotions()
	local success, result = pcall(function()
		return AdminConfigStore:GetAsync("ShopData_v2")
	end)
	if success and result and type(result) == "table" and result.Events then
		cachedShopData = result
		print("🔄 [MonetizationServer] DataStore에서 최신 상점 데이터를 로드했습니다.")
	else
		-- DataStore가 비어있으면 기본 Config로 초기화 (최초 세팅)
		cachedShopData = MonetizationConfig.ShopData
	end
end

-- 서버 시작 시 프로모션 로드
reloadPromotions()

-- 타 서버에서 프로모션 변경 시 알림 수신
pcall(function()
	MessagingService:SubscribeAsync("ShopDataUpdated", function(message)
		print("📡 [MonetizationServer] 타 서버 변경 알림 수신, 상점 데이터를 새로고침합니다.")
		reloadPromotions()
	end)
end)

getActivePromosFunc.OnServerInvoke = function(player)
	return cachedShopData
end

local function fetchAllStocks()
	-- Event 탭 상품들 중 한정 수량이 있는 것만 확인
	if cachedShopData.Events then
		for _, product in ipairs(cachedShopData.Events) do
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

-- 결제 승인 콜백 함수 (Developer Product)
local function processReceipt(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	
	local purchasedProductId = receiptInfo.ProductId
	
	-- 상품 탐색 (Events, Passes, Golds 모든 탭에서 탐색)
	local purchasedProduct = nil
	local categoryList = {cachedShopData.Events, cachedShopData.Passes, cachedShopData.Golds}
	
	for _, category in ipairs(categoryList) do
		if category then
			for _, product in ipairs(category) do
				if product.id == purchasedProductId then
					purchasedProduct = product
					break
				end
			end
		end
		if purchasedProduct then break end
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

		grantProductRewards(player, purchasedProduct)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	else
		warn("🚨 Unknown Product ID purchased: " .. purchasedProductId)
	end
	
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

MarketplaceService.ProcessReceipt = processReceipt
print("🛒 [MonetizationServer] Started processing receipts.")

-- 게임패스 인게임 구매 성공 처리
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, wasPurchased)
	if wasPurchased then
		player:SetAttribute("OwnsPass_" .. tostring(gamePassId), true)
		print("🛒 [MonetizationServer] " .. player.Name .. " purchased GamePass: " .. tostring(gamePassId))
		
		-- 상품 탐색 후 보상 지급 (스타터 팩 등 이벤트/패스에 설정된 보상 지급)
		local foundProduct = nil
		local categoryList = {cachedShopData.Events, cachedShopData.Passes}
		for _, cat in ipairs(categoryList) do
			if cat then
				for _, prod in ipairs(cat) do
					if prod.id == gamePassId then
						foundProduct = prod
						break
					end
				end
			end
			if foundProduct then break end
		end
		
		if foundProduct then
			grantProductRewards(player, foundProduct)
		end
	end
end)
