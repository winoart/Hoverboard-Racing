--!strict
-- AttendanceUIController.client.luau
-- Daily Attendance 14-day cumulative reward UI (Hologram Style - Polished)

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

-- MAIN HOLOGRAM PANEL
local bgFrame = Instance.new("Frame")
bgFrame.Name = "MainFrame"
bgFrame.Size = UDim2.new(0, 700, 0, 460) -- Reduced height to fix empty gap
bgFrame.Position = UDim2.new(0.5, -350, 0.5, -230)
bgFrame.BackgroundColor3 = Color3.fromRGB(25, 50, 75) -- Brighter base color
bgFrame.BackgroundTransparency = 0.35 -- Less transparent
bgFrame.BorderSizePixel = 0
bgFrame.Parent = gui

-- Background Gradient
local bgGradient = Instance.new("UIGradient")
bgGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 150, 150))
})
bgGradient.Rotation = 90
bgGradient.Parent = bgFrame

local bgCorner = Instance.new("UICorner")
bgCorner.CornerRadius = UDim.new(0, 12)
bgCorner.Parent = bgFrame

local bgStroke = Instance.new("UIStroke")
bgStroke.Color = Color3.fromRGB(0, 255, 255) -- Cyan Neon
bgStroke.Thickness = 2
bgStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
bgStroke.Parent = bgFrame

-- TITLE TEXT
local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, 0, 0, 50)
titleLabel.Position = UDim2.new(0, 0, 0, 5)
titleLabel.BackgroundTransparency = 1
titleLabel.Font = Enum.Font.FredokaOne
titleLabel.Text = "💎 DAILY REWARDS 💎"
titleLabel.TextColor3 = Color3.fromRGB(0, 255, 255)
titleLabel.TextSize = 34
titleLabel.Parent = bgFrame

-- Title Underline (Glowing line)
local underline = Instance.new("Frame")
underline.Size = UDim2.new(0.8, 0, 0, 2)
underline.Position = UDim2.new(0.1, 0, 0, 55)
underline.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
underline.BorderSizePixel = 0
underline.Parent = bgFrame
local underlineGlow = Instance.new("UIStroke")
underlineGlow.Color = Color3.fromRGB(0, 255, 255)
underlineGlow.Thickness = 1
underlineGlow.Transparency = 0.5
underlineGlow.Parent = underline

-- CLOSE BUTTON
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 36, 0, 36)
closeBtn.Position = UDim2.new(1, -46, 0, 10)
closeBtn.BackgroundColor3 = Color3.fromRGB(30, 5, 5)
closeBtn.BackgroundTransparency = 0.3
closeBtn.Font = Enum.Font.FredokaOne
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 80, 80)
closeBtn.TextSize = 22
closeBtn.Parent = bgFrame

local closeStroke = Instance.new("UIStroke")
closeStroke.Color = Color3.fromRGB(255, 50, 50)
closeStroke.Thickness = 2
closeStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
closeStroke.Parent = closeBtn

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 8)
closeCorner.Parent = closeBtn

closeBtn.MouseButton1Click:Connect(function()
	gui.Enabled = false
end)

-- GRID
local gridFrame = Instance.new("Frame")
gridFrame.Size = UDim2.new(1, -40, 0, 280)
gridFrame.Position = UDim2.new(0, 20, 0, 75)
gridFrame.BackgroundTransparency = 1
gridFrame.Parent = bgFrame

local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.new(0, 85, 0, 125) -- Taller cells for more flair
gridLayout.CellPadding = UDim2.new(0, 10, 0, 10)
gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = gridFrame

-- CLAIM BUTTON
local claimBtn = Instance.new("TextButton")
claimBtn.Size = UDim2.new(0, 300, 0, 60)
claimBtn.Position = UDim2.new(0.5, -150, 1, -75) -- Moved closer to the grid
claimBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 150)
claimBtn.BackgroundTransparency = 0.2
claimBtn.Font = Enum.Font.FredokaOne
claimBtn.Text = "CLAIM REWARD"
claimBtn.TextColor3 = Color3.fromRGB(200, 255, 255)
claimBtn.TextSize = 28
claimBtn.Parent = bgFrame

local claimStroke = Instance.new("UIStroke")
claimStroke.Color = Color3.fromRGB(0, 255, 255)
claimStroke.Thickness = 2
claimStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
claimStroke.Parent = claimBtn

local claimCorner = Instance.new("UICorner")
claimCorner.CornerRadius = UDim.new(0, 12)
claimCorner.Parent = claimBtn

local dayCards = {}

local function createDayCard(day: number)
	local card = Instance.new("Frame")
	card.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	card.BackgroundTransparency = 0.5
	card.LayoutOrder = day
	card.Parent = gridFrame
	
	local cardGradient = Instance.new("UIGradient")
	cardGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(15, 25, 40)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(5, 15, 30))
	})
	cardGradient.Rotation = 45
	cardGradient.Parent = card
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = card
	
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(0, 150, 200)
	stroke.Thickness = 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = card
	
	local dayLabel = Instance.new("TextLabel")
	dayLabel.Size = UDim2.new(1, 0, 0, 25)
	dayLabel.Position = UDim2.new(0, 0, 0, 5)
	dayLabel.BackgroundTransparency = 1
	dayLabel.Font = Enum.Font.FredokaOne
	dayLabel.Text = "DAY " .. day
	dayLabel.TextColor3 = Color3.fromRGB(150, 200, 255)
	dayLabel.TextSize = 16
	dayLabel.Parent = card
	
	-- Added visual icon for rewards to make it less boring
	local iconLabel = Instance.new("TextLabel")
	iconLabel.Size = UDim2.new(1, 0, 0, 30)
	iconLabel.Position = UDim2.new(0, 0, 0, 35)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Font = Enum.Font.FredokaOne
	iconLabel.Text = "🪙"
	iconLabel.TextSize = 28
	iconLabel.Parent = card
	
	local rewardLabel = Instance.new("TextLabel")
	rewardLabel.Size = UDim2.new(1, 0, 0, 30)
	rewardLabel.Position = UDim2.new(0, 0, 0, 65)
	rewardLabel.BackgroundTransparency = 1
	rewardLabel.Font = Enum.Font.FredokaOne
	rewardLabel.Text = (day * 100) .. "G"
	rewardLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	rewardLabel.TextSize = 20
	rewardLabel.Parent = card
	
	local stampLabel = Instance.new("TextLabel")
	stampLabel.Size = UDim2.new(1, 0, 0, 30)
	stampLabel.Position = UDim2.new(0, 0, 1, -30)
	stampLabel.BackgroundTransparency = 1
	stampLabel.Font = Enum.Font.FredokaOne
	stampLabel.Text = ""
	stampLabel.TextColor3 = Color3.fromRGB(0, 255, 255)
	stampLabel.TextSize = 24
	stampLabel.Parent = card
	
	dayCards[day] = { card = card, gradient = cardGradient, stroke = stroke, stamp = stampLabel, dayLabel = dayLabel, rewardLabel = rewardLabel, iconLabel = iconLabel }
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
			data.gradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(10, 15, 20)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(5, 10, 15))
			})
			data.stroke.Color = Color3.fromRGB(50, 70, 90)
			data.stroke.Thickness = 1
			data.stamp.Text = "✔️"
			data.stamp.TextColor3 = Color3.fromRGB(100, 150, 150)
			data.dayLabel.TextColor3 = Color3.fromRGB(100, 120, 150)
			data.iconLabel.TextTransparency = 0.5
			if data.rewardLabel then
				data.rewardLabel.TextColor3 = Color3.fromRGB(100, 120, 150)
			end
		elseif day == targetDayForToday then
			-- Today
			data.stroke.Thickness = 3
			data.dayLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
			if hasClaimedToday then
				-- Grayscale for today if already claimed
				data.gradient.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(10, 15, 20)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(5, 10, 15))
				})
				data.stroke.Color = Color3.fromRGB(50, 70, 90)
				data.stamp.Text = "✔️"
				data.stamp.TextColor3 = Color3.fromRGB(100, 150, 150)
				data.iconLabel.TextTransparency = 0.5
				if data.rewardLabel then
					data.rewardLabel.TextColor3 = Color3.fromRGB(100, 120, 150)
				end
			else
				data.gradient.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(40, 50, 80)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 20, 40))
				})
				data.stroke.Color = Color3.fromRGB(255, 215, 0) -- Gold glowing border
				data.stamp.Text = "🎁"
				data.stamp.TextColor3 = Color3.fromRGB(255, 215, 0)
				data.iconLabel.TextTransparency = 0
				if data.rewardLabel then
					data.rewardLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
				end
			end
		else
			-- Future
			data.gradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(15, 25, 40)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(5, 15, 30))
			})
			data.stroke.Color = Color3.fromRGB(0, 150, 200)
			data.stroke.Thickness = 1
			data.stamp.Text = ""
			data.dayLabel.TextColor3 = Color3.fromRGB(150, 200, 255)
			data.iconLabel.TextTransparency = 0
			if data.rewardLabel then
				data.rewardLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
			end
		end
	end
	
	if hasClaimedToday then
		claimBtn.BackgroundColor3 = Color3.fromRGB(30, 40, 50)
		claimBtn.TextColor3 = Color3.fromRGB(100, 120, 150)
		claimStroke.Color = Color3.fromRGB(50, 70, 90)
		claimBtn.Text = "CLAIMED"
		claimBtn.AutoButtonColor = false
	else
		claimBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 150)
		claimBtn.TextColor3 = Color3.fromRGB(200, 255, 255)
		claimStroke.Color = Color3.fromRGB(0, 255, 255)
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
		claimBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
		
		TweenService:Create(bgFrame, TweenInfo.new(0.2, Enum.EasingStyle.Sine), { BackgroundTransparency = 0.15 }):Play()
		task.delay(0.2, function()
			TweenService:Create(bgFrame, TweenInfo.new(0.2), { BackgroundTransparency = 0.35 }):Play()
		end)
	else
		claimBtn.Text = "ERROR: " .. tostring(newStreak)
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

