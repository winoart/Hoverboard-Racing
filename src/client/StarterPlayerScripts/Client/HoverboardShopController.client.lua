--!strict
-- HoverboardShopController.client.luau
-- 골드로 호버보드를 구매하는 상점 UI 컨트롤러

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local playerGui = LocalPlayer:WaitForChild("PlayerGui")

local remotesFolder = ReplicatedStorage:WaitForChild("HoverboardRemotes")
local openShopRemote = remotesFolder:WaitForChild("OpenHoverboardShop") :: RemoteEvent
local buyRemote = remotesFolder:WaitForChild("BuyHoverboard") :: RemoteFunction
local getKioskItemsRemote = remotesFolder:WaitForChild("GetKioskItems") :: RemoteFunction

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StoreConfig = require(Shared:WaitForChild("StoreConfig") :: ModuleScript)

-- UI 참조 (GenerateHoverboardShopUI.lua 로 생성된 모델을 사용)
local screenGui = playerGui:WaitForChild("HoverboardShopHUD")
local bgFrame = screenGui:WaitForChild("Background")
local closeBtn = bgFrame:WaitForChild("CloseButton")
local refreshTimerLabel = bgFrame:WaitForChild("RefreshTimerLabel")
local scrollFrame = bgFrame:WaitForChild("ScrollFrame")
local cardTemplate = scrollFrame:WaitForChild("CardTemplate")
cardTemplate.Visible = false

local gridLayout = scrollFrame:FindFirstChildOfClass("UIGridLayout")

-- 보유중인지 확인하는 함수
local function checkOwned(boardId: string)
	local ownedFolder = LocalPlayer:FindFirstChild("OwnedHoverboards")
	if ownedFolder and ownedFolder:FindFirstChild(boardId) then
		return true
	end
	return false
end

-- 아이템 목록 생성
local itemCards = {}

local function generateItems(kioskItemsList)
	for _, child in ipairs(scrollFrame:GetChildren()) do
		if child:IsA("Frame") and child.Name ~= "CardTemplate" then
			child:Destroy()
		end
	end
	
	-- 기존 itemCards 초기화
	for _, data in pairs(itemCards) do
		if data.conn then data.conn:Disconnect() end
	end
	itemCards = {}
	
	for i, id in ipairs(kioskItemsList) do
		local item = nil
		for _, v in ipairs(StoreConfig.Items) do
			if v.id == id then
				item = v
				break
			end
		end
		if not item then continue end
		
		local card = cardTemplate:Clone()
		card.Name = id
		card.BackgroundColor3 = StoreConfig.RarityColors[item.rarity] or Color3.fromRGB(40, 45, 55)
		card.LayoutOrder = i
		
		card.ItemImage.Image = item.imageId
		card.ItemName.Text = item.name
		card.PriceLabel.Text = (item.price or 0) .. " G"
		
		local buyBtn = card.BuyButton
		
		card.Visible = true
		card.Parent = scrollFrame
		
		itemCards[item.id] = { button = buyBtn, price = item.price or 0 }
	end
	
	local rows = math.ceil(#kioskItemsList / 3)
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, rows * 335)
	
end

local function updateButtons()
	for id, data in pairs(itemCards) do
		local btn = data.button
		if checkOwned(id) then
			btn.Text = "보유중"
			btn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
			btn.Active = false
			btn.AutoButtonColor = false
		else
			btn.Text = "구매"
			btn.BackgroundColor3 = Color3.fromRGB(100, 220, 110)
			btn.Active = true
			btn.AutoButtonColor = true
		end
	end
end

-- 버튼 클릭 이벤트 연결
local function bindButtons()
	for id, data in pairs(itemCards) do
		if data.conn then data.conn:Disconnect() end
		data.conn = data.button.MouseButton1Click:Connect(function()
			if checkOwned(id) then return end
			
			local success, msg = buyRemote:InvokeServer(id)
			if success then
				print("✅ 구매 성공:", msg)
				updateButtons()
			else
				warn("❌ 구매 실패:", msg)
			end
		end)
	end
end

local isShopOpen = false
local remainingTime = 0

local function formatTime(seconds)
	local m = math.floor(seconds / 60)
	local s = seconds % 60
	return string.format("%02d:%02d", m, s)
end

task.spawn(function()
	while true do
		if isShopOpen and remainingTime > 0 then
			remainingTime -= 1
			refreshTimerLabel.Text = "다음 갱신까지: " .. formatTime(remainingTime)
			if remainingTime <= 0 then
				refreshTimerLabel.Text = "갱신 중..."
				-- Fetch new items
				local newItems, newRemaining = getKioskItemsRemote:InvokeServer()
				remainingTime = newRemaining
				generateItems(newItems)
				updateButtons()
				bindButtons()
			end
		end
		task.wait(1)
	end
end)

closeBtn.MouseButton1Click:Connect(function()
	isShopOpen = false
	screenGui.Enabled = false
end)

openShopRemote.OnClientEvent:Connect(function()
	local items, remaining = getKioskItemsRemote:InvokeServer()
	remainingTime = remaining
	refreshTimerLabel.Text = "다음 갱신까지: " .. formatTime(remainingTime)
	
	generateItems(items)
	updateButtons()
	bindButtons()
	
	isShopOpen = true
	screenGui.Enabled = true
end)
