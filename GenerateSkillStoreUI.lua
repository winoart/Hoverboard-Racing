local StarterGui = game:GetService("StarterGui")

if StarterGui:FindFirstChild("SkillStoreGui") then
    StarterGui.SkillStoreGui:Destroy()
end

local storeGui = Instance.new("ScreenGui")
storeGui.Name = "SkillStoreGui"
storeGui.ResetOnSpawn = false
storeGui.Enabled = false
storeGui.Parent = StarterGui

local bgFrame = Instance.new("Frame")
bgFrame.Name = "Background"
bgFrame.Size = UDim2.new(0, 800, 0, 500)
bgFrame.Position = UDim2.new(0.5, -400, 0.5, -250)
bgFrame.BackgroundColor3 = Color3.fromRGB(20, 15, 30)
bgFrame.BackgroundTransparency = 0.05
bgFrame.BorderSizePixel = 0
bgFrame.Parent = storeGui

local bgCorner = Instance.new("UICorner")
bgCorner.CornerRadius = UDim.new(0, 12)
bgCorner.Parent = bgFrame

local bgStroke = Instance.new("UIStroke")
bgStroke.Color = Color3.fromRGB(0, 215, 255)
bgStroke.Thickness = 3
bgStroke.Parent = bgFrame

-- Title
local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(1, 0, 0, 50)
titleLabel.Position = UDim2.new(0, 0, 0, 10)
titleLabel.BackgroundTransparency = 1
titleLabel.Font = Enum.Font.GothamBlack
titleLabel.Text = "🔮 스킬 상점"
titleLabel.TextColor3 = Color3.fromRGB(0, 215, 255)
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

-- Scroll Frame for Items
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Name = "ItemsScroll"
scrollFrame.Size = UDim2.new(1, -40, 1, -80)
scrollFrame.Position = UDim2.new(0, 20, 0, 60)
scrollFrame.BackgroundTransparency = 1
scrollFrame.ScrollBarThickness = 8
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrollFrame.Parent = bgFrame

-- Grid Layout (3 per row)
local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.new(0, 240, 0, 280)
gridLayout.CellPadding = UDim2.new(0, 15, 0, 20)
gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = scrollFrame

print("SkillStoreGui generated in StarterGui!")
