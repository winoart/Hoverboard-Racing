local StarterGui = game:GetService("StarterGui")

-- 1. Create main ScreenGui
local screenGui = StarterGui:FindFirstChild("HoverboardShopHUD")
if screenGui then screenGui:Destroy() end

screenGui = Instance.new("ScreenGui")
screenGui.Name = "HoverboardShopHUD"
screenGui.Enabled = false
screenGui.ResetOnSpawn = false
screenGui.Parent = StarterGui

local bgFrame = Instance.new("Frame")
bgFrame.Name = "Background"
bgFrame.Size = UDim2.new(0, 800, 0, 520)
bgFrame.Position = UDim2.new(0.5, -400, 0.5, -260)
bgFrame.BackgroundColor3 = Color3.fromRGB(150, 240, 255)
bgFrame.BackgroundTransparency = 0.5
bgFrame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 24)
corner.Parent = bgFrame

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(0, 0, 0)
stroke.Thickness = 8
stroke.Parent = bgFrame

local titleFrame = Instance.new("Frame")
titleFrame.Name = "TitleFrame"
titleFrame.Size = UDim2.new(1, -60, 0, 60)
titleFrame.Position = UDim2.new(0, 30, 0, 20)
titleFrame.BackgroundColor3 = Color3.fromRGB(40, 180, 255)
titleFrame.BorderSizePixel = 0
titleFrame.ZIndex = 2
titleFrame.Parent = bgFrame

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0.5, 0)
titleCorner.Parent = titleFrame

local titleFrameStroke = Instance.new("UIStroke")
titleFrameStroke.Color = Color3.fromRGB(0, 0, 0)
titleFrameStroke.Thickness = 6
titleFrameStroke.Parent = titleFrame

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, 0, 1, 0)
title.BackgroundTransparency = 1
title.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
title.Text = "HOVERBOARD SHOP"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextSize = 36
title.ZIndex = 3
title.Parent = titleFrame

local titleTextStroke = Instance.new("UIStroke")
titleTextStroke.Color = Color3.fromRGB(0, 0, 0)
titleTextStroke.Thickness = 3
titleTextStroke.Parent = title

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
closeBtn.Parent = bgFrame

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(1, 0)
closeCorner.Parent = closeBtn

local closeStroke = Instance.new("UIStroke")
closeStroke.Color = Color3.fromRGB(0, 0, 0)
closeStroke.Thickness = 4
closeStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
closeStroke.Parent = closeBtn

local refreshTimerLabel = Instance.new("TextLabel")
refreshTimerLabel.Name = "RefreshTimerLabel"
refreshTimerLabel.Size = UDim2.new(1, 0, 0, 30)
refreshTimerLabel.Position = UDim2.new(0, 0, 0, 85)
refreshTimerLabel.BackgroundTransparency = 1
refreshTimerLabel.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
refreshTimerLabel.Text = "NEXT RESTOCK IN: --:--"
refreshTimerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
refreshTimerLabel.TextSize = 20
refreshTimerLabel.Parent = bgFrame

local refreshStroke = Instance.new("UIStroke")
refreshStroke.Color = Color3.fromRGB(0, 0, 0)
refreshStroke.Thickness = 3
refreshStroke.Parent = refreshTimerLabel

local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Name = "ScrollFrame"
scrollFrame.Size = UDim2.new(1, -40, 0, 335)
scrollFrame.Position = UDim2.new(0, 20, 0, 115)
scrollFrame.BackgroundTransparency = 1
scrollFrame.ScrollBarThickness = 8
scrollFrame.Parent = bgFrame

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 5)
padding.PaddingBottom = UDim.new(0, 5)
padding.PaddingLeft = UDim.new(0, 5)
padding.PaddingRight = UDim.new(0, 5)
padding.Parent = scrollFrame

local gridLayout = Instance.new("UIGridLayout")
gridLayout.Name = "GridLayout"
gridLayout.CellSize = UDim2.new(0, 240, 0, 320)
gridLayout.CellPadding = UDim2.new(0, 15, 0, 15)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = scrollFrame

-- Card Template
local cardTemplate = Instance.new("Frame")
cardTemplate.Name = "CardTemplate"
cardTemplate.BackgroundColor3 = Color3.fromRGB(40, 45, 55)
cardTemplate.Visible = true
cardTemplate.Parent = scrollFrame

local cardCorner = Instance.new("UICorner")
cardCorner.CornerRadius = UDim.new(0, 16)
cardCorner.Parent = cardTemplate

local cardStroke = Instance.new("UIStroke")
cardStroke.Color = Color3.fromRGB(0, 0, 0)
cardStroke.Thickness = 4
cardStroke.Parent = cardTemplate

-- UIGradient Stripes
local patternBg = Instance.new("Frame", cardTemplate)
patternBg.Size = UDim2.new(1, 0, 1, 0)
patternBg.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
patternBg.BorderSizePixel = 0
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

local img = Instance.new("ImageLabel")
img.Name = "ItemImage"
img.Size = UDim2.new(1, -20, 0, 160)
img.Position = UDim2.new(0, 10, 0, 10)
img.BackgroundTransparency = 1
img.Image = ""
img.ScaleType = Enum.ScaleType.Fit
img.ZIndex = 2
img.Parent = cardTemplate

local nameLabel = Instance.new("TextLabel")
nameLabel.Name = "ItemName"
nameLabel.Size = UDim2.new(1, 0, 0, 30)
nameLabel.Position = UDim2.new(0, 0, 0, 180)
nameLabel.BackgroundTransparency = 1
nameLabel.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
nameLabel.Text = "Name"
nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
nameLabel.TextSize = 22
nameLabel.ZIndex = 2
nameLabel.Parent = cardTemplate

local nameStroke = Instance.new("UIStroke")
nameStroke.Color = Color3.fromRGB(0, 0, 0)
nameStroke.Thickness = 3
nameStroke.Parent = nameLabel

local priceLabel = Instance.new("TextLabel")
priceLabel.Name = "PriceLabel"
priceLabel.Size = UDim2.new(1, 0, 0, 30)
priceLabel.Position = UDim2.new(0, 0, 0, 215)
priceLabel.BackgroundTransparency = 1
priceLabel.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
priceLabel.Text = "0 G"
priceLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
priceLabel.TextSize = 20
priceLabel.ZIndex = 2
priceLabel.Parent = cardTemplate

local priceStroke = Instance.new("UIStroke")
priceStroke.Color = Color3.fromRGB(0, 0, 0)
priceStroke.Thickness = 3
priceStroke.Parent = priceLabel

local buyBtn = Instance.new("TextButton")
buyBtn.Name = "BuyButton"
buyBtn.Size = UDim2.new(1, -40, 0, 46)
buyBtn.Position = UDim2.new(0, 20, 1, -55)
buyBtn.BackgroundColor3 = Color3.fromRGB(100, 220, 110)
buyBtn.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
buyBtn.TextSize = 22
buyBtn.Text = "BUY"
buyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
buyBtn.ZIndex = 3
buyBtn.Parent = cardTemplate

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 12)
btnCorner.Parent = buyBtn

local btnStroke = Instance.new("UIStroke")
btnStroke.Color = Color3.fromRGB(0, 0, 0)
btnStroke.Thickness = 4
btnStroke.Parent = buyBtn

local btnTextStroke = Instance.new("UIStroke")
btnTextStroke.Color = Color3.fromRGB(0, 0, 0)
btnTextStroke.Thickness = 2
btnTextStroke.Parent = buyBtn

-- 🏷️ Bottom Rarity Legend Indicator
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
	{ name = "Common", color = Color3.fromRGB(255, 255, 0) },
	{ name = "Uncommon", color = Color3.fromRGB(0, 120, 255) },
	{ name = "Rare", color = Color3.fromRGB(128, 0, 128) },
	{ name = "Super Rare", color = Color3.fromRGB(30, 30, 30) },
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

print("HoverboardShopHUD generated in StarterGui!")
