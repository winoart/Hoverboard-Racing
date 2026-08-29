--!strict
-- GoldUIController.client.luau
-- 화면 왼쪽 중간에 플레이어의 현재 골드를 표시합니다. (대기실에서만 보임)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local playerGui = LocalPlayer:WaitForChild("PlayerGui")
local leaderstats = LocalPlayer:WaitForChild("leaderstats", 10)
local goldValue = leaderstats and leaderstats:WaitForChild("Gold", 10) :: IntValue

if not goldValue then
	warn("🚨 [GoldUIController] Could not find leaderstats.Gold for player")
	return
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "GoldDisplayHUD"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 10
screenGui.Parent = playerGui

local goldFrame = Instance.new("Frame")
goldFrame.Name = "GoldFrame"
goldFrame.Size = UDim2.new(0, 160, 0, 50)
goldFrame.Position = UDim2.new(0, 20, 0.5, -25) -- 화면 왼쪽 중간
goldFrame.BackgroundColor3 = Color3.fromRGB(20, 25, 35)
goldFrame.BackgroundTransparency = 0.2
goldFrame.BorderSizePixel = 0
goldFrame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = goldFrame

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(255, 215, 0)
stroke.Thickness = 2.5
stroke.Parent = goldFrame

local goldIconLabel = Instance.new("TextLabel")
goldIconLabel.Size = UDim2.new(0, 45, 1, 0)
goldIconLabel.Position = UDim2.new(0, 5, 0, 0)
goldIconLabel.BackgroundTransparency = 1
goldIconLabel.Font = Enum.Font.GothamBlack
goldIconLabel.Text = "💰"
goldIconLabel.TextSize = 22
goldIconLabel.Parent = goldFrame

local goldTextLabel = Instance.new("TextLabel")
goldTextLabel.Size = UDim2.new(1, -55, 1, 0)
goldTextLabel.Position = UDim2.new(0, 50, 0, 0)
goldTextLabel.BackgroundTransparency = 1
goldTextLabel.Font = Enum.Font.GothamBlack
goldTextLabel.TextColor3 = Color3.fromRGB(255, 220, 0)
goldTextLabel.TextSize = 20
goldTextLabel.TextXAlignment = Enum.TextXAlignment.Left
goldTextLabel.Text = tostring(goldValue.Value)
goldTextLabel.Parent = goldFrame

-- 골드 값 변경 시 UI 업데이트
local function updateGold()
	goldTextLabel.Text = tostring(goldValue.Value)
end
goldValue.Changed:Connect(updateGold)
updateGold()

-- 대기실(Hoverboard 미장착 상태)에서만 보이도록 처리
RunService.RenderStepped:Connect(function()
	local character = LocalPlayer.Character
	local boardModel = character and character:FindFirstChild("EquippedHoverboard")
	
	-- 호버보드가 있으면 레이스 중이므로 숨김, 없으면 대기실이므로 표시
	local isInRace = (boardModel ~= nil)
	screenGui.Enabled = not isInRace
end)

print("💰 [GoldUIController] Gold Display UI loaded.")
