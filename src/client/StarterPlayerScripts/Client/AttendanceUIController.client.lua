--!strict
-- AttendanceUIController.client.luau
-- Daily Attendance 14-day cumulative reward UI (Thick Cartoon Style - Glass & Colored Text)

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

-- MAIN PANEL (Glass Effect)
local bgFrame = Instance.new("Frame")
bgFrame.Name = "MainFrame"
bgFrame.Size = UDim2.new(0, 720, 0, 500) -- Slightly taller for title frame
bgFrame.Position = UDim2.new(0.5, -360, 0.5, -250)
bgFrame.BackgroundColor3 = Color3.fromRGB(150, 240, 255) -- Bright Cyan
bgFrame.BackgroundTransparency = 0.5 -- Glass effect (more transparent)
bgFrame.BorderSizePixel = 0
bgFrame.Parent = gui

local bgCorner = Instance.new("UICorner")
bgCorner.CornerRadius = UDim.new(0, 24)
bgCorner.Parent = bgFrame

local bgStroke = Instance.new("UIStroke")
bgStroke.Color = Color3.fromRGB(0, 0, 0)
bgStroke.Thickness = 8
bgStroke.Parent = bgFrame

-- TITLE HEADER FRAME (Blue from leaderboard)
local titleFrame = Instance.new("Frame")
titleFrame.Name = "TitleFrame"
titleFrame.Size = UDim2.new(1, -60, 0, 60)
titleFrame.Position = UDim2.new(0, 30, 0, 20)
titleFrame.BackgroundColor3 = Color3.fromRGB(40, 180, 255) -- 쨍한 파란색
titleFrame.BorderSizePixel = 0
titleFrame.Parent = bgFrame

local titleFrameCorner = Instance.new("UICorner")
titleFrameCorner.CornerRadius = UDim.new(0.5, 0) -- Pill shape
titleFrameCorner.Parent = titleFrame

local titleFrameStroke = Instance.new("UIStroke")
titleFrameStroke.Color = Color3.fromRGB(0, 0, 0)
titleFrameStroke.Thickness = 6
titleFrameStroke.Parent = titleFrame

-- TITLE TEXT
local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, 0, 1, 0)
titleLabel.Position = UDim2.new(0, 0, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.FontFace = Font.fromName("Montserrat", Enum.FontWeight.ExtraBold, Enum.FontStyle.Normal)
titleLabel.Text = "DAILY REWARDS"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextSize = 36
titleLabel.Parent = titleFrame

local titleTextStroke = Instance.new("UIStroke")
titleTextStroke.Color = Color3.fromRGB(0, 0, 0)
titleTextStroke.Thickness = 3
titleTextStroke.Parent = titleLabel

-- CLOSE BUTTON
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 44, 0, 44)
closeBtn.Position = UDim2.new(1, -22, 0, -22) -- Popped out slightly
closeBtn.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
closeBtn.FontFace = Font.fromName("Montserrat", Enum.FontWeight.ExtraBold, Enum.FontStyle.Normal)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.TextSize = 28
closeBtn.Parent = bgFrame

local closeStroke = Instance.new("UIStroke")
closeStroke.Color = Color3.fromRGB(0, 0, 0)
closeStroke.Thickness = 4
closeStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
closeStroke.Parent = closeBtn

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(1, 0) -- Circle
closeCorner.Parent = closeBtn

closeBtn.MouseButton1Click:Connect(function()
	gui.Enabled = false
end)

-- GRID
local gridFrame = Instance.new("Frame")
gridFrame.Size = UDim2.new(1, -40, 0, 280)
gridFrame.Position = UDim2.new(0, 20, 0, 100)
gridFrame.BackgroundTransparency = 1
gridFrame.Parent = bgFrame

local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.new(0, 85, 0, 125)
gridLayout.CellPadding = UDim2.new(0, 10, 0, 10)
gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = gridFrame

-- CLAIM BUTTON
local claimBtn = Instance.new("TextButton")
claimBtn.Size = UDim2.new(0, 320, 0, 65)
claimBtn.Position = UDim2.new(0.5, -160, 1, -85)
claimBtn.BackgroundColor3 = Color3.fromRGB(100, 220, 110) -- Bright green
claimBtn.FontFace = Font.fromName("Montserrat", Enum.FontWeight.ExtraBold, Enum.FontStyle.Normal)
claimBtn.Text = "CLAIM REWARD"
claimBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
claimBtn.TextSize = 32
claimBtn.Parent = bgFrame

local claimStroke = Instance.new("UIStroke")
claimStroke.Color = Color3.fromRGB(0, 0, 0)
claimStroke.Thickness = 6
claimStroke.Parent = claimBtn

local claimTextStroke = Instance.new("UIStroke")
claimTextStroke.Color = Color3.fromRGB(0, 0, 0)
claimTextStroke.Thickness = 3
claimTextStroke.Parent = claimBtn

local claimCorner = Instance.new("UICorner")
claimCorner.CornerRadius = UDim.new(0, 16)
claimCorner.Parent = claimBtn

local dayCards = {}

-- Colors based on Leaderboard ranks
local colorGold = Color3.fromRGB(255, 200, 50)   -- 1st place
local colorSilver = Color3.fromRGB(210, 220, 230) -- 2nd place
local colorBronze = Color3.fromRGB(220, 140, 90)  -- 3rd place
local colorCyan = Color3.fromRGB(150, 240, 255)   -- 4~10th place

local function createDayCard(day: number)
	local card = Instance.new("Frame")
	card.BackgroundColor3 = colorCyan -- Default background (4th place color)
	card.LayoutOrder = day
	card.Parent = gridFrame
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = card
	
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Thickness = 4
	stroke.Parent = card
	
	-- UIGradient Stripes
	local patternBg = Instance.new("Frame", card)
	patternBg.Size = UDim2.new(1, 0, 1, 0)
	patternBg.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	patternBg.BorderSizePixel = 0
	Instance.new("UICorner", patternBg).CornerRadius = UDim.new(0, 12)
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
	
	-- Date Label
	local dayLabel = Instance.new("TextLabel")
	dayLabel.Size = UDim2.new(1, 0, 0, 25)
	dayLabel.Position = UDim2.new(0, 0, 0, 8)
	dayLabel.BackgroundTransparency = 1
	dayLabel.FontFace = Font.fromName("Montserrat", Enum.FontWeight.ExtraBold, Enum.FontStyle.Normal)
	dayLabel.Text = "DAY " .. day
	dayLabel.TextColor3 = colorGold
	dayLabel.TextSize = 20
	dayLabel.ZIndex = 2
	dayLabel.Parent = card
	
	local dayStroke = Instance.new("UIStroke")
	dayStroke.Color = Color3.fromRGB(0, 0, 0)
	dayStroke.Thickness = 3
	dayStroke.Parent = dayLabel
	
	local iconLabel = Instance.new("TextLabel")
	iconLabel.Size = UDim2.new(1, 0, 0, 30)
	iconLabel.Position = UDim2.new(0, 0, 0, 40)
	iconLabel.BackgroundTransparency = 1
	iconLabel.FontFace = Font.fromName("Montserrat", Enum.FontWeight.ExtraBold, Enum.FontStyle.Normal)
	iconLabel.Text = "🪙"
	iconLabel.TextSize = 32
	iconLabel.ZIndex = 2
	iconLabel.Parent = card
	
	-- Reward Label
	local rewardLabel = Instance.new("TextLabel")
	rewardLabel.Size = UDim2.new(1, 0, 0, 30)
	rewardLabel.Position = UDim2.new(0, 0, 0, 75)
	rewardLabel.BackgroundTransparency = 1
	rewardLabel.FontFace = Font.fromName("Montserrat", Enum.FontWeight.ExtraBold, Enum.FontStyle.Normal)
	rewardLabel.Text = (day * 100) .. "G"
	rewardLabel.TextColor3 = colorBronze
	rewardLabel.TextSize = 22
	rewardLabel.ZIndex = 2
	rewardLabel.Parent = card
	
	local rewardStroke = Instance.new("UIStroke")
	rewardStroke.Color = Color3.fromRGB(0, 0, 0)
	rewardStroke.Thickness = 3
	rewardStroke.Parent = rewardLabel
	
	local stampLabel = Instance.new("TextLabel")
	stampLabel.Size = UDim2.new(1, 0, 0, 30)
	stampLabel.Position = UDim2.new(0, 0, 1, -30)
	stampLabel.BackgroundTransparency = 1
	stampLabel.FontFace = Font.fromName("Montserrat", Enum.FontWeight.ExtraBold, Enum.FontStyle.Normal)
	stampLabel.Text = ""
	stampLabel.TextColor3 = Color3.fromRGB(30, 30, 30)
	stampLabel.TextSize = 28
	stampLabel.ZIndex = 3
	stampLabel.Parent = card
	
	dayCards[day] = { card = card, stroke = stroke, stamp = stampLabel, dayLabel = dayLabel, rewardLabel = rewardLabel, iconLabel = iconLabel, pattern = patternBg }
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
			-- Past (Claimed)
			data.card.BackgroundColor3 = colorSilver
			if data.pattern then data.pattern.Visible = false end
			data.stroke.Thickness = 4
			data.stamp.Text = "✔️"
			data.stamp.TextColor3 = Color3.fromRGB(30, 150, 30) -- Dark green check
			data.iconLabel.TextTransparency = 0.5
		elseif day == targetDayForToday then
			-- Today
			if hasClaimedToday then
				data.card.BackgroundColor3 = colorSilver
				if data.pattern then data.pattern.Visible = false end
				data.stroke.Thickness = 4
				data.stamp.Text = "✔️"
				data.stamp.TextColor3 = Color3.fromRGB(30, 150, 30)
				data.iconLabel.TextTransparency = 0.5
			else
				data.card.BackgroundColor3 = colorGold
				if data.pattern then data.pattern.Visible = true end
				data.stroke.Thickness = 6 
				data.stamp.Text = "🎁"
				data.stamp.TextColor3 = Color3.fromRGB(30, 30, 30)
				data.iconLabel.TextTransparency = 0
			end
		else
			-- Future
			data.card.BackgroundColor3 = colorCyan
			if data.pattern then data.pattern.Visible = true end
			data.stroke.Thickness = 4
			data.stamp.Text = ""
			data.iconLabel.TextTransparency = 0
		end
	end
	
	if hasClaimedToday then
		claimBtn.BackgroundColor3 = colorSilver
		claimBtn.Text = "CLAIMED"
		claimBtn.AutoButtonColor = false
	else
		claimBtn.BackgroundColor3 = Color3.fromRGB(100, 220, 110)
		claimBtn.Text = "CLAIM REWARD"
		claimBtn.AutoButtonColor = true
	end
end

claimBtn.MouseButton1Click:Connect(function()
	if currentHasClaimed then return end
	
	claimBtn.Text = "PROCESSING..."
	local success, newStreak, reward = claimAttendanceRemote:InvokeServer()
	
	if success then
		refreshUI(true, newStreak)
		claimBtn.Text = "REWARD ADDED!"
		claimBtn.BackgroundColor3 = colorGold
		
		TweenService:Create(bgFrame, TweenInfo.new(0.15, Enum.EasingStyle.Bounce), { Size = UDim2.new(0, 730, 0, 510) }):Play()
		task.delay(0.15, function()
			TweenService:Create(bgFrame, TweenInfo.new(0.15, Enum.EasingStyle.Bounce), { Size = UDim2.new(0, 720, 0, 500) }):Play()
		end)
	else
		claimBtn.Text = "ERROR!"
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

-- Hide Attendance UI when Map Voting or Race starts
local gamePhaseRemote = ReplicatedStorage:WaitForChild("HoverboardRemotes"):WaitForChild("GamePhaseChanged") :: RemoteEvent
gamePhaseRemote.OnClientEvent:Connect(function(phase: string)
	if phase ~= "INTERMISSION" then
		gui.Enabled = false
	end
end)

-- Connect HUD Toggle Button
task.spawn(function()
	local function connectDailyButton()
		local dailyRewardGui = playerGui:WaitForChild("dailyreward")
		local toggleBtn = dailyRewardGui:WaitForChild("ImageButton")
		
		if toggleBtn:GetAttribute("DailyHooked") then return end
		toggleBtn:SetAttribute("DailyHooked", true)
		
		toggleBtn.MouseButton1Click:Connect(function()
			gui.Enabled = not gui.Enabled
		end)
	end

	-- Initial connection
	connectDailyButton()
	
	-- In case the UI has ResetOnSpawn turned on and is recreated when the player dies
	playerGui.ChildAdded:Connect(function(child)
		if child.Name == "dailyreward" then
			connectDailyButton()
		end
	end)
end)
