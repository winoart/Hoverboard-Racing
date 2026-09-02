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
local titleLabel = bgFrame:WaitForChild("Title")
local closeBtn = bgFrame:WaitForChild("CloseButton")

closeBtn.MouseButton1Click:Connect(function()
	invGui.Enabled = false
end)
toggleBtn.MouseButton1Click:Connect(function()
	invGui.Enabled = not invGui.Enabled
end)

-- Tabs
local tabsFrame = bgFrame:WaitForChild("Tabs")
local boardsTabBtn = tabsFrame:WaitForChild("BoardsTab")
local skillsTabBtn = tabsFrame:WaitForChild("SkillsTab")

-- Left Column (Scrolls)
local leftCol = bgFrame:WaitForChild("LeftColumn")
local boardsScroll = leftCol:WaitForChild("BoardsScroll")
local skillsScroll = leftCol:WaitForChild("SkillsScroll")

-- Right Column (Details)
local rightCol = bgFrame:WaitForChild("RightColumn")
local rImage = rightCol:WaitForChild("ItemImage")
local rViewport = rightCol:WaitForChild("ItemViewport")

local rCamera = rViewport:FindFirstChild("ViewportCamera")
if not rCamera then
	rCamera = Instance.new("Camera")
	rCamera.Name = "ViewportCamera"
	rCamera.Parent = rViewport
end
rViewport.CurrentCamera = rCamera

local rName = rightCol:WaitForChild("ItemName")
local rDesc = rightCol:WaitForChild("ItemDesc")
local actionBtn = rightCol:WaitForChild("ActionButton")

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
		rImage.Image = ""
		rName.Text = "아이템을 선택하세요"
		rDesc.Text = ""
		actionBtn.Visible = false
		return
	end
	
	rName.Text = selectedItem.name
	
	if selectedItemType == "Board" then
		rImage.Visible = false
		rViewport.Visible = true
		rDesc.Text = selectedItem.rarity and ("등급: " .. selectedItem.rarity) or ""
		
		-- Setup 3D Model
		for _, child in ipairs(rViewport:GetChildren()) do
			if child:IsA("Model") then
				child:Destroy()
			end
		end
		local model = nil
		if customModelsFolder and customModelsFolder:FindFirstChild(selectedItem.id) then
			model = customModelsFolder:FindFirstChild(selectedItem.id):Clone()
		else
			model = HoverboardBuilder.createModel()
		end
		
		model.Parent = rViewport
		local pp = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
		if pp then
			rCamera.FieldOfView = 50
			
			-- Animation (Rotation + Bobbing)
			local t = 0
			local conn = RunService.RenderStepped:Connect(function(dt)
				t += dt
				local yOffset = math.sin(t * 3) * 0.3 -- Up and down bobbing
				local rotation = CFrame.Angles(0, t * 1.0, 0) -- Slow rotation
				
				local offset = rotation * Vector3.new(2.5, 2 + yOffset, -3.5)
				rCamera.CFrame = CFrame.new(pp.Position + offset, pp.Position)
			end)
			table.insert(renderConnections, conn)
		end
	else
		rImage.Visible = true
		rViewport.Visible = false
		rImage.Image = selectedItem.imageId
		rDesc.Text = selectedItem.description or ""
	end
	
	actionBtn.Visible = true
	actionBtn.AutoButtonColor = true
	
	local isEquipped = false
	
	if selectedItemType == "Board" then
		local equippedVal = LocalPlayer:FindFirstChild("EquippedHoverboardId") :: StringValue?
		if equippedVal and equippedVal.Value == selectedItem.id then
			isEquipped = true
		end
	else
		local equippedSkills = LocalPlayer:FindFirstChild("EquippedSkills")
		if equippedSkills and equippedSkills:FindFirstChild(selectedItem.id) then
			isEquipped = true
		end
	end
	
	if isEquipped then
		if selectedItemType == "Board" then
			actionBtn.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
			actionBtn.Text = "장착 중"
			actionBtn.AutoButtonColor = false
		else
			actionBtn.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
			actionBtn.Text = "장착 해제"
			actionBtn.AutoButtonColor = true
		end
	else
		actionBtn.BackgroundColor3 = Color3.fromRGB(50, 255, 100)
		actionBtn.Text = "장착하기"
		actionBtn.AutoButtonColor = true
	end
end

actionBtn.MouseButton1Click:Connect(function()
	if not selectedItem or not actionBtn.AutoButtonColor then return end
	
	-- Equip
	local remote = selectedItemType == "Board" and equipBoardRemote or equipSkillRemote
	local s = remote:InvokeServer(selectedItem.id)
	if s then
		updateRightColumn()
	end
end)

local function selectItem(item, iType)
	selectedItem = item
	selectedItemType = iType
	
	-- Highlight card
	for _, data in ipairs(allCards) do
		if data.item.id == item.id then
			data.stroke.Thickness = 8
		else
			data.stroke.Thickness = 5
		end
	end
	
	updateRightColumn()
end

local cardTemplate = invGui:WaitForChild("CardTemplate")

local function createInvCard(item, itemType, parentScroll)
	local cardBtn = cardTemplate:Clone()
	cardBtn.Name = "Card_" .. item.id
	cardBtn.Parent = parentScroll
	cardBtn.Visible = true
	
	local cardStroke = cardBtn:WaitForChild("UIStroke")
	
	local img = cardBtn:FindFirstChild("Image")
	local vpf = cardBtn:FindFirstChild("Viewport")
	if itemType == "Board" then
		img.Visible = false
		vpf.Visible = true
		
		local cam = vpf:FindFirstChild("Camera")
		if not cam then
			cam = Instance.new("Camera")
			cam.Name = "Camera"
			cam.Parent = vpf
		end
		vpf.CurrentCamera = cam
		
		local model = nil
		if customModelsFolder and customModelsFolder:FindFirstChild(item.id) then
			model = customModelsFolder:FindFirstChild(item.id):Clone()
		else
			model = HoverboardBuilder.createModel()
		end
		
		model.Parent = vpf
		local pp = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
		if pp then
			cam.FieldOfView = 50
			local t = 0
			local conn = RunService.RenderStepped:Connect(function(dt)
				t += dt
				local yOffset = math.sin(t * 3) * 0.2
				local rotation = CFrame.Angles(0, t * 1.0, 0)
				local offset = rotation * Vector3.new(2.5, 2 + yOffset, -3.5)
				cam.CFrame = CFrame.new(pp.Position + offset, pp.Position)
			end)
		end
	else
		img.Visible = true
		vpf.Visible = false
		img.Image = item.imageId
	end
	
	local nameLabel = cardBtn:WaitForChild("ItemName")
	nameLabel.Text = item.name
	nameLabel.TextSize = 28
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextStrokeTransparency = 0
	
	local statusLabel = cardBtn:WaitForChild("Status")
	statusLabel.TextSize = 20
	statusLabel.Font = Enum.Font.GothamBold
	statusLabel.TextStrokeTransparency = 0
	
	table.insert(allCards, {card = cardBtn, stroke = cardStroke, item = item, itemType = itemType, statusLabel = statusLabel})
	
	cardBtn.MouseButton1Click:Connect(function()
		selectItem(item, itemType)
	end)
end

local function refreshCardsVisibility()
	local boardOwned = LocalPlayer:FindFirstChild("OwnedHoverboards")
	local skillOwned = LocalPlayer:FindFirstChild("OwnedSkills")
	local boardEq = LocalPlayer:FindFirstChild("EquippedHoverboardId") :: StringValue?
	local skillEq = LocalPlayer:FindFirstChild("EquippedSkills")
	
	for _, data in ipairs(allCards) do
		if data.itemType == "Board" then
			if data.item.id == "DefaultHoverboard" or (boardOwned and boardOwned:FindFirstChild(data.item.id)) then
				data.card.Visible = true
				if boardEq and boardEq.Value == data.item.id then
					data.statusLabel.Text = "✅ 장착 중"
					data.statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
				else
					data.statusLabel.Text = "보유 중"
					data.statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
				end
			else
				data.card.Visible = false
			end
		else
			if skillOwned and skillOwned:FindFirstChild(data.item.id) then
				data.card.Visible = true
				if skillEq and skillEq:FindFirstChild(data.item.id) then
					data.statusLabel.Text = "✅ 장착 중"
					data.statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
				else
					data.statusLabel.Text = "보유 중"
					data.statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
				end
			else
				data.card.Visible = false
			end
		end
	end
	
	if selectedItem then updateRightColumn() end
end

-- Init Cards
for _, boardInfo in ipairs(StoreConfig.Items) do
	createInvCard(boardInfo, "Board", boardsScroll)
end
for _, skillInfo in ipairs(SkillStoreConfig.Skills) do
	createInvCard(skillInfo, "Skill", skillsScroll)
end

-- Tab Logic
boardsTabBtn.MouseButton1Click:Connect(function()
	boardsScroll.Visible = true
	skillsScroll.Visible = false
	boardsTabBtn.BackgroundColor3 = Color3.fromRGB(255, 180, 50)
	skillsTabBtn.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
	selectedItem = nil
	updateRightColumn()
end)

skillsTabBtn.MouseButton1Click:Connect(function()
	boardsScroll.Visible = false
	skillsScroll.Visible = true
	skillsTabBtn.BackgroundColor3 = Color3.fromRGB(255, 180, 50)
	boardsTabBtn.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
	selectedItem = nil
	updateRightColumn()
end)

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
