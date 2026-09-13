local StarterGui = game:GetService("StarterGui")

if StarterGui:FindFirstChild("SkillStoreGui") then
	StarterGui.SkillStoreGui:Destroy()
end

local storeGui = Instance.new("ScreenGui")
storeGui.Name = "SkillStoreGui"
storeGui.ResetOnSpawn = false
storeGui.Enabled = false
storeGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
storeGui.Parent = StarterGui

-- Main Panel (Glass Cyan + Thick Black Stroke)
local bgFrame = Instance.new("Frame")
bgFrame.Name = "Background"
bgFrame.Size = UDim2.new(0, 840, 0, 600)
bgFrame.Position = UDim2.new(0.5, -420, 0.5, -300)
bgFrame.BackgroundColor3 = Color3.fromRGB(150, 240, 255)
bgFrame.BackgroundTransparency = 0.5
bgFrame.BorderSizePixel = 0
bgFrame.Parent = storeGui

local bgCorner = Instance.new("UICorner")
bgCorner.CornerRadius = UDim.new(0, 24)
bgCorner.Parent = bgFrame

local bgStroke = Instance.new("UIStroke")
bgStroke.Color = Color3.fromRGB(0, 0, 0)
bgStroke.Thickness = 8
bgStroke.Parent = bgFrame

-- Title Header (Pill Frame)
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

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(1, 0, 1, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
titleLabel.Text = "SKILL STORE"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextSize = 36
titleLabel.ZIndex = 3
titleLabel.Parent = titleFrame

local titleTextStroke = Instance.new("UIStroke")
titleTextStroke.Color = Color3.fromRGB(0, 0, 0)
titleTextStroke.Thickness = 3
titleTextStroke.Parent = titleLabel

-- Close Button (Round Red, Protruding Top-Right)
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

local closeTextStroke = Instance.new("UIStroke")
closeTextStroke.Color = Color3.fromRGB(0, 0, 0)
closeTextStroke.Thickness = 2
closeTextStroke.Parent = closeBtn

-- Scrolling Frame for Skill Items
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Name = "ItemsScroll"
scrollFrame.Size = UDim2.new(1, -40, 1, -100)
scrollFrame.Position = UDim2.new(0, 20, 0, 88)
scrollFrame.BackgroundTransparency = 1
scrollFrame.ScrollBarThickness = 8
scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(40, 180, 255)
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrollFrame.Parent = bgFrame

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 8)
padding.PaddingBottom = UDim.new(0, 14)
padding.PaddingLeft = UDim.new(0, 8)
padding.PaddingRight = UDim.new(0, 8)
padding.Parent = scrollFrame

-- Grid Layout (3 items per row)
local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.new(0, 245, 0, 360)
gridLayout.CellPadding = UDim2.new(0, 15, 0, 18)
gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = scrollFrame

print("✨ [GenerateSkillStoreUI] SkillStoreGui updated to Thick Cartoon Style!")
