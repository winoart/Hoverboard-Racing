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

-- 폰트 사이즈가 강제로 작아지는 것 방지 및 화면 축소 시 짤림 방지
goldTextLabel.TextScaled = true
goldTextLabel.Size = UDim2.new(0, 400, 1, 0) -- 가로 제약을 아예 풀어버려서 항상 세로(높이) 높이에 맞춰서 최대 크기로 렌더링되게 함
goldTextLabel.AutomaticSize = Enum.AutomaticSize.None
goldTextLabel.TextXAlignment = Enum.TextXAlignment.Left

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

local function UpdatePlusButtonPosition()
	if goldTextLabel and addGoldButton then
		local textWidth = goldTextLabel.TextBounds.X
		if textWidth > 0 then
			addGoldButton.Position = UDim2.new(
				goldTextLabel.Position.X.Scale, 
				goldTextLabel.Position.X.Offset + textWidth + 10,
				addGoldButton.Position.Y.Scale, 
				addGoldButton.Position.Y.Offset
			)
		end
	end
end

displayGold.Changed:Connect(function()
	goldTextLabel.Text = FormatGold(math.floor(displayGold.Value))
	task.spawn(UpdatePlusButtonPosition)
end)

-- 화면 크기가 변해서 폰트 사이즈가 변할 때도 플러스 버튼 위치 갱신
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
	task.wait(0.05)
	UpdatePlusButtonPosition()
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

-- ROBUX 상점 UI 구성
local shopModal = Instance.new("Frame")
shopModal.Name = "RobuxShopModal"
shopModal.Size = UDim2.new(0, 720, 0, 500) -- 가로로 길게 조금 늘림
shopModal.AnchorPoint = Vector2.new(0.5, 0.5)
shopModal.Position = UDim2.new(0.5, 0, 0.5, 0)
shopModal.BackgroundColor3 = Color3.fromRGB(150, 240, 255)
shopModal.BackgroundTransparency = 0.5
shopModal.Visible = false
shopModal.Parent = screenGui

local shopCorner = Instance.new("UICorner")
shopCorner.CornerRadius = UDim.new(0, 24)
shopCorner.Parent = shopModal

local shopStroke = Instance.new("UIStroke")
shopStroke.Color = Color3.fromRGB(0, 0, 0)
shopStroke.Thickness = 8
shopStroke.Parent = shopModal

local shopHeader = Instance.new("Frame")
shopHeader.Size = UDim2.new(1, -40, 0, 60)
shopHeader.Position = UDim2.new(0, 20, 0, 20)
shopHeader.BackgroundColor3 = Color3.fromRGB(40, 180, 255)
shopHeader.Parent = shopModal

local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0.5, 0)
headerCorner.Parent = shopHeader

local headerStroke = Instance.new("UIStroke")
headerStroke.Color = Color3.fromRGB(0, 0, 0)
headerStroke.Thickness = 6
headerStroke.Parent = shopHeader

local shopTitle = Instance.new("TextLabel")
shopTitle.Size = UDim2.new(1, 0, 1, 0)
shopTitle.BackgroundTransparency = 1
shopTitle.Font = Enum.Font.FredokaOne
shopTitle.Text = "ROBUX SHOP"
shopTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
shopTitle.TextSize = 36
shopTitle.Parent = shopHeader

local titleStroke = Instance.new("UIStroke")
titleStroke.Color = Color3.fromRGB(0, 0, 0)
titleStroke.Thickness = 4
titleStroke.Parent = shopTitle

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 48, 0, 48)
closeButton.Position = UDim2.new(1, 0, 0, 0)
closeButton.AnchorPoint = Vector2.new(0.5, 0.5)
closeButton.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
closeButton.Font = Enum.Font.FredokaOne
closeButton.Text = "X"
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.TextSize = 28
closeButton.ZIndex = 10
closeButton.Parent = shopModal

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(1, 0)
closeCorner.Parent = closeButton

local closeStroke = Instance.new("UIStroke")
closeStroke.Color = Color3.fromRGB(0, 0, 0)
closeStroke.Thickness = 6
closeStroke.Parent = closeButton

local closeTextStroke = Instance.new("UIStroke")
closeTextStroke.Color = Color3.fromRGB(0, 0, 0)
closeTextStroke.Thickness = 3
closeTextStroke.Parent = closeButton

local productContainer = Instance.new("ScrollingFrame")
productContainer.Size = UDim2.new(1, -40, 1, -120)
productContainer.Position = UDim2.new(0, 20, 0, 95)
productContainer.BackgroundTransparency = 1
productContainer.ScrollBarThickness = 8
productContainer.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
productContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
productContainer.Parent = shopModal

local containerPadding = Instance.new("UIPadding")
containerPadding.PaddingTop = UDim.new(0, 10)
containerPadding.PaddingBottom = UDim.new(0, 10)
containerPadding.PaddingLeft = UDim.new(0, 10)
containerPadding.PaddingRight = UDim.new(0, 10)
containerPadding.Parent = productContainer

local listLayout = Instance.new("UIListLayout")
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding = UDim.new(0, 20) -- 배너 간 세로 여백
listLayout.Parent = productContainer

local remotes = ReplicatedStorage:WaitForChild("HoverboardRemotes")
local getShopStockInfo = remotes:WaitForChild("GetShopStockInfo") :: RemoteFunction
local getActivePromosFunc = remotes:WaitForChild("GetActivePromotions") :: RemoteFunction

local function refreshShopUI()
	-- 기존 배너 삭제
	for _, child in ipairs(productContainer:GetChildren()) do
		if child:IsA("ImageLabel") or child:IsA("Frame") then
			child:Destroy()
		end
	end
	
	-- 서버로부터 최신 재고 및 프로모션 데이터 조회
	local stockInfo = {}
	local serverPromos = {}
	
	pcall(function()
		stockInfo = getShopStockInfo:InvokeServer() or {}
	end)
	
	pcall(function()
		serverPromos = getActivePromosFunc:InvokeServer() or {}
	end)
	
	local currentTime = os.time()
	local activePromotions = {}
	
	for _, promo in ipairs(serverPromos) do
		-- 기간 체크
		if currentTime >= promo.startDate and currentTime <= promo.endDate then
			table.insert(activePromotions, promo)
		end
	end
	
	local bannerHeight = 165 -- 660x165 (4:1 비율) 배너 기준
	
	for i, promo in ipairs(activePromotions) do
		local stock = nil
		local isSoldOut = false
		if promo.maxQuantity then
			stock = stockInfo[tostring(promo.id)] or 0
			if stock <= 0 then
				isSoldOut = true
			end
		end
		
		local bannerCard = Instance.new("ImageLabel")
		bannerCard.Name = "Banner_" .. tostring(promo.id)
		bannerCard.Size = UDim2.new(1, -15, 0, bannerHeight) -- 스크롤바 영역 고려
		bannerCard.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
		bannerCard.Image = promo.bannerImage
		bannerCard.ScaleType = Enum.ScaleType.Fit -- 이미지가 잘리지 않고 비율을 유지하도록
		bannerCard.LayoutOrder = i
		bannerCard.Parent = productContainer
		
		local cardCorner = Instance.new("UICorner")
		cardCorner.CornerRadius = UDim.new(0, 16)
		cardCorner.Parent = bannerCard
		
		local cardStroke = Instance.new("UIStroke")
		cardStroke.Color = Color3.fromRGB(0, 0, 0)
		cardStroke.Thickness = 4
		cardStroke.Parent = bannerCard
		
		-- 품절 표시 오버레이
		if isSoldOut then
			local soldOutOverlay = Instance.new("Frame")
			soldOutOverlay.Size = UDim2.new(1, 0, 1, 0)
			soldOutOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
			soldOutOverlay.BackgroundTransparency = 0.6
			soldOutOverlay.ZIndex = 5
			soldOutOverlay.Parent = bannerCard
			
			local soCorner = Instance.new("UICorner")
			soCorner.CornerRadius = UDim.new(0, 16)
			soCorner.Parent = soldOutOverlay
			
			local soText = Instance.new("TextLabel")
			soText.Size = UDim2.new(1, 0, 1, 0)
			soText.BackgroundTransparency = 1
			soText.Font = Enum.Font.FredokaOne
			soText.Text = "SOLD OUT"
			soText.TextColor3 = Color3.fromRGB(255, 50, 50)
			soText.TextSize = 64
			soText.ZIndex = 6
			soText.Parent = soldOutOverlay
			
			local soStroke = Instance.new("UIStroke")
			soStroke.Color = Color3.fromRGB(255, 255, 255)
			soStroke.Thickness = 4
			soStroke.Parent = soText
		else
			-- 구매 버튼 (우측 하단)
			local buyBtn = Instance.new("TextButton")
			buyBtn.Size = UDim2.new(0, 180, 0, 56)
			buyBtn.Position = UDim2.new(1, -200, 1, -76) -- 우측 20px, 하단 20px 여백
			buyBtn.BackgroundColor3 = Color3.fromRGB(100, 220, 110)
			buyBtn.Font = Enum.Font.FredokaOne
			buyBtn.Text = "R$ " .. tostring(promo.price)
			buyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			buyBtn.TextSize = 28
			buyBtn.ZIndex = 5
			buyBtn.Parent = bannerCard
			
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
			
			-- 남은 수량 뱃지
			if stock ~= nil then
				local stockBadge = Instance.new("TextLabel")
				stockBadge.Size = UDim2.new(0, 140, 0, 30)
				stockBadge.Position = UDim2.new(0.5, -70, 0, -15) -- 버튼 상단 중앙
				stockBadge.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
				stockBadge.Font = Enum.Font.GothamBlack
				stockBadge.Text = "남은 수량: " .. tostring(stock)
				stockBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
				stockBadge.TextSize = 16
				stockBadge.ZIndex = 6
				stockBadge.Parent = buyBtn
				
				local bCorner = Instance.new("UICorner")
				bCorner.CornerRadius = UDim.new(0, 8)
				bCorner.Parent = stockBadge
				
				local bStroke = Instance.new("UIStroke")
				bStroke.Color = Color3.fromRGB(0,0,0)
				bStroke.Thickness = 2
				bStroke.Parent = stockBadge
			end
			
			buyBtn.MouseButton1Click:Connect(function()
				MarketplaceService:PromptProductPurchase(LocalPlayer, promo.id)
			end)
		end
	end
	
	-- 캔버스 사이즈 조절
	local totalHeight = (#activePromotions * bannerHeight) + ((#activePromotions - 1) * 20) + 20
	productContainer.CanvasSize = UDim2.new(0, 0, 0, totalHeight)
end

-- 상점 열 때마다 새로고침
local function toggleShop()
	if shopModal.Visible then
		shopModal.Visible = false
	else
		refreshShopUI()
		shopModal.Visible = true
	end
end

closeButton.MouseButton1Click:Connect(function()
	shopModal.Visible = false
end)
addGoldButton.MouseButton1Click:Connect(toggleShop)

task.spawn(function()
	local function linkRobuxShop(btn)
		btn.MouseButton1Click:Connect(toggleShop)
	end

	local robuxShopBtn = nil
	local shopGui = playerGui:FindFirstChild("RobuxShop")
	if shopGui then
		local btn = shopGui:FindFirstChild("RobuxShop")
		if btn and btn:IsA("GuiButton") then
			robuxShopBtn = btn
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


-- (기존에 레이싱 진입 시 골드창을 끄던 로직을 제거하여 항상 보이게 함)
local gamePhaseRemote = ReplicatedStorage:WaitForChild("HoverboardRemotes"):WaitForChild("GamePhaseChanged") :: RemoteEvent
gamePhaseRemote.OnClientEvent:Connect(function(phase: string)
	-- 개발자님 요청에 의해 골드 UI(GoldDisplayHUD)는 레이싱 중에도 항상 표시되지만, 관전 모드일 땐 숨깁니다.
	screenGui.Enabled = not LocalPlayer:GetAttribute("IsSpectating")
end)

LocalPlayer:GetAttributeChangedSignal("IsSpectating"):Connect(function()
	screenGui.Enabled = not LocalPlayer:GetAttribute("IsSpectating")
end)

print("💰 [GoldUIController] Gold Display UI loaded.")

-- =========================================================================
-- 📱 RESPONSIVE UI SCALING
-- =========================================================================
local uiScale = Instance.new("UIScale", shopModal)

local function updateResponsiveScale()
	local viewport = workspace.CurrentCamera.ViewportSize
	if viewport.X == 0 or viewport.Y == 0 then return end
	local scale = math.min(viewport.X / 1280, viewport.Y / 720)
	uiScale.Scale = math.clamp(scale, 0.4, 1.1)
end

local resizeConn = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveScale)
updateResponsiveScale()
task.delay(0.1, updateResponsiveScale)

screenGui.Destroying:Connect(function()
	if resizeConn then resizeConn:Disconnect() end
end)
