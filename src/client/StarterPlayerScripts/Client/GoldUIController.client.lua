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

local screenGui = playerGui:WaitForChild("GoldDisplayHUD")
local goldFrame = screenGui:WaitForChild("GoldFrame")
local goldIcon = goldFrame:WaitForChild("GoldIcon")
local goldTextLabel = goldFrame:WaitForChild("GoldTextLabel")
local addGoldButton = goldFrame:WaitForChild("AddGoldButton")

local goldTextStroke = Instance.new("UIStroke")
goldTextStroke.Color = Color3.fromRGB(0, 0, 0)
goldTextStroke.Thickness = 3
goldTextStroke.Parent = goldTextLabel

local suffixes = {"", "K", "M", "B", "T", "Qa", "Qi"}

local function FormatGold(n)
	if n < 1000 then
		return tostring(n)
	end
	
	local index = 1
	while n >= 1000 and index < #suffixes do
		n = n / 1000
		index = index + 1
	end
	
	-- 1.0K 처럼 불필요한 소수점(.0)이 붙는 것을 제거
	local formatted = string.format("%.1f", n)
	if formatted:sub(-2) == ".0" then
		formatted = formatted:sub(1, -3)
	end
	
	return formatted .. suffixes[index]
end

local displayGold = Instance.new("NumberValue")
displayGold.Name = "DisplayGold"
displayGold.Value = goldValue.Value
displayGold.Parent = screenGui

displayGold.Changed:Connect(function()
	goldTextLabel.Text = FormatGold(math.floor(displayGold.Value))
end)

local function UpdateGoldText()
	if screenGui:GetAttribute("PauseGoldUpdate") then 
		return 
	end
	-- 일반적인 골드 획득 (예: 상점 구매) 시 부드럽게 0.3초 동안 올라감
	TweenService:Create(displayGold, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Value = goldValue.Value}):Play()
end

-- 최초 1회 업데이트 및 골드 변경 시 자동 업데이트 연결
displayGold.Value = goldValue.Value
goldTextLabel.Text = FormatGold(goldValue.Value)

goldValue.Changed:Connect(UpdateGoldText)

screenGui:GetAttributeChangedSignal("PauseGoldUpdate"):Connect(function()
	if not screenGui:GetAttribute("PauseGoldUpdate") then
		-- 일시정지가 풀리면(결과창에서 동전이 날아오기 시작하면) 1초 동안 촤르르륵 올라감!
		TweenService:Create(displayGold, TweenInfo.new(1.0, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Value = goldValue.Value}):Play()
	end
end)

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
shopModal.Size = UDim2.new(0, 680, 0, 460) -- 세로 길이를 살짝 늘려서 2줄이 딱 맞게 들어감
shopModal.Position = UDim2.new(0.5, -340, 0.5, -230)
shopModal.BackgroundColor3 = Color3.fromRGB(150, 240, 255)
shopModal.BackgroundTransparency = 0.5 -- 반투명 유리 질감
shopModal.Visible = false
shopModal.Parent = screenGui

local shopCorner = Instance.new("UICorner")
shopCorner.CornerRadius = UDim.new(0, 24)
shopCorner.Parent = shopModal

local shopStroke = Instance.new("UIStroke")
shopStroke.Color = Color3.fromRGB(0, 0, 0)
shopStroke.Thickness = 8
shopStroke.Parent = shopModal

-- 타이틀 헤더 (파란색 알약 배경)
local shopHeader = Instance.new("Frame")
shopHeader.Size = UDim2.new(1, -40, 0, 60)
shopHeader.Position = UDim2.new(0, 20, 0, 20) -- 여백을 두어 메인 테두리와 겹치지 않게 함
shopHeader.BackgroundColor3 = Color3.fromRGB(40, 180, 255)
shopHeader.Parent = shopModal

local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0.5, 0) -- 좌우가 완전히 둥근 알약 모양
headerCorner.Parent = shopHeader

local headerStroke = Instance.new("UIStroke")
headerStroke.Color = Color3.fromRGB(0, 0, 0)
headerStroke.Thickness = 6
headerStroke.Parent = shopHeader

local shopTitle = Instance.new("TextLabel")
shopTitle.Size = UDim2.new(1, 0, 1, 0)
shopTitle.BackgroundTransparency = 1
shopTitle.Font = Enum.Font.FredokaOne -- 인벤토리와 동일한 두꺼운 폰트 복구
shopTitle.Text = "GOLD SHOP"
shopTitle.TextColor3 = Color3.fromRGB(30, 30, 30) -- 인벤토리와 동일한 다크 그레이
shopTitle.TextSize = 36 -- 크기도 36으로 통일
shopTitle.Parent = shopHeader

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 48, 0, 48)
closeButton.Position = UDim2.new(1, 0, 0, 0) -- 완전히 바깥쪽/우상단에 걸치도록
closeButton.AnchorPoint = Vector2.new(0.5, 0.5)
closeButton.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
closeButton.Font = Enum.Font.FredokaOne
closeButton.Text = "X"
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.TextSize = 28
closeButton.ZIndex = 10
closeButton.Parent = shopModal

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(1, 0) -- 완전한 원형
closeCorner.Parent = closeButton

local closeStroke = Instance.new("UIStroke")
closeStroke.Color = Color3.fromRGB(0, 0, 0)
closeStroke.Thickness = 6 -- 두꺼운 테두리
closeStroke.Parent = closeButton

local closeTextStroke = Instance.new("UIStroke")
closeTextStroke.Color = Color3.fromRGB(0, 0, 0)
closeTextStroke.Thickness = 3
closeTextStroke.Parent = closeButton

closeButton.MouseButton1Click:Connect(function()
	shopModal.Visible = false
end)
addGoldButton.MouseButton1Click:Connect(function()
	shopModal.Visible = not shopModal.Visible
end)

-- Find and link RobuxShop button
task.spawn(function()
	local function linkRobuxShop(btn)
		btn.MouseButton1Click:Connect(function()
			shopModal.Visible = not shopModal.Visible
		end)
	end

	local robuxShopBtn = nil
	for _, gui in ipairs(playerGui:GetChildren()) do
		if gui:IsA("ScreenGui") then
			local btn = gui:FindFirstChild("RobuxShop", true) or gui:FindFirstChild("RobuxShopBtn", true)
			if btn and btn:IsA("GuiButton") then
				robuxShopBtn = btn
				break
			end
		end
	end
	
	if robuxShopBtn then
		linkRobuxShop(robuxShopBtn)
	end
	
	-- In case it is added later
	playerGui.DescendantAdded:Connect(function(desc)
		if desc:IsA("GuiButton") and (desc.Name == "RobuxShop" or desc.Name == "RobuxShopBtn") then
			linkRobuxShop(desc)
		end
	end)
end)

local productContainer = Instance.new("ScrollingFrame")
productContainer.Size = UDim2.new(1, -40, 1, -120) -- 전체 460 높이 중 340 픽셀을 차지 (2줄 완벽 호환)
productContainer.Position = UDim2.new(0, 20, 0, 95)
productContainer.BackgroundTransparency = 1
productContainer.ScrollBarThickness = 8
productContainer.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar -- 스크롤바가 카드와 겹치지 않게
productContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
productContainer.Parent = shopModal

-- UIStroke 잘림 현상(클리핑) 방지를 위한 패딩 추가
local containerPadding = Instance.new("UIPadding")
containerPadding.PaddingTop = UDim.new(0, 10)
containerPadding.PaddingBottom = UDim.new(0, 10)
containerPadding.PaddingLeft = UDim.new(0, 10)
containerPadding.PaddingRight = UDim.new(0, 10)
containerPadding.Parent = productContainer

local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.new(0, 295, 0, 150)
gridLayout.CellPadding = UDim2.new(0, 15, 0, 20) -- 카드 간 여백 조정
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = productContainer

-- 동적 상품 생성
for i, product in ipairs(MonetizationConfig.GoldProducts) do
	local card = Instance.new("Frame")
	card.BackgroundColor3 = Color3.fromRGB(255, 255, 255) -- 화이트톤 바탕
	card.LayoutOrder = i
	card.Parent = productContainer
	
	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 16)
	cardCorner.Parent = card
	
	local cardStroke = Instance.new("UIStroke")
	cardStroke.Color = Color3.fromRGB(0, 0, 0)
	cardStroke.Thickness = 4
	cardStroke.Parent = card
	
	if product.isBestValue then
		local bestTag = Instance.new("TextLabel")
		bestTag.Size = UDim2.new(0, 110, 0, 28)
		bestTag.Position = UDim2.new(0, -10, 0, -10)
		bestTag.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
		bestTag.Font = Enum.Font.FredokaOne
		bestTag.Text = "BEST VALUE"
		bestTag.TextColor3 = Color3.fromRGB(255, 255, 255)
		bestTag.TextSize = 16
		bestTag.Rotation = -10
		bestTag.Parent = card
		
		local tagCorner = Instance.new("UICorner")
		tagCorner.CornerRadius = UDim.new(0, 8)
		tagCorner.Parent = bestTag
		
		local tagStroke = Instance.new("UIStroke")
		tagStroke.Color = Color3.fromRGB(0, 0, 0)
		tagStroke.Thickness = 3
		tagStroke.Parent = bestTag
		
		local tagTextStroke = Instance.new("UIStroke")
		tagTextStroke.Color = Color3.fromRGB(0, 0, 0)
		tagTextStroke.Thickness = 2
		tagTextStroke.Parent = bestTag
	end
	
	local pName = Instance.new("TextLabel")
	pName.Size = UDim2.new(1, 0, 0, 30)
	pName.Position = UDim2.new(0, 0, 0, 15)
	pName.BackgroundTransparency = 1
	pName.Font = Enum.Font.GothamBlack -- 한글이 굵고 예쁘게 나오는 폰트
	pName.Text = product.name
	pName.TextColor3 = Color3.fromRGB(30, 30, 30) -- 다크 그레이
	pName.TextSize = 24
	pName.Parent = card
	
	local pAmount = Instance.new("TextLabel")
	pAmount.Size = UDim2.new(1, 0, 0, 40)
	pAmount.Position = UDim2.new(0, 0, 0, 40)
	pAmount.BackgroundTransparency = 1
	pAmount.Font = Enum.Font.FredokaOne
	pAmount.Text = tostring(product.amount) .. " G"
	pAmount.TextColor3 = Color3.fromRGB(255, 200, 50) -- 골드 컬러
	pAmount.TextSize = 36
	pAmount.Parent = card
	
	local amountStroke = Instance.new("UIStroke")
	amountStroke.Color = Color3.fromRGB(0, 0, 0)
	amountStroke.Thickness = 4
	amountStroke.Parent = pAmount
	
	local buyBtn = Instance.new("TextButton")
	buyBtn.Size = UDim2.new(0, 140, 0, 46)
	buyBtn.Position = UDim2.new(0.5, -70, 1, -55)
	buyBtn.BackgroundColor3 = Color3.fromRGB(100, 220, 110) -- 성공/액션 밝은 녹색
	buyBtn.Font = Enum.Font.FredokaOne
	buyBtn.Text = "R$ " .. tostring(product.price)
	buyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	buyBtn.TextSize = 24
	buyBtn.Parent = card
	
	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 12)
	btnCorner.Parent = buyBtn
	
	local btnStroke = Instance.new("UIStroke")
	btnStroke.Color = Color3.fromRGB(0, 0, 0)
	btnStroke.Thickness = 4
	btnStroke.Parent = buyBtn
	
	local btnTextStroke = Instance.new("UIStroke")
	btnTextStroke.Color = Color3.fromRGB(0, 0, 0)
	btnTextStroke.Thickness = 2
	btnTextStroke.Parent = buyBtn
	
	buyBtn.MouseButton1Click:Connect(function()
		MarketplaceService:PromptProductPurchase(LocalPlayer, product.id)
	end)
end
-- 카드가 2줄일 때는 정확히 스크롤 없이 딱 맞고, 3줄 이상일 때만 스크롤이 생기도록 수학적 계산!
local rowCount = math.ceil(#MonetizationConfig.GoldProducts / 2)
local calculatedCanvasHeight = (rowCount * 150) + ((rowCount - 1) * 20) + 20 -- CellY + CellPaddingY + UIPadding(상하 10씩)
productContainer.CanvasSize = UDim2.new(0, 0, 0, calculatedCanvasHeight)


-- (기존에 레이싱 진입 시 골드창을 끄던 로직을 제거하여 항상 보이게 함)
local gamePhaseRemote = ReplicatedStorage:WaitForChild("HoverboardRemotes"):WaitForChild("GamePhaseChanged") :: RemoteEvent
gamePhaseRemote.OnClientEvent:Connect(function(phase: string)
	-- 개발자님 요청에 의해 골드 UI(GoldDisplayHUD)는 레이싱 중에도 항상 표시됩니다!
	screenGui.Enabled = true
end)

print("💰 [GoldUIController] Gold Display UI loaded.")
