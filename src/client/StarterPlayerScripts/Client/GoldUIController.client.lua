--!strict
-- GoldUIController.client.luau
-- 화면 왼쪽 중간에 플레이어의 현재 골드를 표시합니다. (대기실에서만 보임)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local MonetizationConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MonetizationConfig"))

local LocalPlayer = Players.LocalPlayer
local playerGui = LocalPlayer:WaitForChild("PlayerGui")
local leaderstats = LocalPlayer:WaitForChild("leaderstats", 10)
local goldValue = leaderstats and leaderstats:WaitForChild("Gold", 10) :: IntValue

if not goldValue then
	warn("🚨 [GoldUIController] Could not find leaderstats.Gold for player")
	return
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "GoldDisplayHUD"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 10
screenGui.Parent = playerGui

local goldFrame = Instance.new("Frame")
goldFrame.Name = "GoldFrame"
goldFrame.Size = UDim2.new(0, 160, 0, 50)
goldFrame.Position = UDim2.new(0, 20, 0.5, -25) -- 화면 왼쪽 중간
goldFrame.BackgroundColor3 = Color3.fromRGB(20, 25, 35)
goldFrame.BackgroundTransparency = 0.2
goldFrame.BorderSizePixel = 0
goldFrame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = goldFrame

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(255, 215, 0)
stroke.Thickness = 2.5
stroke.Parent = goldFrame

local goldIconLabel = Instance.new("TextLabel")
goldIconLabel.Size = UDim2.new(0, 45, 1, 0)
goldIconLabel.Position = UDim2.new(0, 5, 0, 0)
goldIconLabel.BackgroundTransparency = 1
goldIconLabel.Font = Enum.Font.GothamBlack
goldIconLabel.Text = "💰"
goldIconLabel.TextSize = 22
goldIconLabel.Parent = goldFrame

local goldTextLabel = Instance.new("TextLabel")
goldTextLabel.Size = UDim2.new(1, -90, 1, 0)
goldTextLabel.Position = UDim2.new(0, 50, 0, 0)
goldTextLabel.BackgroundTransparency = 1
goldTextLabel.Font = Enum.Font.GothamBlack
goldTextLabel.TextColor3 = Color3.fromRGB(255, 220, 0)
goldTextLabel.TextSize = 20
goldTextLabel.TextXAlignment = Enum.TextXAlignment.Left
goldTextLabel.Text = tostring(goldValue.Value)
goldTextLabel.Parent = goldFrame

local addGoldButton = Instance.new("TextButton")
addGoldButton.Name = "AddGoldButton"
addGoldButton.Size = UDim2.new(0, 30, 0, 30)
addGoldButton.Position = UDim2.new(1, -35, 0.5, -15)
addGoldButton.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
addGoldButton.Font = Enum.Font.GothamBlack
addGoldButton.Text = "+"
addGoldButton.TextColor3 = Color3.fromRGB(255, 255, 255)
addGoldButton.TextSize = 24
addGoldButton.Parent = goldFrame

local addCorner = Instance.new("UICorner")
addCorner.CornerRadius = UDim.new(1, 0)
addCorner.Parent = addGoldButton

-- Hover effect for plus button
addGoldButton.MouseEnter:Connect(function()
	TweenService:Create(addGoldButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(70, 220, 70)}):Play()
end)
addGoldButton.MouseLeave:Connect(function()
	TweenService:Create(addGoldButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(50, 200, 50)}):Play()
end)

-- 골드 구매 상점 UI 구성
local shopModal = Instance.new("Frame")
shopModal.Name = "GoldShopModal"
shopModal.Size = UDim2.new(0, 600, 0, 400)
shopModal.Position = UDim2.new(0.5, -300, 0.5, -200)
shopModal.BackgroundColor3 = Color3.fromRGB(30, 35, 45)
shopModal.Visible = false
shopModal.Parent = screenGui

local shopCorner = Instance.new("UICorner")
shopCorner.CornerRadius = UDim.new(0, 16)
shopCorner.Parent = shopModal

local shopStroke = Instance.new("UIStroke")
shopStroke.Color = Color3.fromRGB(255, 215, 0)
shopStroke.Thickness = 3
shopStroke.Parent = shopModal

local shopTitle = Instance.new("TextLabel")
shopTitle.Size = UDim2.new(1, 0, 0, 50)
shopTitle.BackgroundTransparency = 1
shopTitle.Font = Enum.Font.GothamBlack
shopTitle.Text = "골드 상점 (Gold Shop)"
shopTitle.TextColor3 = Color3.fromRGB(255, 215, 0)
shopTitle.TextSize = 28
shopTitle.Parent = shopModal

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 40, 0, 40)
closeButton.Position = UDim2.new(1, -45, 0, 5)
closeButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeButton.Font = Enum.Font.GothamBold
closeButton.Text = "X"
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.TextSize = 20
closeButton.Parent = shopModal

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(1, 0)
closeCorner.Parent = closeButton

closeButton.MouseButton1Click:Connect(function()
	shopModal.Visible = false
end)
addGoldButton.MouseButton1Click:Connect(function()
	shopModal.Visible = not shopModal.Visible
end)

local productContainer = Instance.new("ScrollingFrame")
productContainer.Size = UDim2.new(1, -40, 1, -80)
productContainer.Position = UDim2.new(0, 20, 0, 60)
productContainer.BackgroundTransparency = 1
productContainer.ScrollBarThickness = 8
productContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
productContainer.Parent = shopModal

local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.new(0, 270, 0, 140)
gridLayout.CellPadding = UDim2.new(0, 15, 0, 15)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = productContainer

-- 동적 상품 생성
for i, product in ipairs(MonetizationConfig.GoldProducts) do
	local card = Instance.new("Frame")
	card.BackgroundColor3 = Color3.fromRGB(40, 45, 55)
	card.LayoutOrder = i
	card.Parent = productContainer
	
	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 12)
	cardCorner.Parent = card
	
	if product.isBestValue then
		local cardStroke = Instance.new("UIStroke")
		cardStroke.Color = Color3.fromRGB(255, 100, 100)
		cardStroke.Thickness = 3
		cardStroke.Parent = card
		
		local bestTag = Instance.new("TextLabel")
		bestTag.Size = UDim2.new(0, 100, 0, 24)
		bestTag.Position = UDim2.new(0, -10, 0, -10)
		bestTag.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
		bestTag.Font = Enum.Font.GothamBold
		bestTag.Text = "BEST VALUE"
		bestTag.TextColor3 = Color3.fromRGB(255, 255, 255)
		bestTag.TextSize = 14
		bestTag.Rotation = -10
		bestTag.Parent = card
		
		local tagCorner = Instance.new("UICorner")
		tagCorner.CornerRadius = UDim.new(0, 4)
		tagCorner.Parent = bestTag
	end
	
	local pName = Instance.new("TextLabel")
	pName.Size = UDim2.new(1, 0, 0, 30)
	pName.Position = UDim2.new(0, 0, 0, 10)
	pName.BackgroundTransparency = 1
	pName.Font = Enum.Font.GothamBold
	pName.Text = product.name
	pName.TextColor3 = Color3.fromRGB(200, 200, 200)
	pName.TextSize = 18
	pName.Parent = card
	
	local pAmount = Instance.new("TextLabel")
	pAmount.Size = UDim2.new(1, 0, 0, 40)
	pAmount.Position = UDim2.new(0, 0, 0, 40)
	pAmount.BackgroundTransparency = 1
	pAmount.Font = Enum.Font.GothamBlack
	pAmount.Text = tostring(product.amount) .. " G"
	pAmount.TextColor3 = Color3.fromRGB(255, 215, 0)
	pAmount.TextSize = 28
	pAmount.Parent = card
	
	local buyBtn = Instance.new("TextButton")
	buyBtn.Size = UDim2.new(0, 120, 0, 36)
	buyBtn.Position = UDim2.new(0.5, -60, 1, -45)
	buyBtn.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
	buyBtn.Font = Enum.Font.GothamBold
	buyBtn.Text = "R$ " .. tostring(product.price)
	buyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	buyBtn.TextSize = 18
	buyBtn.Parent = card
	
	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 8)
	btnCorner.Parent = buyBtn
	
	buyBtn.MouseButton1Click:Connect(function()
		MarketplaceService:PromptProductPurchase(LocalPlayer, product.id)
	end)
end
productContainer.CanvasSize = UDim2.new(0, 0, 0, math.ceil(#MonetizationConfig.GoldProducts / 2) * 155)

-- 골드 값 변경 시 UI 업데이트
local function updateGold()
	goldTextLabel.Text = tostring(goldValue.Value)
end
goldValue.Changed:Connect(updateGold)
updateGold()

-- 대기실(Hoverboard 미장착 상태)에서만 보이도록 처리
RunService.RenderStepped:Connect(function()
	local character = LocalPlayer.Character
	local boardModel = character and character:FindFirstChild("EquippedHoverboard")
	
	-- 호버보드가 있으면 레이스 중이므로 숨김, 없으면 대기실이므로 표시
	local isInRace = (boardModel ~= nil)
	screenGui.Enabled = not isInRace
end)

print("💰 [GoldUIController] Gold Display UI loaded.")
