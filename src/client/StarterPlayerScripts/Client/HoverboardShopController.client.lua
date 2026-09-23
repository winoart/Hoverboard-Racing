--!strict
-- HoverboardShopController.client.luau
-- 골드로 호버보드를 구매하는 상점 UI 컨트롤러

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local LocalPlayer = Players.LocalPlayer
local playerGui = LocalPlayer:WaitForChild("PlayerGui")

local remotesFolder = ReplicatedStorage:WaitForChild("HoverboardRemotes")
local openShopRemote = remotesFolder:WaitForChild("OpenHoverboardShop") :: RemoteEvent
local buyRemote = remotesFolder:WaitForChild("BuyHoverboard") :: RemoteFunction
local getKioskItemsRemote = remotesFolder:WaitForChild("GetKioskItems") :: RemoteFunction
local restockRemote = remotesFolder:WaitForChild("ShopRestocked") :: RemoteEvent

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

-- 🌐 Title & Layout English/Size Enforcement
local titleFrame = bgFrame:FindFirstChild("TitleFrame")
if titleFrame then
	local titleLabel = titleFrame:FindFirstChild("Title")
	if titleLabel and titleLabel:IsA("TextLabel") then
		titleLabel.Text = "HOVERBOARD SHOP"
	end
end

-- Adjust frame sizes to ensure bottom legend fits cleanly
bgFrame.Size = UDim2.new(0, 800, 0, 535)
bgFrame.AnchorPoint = Vector2.new(0.5, 0.5)
bgFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
scrollFrame.Size = UDim2.new(1, -40, 0, 335)
scrollFrame.Position = UDim2.new(0, 20, 0, 115)

-- 🏷️ Bottom Rarity Legend Indicator (Always refresh & enlarge)
local oldLegend = bgFrame:FindFirstChild("RarityLegendFrame")
if oldLegend then oldLegend:Destroy() end

local legendFrame = Instance.new("Frame")
legendFrame.Name = "RarityLegendFrame"
legendFrame.Size = UDim2.new(1, -40, 0, 42)
legendFrame.Position = UDim2.new(0.5, 0, 1, -28)
legendFrame.AnchorPoint = Vector2.new(0.5, 0.5)
legendFrame.BackgroundTransparency = 1
legendFrame.ZIndex = 5
legendFrame.Parent = bgFrame

local listLayout = Instance.new("UIListLayout")
listLayout.FillDirection = Enum.FillDirection.Horizontal
listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
listLayout.VerticalAlignment = Enum.VerticalAlignment.Center
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding = UDim.new(0, 24)
listLayout.Parent = legendFrame

local rarities = {
	{ name = "Common", color = StoreConfig.RarityColors["Common"] or Color3.fromRGB(255, 255, 0) },
	{ name = "Uncommon", color = StoreConfig.RarityColors["Uncommon"] or Color3.fromRGB(0, 120, 255) },
	{ name = "Rare", color = StoreConfig.RarityColors["Rare"] or Color3.fromRGB(128, 0, 128) },
	{ name = "Super Rare", color = StoreConfig.RarityColors["Super Rare"] or Color3.fromRGB(30, 30, 30) },
}

for idx, rData in ipairs(rarities) do
	local itemContainer = Instance.new("Frame")
	itemContainer.Name = rData.name .. "Legend"
	itemContainer.LayoutOrder = idx
	itemContainer.Size = UDim2.new(0, 0, 1, 0)
	itemContainer.AutomaticSize = Enum.AutomaticSize.X
	itemContainer.BackgroundTransparency = 1
	itemContainer.Parent = legendFrame
	
	local cLayout = Instance.new("UIListLayout")
	cLayout.FillDirection = Enum.FillDirection.Horizontal
	cLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	cLayout.Padding = UDim.new(0, 10)
	cLayout.Parent = itemContainer
	
	local colorBox = Instance.new("Frame")
	colorBox.Name = "ColorBox"
	colorBox.Size = UDim2.new(0, 24, 0, 24)
	colorBox.BackgroundColor3 = rData.color
	colorBox.BorderSizePixel = 0
	colorBox.Parent = itemContainer
	
	local cCorner = Instance.new("UICorner")
	cCorner.CornerRadius = UDim.new(0, 6)
	cCorner.Parent = colorBox
	
	local cStroke = Instance.new("UIStroke")
	cStroke.Color = Color3.fromRGB(0, 0, 0)
	cStroke.Thickness = 3
	cStroke.Parent = colorBox
	
	local textLbl = Instance.new("TextLabel")
	textLbl.Name = "RarityText"
	textLbl.Size = UDim2.new(0, 0, 1, 0)
	textLbl.AutomaticSize = Enum.AutomaticSize.X
	textLbl.BackgroundTransparency = 1
	textLbl.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	textLbl.Text = rData.name
	textLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	textLbl.TextSize = 22
	textLbl.TextXAlignment = Enum.TextXAlignment.Left
	textLbl.Parent = itemContainer
	
	local tStroke = Instance.new("UIStroke")
	tStroke.Color = Color3.fromRGB(0, 0, 0)
	tStroke.Thickness = 3
	tStroke.Parent = textLbl
end

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
			btn.Text = "✓ OWNED"
			btn.TextSize = 20
			btn.BackgroundColor3 = Color3.fromRGB(210, 220, 230)
			btn.TextColor3 = Color3.fromRGB(255, 255, 255)
			btn.Active = false
			btn.AutoButtonColor = false
		else
			btn.Text = "BUY"
			btn.TextSize = 22
			btn.BackgroundColor3 = Color3.fromRGB(100, 220, 110)
			btn.TextColor3 = Color3.fromRGB(255, 255, 255)
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
			refreshTimerLabel.Text = "NEXT RESTOCK IN: " .. formatTime(remainingTime)
			if remainingTime <= 0 then
				refreshTimerLabel.Text = "RESTOCKING..."
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
	refreshTimerLabel.Text = "NEXT RESTOCK IN: " .. formatTime(remainingTime)
	
	generateItems(items)
	updateButtons()
	bindButtons()
	
	isShopOpen = true
	screenGui.Enabled = true
end)

-- 📢 15-Minute Shop Restock Banner Notification
local toastGui = playerGui:FindFirstChild("ShopRestockToastGui")
if not toastGui then
	toastGui = Instance.new("ScreenGui")
	toastGui.Name = "ShopRestockToastGui"
	toastGui.DisplayOrder = 150
	toastGui.ResetOnSpawn = false
	toastGui.Parent = playerGui
end

local gamePhaseRemote = remotesFolder:WaitForChild("GamePhaseChanged") :: RemoteEvent
local currentGamePhase = "Intermission"

gamePhaseRemote.OnClientEvent:Connect(function(phase: string)
	currentGamePhase = phase
end)

local function showRestockBanner(newItems: {string})
	if currentGamePhase == "Racing" then return end -- 레이싱 모드일 때는 안 뜨게 변경

	-- Remove any existing banner
	local existingBanner = toastGui:FindFirstChild("RestockBanner")
	if existingBanner then existingBanner:Destroy() end

	-- 🎨 Banner Frame (Strict adherence to HoverboardRacing_UI_Design_Guide.md: Glass Sky Blue + 6px Black Stroke)
	local banner = Instance.new("Frame")
	banner.Name = "RestockBanner"
	banner.Size = UDim2.new(0, 480, 0, 60) -- 자막이 없어져 높이를 86 -> 60으로 축소
	banner.Position = UDim2.new(0.5, -240, 0, -120) -- Starts hidden off-screen above
	banner.BackgroundColor3 = Color3.fromRGB(150, 240, 255) -- Main Glass Color
	banner.BackgroundTransparency = 0.15 -- Glass translucency
	banner.ZIndex = 100
	banner.Parent = toastGui

	local bCorner = Instance.new("UICorner")
	bCorner.CornerRadius = UDim.new(0, 24)
	bCorner.Parent = banner

	local bStroke = Instance.new("UIStroke")
	bStroke.Color = Color3.fromRGB(0, 0, 0) -- Thick Cartoon Black Border
	bStroke.Thickness = 6
	bStroke.Parent = banner

	-- 5.1 Diagonal Stripes Pattern (UIGradient Keypoint rendering)
	local patternBg = Instance.new("Frame")
	patternBg.Name = "PatternBg"
	patternBg.Size = UDim2.new(1, 0, 1, 0)
	patternBg.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	patternBg.BorderSizePixel = 0
	patternBg.ZIndex = 101
	patternBg.Parent = banner
	Instance.new("UICorner", patternBg).CornerRadius = UDim.new(0, 24)

	local grad = Instance.new("UIGradient", patternBg)
	grad.Rotation = 45
	local keypoints = { NumberSequenceKeypoint.new(0, 0.88) }
	for i = 1, 9 do
		local p = i / 10
		if i % 2 == 1 then
			table.insert(keypoints, NumberSequenceKeypoint.new(p, 0.88))
			table.insert(keypoints, NumberSequenceKeypoint.new(p + 0.001, 1))
		else
			table.insert(keypoints, NumberSequenceKeypoint.new(p, 1))
			table.insert(keypoints, NumberSequenceKeypoint.new(p + 0.001, 0.88))
		end
	end
	table.insert(keypoints, NumberSequenceKeypoint.new(1, 1))
	grad.Transparency = NumberSequence.new(keypoints)

	-- Left Hoverboard Icon Box
	local iconBox = Instance.new("Frame")
	iconBox.Name = "IconBox"
	iconBox.Size = UDim2.new(0, 44, 0, 44) -- 아이콘 박스 축소
	iconBox.Position = UDim2.new(0, 12, 0.5, -22) -- 상하 정중앙 배치
	iconBox.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
	iconBox.BorderSizePixel = 0
	iconBox.ZIndex = 102
	iconBox.Parent = banner

	local iconCorner = Instance.new("UICorner")
	iconCorner.CornerRadius = UDim.new(0, 12)
	iconCorner.Parent = iconBox

	local iconStroke = Instance.new("UIStroke")
	iconStroke.Color = Color3.fromRGB(0, 0, 0)
	iconStroke.Thickness = 3
	iconStroke.Parent = iconBox

	local iconEmoji = Instance.new("TextLabel")
	iconEmoji.Size = UDim2.new(1, 0, 1, 0)
	iconEmoji.BackgroundTransparency = 1
	iconEmoji.Text = "🛹"
	iconEmoji.TextSize = 28
	iconEmoji.ZIndex = 103
	iconEmoji.Parent = iconBox

	-- Header Pill
	local titlePill = Instance.new("Frame")
	titlePill.Name = "TitlePill"
	titlePill.Size = UDim2.new(1, -75, 0, 36)
	titlePill.Position = UDim2.new(0, 65, 0.5, -18) -- 자막 없이 정중앙에 배치
	titlePill.BackgroundColor3 = Color3.fromRGB(40, 180, 255)
	titlePill.BorderSizePixel = 0
	titlePill.ZIndex = 102
	titlePill.Parent = banner

	local titlePillCorner = Instance.new("UICorner")
	titlePillCorner.CornerRadius = UDim.new(0.5, 0)
	titlePillCorner.Parent = titlePill

	local titlePillStroke = Instance.new("UIStroke")
	titlePillStroke.Color = Color3.fromRGB(0, 0, 0)
	titlePillStroke.Thickness = 3
	titlePillStroke.Parent = titlePill

	local titleLbl = Instance.new("TextLabel")
	titleLbl.Name = "TitleLabel"
	titleLbl.Size = UDim2.new(1, 0, 1, 0)
	titleLbl.BackgroundTransparency = 1
	titleLbl.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	titleLbl.Text = "✨ HOVERBOARD SHOP RESTOCKED! ✨"
	titleLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLbl.TextSize = 20
	titleLbl.ZIndex = 103
	titleLbl.Parent = titlePill

	local tStroke = Instance.new("UIStroke")
	tStroke.Color = Color3.fromRGB(0, 0, 0)
	tStroke.Thickness = 3
	tStroke.Parent = titleLbl

	-- Sound Effect: Pleasant notification chime
	pcall(function()
		local chimeSound = Instance.new("Sound")
		chimeSound.SoundId = "rbxassetid://9069609268"
		chimeSound.Volume = 0.8
		chimeSound.Parent = SoundService
		chimeSound:Play()
		chimeSound.Ended:Connect(function() chimeSound:Destroy() end)
	end)

	-- Animate In
	TweenService:Create(banner, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, -240, 0, 40)
	}):Play()

	-- Hold for 3 seconds then slide up smoothly
	task.delay(3, function()
		if not banner.Parent then return end
		local tweenOut = TweenService:Create(banner, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, -240, 0, -120)
		})
		tweenOut:Play()
		tweenOut.Completed:Connect(function()
			banner:Destroy()
		end)
	end)
end

-- Listen to server 15-minute restock broadcast
restockRemote.OnClientEvent:Connect(function(newItems)
	print("📢 [HoverboardShop] 15-Minute Restock broadcast received!")
	-- If the player currently has the shop UI open, instantly refresh items & timer
	if isShopOpen then
		remainingTime = 60 -- 테스트용 1분 (완료 후 15 * 60으로 복구)
		refreshTimerLabel.Text = "NEXT RESTOCK IN: " .. formatTime(remainingTime)
		generateItems(newItems)
		updateButtons()
		bindButtons()
	end

	showRestockBanner(newItems)
end)

-- =========================================================================
-- 📱 RESPONSIVE UI SCALING
-- =========================================================================
local uiScale = Instance.new("UIScale", bgFrame)
local toastScale = Instance.new("UIScale", toastGui)

local function updateResponsiveScale()
	local viewport = workspace.CurrentCamera.ViewportSize
	if viewport.X == 0 or viewport.Y == 0 then return end
	local scale = math.min(viewport.X / 1280, viewport.Y / 720)
	local finalScale = math.clamp(scale, 0.4, 1.1)
	uiScale.Scale = finalScale
	toastScale.Scale = finalScale
end

local resizeConn = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveScale)
updateResponsiveScale()
task.delay(0.1, updateResponsiveScale)

screenGui.Destroying:Connect(function()
	if resizeConn then resizeConn:Disconnect() end
end)
