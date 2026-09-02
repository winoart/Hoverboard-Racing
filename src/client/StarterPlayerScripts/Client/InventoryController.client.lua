--!strict
-- InventoryController.client.luau
-- Displays the Unified Inventory UI for equipping Hoverboards and Skills

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
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

local bgFrame = invGui:WaitForChild("Background")
local titleLabel = bgFrame:FindFirstChild("Title")
local closeBtn = bgFrame:FindFirstChild("CloseButton")

if closeBtn then
	closeBtn.MouseButton1Click:Connect(function()
		invGui.Enabled = false
	end)
end

toggleBtn.MouseButton1Click:Connect(function()
	print("Inventory toggle button clicked! Current state:", invGui.Enabled)
	invGui.Enabled = not invGui.Enabled
	invGui.DisplayOrder = 100 -- Ensure it renders above other GUIs
	if bgFrame then
		bgFrame.Visible = true
		bgFrame.Size = UDim2.new(0, 850, 0, 500)
		bgFrame.Position = UDim2.new(0.5, -425, 0.5, -250)
	end
	print("InventoryGui Enabled set to:", invGui.Enabled)
end)

-- Tabs
local tabsFrame = bgFrame:FindFirstChild("Tabs")
local boardsTabBtn = tabsFrame and (tabsFrame:FindFirstChild("BoardsTab") or tabsFrame:FindFirstChild("BoardsTab frame"))
local skillsTabBtn = tabsFrame and (tabsFrame:FindFirstChild("SkillsTab") or tabsFrame:FindFirstChild("SkillsTab frame"))

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

-- Left Column (Scrolls)
local leftCol = bgFrame:FindFirstChild("LeftColumn")
local boardsScroll = leftCol and leftCol:FindFirstChild("BoardsScroll")
local skillsScroll = leftCol and leftCol:FindFirstChild("SkillsScroll")

-- Right Column (Details)
local rightCol = bgFrame:FindFirstChild("RightColumn")

local rImage = rightCol and rightCol:FindFirstChild("ItemImage")
local rViewport = rightCol and rightCol:FindFirstChild("ItemViewport")

local rCamera = rViewport and rViewport:FindFirstChild("ViewportCamera")
if rViewport and not rCamera then
	rCamera = Instance.new("Camera")
	rCamera.Name = "ViewportCamera"
	rCamera.Parent = rViewport
end
if rViewport and rCamera then
	rViewport.CurrentCamera = rCamera
end

local rName = rightCol and rightCol:FindFirstChild("ItemName")
local rDesc = rightCol and rightCol:FindFirstChild("ItemDesc")
local actionBtn = rightCol and rightCol:FindFirstChild("ActionButton")

local allCards = {}
local renderConnections = {}

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
	if rDesc then rDesc.Text = info.desc or "설명이 없습니다." end

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
		if rImage then rImage.Visible = false end
		if rViewport then rViewport.Visible = true end
		if rViewport then rViewport:ClearAllChildren() end
		if rCamera then rCamera.Parent = rViewport end
		
		local model = nil
		if customModelsFolder and customModelsFolder:FindFirstChild(info.id) then
			model = customModelsFolder:FindFirstChild(info.id):Clone()
		else
			model = HoverboardBuilder.createModel()
		end
		model.Parent = rViewport
		local pp = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
		if pp and rCamera then
			rCamera.FieldOfView = 70
			local t = 0
			local conn = RunService.RenderStepped:Connect(function(dt)
				t += dt
				local yOffset = math.sin(t * 4) * 0.4
				local rotation = CFrame.Angles(0, t * 1.5, 0)
				local offset = rotation * Vector3.new(3.5, 2.5 + yOffset, -5)
				rCamera.CFrame = CFrame.new(pp.Position + offset, pp.Position)
			end)
			table.insert(renderConnections, conn)
		end
	else
		if rImage then rImage.Visible = true end
		if rViewport then rViewport.Visible = false end
		if rImage then rImage.Image = info.imageId end
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
	bgGradient.Color = itemType == "Board" and ColorSequence.new(Color3.fromRGB(100, 220, 255), Color3.fromRGB(20, 100, 255)) or ColorSequence.new(Color3.fromRGB(150, 100, 255), Color3.fromRGB(255, 100, 255))
	bgGradient.Rotation = 45
	bgGradient.Parent = cardBtn
	
	local cardStroke = cardBtn:FindFirstChild("UIStroke")
	if cardStroke then cardStroke.Thickness = 5 end
	
	local img = cardBtn:FindFirstChild("Image")
	local vpf = cardBtn:FindFirstChild("Viewport")
	
	if itemType == "Board" then
		if img then img.Visible = false end
		if vpf then vpf.Visible = true end
	else
		if img then img.Visible = true; img.Image = item.imageId end
		if vpf then vpf.Visible = false end
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
	checkIcon.Parent = cardBtn
	
	table.insert(allCards, {card = cardBtn, stroke = cardStroke, item = item, itemType = itemType, checkIcon = checkIcon})
	
	cardBtn.MouseButton1Click:Connect(function()
		selectItem(item, itemType)
	end)
end

local function refreshCardsVisibility()
	for _, data in ipairs(allCards) do
		local isOwned = data.itemType == "Board" and checkOwnsBoard(data.item.id) or checkOwnsSkill(data.item.id)
		local isEquipped = data.itemType == "Board" and checkEquippedBoard(data.item.id) or checkEquippedSkill(data.item.id)
		
		data.card.Visible = isOwned and true or false
		data.checkIcon.Visible = isEquipped
	end
	if selectedItem then updateRightColumn() end
end

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
