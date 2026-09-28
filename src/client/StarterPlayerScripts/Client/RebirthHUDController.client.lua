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
screenGui.ResetOnSpawn = false
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
	boostLabel.TextSize = 14
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

local function getRebirthTextLabel()
	if not textLabel or textLabel.Parent == nil then
		print("🚨 [RebirthHUD] 기존 환생 UI 파괴됨. 새로 찾습니다!")
		local newGui = PlayerGui:FindFirstChild("RebirthDisplayHUD")
		if newGui then
			screenGui = newGui
			screenGui.ResetOnSpawn = false
			local newFrame = screenGui:FindFirstChild("RebirthFrame")
			if newFrame then
				textLabel = newFrame:FindFirstChild("RebirthTextLabel") :: TextLabel
				
				-- 새 UI가 복제되었으므로 폰트 외곽선(UIStroke)과 색상 등을 다시 적용합니다.
				textLabel.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
				textLabel.TextColor3 = Color3.fromRGB(255, 200, 50)
				if not textLabel:FindFirstChildOfClass("UIStroke") then
					local newStroke = Instance.new("UIStroke")
					newStroke.Color = Color3.fromRGB(0, 0, 0)
					newStroke.Thickness = 3
					newStroke.Parent = textLabel
				end
				
				boostLabel = textLabel:FindFirstChild("BoostTextLabel")
				if not boostLabel then
					boostLabel = Instance.new("TextLabel")
					boostLabel.Name = "BoostTextLabel"
					boostLabel.Size = UDim2.new(1.5, 0, 0, 24)
					boostLabel.Position = UDim2.new(0, 0, 0.85, 0)
					boostLabel.BackgroundTransparency = 1
					boostLabel.FontFace = Font.fromEnum(Enum.Font.GothamBold)
					boostLabel.TextColor3 = Color3.fromRGB(100, 255, 120)
					boostLabel.TextSize = 14
					boostLabel.TextXAlignment = Enum.TextXAlignment.Left
					boostLabel.TextYAlignment = Enum.TextYAlignment.Top
					boostLabel.Parent = textLabel
					
					local boostStroke = Instance.new("UIStroke")
					boostStroke.Color = Color3.fromRGB(0, 0, 0)
					boostStroke.Thickness = 2
					boostStroke.Parent = boostLabel
				end
			end
		end
	end
	return textLabel, boostLabel
end

local function updateRebirthText()
	local rVal = rebirthValue.Value
	local boostVal = 0
	
	if rVal > 0 then
		local data = RebirthConfig.GetRebirthData(rVal)
		boostVal = data.BoostSpeedBonus
	end
	
	local currentLabel, currentBoostLabel = getRebirthTextLabel()
	if not currentLabel then
		print("❌ [RebirthHUD] 환생 텍스트 라벨을 찾을 수 없습니다!")
		return
	end
	
	-- 메인 텍스트: "23 RB"
	currentLabel.Text = tostring(rVal) .. " RB"
	print("🌀 [RebirthHUD] 환생 텍스트 갱신됨:", currentLabel.Text)
	
	-- 부스트 텍스트: "Boost +34.5km"
	if boostVal > 0 and currentBoostLabel then
		currentBoostLabel.Text = string.format("Boost +%.1fkm", boostVal)
		currentBoostLabel.Visible = true
	elseif currentBoostLabel then
		currentBoostLabel.Visible = false
	end
	
	-- 애니메이션
	local originalSize = currentLabel.TextSize
	local popTween = TweenService:Create(currentLabel, TweenInfo.new(0.2, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), {TextSize = originalSize + 5})
	popTween:Play()
	popTween.Completed:Connect(function()
		TweenService:Create(currentLabel, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextSize = originalSize}):Play()
	end)
end

updateRebirthText()
rebirthValue.Changed:Connect(updateRebirthText)

PlayerGui.ChildAdded:Connect(function(child)
	if child.Name == "RebirthDisplayHUD" then
		print("🔄 [RebirthHUD] 새 UI 생성 감지 - 즉각 강제 갱신")
		if textLabel and textLabel.Parent == nil then
			textLabel = nil
			boostLabel = nil
		end
		updateRebirthText()
	end
end)