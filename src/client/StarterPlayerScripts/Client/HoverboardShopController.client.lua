--!strict
-- HoverboardShopController.client.luau
-- 쇼핑몰 카탈로그 리스트 방식 (1행 3개, 등급별 레벨 제한, 실시간 동기화)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local playerGui = LocalPlayer:WaitForChild("PlayerGui")

local remotesFolder = ReplicatedStorage:WaitForChild("HoverboardRemotes")
local openShopRemote = remotesFolder:WaitForChild("OpenHoverboardShop") :: RemoteEvent
local buyRemote = remotesFolder:WaitForChild("BuyHoverboard") :: RemoteFunction
local getCatalogRemote = remotesFolder:WaitForChild("GetHoverboardsCatalog") :: RemoteFunction
local catalogUpdatedRemote = remotesFolder:WaitForChild("HoverboardsCatalogUpdated") :: RemoteEvent

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StoreConfig = require(Shared:WaitForChild("StoreConfig") :: ModuleScript)
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")

-- 🎵 사운드 설정 (샵 오픈: 78897892629188, 아이템 셀렉: 9119730203)
local openSound = Instance.new("Sound")
openSound.Name = "HoverboardShopOpenSound"
openSound.SoundId = "rbxassetid://78897892629188"
openSound.Volume = 0.9
openSound.Parent = SoundService

local selectSound = Instance.new("Sound")
selectSound.Name = "HoverboardItemSelectSound"
selectSound.SoundId = "rbxassetid://9119730203"
selectSound.Volume = 0.9
selectSound.Parent = SoundService

task.spawn(function()
	pcall(function()
		ContentProvider:PreloadAsync({ openSound, selectSound })
	end)
end)

local function playOpenSound()
	pcall(function()
		openSound.TimePosition = 0
		openSound:Play()
	end)
end

local lastSelectTime = 0
local function playSelectSound()
	local now = os.clock()
	if now - lastSelectTime < 0.05 then return end
	lastSelectTime = now
	pcall(function()
		selectSound.TimePosition = 0
		selectSound:Play()
	end)
end

-- UI 참조
local screenGui = playerGui:WaitForChild("HoverboardShopHUD")
local bgFrame = screenGui:WaitForChild("Background")
local closeBtn = bgFrame:WaitForChild("CloseButton")
local refreshTimerLabel = bgFrame:FindFirstChild("RefreshTimerLabel")
if refreshTimerLabel and refreshTimerLabel:IsA("TextLabel") then
	refreshTimerLabel.Visible = false -- 순환 타이머 제거
end

local scrollFrame = bgFrame:WaitForChild("ScrollFrame") :: ScrollingFrame
local cardTemplate = scrollFrame:WaitForChild("CardTemplate") :: Frame
cardTemplate.Visible = false

-- 기존 UIGridLayout이 ScrollFrame 전체에 걸려있으면 섹션별 분할에 방해되므로 제거
local oldGrid = scrollFrame:FindFirstChildOfClass("UIGridLayout")
if oldGrid then oldGrid:Destroy() end

local scrollListLayout = scrollFrame:FindFirstChildOfClass("UIListLayout")
if not scrollListLayout then
	scrollListLayout = Instance.new("UIListLayout")
	scrollListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	scrollListLayout.Padding = UDim.new(0, 16)
	scrollListLayout.Parent = scrollFrame
end

-- 🌐 Title
local titleFrame = bgFrame:FindFirstChild("TitleFrame")
if titleFrame then
	local titleLabel = titleFrame:FindFirstChild("Title")
	if titleLabel and titleLabel:IsA("TextLabel") then
		titleLabel.Text = "HOVERBOARD SHOP"
	end
end

-- UI 크기 및 스크롤 영역 조정 (타이틀과의 간격 및 프레임 여백 확보)
bgFrame.Size = UDim2.new(0, 840, 0, 560)
bgFrame.AnchorPoint = Vector2.new(0.5, 0.5)
bgFrame.Position = UDim2.new(0.5, 0, 0.5, 0)

-- 1. 타이틀(Y 20~80) 아래 충분한 간격을 두고 ScrollFrame 배치
scrollFrame.Size = UDim2.new(1, -60, 1, -125)
scrollFrame.Position = UDim2.new(0, 30, 0, 102)
scrollFrame.ScrollBarThickness = 8
scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)

local scrollPadding = scrollFrame:FindFirstChildOfClass("UIPadding")
if not scrollPadding then
	scrollPadding = Instance.new("UIPadding")
	scrollPadding.Parent = scrollFrame
end
scrollPadding.PaddingTop = UDim.new(0, 8)
scrollPadding.PaddingBottom = UDim.new(0, 16)
scrollPadding.PaddingLeft = UDim.new(0, 8)
scrollPadding.PaddingRight = UDim.new(0, 14)

-- 하단 불필요한 레전드 제거 (쇼핑몰 섹션 자체에 등급명이 들어가므로)
local oldLegend = bgFrame:FindFirstChild("RarityLegendFrame")
if oldLegend then oldLegend:Destroy() end

local RARITY_ORDER = {
	{ name = "Common", reqLevel = 1, color = Color3.fromRGB(255, 200, 30), bg = Color3.fromRGB(240, 190, 20) },
	{ name = "Uncommon", reqLevel = 10, color = Color3.fromRGB(0, 150, 255), bg = Color3.fromRGB(0, 130, 230) },
	{ name = "Rare", reqLevel = 50, color = Color3.fromRGB(170, 70, 255), bg = Color3.fromRGB(140, 50, 220) },
	{ name = "Super Rare", reqLevel = 90, color = Color3.fromRGB(45, 45, 55), bg = Color3.fromRGB(25, 25, 30) },
}

local function getPlayerLevel(): number
	local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
	if leaderstats then
		local lvlVal = (leaderstats:FindFirstChild("Level") or leaderstats:FindFirstChild("Rebirths")) :: IntValue?
		if lvlVal then return lvlVal.Value end
	end
	return 0
end

local function checkOwned(boardId: string): boolean
	local ownedFolder = LocalPlayer:FindFirstChild("OwnedHoverboards")
	if ownedFolder and ownedFolder:FindFirstChild(boardId) then
		return true
	end
	return false
end

local currentCatalog = {}

-- 3열 쇼핑몰 렌더링 함수
local function renderCatalog(catalogList)
	currentCatalog = catalogList or {}
	
	-- 기존 렌더링된 섹션 및 카드 정리 (CardTemplate 제외)
	for _, child in ipairs(scrollFrame:GetChildren()) do
		if child ~= cardTemplate and not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
	
	local playerLevel = getPlayerLevel()
	
	-- 등급별로 그룹화
	local grouped: { [string]: { any } } = {
		["Common"] = {},
		["Uncommon"] = {},
		["Rare"] = {},
		["Super Rare"] = {},
	}
	
	for _, item in ipairs(currentCatalog) do
		if item.isVisible ~= false then
			local r = item.rarity or "Common"
			if not grouped[r] then grouped[r] = {} end
			table.insert(grouped[r], item)
		end
	end
	
	for orderIdx, rData in ipairs(RARITY_ORDER) do
		local rName = rData.name
		local boards = grouped[rName] or {}
		
		-- 해당 등급에 등록된 보드가 없으면 패스
		if #boards == 0 then continue end
		
		local isUnlocked = (playerLevel >= rData.reqLevel)
		
		-- 1. 섹션 헤더 프레임 (가로폭을 줄이고 중앙 정렬하여 외곽 프레임바와 겹치지 않도록 처리)
		local headerFrame = Instance.new("Frame")
		headerFrame.Name = "Header_" .. rName
		headerFrame.Size = UDim2.new(1, -28, 0, 38)
		headerFrame.AnchorPoint = Vector2.new(0.5, 0)
		headerFrame.Position = UDim2.new(0.5, 0, 0, 0)
		headerFrame.BackgroundColor3 = rData.bg
		headerFrame.LayoutOrder = orderIdx * 10
		headerFrame.Parent = scrollFrame
		
		local hCorner = Instance.new("UICorner", headerFrame)
		hCorner.CornerRadius = UDim.new(0, 10)
		
		local hStroke = Instance.new("UIStroke", headerFrame)
		hStroke.Color = Color3.fromRGB(0, 0, 0)
		hStroke.Thickness = 2.5
		
		local hTitle = Instance.new("TextLabel")
		hTitle.Size = UDim2.new(1, -20, 1, 0)
		hTitle.Position = UDim2.new(0, 15, 0, 0)
		hTitle.BackgroundTransparency = 1
		hTitle.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
		
		local lockText = (rData.reqLevel > 1) and string.format(" (%d LV~)", rData.reqLevel) or ""
		if not isUnlocked then
			lockText = lockText .. " 🔒 LOCKED"
		end
		hTitle.Text = string.upper(rName) .. lockText
		hTitle.TextColor3 = Color3.new(1, 1, 1)
		hTitle.TextSize = 20
		hTitle.TextXAlignment = Enum.TextXAlignment.Left
		hTitle.Parent = headerFrame
		
		local htStroke = Instance.new("UIStroke", hTitle)
		htStroke.Color = Color3.fromRGB(0, 0, 0)
		htStroke.Thickness = 2.5
		
		-- 2. 1행에 3개(3열 Grid) 호버보드 컨테이너
		local gridContainer = Instance.new("Frame")
		gridContainer.Name = "Grid_" .. rName
		gridContainer.Size = UDim2.new(1, 0, 0, 0)
		gridContainer.AutomaticSize = Enum.AutomaticSize.Y
		gridContainer.BackgroundTransparency = 1
		gridContainer.LayoutOrder = orderIdx * 10 + 1
		gridContainer.Parent = scrollFrame
		
		local grid = Instance.new("UIGridLayout")
		-- 3열 고정: 스크롤프레임 너비에 맞춰 230 x 280 설정
		grid.CellSize = UDim2.new(0, 230, 0, 280)
		grid.CellPadding = UDim2.new(0, 16, 0, 16)
		grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
		grid.SortOrder = Enum.SortOrder.LayoutOrder
		grid.Parent = gridContainer
		
		for bIdx, board in ipairs(boards) do
			local card = cardTemplate:Clone()
			card.Name = board.id
			card.LayoutOrder = bIdx
			card.BackgroundColor3 = StoreConfig.RarityColors[board.rarity] or Color3.fromRGB(45, 50, 60)
			
			local itemImg = card:FindFirstChild("ItemImage") :: ImageLabel?
			if itemImg then
				itemImg.Image = board.imageId or ""
				itemImg.Size = UDim2.new(1, -20, 0, 130)
				itemImg.Position = UDim2.new(0, 10, 0, 10)
			end
			
			local itemNm = card:FindFirstChild("ItemName") :: TextLabel?
			if itemNm then
				itemNm.Text = board.name or "Hoverboard"
				itemNm.Size = UDim2.new(1, 0, 0, 26)
				itemNm.Position = UDim2.new(0, 0, 0, 146)
				itemNm.TextSize = 18
			end
			
			local priceLbl = card:FindFirstChild("PriceLabel") :: TextLabel?
			if priceLbl then
				priceLbl.Size = UDim2.new(1, 0, 0, 24)
				priceLbl.Position = UDim2.new(0, 0, 0, 174)
				priceLbl.TextSize = 16
			end
			
			local buyBtn = card:FindFirstChild("BuyButton") :: TextButton?
			if buyBtn then
				buyBtn.Size = UDim2.new(1, -30, 0, 42)
				buyBtn.AnchorPoint = Vector2.new(0.5, 1)
				buyBtn.Position = UDim2.new(0.5, 0, 1, -14)
			end
			
			local isOwned = checkOwned(board.id)
			
			-- 잠금 오버레이 확인/생성
			local lockOverlay = card:FindFirstChild("LockOverlay") :: Frame?
			if not lockOverlay then
				lockOverlay = Instance.new("Frame")
				lockOverlay.Name = "LockOverlay"
				lockOverlay.Size = UDim2.new(1, 0, 1, 0)
				lockOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
				lockOverlay.BackgroundTransparency = 0.5
				lockOverlay.ZIndex = 8
				lockOverlay.Parent = card
				Instance.new("UICorner", lockOverlay).CornerRadius = UDim.new(0, 12)
				
				local lockIcon = Instance.new("TextLabel")
				lockIcon.Size = UDim2.new(1, 0, 0, 40)
				lockIcon.Position = UDim2.new(0, 0, 0.35, -20)
				lockIcon.BackgroundTransparency = 1
				lockIcon.Text = "🔒"
				lockIcon.TextSize = 36
				lockIcon.Parent = lockOverlay
				
				local lockDesc = Instance.new("TextLabel")
				lockDesc.Size = UDim2.new(1, 0, 0, 30)
				lockDesc.Position = UDim2.new(0, 0, 0.52, 0)
				lockDesc.BackgroundTransparency = 1
				lockDesc.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
				lockDesc.Text = string.format("Lv. %d Required", rData.reqLevel)
				lockDesc.TextColor3 = Color3.fromRGB(255, 200, 50)
				lockDesc.TextSize = 16
				lockDesc.Parent = lockOverlay
			end
			
			if isOwned then
				lockOverlay.Visible = false
				-- Owned 상태일 때 가격 라벨 숨김 (버튼 뒤로 비침 완벽 방지)
				if priceLbl then
					priceLbl.Visible = false
					priceLbl.Text = ""
				end
				if buyBtn then
					buyBtn.Text = "Owned"
					buyBtn.BackgroundColor3 = Color3.fromRGB(120, 130, 145)
					buyBtn.TextColor3 = Color3.fromRGB(240, 240, 240)
					buyBtn.Active = false
				end
			elseif not isUnlocked then
				lockOverlay.Visible = true
				if priceLbl then
					priceLbl.Visible = false
					priceLbl.Text = ""
				end
				if buyBtn then
					buyBtn.Text = "LOCKED"
					buyBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
					buyBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
					buyBtn.Active = false
				end
			else
				lockOverlay.Visible = false
				if priceLbl then
					priceLbl.Visible = true
					priceLbl.Text = string.format("💰 %d G", board.price or 0)
				end
				if buyBtn then
					buyBtn.Text = "BUY"
					buyBtn.BackgroundColor3 = Color3.fromRGB(50, 205, 50)
					buyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
					buyBtn.Active = true
					buyBtn:SetAttribute("IgnoreClickSound", true)
					
					buyBtn.MouseButton1Click:Connect(function()
						playSelectSound()
						if checkOwned(board.id) then return end
						local success, msg = buyRemote:InvokeServer(board.id)
						if success then
							print("✅ 호버보드 구매 성공:", msg)
							renderCatalog(currentCatalog)
						else
							warn("❌ 구매 실패:", msg)
						end
					end)
				end
			end
			
			-- 카드 클릭 시 아이템 셀렉 사운드 재생
			card:SetAttribute("IgnoreClickSound", true)
			card.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					playSelectSound()
				end
			end)
			
			card.Visible = true
			card.Parent = gridContainer
		end
	end
end

local isShopOpen = false

local function openShop()
	local catalog = getCatalogRemote:InvokeServer()
	renderCatalog(catalog)
	isShopOpen = true
	screenGui.Enabled = true
	playOpenSound()
end

screenGui:GetPropertyChangedSignal("Enabled"):Connect(function()
	if screenGui.Enabled then
		playOpenSound()
	end
end)

openShopRemote.OnClientEvent:Connect(openShop)

catalogUpdatedRemote.OnClientEvent:Connect(function(newCatalog)
	if isShopOpen then
		renderCatalog(newCatalog)
	end
end)

closeBtn.MouseButton1Click:Connect(function()
	isShopOpen = false
	screenGui.Enabled = false
end)

-- 리더스탯(레벨) 또는 인벤토리 변경 시 실시간 반영
local leaderstats = LocalPlayer:WaitForChild("leaderstats", 10)
if leaderstats then
	local lvlVal = leaderstats:FindFirstChild("Level") or leaderstats:FindFirstChild("Rebirths")
	if lvlVal then
		lvlVal.Changed:Connect(function()
			if isShopOpen then renderCatalog(currentCatalog) end
		end)
	end
end

LocalPlayer.ChildAdded:Connect(function(child)
	if child.Name == "OwnedHoverboards" then
		child.ChildAdded:Connect(function()
			if isShopOpen then renderCatalog(currentCatalog) end
		end)
	end
end)
local existingOwned = LocalPlayer:FindFirstChild("OwnedHoverboards")
if existingOwned then
	existingOwned.ChildAdded:Connect(function()
		if isShopOpen then renderCatalog(currentCatalog) end
	end)
end

-- =========================================================================
-- 📱 RESPONSIVE UI SCALING
-- =========================================================================
local uiScale = Instance.new("UIScale", bgFrame)
local function updateResponsiveScale()
	local viewport = workspace.CurrentCamera.ViewportSize
	if viewport.X == 0 or viewport.Y == 0 then return end
	local scale = math.min(viewport.X / 1280, viewport.Y / 720)
	uiScale.Scale = math.clamp(scale, 0.45, 1.1)
end

local resizeConn = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveScale)
updateResponsiveScale()
task.delay(0.1, updateResponsiveScale)

screenGui.Destroying:Connect(function()
	if resizeConn then resizeConn:Disconnect() end
end)
