local StarterGui = game:GetService("StarterGui")

-- 1. Create main ScreenGui
local screenGui = StarterGui:FindFirstChild("RobuxShopUI")
if screenGui then screenGui:Destroy() end

screenGui = Instance.new("ScreenGui")
screenGui.Name = "RobuxShopUI"
screenGui.Enabled = false
screenGui.ResetOnSpawn = false
screenGui.Parent = StarterGui

local montserratExtraBold = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.ExtraBold)

-- MainFrame (Thick Cartoon Glass Style)
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 720, 0, 500)
mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(150, 240, 255)
mainFrame.BackgroundTransparency = 0.5 -- 유리 질감
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 24)
mainCorner.Parent = mainFrame

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(0, 0, 0)
mainStroke.Thickness = 8
mainStroke.Parent = mainFrame

-- TitleFrame (Pill Shape)
local titleFrame = Instance.new("Frame")
titleFrame.Name = "TitleFrame"
titleFrame.Size = UDim2.new(1, -60, 0, 60)
titleFrame.Position = UDim2.new(0, 30, 0, 20)
titleFrame.BackgroundColor3 = Color3.fromRGB(40, 180, 255)
titleFrame.BorderSizePixel = 0
titleFrame.ZIndex = 2
titleFrame.Parent = mainFrame

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0.5, 0)
titleCorner.Parent = titleFrame

local titleFrameStroke = Instance.new("UIStroke")
titleFrameStroke.Color = Color3.fromRGB(0, 0, 0)
titleFrameStroke.Thickness = 6
titleFrameStroke.Parent = titleFrame

-- Title Text
local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, 0, 1, 0)
title.BackgroundTransparency = 1
title.FontFace = montserratExtraBold
title.Text = "Robux Shop"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextSize = 36
title.ZIndex = 3
title.Parent = titleFrame

local titleTextStroke = Instance.new("UIStroke")
titleTextStroke.Color = Color3.fromRGB(0, 0, 0)
titleTextStroke.Thickness = 3
titleTextStroke.Parent = title

-- Close Button
local closeBtn = Instance.new("TextButton")
closeBtn.Name = "CloseButton"
closeBtn.Size = UDim2.new(0, 44, 0, 44)
closeBtn.Position = UDim2.new(1, -22, 0, -22)
closeBtn.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
closeBtn.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.TextSize = 28
closeBtn.ZIndex = 5
closeBtn.Parent = mainFrame

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(1, 0)
closeCorner.Parent = closeBtn

local closeStroke = Instance.new("UIStroke")
closeStroke.Color = Color3.fromRGB(0, 0, 0)
closeStroke.Thickness = 4
closeStroke.Parent = closeBtn

-- Tabs Frame
local tabs = Instance.new("Frame")
tabs.Name = "Tabs"
tabs.Size = UDim2.new(1, -60, 0, 50)
tabs.Position = UDim2.new(0, 30, 0, 95)
tabs.BackgroundTransparency = 1
tabs.Parent = mainFrame

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.Padding = UDim.new(0, 15)
tabLayout.Parent = tabs

local function createTabButton(name, text, order, selected)
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.Size = UDim2.new(0, 140, 1, 0)
	-- 선택된 탭은 Gold, 아니면 Silver 사용
	btn.BackgroundColor3 = selected and Color3.fromRGB(255, 200, 50) or Color3.fromRGB(210, 220, 230)
	btn.FontFace = montserratExtraBold
	btn.Text = text
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.TextSize = 24
	btn.LayoutOrder = order
	btn.Parent = tabs
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = btn
	
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Thickness = 4
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = btn
	
	local textStroke = Instance.new("UIStroke")
	textStroke.Color = Color3.fromRGB(0, 0, 0)
	textStroke.Thickness = 3
	textStroke.Parent = btn
	return btn
end

createTabButton("EventButton", "EVENT", 1, true)
createTabButton("PassButton", "PASS", 2, false)
createTabButton("GoldButton", "GOLD", 3, false)

-- ContentArea
local contentArea = Instance.new("Frame")
contentArea.Name = "ContentArea"
contentArea.Size = UDim2.new(1, -60, 1, -165)
contentArea.Position = UDim2.new(0, 30, 0, 155)
contentArea.BackgroundTransparency = 1
contentArea.Parent = mainFrame

local function createScroll(name, visible, cellSize)
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = name
	scroll.Size = UDim2.new(1, 0, 1, 0)
	scroll.BackgroundTransparency = 1
	scroll.ScrollBarThickness = 8
	scroll.Visible = visible
	scroll.Parent = contentArea
	
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.Parent = scroll
	
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = cellSize
	grid.CellPadding = UDim2.new(0, 20, 0, 20)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = scroll
	return scroll
end

-- EventScroll 1x1 (approx 5:3 ratio for banner)
createScroll("EventScroll", true, UDim2.new(1, -20, 0, 250)) 
createScroll("PassScroll", false, UDim2.new(0.5, -20, 0, 150)) 
createScroll("GoldScroll", false, UDim2.new(0.5, -20, 0, 150)) 

-- Templates Folder
local templates = Instance.new("Folder")
templates.Name = "Templates"
templates.Parent = screenGui

-- Stripes Pattern Generator Function
local function addStripesPattern(parentFrame)
	local patternBg = Instance.new("Frame", parentFrame)
	patternBg.Name = "PatternBg"
	patternBg.Size = UDim2.new(1, 0, 1, 0)
	patternBg.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	patternBg.BorderSizePixel = 0
	patternBg.ZIndex = 2 -- 배경 이미지 위로 올라오도록 ZIndex 2로 설정
	Instance.new("UICorner", patternBg).CornerRadius = UDim.new(0, 16)
	
	local grad = Instance.new("UIGradient", patternBg)
	grad.Rotation = 45
	local keypoints = {}
	table.insert(keypoints, NumberSequenceKeypoint.new(0, 0.85))
	for i = 1, 9 do
		local p = i / 10
		if i % 2 == 1 then
			table.insert(keypoints, NumberSequenceKeypoint.new(p, 0.85))
			table.insert(keypoints, NumberSequenceKeypoint.new(p + 0.001, 1))
		else
			table.insert(keypoints, NumberSequenceKeypoint.new(p, 1))
			table.insert(keypoints, NumberSequenceKeypoint.new(p + 0.001, 0.85))
		end
	end
	table.insert(keypoints, NumberSequenceKeypoint.new(1, 1))
	grad.Transparency = NumberSequence.new(keypoints)
end

-- 1. EventTemplate (1x1 banner style)
local eventTemplate = Instance.new("Frame")
eventTemplate.Name = "EventTemplate"
eventTemplate.BackgroundColor3 = Color3.fromRGB(40, 45, 55)
eventTemplate.Visible = false
eventTemplate.Parent = templates

Instance.new("UICorner", eventTemplate).CornerRadius = UDim.new(0, 16)
local eStroke = Instance.new("UIStroke", eventTemplate)
eStroke.Color = Color3.fromRGB(0, 0, 0)
eStroke.Thickness = 6

addStripesPattern(eventTemplate)

local bannerImage = Instance.new("ImageLabel")
bannerImage.Name = "BannerImage"
bannerImage.Size = UDim2.new(1, 0, 1, 0)
bannerImage.BackgroundTransparency = 1
bannerImage.ScaleType = Enum.ScaleType.Crop
bannerImage.ZIndex = 2
bannerImage.Parent = eventTemplate
Instance.new("UICorner", bannerImage).CornerRadius = UDim.new(0, 16)

local eventTitle = Instance.new("TextLabel")
eventTitle.Name = "Title"
eventTitle.Size = UDim2.new(1, -40, 0, 50)
eventTitle.Position = UDim2.new(0, 20, 0, 20)
eventTitle.BackgroundTransparency = 1
eventTitle.FontFace = montserratExtraBold
eventTitle.Text = "Event Title"
eventTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
eventTitle.TextSize = 48
eventTitle.TextXAlignment = Enum.TextXAlignment.Left
eventTitle.ZIndex = 3
eventTitle.Parent = eventTemplate
local tStroke = Instance.new("UIStroke", eventTitle)
tStroke.Thickness = 4

local hookText = Instance.new("TextLabel")
hookText.Name = "HookText"
hookText.Size = UDim2.new(1, -40, 0, 30)
hookText.Position = UDim2.new(0, 20, 0, 75)
hookText.BackgroundTransparency = 1
hookText.FontFace = montserratExtraBold
hookText.Text = "Hook phrase here!"
hookText.TextColor3 = Color3.fromRGB(255, 200, 50) -- Gold for emphasis
hookText.TextSize = 24
hookText.TextXAlignment = Enum.TextXAlignment.Left
hookText.ZIndex = 3
hookText.Parent = eventTemplate
Instance.new("UIStroke", hookText).Thickness = 3

local timerLabel = Instance.new("TextLabel")
timerLabel.Name = "TimerLabel"
timerLabel.Size = UDim2.new(0, 250, 0, 40)
timerLabel.Position = UDim2.new(1, -270, 0, 5)
timerLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
timerLabel.BackgroundTransparency = 1
timerLabel.FontFace = montserratExtraBold
timerLabel.RichText = true
timerLabel.Text = "24<font color='#FFFFFF'>h</font> 00<font color='#FFFFFF'>m</font> 00<font color='#FFFFFF'>s</font>"
timerLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
timerLabel.TextSize = 28
timerLabel.ZIndex = 3
timerLabel.Parent = eventTemplate
Instance.new("UICorner", timerLabel).CornerRadius = UDim.new(0, 8)
Instance.new("UIStroke", timerLabel).Thickness = 2

-- Rewards Container (A, B, C slots)
local rewardsContainer = Instance.new("Frame")
rewardsContainer.Name = "RewardsContainer"
rewardsContainer.Size = UDim2.new(0, 300, 0, 90)
rewardsContainer.Position = UDim2.new(1, -320, 1, -155)
rewardsContainer.BackgroundTransparency = 1
rewardsContainer.ZIndex = 3
rewardsContainer.Parent = eventTemplate

local rLayout = Instance.new("UIListLayout")
rLayout.FillDirection = Enum.FillDirection.Horizontal
rLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
rLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
rLayout.Padding = UDim.new(0, 15)
rLayout.Parent = rewardsContainer

local function createSlot(name, parent)
	local slot = Instance.new("Frame")
	slot.Name = name
	slot.Size = UDim2.new(0, 90, 0, 90)
	slot.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	slot.BackgroundTransparency = 0.6
	slot.Visible = false -- 기본적으로 숨김 (데이터가 있을 때만 표시)
	slot.ZIndex = 4
	slot.Parent = parent
	Instance.new("UICorner", slot).CornerRadius = UDim.new(0, 12)
	local sStroke = Instance.new("UIStroke", slot)
	sStroke.Color = Color3.fromRGB(255, 255, 255)
	sStroke.Transparency = 0.5
	sStroke.Thickness = 2
	
	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.Size = UDim2.new(1, -20, 1, -40)
	icon.Position = UDim2.new(0, 10, 0, 10)
	icon.BackgroundTransparency = 1
	icon.ScaleType = Enum.ScaleType.Fit
	icon.ZIndex = 5
	icon.Parent = slot
	
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(1, -8, 0, 30)
	label.Position = UDim2.new(0, 4, 1, -34)
	label.BackgroundTransparency = 1
	label.FontFace = montserratExtraBold
	label.Text = "Reward"
	label.TextColor3 = Color3.fromRGB(255, 245, 180) -- 살짝 은은한 골드빛으로 눈에 띄게
	label.TextScaled = true
	label.TextWrapped = true
	label.ZIndex = 5
	label.Parent = slot
	
	local lStroke = Instance.new("UIStroke", label)
	lStroke.Color = Color3.fromRGB(0, 0, 0)
	lStroke.Thickness = 2.5
end

createSlot("BoardReward", rewardsContainer)
createSlot("SkillReward", rewardsContainer)
createSlot("GoldReward", rewardsContainer)

local ePriceBtn = Instance.new("TextButton")
ePriceBtn.Name = "PriceButton"
ePriceBtn.Size = UDim2.new(0, 180, 0, 40)
ePriceBtn.Position = UDim2.new(1, -210, 1, -55)
ePriceBtn.BackgroundColor3 = Color3.fromRGB(100, 220, 110) -- 밝은 녹색
ePriceBtn.Text = ""
ePriceBtn.ZIndex = 4
ePriceBtn.Parent = eventTemplate
Instance.new("UICorner", ePriceBtn).CornerRadius = UDim.new(0, 12)
Instance.new("UIStroke", ePriceBtn).Thickness = 6

local ePriceText = Instance.new("TextLabel")
ePriceText.Name = "TextLabel"
ePriceText.Size = UDim2.new(1, 0, 1, 0)
ePriceText.BackgroundTransparency = 1
ePriceText.FontFace = montserratExtraBold
ePriceText.Text = "R$ 500"
ePriceText.TextColor3 = Color3.fromRGB(255, 255, 255)
ePriceText.TextSize = 28
ePriceText.ZIndex = 5
ePriceText.Parent = ePriceBtn
Instance.new("UIStroke", ePriceText).Thickness = 3

-- 2. ItemTemplate (2x1 grid style for Pass/Gold)
local itemTemplate = Instance.new("Frame")
itemTemplate.Name = "ItemTemplate"
itemTemplate.BackgroundColor3 = Color3.fromRGB(210, 220, 230) -- Silver background
itemTemplate.Visible = false
itemTemplate.Parent = templates

Instance.new("UICorner", itemTemplate).CornerRadius = UDim.new(0, 16)
Instance.new("UIStroke", itemTemplate).Thickness = 6

-- Background Image (Optional)
local itemBgImage = Instance.new("ImageLabel")
itemBgImage.Name = "BackgroundImage"
itemBgImage.Size = UDim2.new(1, 0, 1, 0)
itemBgImage.BackgroundTransparency = 1
itemBgImage.ScaleType = Enum.ScaleType.Crop
itemBgImage.ZIndex = 1
itemBgImage.Visible = false -- 스크립트에서 이미지가 있으면 true로 바꿈
itemBgImage.Parent = itemTemplate
Instance.new("UICorner", itemBgImage).CornerRadius = UDim.new(0, 16)

addStripesPattern(itemTemplate)

local itemIcon = Instance.new("ImageLabel")
itemIcon.Name = "ItemIcon"
itemIcon.Size = UDim2.new(0, 90, 0, 90)
itemIcon.Position = UDim2.new(0, 20, 0.5, -45)
itemIcon.BackgroundTransparency = 1
itemIcon.ScaleType = Enum.ScaleType.Fit
itemIcon.ZIndex = 3
itemIcon.Parent = itemTemplate

local itemName = Instance.new("TextLabel")
itemName.Name = "ItemName"
itemName.Size = UDim2.new(1, -130, 0, 50)
itemName.Position = UDim2.new(0, 120, 0, 20)
itemName.BackgroundTransparency = 1
itemName.FontFace = montserratExtraBold
itemName.Text = "Item Name"
itemName.TextColor3 = Color3.fromRGB(30, 30, 30) -- 다크 그레이
itemName.TextSize = 24
itemName.TextWrapped = true
itemName.TextXAlignment = Enum.TextXAlignment.Left
itemName.ZIndex = 3
itemName.Parent = itemTemplate
-- 본문 다크 그레이는 외곽선을 얇게 주거나 안 줌. (여기선 얇게 흰색)
local iNameStroke = Instance.new("UIStroke", itemName)
iNameStroke.Color = Color3.fromRGB(255, 255, 255)
iNameStroke.Thickness = 2

local iPriceBtn = Instance.new("TextButton")
iPriceBtn.Name = "PriceButton"
iPriceBtn.Size = UDim2.new(1, -140, 0, 45)
iPriceBtn.Position = UDim2.new(0, 120, 1, -60)
iPriceBtn.BackgroundColor3 = Color3.fromRGB(100, 220, 110)
iPriceBtn.Text = ""
iPriceBtn.ZIndex = 4
iPriceBtn.Parent = itemTemplate
Instance.new("UICorner", iPriceBtn).CornerRadius = UDim.new(0, 12)
Instance.new("UIStroke", iPriceBtn).Thickness = 6

local iPriceText = Instance.new("TextLabel")
iPriceText.Name = "TextLabel"
iPriceText.Size = UDim2.new(1, 0, 1, 0)
iPriceText.BackgroundTransparency = 1
iPriceText.FontFace = montserratExtraBold
iPriceText.Text = "R$ 100"
iPriceText.TextColor3 = Color3.fromRGB(255, 255, 255)
iPriceText.TextSize = 26
iPriceText.ZIndex = 5
iPriceText.Parent = iPriceBtn
Instance.new("UIStroke", iPriceText).Thickness = 3

print("Thick Cartoon Style RobuxShopUI generated in StarterGui!")
