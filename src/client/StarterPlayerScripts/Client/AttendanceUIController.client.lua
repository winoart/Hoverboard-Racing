--!strict
-- AttendanceUIController.client.luau
-- Daily Attendance 14-day cumulative reward UI

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local playerGui = LocalPlayer:WaitForChild("PlayerGui")

local attendanceRemotes = ReplicatedStorage:WaitForChild("AttendanceRemotes")
local checkAttendanceRemote = attendanceRemotes:WaitForChild("CheckAttendance") :: RemoteFunction
local claimAttendanceRemote = attendanceRemotes:WaitForChild("ClaimAttendance") :: RemoteFunction

local gui = Instance.new("ScreenGui")
gui.Name = "AttendanceGui"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local bgFrame = Instance.new("Frame")
bgFrame.Name = "MainFrame"
bgFrame.Size = UDim2.new(0, 700, 0, 520)
bgFrame.Position = UDim2.new(0.5, -350, 0.5, -260)
bgFrame.BackgroundColor3 = Color3.fromRGB(20, 25, 35)
bgFrame.BackgroundTransparency = 0.05
bgFrame.BorderSizePixel = 0
bgFrame.Parent = gui

local bgCorner = Instance.new("UICorner")
bgCorner.CornerRadius = UDim.new(0, 15)
bgCorner.Parent = bgFrame

local bgStroke = Instance.new("UIStroke")
bgStroke.Color = Color3.fromRGB(255, 215, 0)
bgStroke.Thickness = 4
bgStroke.Parent = bgFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, 0, 0, 60)
titleLabel.BackgroundTransparency = 1
titleLabel.Font = Enum.Font.GothamBlack
titleLabel.Text = "🎁 출석체크 보상 (14일 누적) 🎁"
titleLabel.TextColor3 = Color3.fromRGB(255, 220, 50)
titleLabel.TextSize = 32
titleLabel.Parent = bgFrame

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 40, 0, 40)
closeBtn.Position = UDim2.new(1, -50, 0, 10)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.TextSize = 22
closeBtn.Parent = bgFrame

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 8)
closeCorner.Parent = closeBtn

closeBtn.MouseButton1Click:Connect(function()
	gui.Enabled = false
end)

local gridFrame = Instance.new("Frame")
gridFrame.Size = UDim2.new(1, -40, 0, 360)
gridFrame.Position = UDim2.new(0, 20, 0, 70)
gridFrame.BackgroundTransparency = 1
gridFrame.Parent = bgFrame

local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.new(0, 85, 0, 110)
gridLayout.CellPadding = UDim2.new(0, 10, 0, 10)
gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = gridFrame

local claimBtn = Instance.new("TextButton")
claimBtn.Size = UDim2.new(0, 300, 0, 60)
claimBtn.Position = UDim2.new(0.5, -150, 1, -80)
claimBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 80)
claimBtn.Font = Enum.Font.GothamBlack
claimBtn.Text = "수령하기"
claimBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
claimBtn.TextSize = 28
claimBtn.Parent = bgFrame

local claimCorner = Instance.new("UICorner")
claimCorner.CornerRadius = UDim.new(0, 12)
claimCorner.Parent = claimBtn

local dayCards = {}

local function createDayCard(day: number)
	local card = Instance.new("Frame")
	card.BackgroundColor3 = Color3.fromRGB(30, 40, 50)
	card.LayoutOrder = day
	card.Parent = gridFrame
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = card
	
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(100, 110, 130)
	stroke.Thickness = 2
	stroke.Parent = card
	
	local dayLabel = Instance.new("TextLabel")
	dayLabel.Size = UDim2.new(1, 0, 0, 30)
	dayLabel.BackgroundTransparency = 1
	dayLabel.Font = Enum.Font.GothamBold
	dayLabel.Text = day .. "일차"
	dayLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	dayLabel.TextSize = 16
	dayLabel.Parent = card
	
	local rewardLabel = Instance.new("TextLabel")
	rewardLabel.Size = UDim2.new(1, 0, 0, 40)
	rewardLabel.Position = UDim2.new(0, 0, 0, 35)
	rewardLabel.BackgroundTransparency = 1
	rewardLabel.Font = Enum.Font.GothamBlack
	rewardLabel.Text = (day * 100) .. "G"
	rewardLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	rewardLabel.TextSize = 20
	rewardLabel.Parent = card
	
	local stampLabel = Instance.new("TextLabel")
	stampLabel.Size = UDim2.new(1, 0, 0, 30)
	stampLabel.Position = UDim2.new(0, 0, 1, -35)
	stampLabel.BackgroundTransparency = 1
	stampLabel.Font = Enum.Font.GothamBold
	stampLabel.Text = ""
	stampLabel.TextColor3 = Color3.fromRGB(50, 255, 100)
	stampLabel.TextSize = 24
	stampLabel.Parent = card
	
	dayCards[day] = { card = card, stroke = stroke, stamp = stampLabel, dayLabel = dayLabel }
end

for i = 1, 14 do
	createDayCard(i)
end

local currentHasClaimed = false
local currentStreak = 0

local function refreshUI(hasClaimedToday: boolean, streak: number)
	currentHasClaimed = hasClaimedToday
	currentStreak = streak
	
	local targetDayForToday = hasClaimedToday and streak or (streak + 1)
	if targetDayForToday > 14 then targetDayForToday = 14 end
	if targetDayForToday < 1 then targetDayForToday = 1 end
	
	for day, data in pairs(dayCards) do
		if day < targetDayForToday then
			-- Past
			data.card.BackgroundColor3 = Color3.fromRGB(15, 20, 25)
			data.stroke.Color = Color3.fromRGB(50, 60, 70)
			data.stamp.Text = "✅"
			data.dayLabel.TextColor3 = Color3.fromRGB(100, 100, 100)
			data.card:FindFirstChild("TextLabel").TextColor3 = Color3.fromRGB(100, 100, 100) -- Grayscale reward text
		elseif day == targetDayForToday then
			-- Today
			data.stroke.Thickness = 4
			data.dayLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
			if hasClaimedToday then
				-- Grayscale for today if already claimed
				data.card.BackgroundColor3 = Color3.fromRGB(25, 30, 35)
				data.stroke.Color = Color3.fromRGB(100, 100, 100)
				data.stamp.Text = "✅"
				-- Ensure the reward text label turns grayscale too
				local rLabel = data.card:GetChildren()[3]
				if rLabel and rLabel:IsA("TextLabel") then
					rLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
				end
			else
				data.card.BackgroundColor3 = Color3.fromRGB(50, 60, 80)
				data.stroke.Color = Color3.fromRGB(255, 215, 0)
				data.stamp.Text = "🎁"
				local rLabel = data.card:GetChildren()[3]
				if rLabel and rLabel:IsA("TextLabel") then
					rLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
				end
			end
		else
			-- Future
			data.card.BackgroundColor3 = Color3.fromRGB(30, 40, 50)
			data.stroke.Color = Color3.fromRGB(100, 110, 130)
			data.stroke.Thickness = 2
			data.stamp.Text = ""
			data.dayLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
			local rLabel = data.card:GetChildren()[3]
			if rLabel and rLabel:IsA("TextLabel") then
				rLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
			end
		end
	end
	
	if hasClaimedToday then
		claimBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
		claimBtn.Text = "✅ 수령완료"
		claimBtn.AutoButtonColor = false
	else
		claimBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 80)
		claimBtn.Text = "수령하기"
		claimBtn.AutoButtonColor = true
	end
end

claimBtn.MouseButton1Click:Connect(function()
	if currentHasClaimed then return end
	
	claimBtn.Text = "처리중..."
	local success, newStreak, reward = claimAttendanceRemote:InvokeServer()
	
	if success then
		refreshUI(true, newStreak)
		claimBtn.Text = "✅ " .. reward .. "G 획득 완료!"
		claimBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
		
		-- Simple pop animation
		TweenService:Create(bgFrame, TweenInfo.new(0.2, Enum.EasingStyle.Bounce), { Size = UDim2.new(0, 720, 0, 540) }):Play()
		task.delay(0.2, function()
			TweenService:Create(bgFrame, TweenInfo.new(0.2), { Size = UDim2.new(0, 700, 0, 520) }):Play()
		end)
	else
		claimBtn.Text = "오류: " .. tostring(newStreak)
		task.wait(2)
		refreshUI(currentHasClaimed, currentStreak)
	end
end)

-- Initialize on join
task.spawn(function()
	local hasClaimed, streak = checkAttendanceRemote:InvokeServer()
	refreshUI(hasClaimed, streak)
	gui.Enabled = true -- Auto popup on join
end)
