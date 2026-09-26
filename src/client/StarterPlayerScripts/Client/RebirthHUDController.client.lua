--!strict
-- RebirthHUDController.client.luau

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RebirthConfig = require(Shared:WaitForChild("RebirthConfig"))

local screenGui = PlayerGui:WaitForChild("RebirthDisplayHUD")
local frame = screenGui:WaitForChild("RebirthFrame")
local textLabel = frame:WaitForChild("RebirthTextLabel") :: TextLabel

-- 메인 텍스트 (숫자 + RB) 설정
textLabel.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
textLabel.TextColor3 = Color3.fromRGB(255, 200, 50)
local stroke = textLabel:FindFirstChildOfClass("UIStroke")
if not stroke then
	stroke = Instance.new("UIStroke")
	stroke.Parent = textLabel
end
stroke.Color = Color3.fromRGB(0, 0, 0)
stroke.Thickness = 3

-- 부스트 텍스트 라벨 (새로 생성하여 메인 텍스트 아래에 배치)
local boostLabel = textLabel:FindFirstChild("BoostTextLabel")
if not boostLabel then
	boostLabel = Instance.new("TextLabel")
	boostLabel.Name = "BoostTextLabel"
	boostLabel.Size = UDim2.new(1.5, 0, 0, 24) -- 조금 넓게 설정
	boostLabel.Position = UDim2.new(0, 0, 0.85, 0) -- 메인 텍스트 바로 아래
	boostLabel.BackgroundTransparency = 1
	boostLabel.FontFace = Font.fromEnum(Enum.Font.GothamBold) -- 세련된 폰트
	boostLabel.TextColor3 = Color3.fromRGB(100, 255, 120) -- 밝은 초록색
	boostLabel.TextSize = 18
	boostLabel.TextXAlignment = Enum.TextXAlignment.Left
	boostLabel.TextYAlignment = Enum.TextYAlignment.Top
	boostLabel.Parent = textLabel
	
	local boostStroke = Instance.new("UIStroke")
	boostStroke.Color = Color3.fromRGB(0, 0, 0)
	boostStroke.Thickness = 2
	boostStroke.Parent = boostLabel
end

local leaderstats = LocalPlayer:WaitForChild("leaderstats", 10)
if not leaderstats then return end

local rebirthValue = leaderstats:WaitForChild("Rebirths", 10) :: IntValue
if not rebirthValue then return end

local function updateRebirthText()
	local rVal = rebirthValue.Value
	local boostVal = 0
	
	if rVal > 0 then
		local data = RebirthConfig.GetRebirthData(rVal)
		boostVal = data.BoostSpeedBonus
	end
	
	-- 메인 텍스트: "23 RB"
	textLabel.Text = tostring(rVal) .. " RB"
	
	-- 부스트 텍스트: "Boost +34.5km"
	if boostVal > 0 then
		boostLabel.Text = string.format("Boost +%.1fkm", boostVal)
		boostLabel.Visible = true
	else
		boostLabel.Visible = false
	end
	
	-- 애니메이션
	local originalSize = textLabel.TextSize
	local popTween = TweenService:Create(textLabel, TweenInfo.new(0.2, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), {TextSize = originalSize + 5})
	popTween:Play()
	popTween.Completed:Connect(function()
		TweenService:Create(textLabel, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextSize = originalSize}):Play()
	end)
end

updateRebirthText()
rebirthValue.Changed:Connect(updateRebirthText)