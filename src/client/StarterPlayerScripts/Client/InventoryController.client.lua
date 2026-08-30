--!strict
-- InventoryController.client.luau
-- Displays the Unified Inventory UI for equipping Hoverboards and Skills

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local playerGui = LocalPlayer:WaitForChild("PlayerGui")

local hoverRemotes = ReplicatedStorage:WaitForChild("HoverboardRemotes")
local equipBoardRemote = hoverRemotes:WaitForChild("EquipItem") :: RemoteFunction

local skillRemotes = ReplicatedStorage:WaitForChild("SkillRemotes")
local equipSkillRemote = skillRemotes:WaitForChild("EquipSkill") :: RemoteFunction

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StoreConfig = require(Shared:WaitForChild("StoreConfig") :: ModuleScript)
local SkillStoreConfig = require(Shared:WaitForChild("SkillStoreConfig") :: ModuleScript)

-- Main Toggle Button (HUD)
local hudGui = Instance.new("ScreenGui")
hudGui.Name = "InventoryHUD"
hudGui.ResetOnSpawn = false
hudGui.Parent = playerGui

local toggleBtn = Instance.new("TextButton")
toggleBtn.Name = "InventoryToggle"
toggleBtn.Size = UDim2.new(0, 70, 0, 70)
toggleBtn.Position = UDim2.new(1, -90, 0, 20)
toggleBtn.BackgroundColor3 = Color3.fromRGB(30, 40, 60)
toggleBtn.Font = Enum.Font.GothamBlack
toggleBtn.Text = "🎒"
toggleBtn.TextSize = 36
toggleBtn.Parent = hudGui

local tCorner = Instance.new("UICorner")
tCorner.CornerRadius = UDim.new(1, 0)
tCorner.Parent = toggleBtn

local tStroke = Instance.new("UIStroke")
tStroke.Color = Color3.fromRGB(255, 255, 255)
tStroke.Thickness = 2
tStroke.Parent = toggleBtn

-- Inventory UI
local invGui = Instance.new("ScreenGui")
invGui.Name = "InventoryGui"
invGui.ResetOnSpawn = false
invGui.Enabled = false
invGui.Parent = playerGui

local bgFrame = Instance.new("Frame")
bgFrame.Name = "Background"
bgFrame.Size = UDim2.new(0, 800, 0, 500)
bgFrame.Position = UDim2.new(0.5, -400, 0.5, -250)
bgFrame.BackgroundColor3 = Color3.fromRGB(15, 20, 30)
bgFrame.BackgroundTransparency = 0.05
bgFrame.BorderSizePixel = 0
bgFrame.Parent = invGui

local bgCorner = Instance.new("UICorner")
bgCorner.CornerRadius = UDim.new(0, 12)
bgCorner.Parent = bgFrame

local bgStroke = Instance.new("UIStroke")
bgStroke.Color = Color3.fromRGB(200, 200, 255)
bgStroke.Thickness = 3
bgStroke.Parent = bgFrame

-- Title
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

-- Close Button
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

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 8)
closeCorner.Parent = closeBtn

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

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 10)
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.Parent = tabsFrame

local boardsTabBtn = Instance.new("TextButton")
boardsTabBtn.Size = UDim2.new(0, 150, 1, 0)
boardsTabBtn.BackgroundColor3 = Color3.fromRGB(50, 100, 255)
boardsTabBtn.Font = Enum.Font.GothamBold
boardsTabBtn.Text = "호버보드"
boardsTabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
boardsTabBtn.TextSize = 18
boardsTabBtn.LayoutOrder = 1
boardsTabBtn.Parent = tabsFrame

local boardsCorner = Instance.new("UICorner")
boardsCorner.CornerRadius = UDim.new(0, 6)
boardsCorner.Parent = boardsTabBtn

local skillsTabBtn = Instance.new("TextButton")
skillsTabBtn.Size = UDim2.new(0, 150, 1, 0)
skillsTabBtn.BackgroundColor3 = Color3.fromRGB(40, 50, 70)
skillsTabBtn.Font = Enum.Font.GothamBold
skillsTabBtn.Text = "스킬"
skillsTabBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
skillsTabBtn.TextSize = 18
skillsTabBtn.LayoutOrder = 2
skillsTabBtn.Parent = tabsFrame

local skillsCorner = Instance.new("UICorner")
skillsCorner.CornerRadius = UDim.new(0, 6)
skillsCorner.Parent = skillsTabBtn

-- Scroll Frames for content
local boardsScroll = Instance.new("ScrollingFrame")
boardsScroll.Name = "BoardsScroll"
boardsScroll.Size = UDim2.new(1, -40, 1, -120)
boardsScroll.Position = UDim2.new(0, 20, 0, 110)
boardsScroll.BackgroundTransparency = 1
boardsScroll.ScrollBarThickness = 8
boardsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
boardsScroll.Visible = true
boardsScroll.Parent = bgFrame

local boardsGrid = Instance.new("UIGridLayout")
boardsGrid.CellSize = UDim2.new(0, 220, 0, 260)
boardsGrid.CellPadding = UDim2.new(0, 15, 0, 20)
boardsGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
boardsGrid.SortOrder = Enum.SortOrder.LayoutOrder
boardsGrid.Parent = boardsScroll

local skillsScroll = Instance.new("ScrollingFrame")
skillsScroll.Name = "SkillsScroll"
skillsScroll.Size = UDim2.new(1, -40, 1, -120)
skillsScroll.Position = UDim2.new(0, 20, 0, 110)
skillsScroll.BackgroundTransparency = 1
skillsScroll.ScrollBarThickness = 8
skillsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
skillsScroll.Visible = false
skillsScroll.Parent = bgFrame

local skillsGrid = Instance.new("UIGridLayout")
skillsGrid.CellSize = UDim2.new(0, 220, 0, 260)
skillsGrid.CellPadding = UDim2.new(0, 15, 0, 20)
skillsGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
skillsGrid.SortOrder = Enum.SortOrder.LayoutOrder
skillsGrid.Parent = skillsScroll

-- Tab Logic
boardsTabBtn.MouseButton1Click:Connect(function()
	boardsScroll.Visible = true
	skillsScroll.Visible = false
	boardsTabBtn.BackgroundColor3 = Color3.fromRGB(50, 100, 255)
	boardsTabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	skillsTabBtn.BackgroundColor3 = Color3.fromRGB(40, 50, 70)
	skillsTabBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
end)

skillsTabBtn.MouseButton1Click:Connect(function()
	boardsScroll.Visible = false
	skillsScroll.Visible = true
	skillsTabBtn.BackgroundColor3 = Color3.fromRGB(50, 100, 255)
	skillsTabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	boardsTabBtn.BackgroundColor3 = Color3.fromRGB(40, 50, 70)
	boardsTabBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
end)

-- Helper: Create Inventory Card
local function createInvCard(item, itemType, parentScroll, equipRemote)
	local card = Instance.new("Frame")
	card.Name = "Card_" .. item.id
	card.BackgroundColor3 = Color3.fromRGB(25, 30, 45)
	card.Parent = parentScroll
	
	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 10)
	cardCorner.Parent = card
	
	local cardStroke = Instance.new("UIStroke")
	cardStroke.Color = Color3.fromRGB(100, 120, 150)
	cardStroke.Thickness = 2
	cardStroke.Parent = card
	
	-- Rarity (only for boards, for skills default color)
	local rColor = Color3.fromRGB(200, 200, 200)
	if itemType == "Board" and item.rarity then
		rColor = StoreConfig.RarityColors[item.rarity] or rColor
		
		local rLabel = Instance.new("TextLabel")
		rLabel.Size = UDim2.new(1, 0, 0, 20)
		rLabel.BackgroundTransparency = 1
		rLabel.Font = Enum.Font.GothamBold
		rLabel.Text = item.rarity
		rLabel.TextColor3 = rColor
		rLabel.TextSize = 12
		rLabel.Parent = card
	end
	
	-- Item Name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 0, 30)
	nameLabel.Position = UDim2.new(0, 0, 0, 15)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Text = item.name
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextSize = 16
	nameLabel.Parent = card
	
	-- Item Image
	local img = Instance.new("ImageLabel")
	img.Size = UDim2.new(1, -20, 0, 110)
	img.Position = UDim2.new(0, 10, 0, 50)
	img.BackgroundColor3 = Color3.fromRGB(15, 20, 30)
	img.Image = item.imageId
	img.ScaleType = Enum.ScaleType.Fit
	img.Parent = card
	
	local imgCorner = Instance.new("UICorner")
	imgCorner.CornerRadius = UDim.new(0, 8)
	imgCorner.Parent = img
	
	-- Equip Button
	local equipBtn = Instance.new("TextButton")
	equipBtn.Size = UDim2.new(1, -20, 0, 40)
	equipBtn.Position = UDim2.new(0, 10, 1, -50)
	equipBtn.Font = Enum.Font.GothamBold
	equipBtn.TextSize = 18
	equipBtn.Parent = card
	
	local eCorner = Instance.new("UICorner")
	eCorner.CornerRadius = UDim.new(0, 8)
	eCorner.Parent = equipBtn
	
	local function updateEquipState()
		local ownedFolder
		local isEquipped = false
		
		if itemType == "Board" then
			local equippedVal = LocalPlayer:FindFirstChild("EquippedHoverboardId") :: StringValue?
			ownedFolder = LocalPlayer:FindFirstChild("OwnedHoverboards")
			if equippedVal and equippedVal.Value == item.id then
				isEquipped = true
			end
		else
			local equippedSkills = LocalPlayer:FindFirstChild("EquippedSkills")
			ownedFolder = LocalPlayer:FindFirstChild("OwnedSkills")
			if equippedSkills and equippedSkills:FindFirstChild(item.id) then
				isEquipped = true
			end
		end
		
		-- Hide card if not owned (except default board)
		if item.id == "DefaultHoverboard" or (ownedFolder and ownedFolder:FindFirstChild(item.id)) then
			card.Visible = true
		else
			card.Visible = false
			return
		end
		
		if isEquipped then
			equipBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
			equipBtn.Text = "✅ 장착해제"
			equipBtn.AutoButtonColor = true
		else
			equipBtn.BackgroundColor3 = Color3.fromRGB(30, 120, 255)
			equipBtn.Text = "👆 장착하기"
			equipBtn.AutoButtonColor = true
		end
	end
	
	-- Bind
	task.spawn(function()
		if itemType == "Board" then
			local bVal = LocalPlayer:WaitForChild("EquippedHoverboardId")
			bVal.Changed:Connect(updateEquipState)
			local f = LocalPlayer:WaitForChild("OwnedHoverboards")
			f.ChildAdded:Connect(updateEquipState)
			f.ChildRemoved:Connect(updateEquipState)
		else
			local eqFolder = LocalPlayer:WaitForChild("EquippedSkills")
			eqFolder.ChildAdded:Connect(updateEquipState)
			eqFolder.ChildRemoved:Connect(updateEquipState)
			local f = LocalPlayer:WaitForChild("OwnedSkills")
			f.ChildAdded:Connect(updateEquipState)
			f.ChildRemoved:Connect(updateEquipState)
		end
		updateEquipState()
	end)
	
	equipBtn.MouseButton1Click:Connect(function()
		if itemType == "Board" then
			local equippedVal = LocalPlayer:FindFirstChild("EquippedHoverboardId") :: StringValue?
			if equippedVal and equippedVal.Value ~= item.id then
				local s, msg = equipRemote:InvokeServer(item.id)
				if s then
					cardStroke.Color = Color3.fromRGB(0, 255, 0)
					task.wait(0.5)
					cardStroke.Color = Color3.fromRGB(100, 120, 150)
				end
			end
		else
			-- Toggle Skill
			local s, msg = equipRemote:InvokeServer(item.id)
			if s then
				cardStroke.Color = Color3.fromRGB(0, 255, 0)
				task.wait(0.5)
				cardStroke.Color = Color3.fromRGB(100, 120, 150)
			else
				-- If full slot error or something, flash red
				cardStroke.Color = Color3.fromRGB(255, 0, 0)
				task.wait(0.5)
				cardStroke.Color = Color3.fromRGB(100, 120, 150)
			end
		end
	end)
end

-- Initialize Inventory Cards
for _, boardInfo in ipairs(StoreConfig.Items) do
	createInvCard(boardInfo, "Board", boardsScroll, equipBoardRemote)
end

for _, skillInfo in ipairs(SkillStoreConfig.Skills) do
	createInvCard(skillInfo, "Skill", skillsScroll, equipSkillRemote)
end

-- Listen to GamePhase changes to hide inventory button during races
local phaseRemote = hoverRemotes:WaitForChild("GamePhaseChanged") :: RemoteEvent
phaseRemote.OnClientEvent:Connect(function(phase, timeLeft)
	if phase == "INTERMISSION" then
		hudGui.Enabled = true
	else
		hudGui.Enabled = false
		invGui.Enabled = false -- Auto close if open when race starts
	end
end)

