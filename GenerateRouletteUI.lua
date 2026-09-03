local StarterGui = game:GetService("StarterGui")

if StarterGui:FindFirstChild("HoverboardRouletteGui") then
    StarterGui.HoverboardRouletteGui:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "HoverboardRouletteGui"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = StarterGui

local bgFrame = Instance.new("Frame")
bgFrame.Name = "Background"
bgFrame.Size = UDim2.new(0, 900, 0, 500)
bgFrame.Position = UDim2.new(0.5, -450, 0.5, -250)
bgFrame.BackgroundColor3 = Color3.fromRGB(15, 20, 30)
bgFrame.BackgroundTransparency = 0.05
bgFrame.BorderSizePixel = 0
bgFrame.Parent = gui

local bgCorner = Instance.new("UICorner")
bgCorner.CornerRadius = UDim.new(0, 12)
bgCorner.Parent = bgFrame

local bgStroke = Instance.new("UIStroke")
bgStroke.Color = Color3.fromRGB(255, 215, 0)
bgStroke.Thickness = 3
bgStroke.Parent = bgFrame

-- Title
local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(1, 0, 0, 50)
titleLabel.Position = UDim2.new(0, 0, 0, 10)
titleLabel.BackgroundTransparency = 1
titleLabel.Font = Enum.Font.GothamBlack
titleLabel.Text = "🎰 호버보드 뽑기 상점"
titleLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
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

-- Roulette Viewport (Clips contents)
local viewportFrame = Instance.new("Frame")
viewportFrame.Name = "Viewport"
viewportFrame.Size = UDim2.new(1, -40, 0, 240)
viewportFrame.Position = UDim2.new(0, 20, 0, 100)
viewportFrame.BackgroundColor3 = Color3.fromRGB(10, 15, 20)
viewportFrame.ClipsDescendants = true
viewportFrame.Parent = bgFrame

local vCorner = Instance.new("UICorner")
vCorner.CornerRadius = UDim.new(0, 8)
vCorner.Parent = viewportFrame

local vStroke = Instance.new("UIStroke")
vStroke.Color = Color3.fromRGB(100, 120, 150)
vStroke.Thickness = 2
vStroke.Parent = viewportFrame

-- Strip that moves horizontally
local stripFrame = Instance.new("Frame")
stripFrame.Name = "Strip"
stripFrame.Size = UDim2.new(0, 10000, 1, 0) -- Wide enough for many items
stripFrame.Position = UDim2.new(0, 0, 0, 0)
stripFrame.BackgroundTransparency = 1
stripFrame.Parent = viewportFrame

-- Spin Button
local spinBtn = Instance.new("TextButton")
spinBtn.Name = "SpinButton"
spinBtn.Size = UDim2.new(0, 300, 0, 60)
spinBtn.Position = UDim2.new(0.5, -150, 1, -100)
spinBtn.BackgroundColor3 = Color3.fromRGB(255, 180, 0)
spinBtn.Font = Enum.Font.GothamBlack
spinBtn.Text = "SPIN! (300 G)"
spinBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
spinBtn.TextSize = 24
spinBtn.Parent = bgFrame

local sCorner = Instance.new("UICorner")
sCorner.CornerRadius = UDim.new(0, 10)
sCorner.Parent = spinBtn

-- Message Label (Refunds, Errrors)
local msgLabel = Instance.new("TextLabel")
msgLabel.Name = "Message"
msgLabel.Size = UDim2.new(1, 0, 0, 30)
msgLabel.Position = UDim2.new(0, 0, 1, -35)
msgLabel.BackgroundTransparency = 1
msgLabel.Font = Enum.Font.GothamBold
msgLabel.Text = ""
msgLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
msgLabel.TextSize = 16
msgLabel.Parent = bgFrame

print("HoverboardRouletteGui generated in StarterGui!")
