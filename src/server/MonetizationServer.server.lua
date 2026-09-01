--!strict
-- MonetizationServer.server.lua
-- 로블록스 결제 승인(ProcessReceipt) 및 골드 지급을 담당하는 서버 스크립트

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local MonetizationConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("MonetizationConfig"))

local UNLOCK_SLOT3_PRODUCT_ID = 123456789 
local UNLOCK_SLOT4_PRODUCT_ID = 987654321 

-- 결제 승인 콜백 함수
local function processReceipt(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		-- 플레이어가 게임을 나갔으면 NotProcessed 처리 (다음 접속 시 재시도)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	
	local purchasedProductId = receiptInfo.ProductId
	
	if purchasedProductId == UNLOCK_SLOT3_PRODUCT_ID then
		local maxSkillSlots = player:FindFirstChild("MaxSkillSlots")
		if maxSkillSlots and maxSkillSlots.Value < 3 then
			maxSkillSlots.Value = 3
			print("🔓 [MonetizationServer] " .. player.Name .. " unlocked Slot 3!")
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		return Enum.ProductPurchaseDecision.PurchaseGranted -- Already unlocked
	elseif purchasedProductId == UNLOCK_SLOT4_PRODUCT_ID then
		local maxSkillSlots = player:FindFirstChild("MaxSkillSlots")
		if maxSkillSlots and maxSkillSlots.Value < 4 then
			maxSkillSlots.Value = 4
			print("🔓 [MonetizationServer] " .. player.Name .. " unlocked Slot 4!")
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		return Enum.ProductPurchaseDecision.PurchaseGranted -- Already unlocked
	end
	
	local purchasedProduct = nil
	
	-- 어떤 상품을 샀는지 찾기
	for _, product in ipairs(MonetizationConfig.GoldProducts) do
		if product.id == purchasedProductId then
			purchasedProduct = product
			break
		end
	end
	
	if purchasedProduct then
		local leaderstats = player:FindFirstChild("leaderstats")
		if leaderstats then
			local goldValue = leaderstats:FindFirstChild("Gold")
			if goldValue and goldValue:IsA("IntValue") then
				-- 골드 지급!
				goldValue.Value += purchasedProduct.amount
				print("💰 [MonetizationServer] " .. player.Name .. " purchased " .. purchasedProduct.name .. "! Awarded " .. purchasedProduct.amount .. " Gold.")
				
				-- 성공적으로 지급 완료
				return Enum.ProductPurchaseDecision.PurchaseGranted
			end
		end
	else
		warn("🚨 [MonetizationServer] Unknown Product ID purchased: " .. purchasedProductId)
	end
	
	-- 뭔가 문제가 생겼다면 나중에 다시 시도하도록 NotProcessed 반환
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- 콜백 등록 (전역에서 딱 한 번만 등록해야 함)
MarketplaceService.ProcessReceipt = processReceipt

print("🛒 [MonetizationServer] Started processing receipts.")
