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

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StoreConfig = require(Shared:WaitForChild("StoreConfig") :: ModuleScript)

-- UI 구성
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HoverboardShopHUD"
screenGui.Enabled = false
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local bgFrame = Instance.new("Frame")
bgFrame.Size = UDim2.new(0, 800, 0, 500)
bgFrame.Position = UDim2.new(0.5, -400, 0.5, -250)
bgFrame.BackgroundColor3 = Color3.fromRGB(30, 35, 45)
bgFrame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 16)
corner.Parent = bgFrame

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(255, 215, 0)
stroke.Thickness = 3
stroke.Parent = bgFrame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 60)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBlack
title.Text = "호버보드 상점"
title.TextColor3 = Color3.fromRGB(255, 215, 0)
title.TextSize = 32
title.Parent = bgFrame

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 40, 0, 40)
closeBtn.Position = UDim2.new(1, -50, 0, 10)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.TextSize = 24
closeBtn.Parent = bgFrame

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(1, 0)
closeCorner.Parent = closeBtn

closeBtn.MouseButton1Click:Connect(function()
	screenGui.Enabled = false
end)

local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Size = UDim2.new(1, -40, 1, -80)
scrollFrame.Position = UDim2.new(0, 20, 0, 60)
scrollFrame.BackgroundTransparency = 1
scrollFrame.ScrollBarThickness = 8
scrollFrame.Parent = bgFrame

local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.new(0, 240, 0, 320)
gridLayout.CellPadding = UDim2.new(0, 15, 0, 15)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = scrollFrame

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

local function generateItems()
	for _, child in ipairs(scrollFrame:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	
	for i, item in ipairs(StoreConfig.Items) do
		local card = Instance.new("Frame")
		card.BackgroundColor3 = Color3.fromRGB(40, 45, 55)
		card.LayoutOrder = i
		card.Parent = scrollFrame
		
		local cardCorner = Instance.new("UICorner")
		cardCorner.CornerRadius = UDim.new(0, 12)
		cardCorner.Parent = card
		
		local cardStroke = Instance.new("UIStroke")
		cardStroke.Color = StoreConfig.RarityColors[item.rarity] or Color3.fromRGB(200, 200, 200)
		cardStroke.Thickness = 2
		cardStroke.Parent = card
		
		-- 이미지
		local img = Instance.new("ImageLabel")
		img.Size = UDim2.new(1, -20, 0, 160)
		img.Position = UDim2.new(0, 10, 0, 10)
		img.BackgroundTransparency = 1
		img.Image = item.imageId
		img.ScaleType = Enum.ScaleType.Fit
		img.Parent = card
		
		-- 이름
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, 0, 0, 30)
		nameLabel.Position = UDim2.new(0, 0, 0, 180)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.Text = item.name
		nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLabel.TextSize = 20
		nameLabel.Parent = card
		
		-- 가격 표시
		local priceLabel = Instance.new("TextLabel")
		priceLabel.Size = UDim2.new(1, 0, 0, 30)
		priceLabel.Position = UDim2.new(0, 0, 0, 210)
		priceLabel.BackgroundTransparency = 1
		priceLabel.Font = Enum.Font.GothamMedium
		priceLabel.Text = (item.price or 0) .. " G"
		priceLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
		priceLabel.TextSize = 18
		priceLabel.Parent = card
		
		-- 구매 버튼
		local buyBtn = Instance.new("TextButton")
		buyBtn.Size = UDim2.new(1, -40, 0, 40)
		buyBtn.Position = UDim2.new(0, 20, 1, -50)
		buyBtn.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
		buyBtn.Font = Enum.Font.GothamBold
		buyBtn.TextSize = 18
		buyBtn.Parent = card
		
		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 8)
		btnCorner.Parent = buyBtn
		
		itemCards[item.id] = { button = buyBtn, price = item.price or 0 }
	end
	
	local rows = math.ceil(#StoreConfig.Items / 3)
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
			btn.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
			btn.Active = true
			btn.AutoButtonColor = true
		end
	end
end

-- 버튼 클릭 이벤트 연결
local function bindButtons()
	for id, data in pairs(itemCards) do
		data.button.MouseButton1Click:Connect(function()
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

generateItems()
updateButtons()
bindButtons()

openShopRemote.OnClientEvent:Connect(function()
	updateButtons()
	screenGui.Enabled = true
end)
