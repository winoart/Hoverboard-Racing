--!strict
-- InventoryController.client.luau
-- Displays the Unified Inventory UI for equipping Hoverboards and Skills

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local playerGui = LocalPlayer:WaitForChild("PlayerGui")

local hoverRemotes = ReplicatedStorage:WaitForChild("HoverboardRemotes")
local equipBoardRemote = hoverRemotes:WaitForChild("EquipItem") :: RemoteFunction

local skillRemotes = ReplicatedStorage:WaitForChild("SkillRemotes")
local equipSkillRemote = skillRemotes:WaitForChild("EquipSkill") :: RemoteFunction
local buySkillRemote = skillRemotes:WaitForChild("PurchaseSkill") :: RemoteFunction

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StoreConfig = require(Shared:WaitForChild("StoreConfig") :: ModuleScript)
local SkillStoreConfig = require(Shared:WaitForChild("SkillStoreConfig") :: ModuleScript)
local HoverboardBuilder = require(Shared:WaitForChild("HoverboardBuilder") :: ModuleScript)
local RunService = game:GetService("RunService")

-- Folder for custom models
local customModelsFolder = ReplicatedStorage:FindFirstChild("HoverboardModels")

-- Main Toggle Button (HUD)
local hudGui = playerGui:WaitForChild("InventoryHUD")
local toggleBtn = hudGui:WaitForChild("InventoryToggle")

-- Hover Effects on HUD
local originalSize = toggleBtn.Size
local hoverSize = UDim2.new(originalSize.X.Scale, originalSize.X.Offset + 8, originalSize.Y.Scale, originalSize.Y.Offset + 8)

toggleBtn.MouseEnter:Connect(function()
	TweenService:Create(toggleBtn, TweenInfo.new(0.15, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Size = hoverSize}):Play()
end)
toggleBtn.MouseLeave:Connect(function()
	TweenService:Create(toggleBtn, TweenInfo.new(0.15, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Size = originalSize}):Play()
end)

-- State
local currentTab = "Board"
local selectedItem: any = nil
local selectedItemType: string = "Board"

-- Inventory UI References
local invGui = playerGui:WaitForChild("InventoryGui")
invGui.Enabled = false

-- Helper to find UI elements recursively
local function findUI(name)
	for _, desc in ipairs(invGui:GetDescendants()) do
		if desc.Name == name then
			return desc
		end
	end
	return nil
end

local bgFrame = findUI("Background") or invGui:FindFirstChildWhichIsA("Frame")
local closeBtn = findUI("CloseButton")

if closeBtn then
	closeBtn.MouseButton1Click:Connect(function()
		invGui.Enabled = false
	end)
end

toggleBtn.MouseButton1Click:Connect(function()
	invGui.Enabled = not invGui.Enabled
	invGui.DisplayOrder = 100 -- Ensure it renders above other GUIs
	if bgFrame then
		bgFrame.Visible = true
	end
end)

-- Tabs
local boardsTabBtn = findUI("BoardsTab") or findUI("BoardsTab frame")
local skillsTabBtn = findUI("SkillsTab") or findUI("SkillsTab frame")

-- Helper for clicking (Supports both Buttons and normal Frames)
local function bindClick(guiObject, callback)
	if not guiObject then return end
	if guiObject:IsA("GuiButton") then
		guiObject.MouseButton1Click:Connect(callback)
	else
		guiObject.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				callback()
			end
		end)
	end
end

-- Scrolls
local boardsScroll = findUI("BoardsScroll")
local skillsScroll = findUI("SkillsScroll")

-- Tab Logic
local function switchTab(tabName)
	currentTab = tabName
	if tabName == "Board" then
		if boardsScroll then boardsScroll.Visible = true end
		if skillsScroll then skillsScroll.Visible = false end
	else
		if boardsScroll then boardsScroll.Visible = false end
		if skillsScroll then skillsScroll.Visible = true end
	end
end

if boardsTabBtn then
	bindClick(boardsTabBtn, function() switchTab("Board") end)
end
if skillsTabBtn then
	bindClick(skillsTabBtn, function() switchTab("Skill") end)
end

switchTab("Board")

-- Right Column (Details)
local rImage = findUI("ItemImage")
local rViewport = findUI("ItemViewport")

local rCamera = rViewport and rViewport:FindFirstChild("ViewportCamera")
if rViewport and not rCamera then
	rCamera = Instance.new("Camera")
	rCamera.Name = "ViewportCamera"
	rCamera.Parent = rViewport
end
if rViewport and rCamera then
	rViewport.CurrentCamera = rCamera
end

local rName = findUI("ItemName")
local rDesc = findUI("ItemDesc")
local actionBtn = findUI("ActionButton")

local allCards = {}
local renderConnections = {}

local function checkOwnsBoard(id)
	if id == "DefaultHoverboard" then return true end
	local ownBoard = LocalPlayer:FindFirstChild("OwnedHoverboards")
	if ownBoard and ownBoard:FindFirstChild(id) then return true end
	return false
end

local function checkEquippedBoard(id)
	local eqBoard = LocalPlayer:FindFirstChild("EquippedHoverboardId")
	if eqBoard and eqBoard.Value == id then return true end
	return false
end

local function checkOwnsSkill(id)
	local ownSkill = LocalPlayer:FindFirstChild("OwnedSkills")
	if ownSkill and ownSkill:FindFirstChild(id) then return true end
	return false
end

local function checkEquippedSkill(id)
	local eqSkill = LocalPlayer:FindFirstChild("EquippedSkills")
	if eqSkill and eqSkill:FindFirstChild(id) then return true end
	return false
end

local function clearRenderConnections()
	for _, conn in ipairs(renderConnections) do
		conn:Disconnect()
	end
	table.clear(renderConnections)
end

local function updateRightColumn()
	clearRenderConnections()
	
	if not selectedItem then
		if rImage then rImage.Image = "" end
		if rName then rName.Text = "아이템을 선택하세요" end
		if rDesc then rDesc.Text = "" end
		if rViewport then rViewport.Visible = false end
		if rImage then rImage.Visible = true end
		if actionBtn then actionBtn.Visible = false end
		return
	end
	
	local info = selectedItem
	if rName then rName.Text = info.name end
	if rDesc then rDesc.Text = info.desc or info.description or "설명이 없습니다." end

	local isEquipped = false
	local isOwned = false
	
	if selectedItemType == "Board" then
		isOwned = checkOwnsBoard(info.id)
		isEquipped = checkEquippedBoard(info.id)
	else
		isOwned = checkOwnsSkill(info.id)
		isEquipped = checkEquippedSkill(info.id)
	end
	
	if actionBtn then
		actionBtn.Visible = true
		if isEquipped then
			actionBtn.Text = "장착 해제"
			actionBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
		elseif isOwned then
			actionBtn.Text = "장착하기"
			actionBtn.BackgroundColor3 = Color3.fromRGB(60, 200, 60)
		else
			actionBtn.Text = "상점에서 구매"
			actionBtn.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
		end
	end
	
	if selectedItemType == "Board" then
		if rImage then 
			rImage.Visible = true 
			rImage.Image = info.imageId
		end
		if rViewport then rViewport.Visible = false end
	else
		if rImage then 
			rImage.Visible = true 
			rImage.Image = info.imageId 
		end
		if rViewport then rViewport.Visible = false end
	end
	
	-- 아이콘 바운스(플로팅) 애니메이션 효과 추가
	if rImage then
		local startTick = tick()
		local basePos = UDim2.new(0.1, 0, 0.05, 0)
		local conn = RunService.RenderStepped:Connect(function()
			local t = tick() - startTick
			local bounce = math.sin(t * 2.5) * 0.04 -- 속도 2.5, 진폭 4% (천천히 부드럽게)
			rImage.Position = UDim2.new(basePos.X.Scale, basePos.X.Offset, basePos.Y.Scale + bounce, basePos.Y.Offset)
		end)
		table.insert(renderConnections, conn)
	end
end

if actionBtn then
	actionBtn.MouseButton1Click:Connect(function()
		if not selectedItem then return end
		local info = selectedItem
		
		if selectedItemType == "Board" then
			if checkOwnsBoard(info.id) then
				equipBoardRemote:InvokeServer(info.id)
			end
		else
			if checkOwnsSkill(info.id) then
				equipSkillRemote:InvokeServer(info.id)
			end
		end
		updateRightColumn()
	end)
end

local function selectItem(item, iType)
	selectedItem = item
	selectedItemType = iType
	
	for _, data in ipairs(allCards) do
		if data.item.id == item.id then
			data.stroke.Thickness = 8
		else
			data.stroke.Thickness = 5
		end
	end
	
	updateRightColumn()
end

local cardTemplate = invGui:FindFirstChild("CardTemplate")

local function createInvCard(item, itemType, parentScroll)
	if not cardTemplate then return end
	local cardBtn = cardTemplate:Clone()
	cardBtn.Name = "Card_" .. item.id
	cardBtn.Parent = parentScroll
	cardBtn.Visible = true
	
	local bgGradient = Instance.new("UIGradient")
	-- 보스의 요청대로 호버보드와 스킬의 카드 배경색을 호버보드(파란색)으로 통일합니다.
	bgGradient.Color = ColorSequence.new(Color3.fromRGB(100, 220, 255), Color3.fromRGB(20, 100, 255))
	bgGradient.Rotation = 45
	bgGradient.Parent = cardBtn
	
	local cardStroke = cardBtn:FindFirstChild("UIStroke")
	if cardStroke then cardStroke.Thickness = 5 end
	
	local img = cardBtn:FindFirstChild("Image")
	if not img then
		img = Instance.new("ImageLabel")
		img.Name = "Image"
		img.Size = UDim2.new(1, -20, 0, 110)
		img.Position = UDim2.new(0, 10, 0, 10)
		img.BackgroundTransparency = 1
		img.ScaleType = Enum.ScaleType.Fit
		img.ZIndex = 10 -- 노란색 배경(Viewport)보다 무조건 위에 뜨도록 ZIndex 10
		img.Parent = cardBtn
	else
		img.ZIndex = 10
	end
	
	local vpf = cardBtn:FindFirstChild("Viewport")
	
	-- 보스 요청: 스킬에서도 호버보드처럼 예쁜 노란색 박스가 보이게 해달라!
	if itemType == "Board" then
		img.Visible = true
		img.Image = item.imageId
		if vpf then vpf.Visible = true end
	else
		img.Visible = true
		img.Image = item.imageId
		if vpf then vpf.Visible = true end
	end
	
	local nameLabel = cardBtn:FindFirstChild("ItemName")
	if nameLabel then nameLabel.Text = string.gsub(item.name, "%s*%([a-zA-Z가-힣%s]+%)", "") end
	
	local statusLabel = cardBtn:FindFirstChild("Status")
	if statusLabel then statusLabel.Visible = false end
	
	local checkIcon = Instance.new("ImageLabel")
	checkIcon.Name = "EquippedCheck"
	checkIcon.Size = UDim2.new(0, 64, 0, 64)
	checkIcon.Position = UDim2.new(0, 8, 0, 8)
	checkIcon.BackgroundTransparency = 1
	checkIcon.Image = "rbxassetid://17368190066"
	checkIcon.Visible = false
	checkIcon.ZIndex = 10 -- 카드의 모든 요소(ZIndex 8,9)보다 위에 오도록 설정
	checkIcon.Parent = cardBtn
	
	table.insert(allCards, {card = cardBtn, stroke = cardStroke, item = item, itemType = itemType, checkIcon = checkIcon, img = img})
	
	cardBtn.MouseButton1Click:Connect(function()
		selectItem(item, itemType)
	end)
end

local function refreshCardsVisibility()
	for _, data in ipairs(allCards) do
		local isOwned = data.itemType == "Board" and checkOwnsBoard(data.item.id) or checkOwnsSkill(data.item.id)
		local isEquipped = data.itemType == "Board" and checkEquippedBoard(data.item.id) or checkEquippedSkill(data.item.id)
		
		data.card.Visible = isOwned and true or false -- 보유한 아이템만 표시
		data.checkIcon.Visible = isEquipped
	end
	if selectedItem then updateRightColumn() end
end

local function initializeInventoryCards()
	if boardsScroll then
		for _, item in ipairs(StoreConfig.Items) do
			createInvCard(item, "Board", boardsScroll)
		end
	end
	
	if skillsScroll then
		for _, item in ipairs(SkillStoreConfig.Skills) do
			createInvCard(item, "Skill", skillsScroll)
		end
	end
end

initializeInventoryCards()

-- Bind updates
task.spawn(function()
	local eqBoard = LocalPlayer:WaitForChild("EquippedHoverboardId")
	eqBoard.Changed:Connect(refreshCardsVisibility)
	local ownBoard = LocalPlayer:WaitForChild("OwnedHoverboards")
	ownBoard.ChildAdded:Connect(refreshCardsVisibility)
	ownBoard.ChildRemoved:Connect(refreshCardsVisibility)
	
	local eqSkill = LocalPlayer:WaitForChild("EquippedSkills")
	eqSkill.ChildAdded:Connect(refreshCardsVisibility)
	eqSkill.ChildRemoved:Connect(refreshCardsVisibility)
	local ownSkill = LocalPlayer:WaitForChild("OwnedSkills")
	ownSkill.ChildAdded:Connect(refreshCardsVisibility)
	ownSkill.ChildRemoved:Connect(refreshCardsVisibility)
	
	refreshCardsVisibility()
end)

-- Game Phase Integration
local phaseRemote = hoverRemotes:WaitForChild("GamePhaseChanged") :: RemoteEvent
phaseRemote.OnClientEvent:Connect(function(phase, timeLeft)
	if phase == "INTERMISSION" or phase == "MAP_VOTING" then
		hudGui.Enabled = true
	else
		-- 레이스 중(RACE_MATCH 등)이라도, 늦게 접속해 대기실에 있는 유저는 호버보드가 없습니다.
		-- 호버보드가 없다면 대기실에 있는 것이므로 인벤토리를 띄워줍니다.
		local character = LocalPlayer.Character
		local isRacing = false
		if character and character:FindFirstChild("EquippedHoverboard") then
			isRacing = true
		end
		
		if isRacing then
			hudGui.Enabled = false
			invGui.Enabled = false
		else
			hudGui.Enabled = true
		end
	end
end)

-- 인벤토리 리스트에 있는 모든 카드의 아이콘에도 바운스 애니메이션(물결 효과) 적용
RunService.RenderStepped:Connect(function()
	local t = tick()
	for i, data in ipairs(allCards) do
		if data.img and data.card.Visible then
			-- 각 카드마다 i(인덱스) 값으로 위상 차이를 줘서 파도치듯(Wave) 부드럽게 움직이게 합니다.
			-- 진폭 4픽셀, 속도 3
			local bounce = math.sin(t * 3 + (i * 0.5)) * 4
			data.img.Position = UDim2.new(0, 10, 0, 10 + bounce)
		end
	end
end)
