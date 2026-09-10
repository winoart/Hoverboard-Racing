local StarterGui = game:GetService("StarterGui")

local invGui = Instance.new("ScreenGui")
invGui.Name = "InventoryGui"
invGui.ResetOnSpawn = false
invGui.Enabled = false
invGui.Parent = StarterGui

local function addStroke(parent, thickness, color)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color or Color3.fromRGB(0, 0, 0)
    stroke.Thickness = thickness or 4 -- 출석체크처럼 두껍게 (4)
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = parent
    return stroke
end

local function addTextStroke(parent, thickness, color)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color or Color3.fromRGB(0, 0, 0)
    stroke.Thickness = thickness or 3
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
    stroke.Parent = parent
    return stroke
end

local function addStripePattern(parent, cornerRadius)
	local patternBg = Instance.new("Frame", parent)
	patternBg.Name = "PatternBg"
	patternBg.Size = UDim2.new(1, 0, 1, 0)
	patternBg.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	patternBg.BorderSizePixel = 0
	patternBg.ZIndex = 1
	if cornerRadius then
		Instance.new("UICorner", patternBg).CornerRadius = cornerRadius
	end

	local grad = Instance.new("UIGradient", patternBg)
	grad.Rotation = 45

	local keypoints = {}
	table.insert(keypoints, NumberSequenceKeypoint.new(0, 0.85))
	for i = 1, 9 do
		local pos = i / 10
		if i % 2 == 1 then
			table.insert(keypoints, NumberSequenceKeypoint.new(pos, 0.85))
			table.insert(keypoints, NumberSequenceKeypoint.new(pos + 0.001, 1))
		else
			table.insert(keypoints, NumberSequenceKeypoint.new(pos, 1))
			table.insert(keypoints, NumberSequenceKeypoint.new(pos + 0.001, 0.85))
		end
	end
	table.insert(keypoints, NumberSequenceKeypoint.new(1, 1))
	grad.Transparency = NumberSequence.new(keypoints)
	
	return patternBg
end

-- MAIN PANEL (출석체크와 완벽히 동일한 Cyan, 불투명도 0)
local bgFrame = Instance.new("Frame")
bgFrame.Name = "Background"
bgFrame.Size = UDim2.new(0, 940, 0, 580)
bgFrame.Position = UDim2.new(0.5, -470, 0.5, -290)
bgFrame.BackgroundColor3 = Color3.fromRGB(150, 240, 255)
bgFrame.BackgroundTransparency = 0.5
bgFrame.BorderSizePixel = 0
bgFrame.Parent = invGui
Instance.new("UICorner", bgFrame).CornerRadius = UDim.new(0, 24)
addStroke(bgFrame, 6)

-- TITLE HEADER (출석체크의 쨍한 블루)
local titleFrame = Instance.new("Frame")
titleFrame.Name = "TitleFrame"
titleFrame.Size = UDim2.new(1, -60, 0, 60)
titleFrame.Position = UDim2.new(0, 30, 0, 20)
titleFrame.BackgroundColor3 = Color3.fromRGB(40, 180, 255)
titleFrame.BorderSizePixel = 0
titleFrame.Parent = bgFrame
Instance.new("UICorner", titleFrame).CornerRadius = UDim.new(0.5, 0)
addStroke(titleFrame, 5)

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(1, 0, 1, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Font = Enum.Font.FredokaOne
titleLabel.Text = "INVENTORY"
titleLabel.TextColor3 = Color3.fromRGB(30, 30, 30)
titleLabel.TextSize = 36
titleLabel.Parent = titleFrame

-- CLOSE BUTTON
local closeBtn = Instance.new("TextButton")
closeBtn.Name = "CloseButton"
closeBtn.Size = UDim2.new(0, 46, 0, 46)
closeBtn.Position = UDim2.new(1, -23, 0, -23)
closeBtn.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
closeBtn.Font = Enum.Font.FredokaOne
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.TextSize = 28
closeBtn.Parent = bgFrame
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(1, 0)
addStroke(closeBtn, 4)
addTextStroke(closeBtn, 3)

-- TABS
local tabsFrame = Instance.new("Frame")
tabsFrame.Name = "Tabs"
tabsFrame.Size = UDim2.new(0.55, -45, 0, 50)
tabsFrame.Position = UDim2.new(0, 30, 0, 100)
tabsFrame.BackgroundTransparency = 1
tabsFrame.Parent = bgFrame

local tabLayout = Instance.new("UIListLayout", tabsFrame)
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 8)

local boardsTabBtn = Instance.new("TextButton", tabsFrame)
boardsTabBtn.Name = "BoardsTab"
boardsTabBtn.Size = UDim2.new(0.5, -4, 1, 0)
boardsTabBtn.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
boardsTabBtn.FontFace = Font.fromName("Montserrat", Enum.FontWeight.ExtraBold, Enum.FontStyle.Normal)
boardsTabBtn.Text = "호버보드"
boardsTabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
boardsTabBtn.TextSize = 26
Instance.new("UICorner", boardsTabBtn).CornerRadius = UDim.new(0, 12)
addStroke(boardsTabBtn, 4)
addTextStroke(boardsTabBtn, 3, Color3.fromRGB(0, 0, 0))

local skillsTabBtn = Instance.new("TextButton", tabsFrame)
skillsTabBtn.Name = "SkillsTab"
skillsTabBtn.Size = UDim2.new(0.5, -4, 1, 0)
skillsTabBtn.BackgroundColor3 = Color3.fromRGB(210, 220, 230)
skillsTabBtn.FontFace = Font.fromName("Montserrat", Enum.FontWeight.ExtraBold, Enum.FontStyle.Normal)
skillsTabBtn.Text = "스킬"
skillsTabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
skillsTabBtn.TextSize = 26
Instance.new("UICorner", skillsTabBtn).CornerRadius = UDim.new(0, 12)
addStroke(skillsTabBtn, 4)
addTextStroke(skillsTabBtn, 3, Color3.fromRGB(0, 0, 0))

-- LEFT COLUMN
local leftCol = Instance.new("Frame", bgFrame)
leftCol.Name = "LeftColumn"
leftCol.Size = UDim2.new(0.55, -40, 1, -180)
leftCol.Position = UDim2.new(0, 30, 0, 160) -- 탭과 적당한 간격 확보
leftCol.BackgroundTransparency = 1
leftCol.BorderSizePixel = 0

local boardsScroll = Instance.new("ScrollingFrame", leftCol)
boardsScroll.Name = "BoardsScroll"
boardsScroll.Size = UDim2.new(1, 0, 1, 0)
boardsScroll.BackgroundTransparency = 1
boardsScroll.ScrollBarThickness = 10
boardsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
boardsScroll.Visible = true

local boardsPadding = Instance.new("UIPadding", boardsScroll)
boardsPadding.PaddingTop = UDim.new(0, 8)
boardsPadding.PaddingBottom = UDim.new(0, 15)
boardsPadding.PaddingLeft = UDim.new(0, 8)
boardsPadding.PaddingRight = UDim.new(0, 15)

local boardsGrid = Instance.new("UIGridLayout", boardsScroll)
boardsGrid.CellSize = UDim2.new(0, 130, 0, 150)
boardsGrid.CellPadding = UDim2.new(0, 15, 0, 15)
boardsGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center

local skillsScroll = Instance.new("ScrollingFrame", leftCol)
skillsScroll.Name = "SkillsScroll"
skillsScroll.Size = UDim2.new(1, 0, 1, 0)
skillsScroll.BackgroundTransparency = 1
skillsScroll.ScrollBarThickness = 10
skillsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
skillsScroll.Visible = false

local skillsPadding = Instance.new("UIPadding", skillsScroll)
skillsPadding.PaddingTop = UDim.new(0, 8)
skillsPadding.PaddingBottom = UDim.new(0, 15)
skillsPadding.PaddingLeft = UDim.new(0, 8)
skillsPadding.PaddingRight = UDim.new(0, 15)

local skillsGrid = Instance.new("UIGridLayout", skillsScroll)
skillsGrid.CellSize = UDim2.new(0, 130, 0, 150)
skillsGrid.CellPadding = UDim2.new(0, 15, 0, 15)
skillsGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center

-- RIGHT COLUMN (디테일 뷰)
local rightCol = Instance.new("Frame", bgFrame)
rightCol.Name = "RightColumn"
rightCol.Size = UDim2.new(0.45, -20, 1, -120)
rightCol.Position = UDim2.new(0.55, 0, 0, 100)
rightCol.BackgroundColor3 = Color3.fromRGB(150, 240, 255) -- 메인 배경과 동일하게
Instance.new("UICorner", rightCol).CornerRadius = UDim.new(0, 16)
addStroke(rightCol, 5)

local thumbZone = Instance.new("Frame", rightCol)
thumbZone.Name = "ThumbZone"
thumbZone.Size = UDim2.new(1, -30, 0, 180)
thumbZone.Position = UDim2.new(0, 15, 0, 15)
thumbZone.BackgroundColor3 = Color3.fromRGB(150, 240, 255)
Instance.new("UICorner", thumbZone).CornerRadius = UDim.new(0, 12)
addStroke(thumbZone, 4)

addStripePattern(thumbZone, UDim.new(0, 12))

local rImage = Instance.new("ImageLabel", thumbZone)
rImage.Name = "ItemImage"
rImage.Size = UDim2.new(0.9, 0, 0.9, 0)
rImage.Position = UDim2.new(0.05, 0, 0.05, 0)
rImage.BackgroundTransparency = 1
rImage.Image = ""
rImage.ScaleType = Enum.ScaleType.Fit
rImage.ZIndex = 2

local rViewport = Instance.new("ViewportFrame", thumbZone)
rViewport.Name = "ItemViewport"
rViewport.Size = UDim2.new(1, 0, 1, 0)
rViewport.BackgroundTransparency = 1
rViewport.Visible = false

local rName = Instance.new("TextLabel", rightCol)
rName.Name = "ItemName"
rName.Size = UDim2.new(1, -30, 0, 40)
rName.Position = UDim2.new(0, 15, 0, 210)
rName.BackgroundTransparency = 1
rName.FontFace = Font.fromName("Montserrat", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
rName.Text = "아이템을 선택하세요"
-- 우측 아이템 이름: 출석체크 'DAY 1' 텍스트처럼 골드 + 블랙 스트로크 적용
rName.TextColor3 = Color3.fromRGB(255, 200, 50)
rName.TextSize = 22
addTextStroke(rName, 3, Color3.fromRGB(0, 0, 0))

local rDesc = Instance.new("TextLabel", rightCol)
rDesc.Name = "ItemDesc"
rDesc.Size = UDim2.new(1, -40, 0, 80)
rDesc.Position = UDim2.new(0, 20, 0, 260)
rDesc.BackgroundTransparency = 1
rDesc.FontFace = Font.fromName("Montserrat", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
rDesc.Text = "설명 텍스트가 여기에 나타납니다. 왼쪽 목록에서 아이템을 클릭해 주세요."
rDesc.TextColor3 = Color3.fromRGB(255, 255, 255)
rDesc.TextSize = 22
rDesc.TextWrapped = true
rDesc.TextYAlignment = Enum.TextYAlignment.Top
addTextStroke(rDesc, 3, Color3.fromRGB(0, 0, 0))

local actionBtn = Instance.new("TextButton", rightCol)
actionBtn.Name = "ActionButton"
actionBtn.Size = UDim2.new(1, -30, 0, 60)
actionBtn.Position = UDim2.new(0, 15, 1, -75)
actionBtn.BackgroundColor3 = Color3.fromRGB(100, 220, 110)
actionBtn.FontFace = Font.fromName("Montserrat", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
actionBtn.Text = "선택 안됨"
actionBtn.TextColor3 = Color3.fromRGB(30, 30, 30)
actionBtn.TextSize = 22
actionBtn.Visible = false
Instance.new("UICorner", actionBtn).CornerRadius = UDim.new(0, 12)
addStroke(actionBtn, 5)

-- CARD TEMPLATE (출석체크 'DAY' 박스와 100% 동일하게)
local cardTemplate = Instance.new("TextButton")
cardTemplate.Name = "CardTemplate"
cardTemplate.Size = UDim2.new(0, 130, 0, 150)
cardTemplate.BackgroundColor3 = Color3.fromRGB(255, 255, 255) -- White background for the card
cardTemplate.Text = ""
cardTemplate.Visible = false
Instance.new("UICorner", cardTemplate).CornerRadius = UDim.new(0, 16)
addStroke(cardTemplate, 4)

local imgBg = Instance.new("Frame", cardTemplate)
imgBg.Name = "ImageBackground"
imgBg.Size = UDim2.new(1, -12, 1, -45)
imgBg.Position = UDim2.new(0, 6, 0, 6)
imgBg.BackgroundColor3 = Color3.fromRGB(255, 200, 50) -- Yellow background for image
imgBg.BorderSizePixel = 0
imgBg.ZIndex = 1
Instance.new("UICorner", imgBg).CornerRadius = UDim.new(0, 12)
local imgBgStroke = Instance.new("UIStroke", imgBg)
imgBgStroke.Color = Color3.fromRGB(0, 0, 0)
imgBgStroke.Thickness = 2

local vpf = Instance.new("ViewportFrame", cardTemplate)
vpf.Name = "Viewport"
vpf.Size = UDim2.new(1, -20, 1, -45)
vpf.Position = UDim2.new(0, 10, 0, 10)
vpf.BackgroundTransparency = 1
vpf.Visible = false
vpf.ZIndex = 2

local img = Instance.new("ImageLabel", cardTemplate)
img.Name = "Image"
img.Size = UDim2.new(1, -20, 1, -45)
img.Position = UDim2.new(0, 10, 0, 10)
img.BackgroundTransparency = 1
img.ScaleType = Enum.ScaleType.Fit
img.Visible = false
img.ZIndex = 2

local nameLabel = Instance.new("TextLabel", cardTemplate)
nameLabel.Name = "ItemName"
nameLabel.Size = UDim2.new(1, 0, 0, 30)
nameLabel.Position = UDim2.new(0, 0, 1, -35)
nameLabel.BackgroundTransparency = 1
nameLabel.FontFace = Font.fromName("Montserrat", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
nameLabel.Text = "Name"
nameLabel.TextColor3 = Color3.fromRGB(30, 30, 30) -- Dark gray on white background
nameLabel.TextSize = 22
-- No stroke for cleaner look on white background

local statusLabel = Instance.new("TextLabel", cardTemplate)
statusLabel.Name = "Status"
statusLabel.Size = UDim2.new(1, 0, 0, 20)
statusLabel.Position = UDim2.new(0, 0, 0, 5)
statusLabel.BackgroundTransparency = 1
statusLabel.FontFace = Font.fromName("Montserrat", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
statusLabel.Text = "Status"
statusLabel.TextColor3 = Color3.fromRGB(255, 200, 50)
statusLabel.TextSize = 16
statusLabel.Visible = false
addTextStroke(statusLabel, 2, Color3.fromRGB(0, 0, 0))

cardTemplate.Parent = invGui
print("InventoryGui Generated - 100% Daily Rewards Style Clone")
