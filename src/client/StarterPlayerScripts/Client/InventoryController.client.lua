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

-- Inventory UI Generation
local invGui = Instance.new("ScreenGui")
invGui.Name = "InventoryGui"
invGui.ResetOnSpawn = false
invGui.Enabled = false
invGui.Parent = playerGui

local bgFrame = Instance.new("Frame")
bgFrame.Name = "Background"
bgFrame.Size = UDim2.new(0, 850, 0, 500)
bgFrame.Position = UDim2.new(0.5, -425, 0.5, -250)
bgFrame.BackgroundColor3 = Color3.fromRGB(20, 25, 35)
bgFrame.Parent = invGui
Instance.new("UICorner", bgFrame).CornerRadius = UDim.new(0, 12)
local bgStroke = Instance.new("UIStroke", bgFrame)
bgStroke.Color = Color3.fromRGB(150, 150, 200)
bgStroke.Thickness = 3

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(1, 0, 0, 50)
titleLabel.Position = UDim2.new(0, 0, 0, 10)
titleLabel.BackgroundTransparency = 1
titleLabel.Font = Enum.Font.GothamBlack
titleLabel.Text = "내 인벤토리"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextSize = 28
titleLabel.Parent = bgFrame

local closeBtn = Instance.new("TextButton")
closeBtn.Name = "CloseButton"
closeBtn.Size = UDim2.new(0, 40, 0, 40)
closeBtn.Position = UDim2.new(1, -50, 0, 10)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.TextSize = 20
closeBtn.Parent = bgFrame
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)

toggleBtn.MouseButton1Click:Connect(function()
	invGui.Enabled = not invGui.Enabled
end)
closeBtn.MouseButton1Click:Connect(function()
	invGui.Enabled = false
end)

-- Tabs
local tabsFrame = Instance.new("Frame")
tabsFrame.Size = UDim2.new(1, -40, 0, 40)
tabsFrame.Position = UDim2.new(0, 20, 0, 60)
tabsFrame.BackgroundTransparency = 1
tabsFrame.Parent = bgFrame

local tabLayout = Instance.new("UIListLayout", tabsFrame)
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 10)

local boardsTabBtn = Instance.new("TextButton", tabsFrame)
boardsTabBtn.Size = UDim2.new(0, 150, 1, 0)
boardsTabBtn.BackgroundColor3 = Color3.fromRGB(50, 100, 255)
boardsTabBtn.Font = Enum.Font.GothamBold
boardsTabBtn.Text = "호버보드"
boardsTabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
boardsTabBtn.TextSize = 18
Instance.new("UICorner", boardsTabBtn).CornerRadius = UDim.new(0, 6)

local skillsTabBtn = Instance.new("TextButton", tabsFrame)
skillsTabBtn.Size = UDim2.new(0, 150, 1, 0)
skillsTabBtn.BackgroundColor3 = Color3.fromRGB(40, 50, 70)
skillsTabBtn.Font = Enum.Font.GothamBold
skillsTabBtn.Text = "스킬"
skillsTabBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
skillsTabBtn.TextSize = 18
Instance.new("UICorner", skillsTabBtn).CornerRadius = UDim.new(0, 6)

-- Left Column (Scrolls)
local leftCol = Instance.new("Frame", bgFrame)
leftCol.Name = "LeftColumn"
leftCol.Size = UDim2.new(0.6, -10, 1, -120)
leftCol.Position = UDim2.new(0, 20, 0, 110)
leftCol.BackgroundTransparency = 1

local boardsScroll = Instance.new("ScrollingFrame", leftCol)
boardsScroll.Size = UDim2.new(1, 0, 1, 0)
boardsScroll.BackgroundTransparency = 1
boardsScroll.ScrollBarThickness = 8
boardsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
boardsScroll.Visible = true

local boardsGrid = Instance.new("UIGridLayout", boardsScroll)
boardsGrid.CellSize = UDim2.new(0, 150, 0, 180)
boardsGrid.CellPadding = UDim2.new(0, 10, 0, 10)
boardsGrid.HorizontalAlignment = Enum.HorizontalAlignment.Left

local skillsScroll = Instance.new("ScrollingFrame", leftCol)
skillsScroll.Size = UDim2.new(1, 0, 1, 0)
skillsScroll.BackgroundTransparency = 1
skillsScroll.ScrollBarThickness = 8
skillsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
skillsScroll.Visible = false

local skillsGrid = Instance.new("UIGridLayout", skillsScroll)
skillsGrid.CellSize = UDim2.new(0, 150, 0, 180)
skillsGrid.CellPadding = UDim2.new(0, 10, 0, 10)
skillsGrid.HorizontalAlignment = Enum.HorizontalAlignment.Left

-- Right Column (Details)
local rightCol = Instance.new("Frame", bgFrame)
rightCol.Name = "RightColumn"
rightCol.Size = UDim2.new(0.4, -30, 1, -120)
rightCol.Position = UDim2.new(0.6, 10, 0, 110)
rightCol.BackgroundColor3 = Color3.fromRGB(15, 20, 30)
Instance.new("UICorner", rightCol).CornerRadius = UDim.new(0, 12)
local rcStroke = Instance.new("UIStroke", rightCol)
rcStroke.Color = Color3.fromRGB(100, 120, 150)
rcStroke.Thickness = 2

local rImage = Instance.new("ImageLabel", rightCol)
rImage.Size = UDim2.new(0.8, 0, 0.4, 0)
rImage.Position = UDim2.new(0.1, 0, 0.05, 0)
rImage.BackgroundTransparency = 1
rImage.Image = ""
rImage.ScaleType = Enum.ScaleType.Fit

local rViewport = Instance.new("ViewportFrame", rightCol)
rViewport.Size = UDim2.new(0.8, 0, 0.4, 0)
rViewport.Position = UDim2.new(0.1, 0, 0.05, 0)
rViewport.BackgroundColor3 = Color3.fromRGB(255, 230, 100)
rViewport.BackgroundTransparency = 0
Instance.new("UICorner", rViewport).CornerRadius = UDim.new(0, 8)
rViewport.Visible = false

local rCamera = Instance.new("Camera")
rViewport.CurrentCamera = rCamera
rCamera.Parent = rViewport

local rName = Instance.new("TextLabel", rightCol)
rName.Size = UDim2.new(1, 0, 0, 40)
rName.Position = UDim2.new(0, 0, 0.45, 0)
rName.BackgroundTransparency = 1
rName.Font = Enum.Font.GothamBlack
rName.Text = "아이템을 선택하세요"
rName.TextColor3 = Color3.fromRGB(255, 255, 255)
rName.TextSize = 22

local rDesc = Instance.new("TextLabel", rightCol)
rDesc.Size = UDim2.new(0.9, 0, 0, 60)
rDesc.Position = UDim2.new(0.05, 0, 0.55, 0)
rDesc.BackgroundTransparency = 1
rDesc.Font = Enum.Font.GothamMedium
rDesc.Text = ""
rDesc.TextColor3 = Color3.fromRGB(180, 180, 200)
rDesc.TextSize = 14
rDesc.TextWrapped = true
rDesc.TextYAlignment = Enum.TextYAlignment.Top

local actionBtn = Instance.new("TextButton", rightCol)
actionBtn.Size = UDim2.new(0.9, 0, 0, 50)
actionBtn.Position = UDim2.new(0.05, 0, 1, -60)
actionBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
actionBtn.Font = Enum.Font.GothamBlack
actionBtn.Text = "선택 안됨"
actionBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
actionBtn.TextSize = 20
actionBtn.Visible = false
Instance.new("UICorner", actionBtn).CornerRadius = UDim.new(0, 8)

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
		actionBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
		actionBtn.Text = "✅ 장착 중"
		actionBtn.AutoButtonColor = false
	else
		actionBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
		actionBtn.Text = "👆 장착하기"
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
			data.stroke.Color = Color3.fromRGB(0, 255, 100)
			data.stroke.Thickness = 3
		else
			data.stroke.Color = Color3.fromRGB(100, 120, 150)
			data.stroke.Thickness = 2
		end
	end
	
	updateRightColumn()
end

local function createInvCard(item, itemType, parentScroll)
	local cardBtn = Instance.new("TextButton")
	cardBtn.Name = "Card_" .. item.id
	cardBtn.BackgroundColor3 = Color3.fromRGB(25, 30, 45)
	cardBtn.Text = ""
	cardBtn.Parent = parentScroll
	
	Instance.new("UICorner", cardBtn).CornerRadius = UDim.new(0, 10)
	local cardStroke = Instance.new("UIStroke", cardBtn)
	cardStroke.Color = Color3.fromRGB(100, 120, 150)
	cardStroke.Thickness = 2
	
	local img
	local vpf
	if itemType == "Board" then
		vpf = Instance.new("ViewportFrame", cardBtn)
		vpf.Size = UDim2.new(1, -20, 0, 90)
		vpf.Position = UDim2.new(0, 10, 0, 10)
		vpf.BackgroundColor3 = Color3.fromRGB(255, 230, 100)
		vpf.BackgroundTransparency = 0
		Instance.new("UICorner", vpf).CornerRadius = UDim.new(0, 8)
		
		local cam = Instance.new("Camera")
		vpf.CurrentCamera = cam
		cam.Parent = vpf
		
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
		img = Instance.new("ImageLabel", cardBtn)
		img.Size = UDim2.new(1, -20, 0, 90)
		img.Position = UDim2.new(0, 10, 0, 10)
		img.BackgroundColor3 = Color3.fromRGB(15, 20, 30)
		img.Image = item.imageId
		img.ScaleType = Enum.ScaleType.Fit
		Instance.new("UICorner", img).CornerRadius = UDim.new(0, 8)
	end
	
	local nameLabel = Instance.new("TextLabel", cardBtn)
	nameLabel.Size = UDim2.new(1, 0, 0, 30)
	nameLabel.Position = UDim2.new(0, 0, 0, 110)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Text = item.name
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextSize = 14
	
	local statusLabel = Instance.new("TextLabel", cardBtn)
	statusLabel.Size = UDim2.new(1, 0, 0, 20)
	statusLabel.Position = UDim2.new(0, 0, 0, 145)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Font = Enum.Font.GothamBold
	statusLabel.TextSize = 13
	
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
					data.statusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
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
					data.statusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
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
	boardsTabBtn.BackgroundColor3 = Color3.fromRGB(50, 100, 255)
	boardsTabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	skillsTabBtn.BackgroundColor3 = Color3.fromRGB(40, 50, 70)
	skillsTabBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
	selectedItem = nil
	updateRightColumn()
end)

skillsTabBtn.MouseButton1Click:Connect(function()
	boardsScroll.Visible = false
	skillsScroll.Visible = true
	skillsTabBtn.BackgroundColor3 = Color3.fromRGB(50, 100, 255)
	skillsTabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	boardsTabBtn.BackgroundColor3 = Color3.fromRGB(40, 50, 70)
	boardsTabBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
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
		hudGui.Enabled = false
		invGui.Enabled = false
	end
end)
