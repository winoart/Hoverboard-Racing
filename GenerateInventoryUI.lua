local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local invGui = Instance.new("ScreenGui")
invGui.Name = "InventoryGui"
invGui.ResetOnSpawn = false
invGui.Enabled = false
invGui.Parent = StarterGui

-- Helper for Stroke
local function addStroke(parent, thickness)
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(0, 0, 0)
    stroke.Thickness = thickness or 4
    stroke.Parent = parent
    return stroke
end

local bgFrame = Instance.new("Frame")
bgFrame.Name = "Background"
bgFrame.Size = UDim2.new(0, 850, 0, 500)
bgFrame.Position = UDim2.new(0.5, -425, 0.5, -250)
bgFrame.BackgroundColor3 = Color3.fromRGB(90, 200, 255)
bgFrame.Parent = invGui
Instance.new("UICorner", bgFrame).CornerRadius = UDim.new(0, 16)
addStroke(bgFrame, 6)

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(1, 0, 0, 50)
titleLabel.Position = UDim2.new(0, 0, 0, 10)
titleLabel.BackgroundTransparency = 1
titleLabel.Font = Enum.Font.FredokaOne
titleLabel.Text = "내 인벤토리"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextSize = 36
titleLabel.Parent = bgFrame
addStroke(titleLabel, 4)

local closeBtn = Instance.new("TextButton")
closeBtn.Name = "CloseButton"
closeBtn.Size = UDim2.new(0, 45, 0, 45)
closeBtn.Position = UDim2.new(1, -55, 0, 10)
closeBtn.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
closeBtn.Font = Enum.Font.FredokaOne
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.TextSize = 24
closeBtn.Parent = bgFrame
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 12)
addStroke(closeBtn, 4)

-- Tabs
local tabsFrame = Instance.new("Frame")
tabsFrame.Name = "Tabs"
tabsFrame.Size = UDim2.new(1, -40, 0, 50)
tabsFrame.Position = UDim2.new(0, 20, 0, 65)
tabsFrame.BackgroundTransparency = 1
tabsFrame.Parent = bgFrame

local tabLayout = Instance.new("UIListLayout", tabsFrame)
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 15)

local boardsTabBtn = Instance.new("TextButton", tabsFrame)
boardsTabBtn.Name = "BoardsTab"
boardsTabBtn.Size = UDim2.new(0, 160, 1, 0)
boardsTabBtn.BackgroundColor3 = Color3.fromRGB(255, 180, 50)
boardsTabBtn.Font = Enum.Font.FredokaOne
boardsTabBtn.Text = "호버보드"
boardsTabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
boardsTabBtn.TextSize = 22
Instance.new("UICorner", boardsTabBtn).CornerRadius = UDim.new(0, 12)
addStroke(boardsTabBtn, 4)

local skillsTabBtn = Instance.new("TextButton", tabsFrame)
skillsTabBtn.Name = "SkillsTab"
skillsTabBtn.Size = UDim2.new(0, 160, 1, 0)
skillsTabBtn.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
skillsTabBtn.Font = Enum.Font.FredokaOne
skillsTabBtn.Text = "스킬"
skillsTabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
skillsTabBtn.TextSize = 22
Instance.new("UICorner", skillsTabBtn).CornerRadius = UDim.new(0, 12)
addStroke(skillsTabBtn, 4)

-- Left Column (Scrolls)
local leftCol = Instance.new("Frame", bgFrame)
leftCol.Name = "LeftColumn"
leftCol.Size = UDim2.new(0.6, -10, 1, -135)
leftCol.Position = UDim2.new(0, 20, 0, 125)
leftCol.BackgroundTransparency = 1

local boardsScroll = Instance.new("ScrollingFrame", leftCol)
boardsScroll.Name = "BoardsScroll"
boardsScroll.Size = UDim2.new(1, 0, 1, 0)
boardsScroll.BackgroundTransparency = 1
boardsScroll.ScrollBarThickness = 12
boardsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
boardsScroll.Visible = true

local boardsGrid = Instance.new("UIGridLayout", boardsScroll)
boardsGrid.CellSize = UDim2.new(0, 150, 0, 180)
boardsGrid.CellPadding = UDim2.new(0, 15, 0, 15)
boardsGrid.HorizontalAlignment = Enum.HorizontalAlignment.Left

local skillsScroll = Instance.new("ScrollingFrame", leftCol)
skillsScroll.Name = "SkillsScroll"
skillsScroll.Size = UDim2.new(1, 0, 1, 0)
skillsScroll.BackgroundTransparency = 1
skillsScroll.ScrollBarThickness = 12
skillsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
skillsScroll.Visible = false

local skillsGrid = Instance.new("UIGridLayout", skillsScroll)
skillsGrid.CellSize = UDim2.new(0, 150, 0, 180)
skillsGrid.CellPadding = UDim2.new(0, 15, 0, 15)
skillsGrid.HorizontalAlignment = Enum.HorizontalAlignment.Left

-- Right Column (Details)
local rightCol = Instance.new("Frame", bgFrame)
rightCol.Name = "RightColumn"
rightCol.Size = UDim2.new(0.4, -30, 1, -135)
rightCol.Position = UDim2.new(0.6, 10, 0, 125)
rightCol.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
Instance.new("UICorner", rightCol).CornerRadius = UDim.new(0, 16)
addStroke(rightCol, 5)

local rImage = Instance.new("ImageLabel", rightCol)
rImage.Name = "ItemImage"
rImage.Size = UDim2.new(0.8, 0, 0.4, 0)
rImage.Position = UDim2.new(0.1, 0, 0.05, 0)
rImage.BackgroundTransparency = 1
rImage.Image = ""
rImage.ScaleType = Enum.ScaleType.Fit

local rViewport = Instance.new("ViewportFrame", rightCol)
rViewport.Name = "ItemViewport"
rViewport.Size = UDim2.new(0.8, 0, 0.4, 0)
rViewport.Position = UDim2.new(0.1, 0, 0.05, 0)
rViewport.BackgroundColor3 = Color3.fromRGB(255, 230, 100)
rViewport.BackgroundTransparency = 0
Instance.new("UICorner", rViewport).CornerRadius = UDim.new(0, 12)
addStroke(rViewport, 4)
rViewport.Visible = false

local rName = Instance.new("TextLabel", rightCol)
rName.Name = "ItemName"
rName.Size = UDim2.new(1, 0, 0, 40)
rName.Position = UDim2.new(0, 0, 0.45, 0)
rName.BackgroundTransparency = 1
rName.Font = Enum.Font.FredokaOne
rName.Text = "아이템을 선택하세요"
rName.TextColor3 = Color3.fromRGB(255, 255, 255)
rName.TextSize = 26
addStroke(rName, 4)

local rDesc = Instance.new("TextLabel", rightCol)
rDesc.Name = "ItemDesc"
rDesc.Size = UDim2.new(0.9, 0, 0, 60)
rDesc.Position = UDim2.new(0.05, 0, 0.55, 0)
rDesc.BackgroundTransparency = 1
rDesc.Font = Enum.Font.FredokaOne
rDesc.Text = ""
rDesc.TextColor3 = Color3.fromRGB(255, 255, 255)
rDesc.TextSize = 16
rDesc.TextWrapped = true
rDesc.TextYAlignment = Enum.TextYAlignment.Top
addStroke(rDesc, 3)

local actionBtn = Instance.new("TextButton", rightCol)
actionBtn.Name = "ActionButton"
actionBtn.Size = UDim2.new(0.9, 0, 0, 55)
actionBtn.Position = UDim2.new(0.05, 0, 1, -65)
actionBtn.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
actionBtn.Font = Enum.Font.FredokaOne
actionBtn.Text = "선택 안됨"
actionBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
actionBtn.TextSize = 24
actionBtn.Visible = false
Instance.new("UICorner", actionBtn).CornerRadius = UDim.new(0, 12)
addStroke(actionBtn, 4)

-- Card Template
local cardTemplate = Instance.new("TextButton")
cardTemplate.Name = "CardTemplate"
cardTemplate.Size = UDim2.new(0, 150, 0, 180)
cardTemplate.Position = UDim2.new(0.5, -75, 0.5, -90)
cardTemplate.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
cardTemplate.Text = ""
cardTemplate.Visible = false
Instance.new("UICorner", cardTemplate).CornerRadius = UDim.new(0, 16)
addStroke(cardTemplate, 5)

local vpf = Instance.new("ViewportFrame", cardTemplate)
vpf.Name = "Viewport"
vpf.Size = UDim2.new(1, -20, 0, 90)
vpf.Position = UDim2.new(0, 10, 0, 10)
vpf.BackgroundColor3 = Color3.fromRGB(255, 230, 100)
vpf.BackgroundTransparency = 0
vpf.Visible = false
Instance.new("UICorner", vpf).CornerRadius = UDim.new(0, 12)
addStroke(vpf, 3)

local img = Instance.new("ImageLabel", cardTemplate)
img.Name = "Image"
img.Size = UDim2.new(1, -20, 0, 90)
img.Position = UDim2.new(0, 10, 0, 10)
img.BackgroundColor3 = Color3.fromRGB(255, 200, 100)
img.ScaleType = Enum.ScaleType.Fit
img.Visible = false
Instance.new("UICorner", img).CornerRadius = UDim.new(0, 12)
addStroke(img, 3)

local nameLabel = Instance.new("TextLabel", cardTemplate)
nameLabel.Name = "ItemName"
nameLabel.Size = UDim2.new(1, 0, 0, 30)
nameLabel.Position = UDim2.new(0, 0, 0, 110)
nameLabel.BackgroundTransparency = 1
nameLabel.Font = Enum.Font.FredokaOne
nameLabel.Text = "Name"
nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
nameLabel.TextSize = 16
addStroke(nameLabel, 3)

local statusLabel = Instance.new("TextLabel", cardTemplate)
statusLabel.Name = "Status"
statusLabel.Size = UDim2.new(1, 0, 0, 20)
statusLabel.Position = UDim2.new(0, 0, 0, 145)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.FredokaOne
statusLabel.Text = "Status"
statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
statusLabel.TextSize = 14
addStroke(statusLabel, 3)

cardTemplate.Parent = invGui

print("InventoryGui generated with New Casual Style in StarterGui!")
