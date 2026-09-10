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
bgFrame.Size = UDim2.new(0, 800, 0, 500)
bgFrame.Position = UDim2.new(0.5, -400, 0.5, -250)
bgFrame.BackgroundColor3 = Color3.fromRGB(30, 35, 45)
bgFrame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 16)
corner.Parent = bgFrame

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(255, 215, 0)
stroke.Thickness = 3
stroke.Parent = bgFrame

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, 0, 0, 60)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBlack
title.Text = "호버보드 상점"
title.TextColor3 = Color3.fromRGB(255, 215, 0)
title.TextSize = 32
title.Parent = bgFrame

local closeBtn = Instance.new("TextButton")
closeBtn.Name = "CloseButton"
closeBtn.Size = UDim2.new(0, 40, 0, 40)
closeBtn.Position = UDim2.new(1, -50, 0, 10)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.TextSize = 24
closeBtn.Parent = bgFrame

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(1, 0)
closeCorner.Parent = closeBtn

local refreshTimerLabel = Instance.new("TextLabel")
refreshTimerLabel.Name = "RefreshTimerLabel"
refreshTimerLabel.Size = UDim2.new(1, 0, 0, 30)
refreshTimerLabel.Position = UDim2.new(0, 0, 0, 60)
refreshTimerLabel.BackgroundTransparency = 1
refreshTimerLabel.Font = Enum.Font.GothamMedium
refreshTimerLabel.Text = "다음 갱신까지: --:--"
refreshTimerLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
refreshTimerLabel.TextSize = 18
refreshTimerLabel.Parent = bgFrame

local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Name = "ScrollFrame"
scrollFrame.Size = UDim2.new(1, -40, 1, -110)
scrollFrame.Position = UDim2.new(0, 20, 0, 90)
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
cardCorner.CornerRadius = UDim.new(0, 12)
cardCorner.Parent = cardTemplate

local img = Instance.new("ImageLabel")
img.Name = "ItemImage"
img.Size = UDim2.new(1, -20, 0, 160)
img.Position = UDim2.new(0, 10, 0, 10)
img.BackgroundTransparency = 1
img.Image = ""
img.ScaleType = Enum.ScaleType.Fit
img.Parent = cardTemplate

local nameLabel = Instance.new("TextLabel")
nameLabel.Name = "ItemName"
nameLabel.Size = UDim2.new(1, 0, 0, 30)
nameLabel.Position = UDim2.new(0, 0, 0, 180)
nameLabel.BackgroundTransparency = 1
nameLabel.Font = Enum.Font.GothamBold
nameLabel.Text = "이름"
nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
nameLabel.TextSize = 20
nameLabel.Parent = cardTemplate

local nameStroke = Instance.new("UIStroke")
nameStroke.Color = Color3.fromRGB(0, 0, 0)
nameStroke.Thickness = 1.5
nameStroke.Parent = nameLabel

local priceLabel = Instance.new("TextLabel")
priceLabel.Name = "PriceLabel"
priceLabel.Size = UDim2.new(1, 0, 0, 30)
priceLabel.Position = UDim2.new(0, 0, 0, 210)
priceLabel.BackgroundTransparency = 1
priceLabel.Font = Enum.Font.GothamMedium
priceLabel.Text = "0 G"
priceLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
priceLabel.TextSize = 18
priceLabel.Parent = cardTemplate

local priceStroke = Instance.new("UIStroke")
priceStroke.Color = Color3.fromRGB(0, 0, 0)
priceStroke.Thickness = 1.5
priceStroke.Parent = priceLabel

local buyBtn = Instance.new("TextButton")
buyBtn.Name = "BuyButton"
buyBtn.Size = UDim2.new(1, -40, 0, 40)
buyBtn.Position = UDim2.new(0, 20, 1, -50)
buyBtn.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
buyBtn.Font = Enum.Font.GothamBold
buyBtn.TextSize = 18
buyBtn.Text = "구매"
buyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
buyBtn.Parent = cardTemplate

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 8)
btnCorner.Parent = buyBtn

print("HoverboardShopHUD generated in StarterGui!")
