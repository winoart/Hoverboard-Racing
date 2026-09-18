--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local StarterGui = game:GetService("StarterGui") -- for existing button if any

local hoverRemotes = ReplicatedStorage:WaitForChild("HoverboardRemotes")
local claimQuestRemote = hoverRemotes:WaitForChild("ClaimQuestReward") :: RemoteFunction
local getQuestsRemote = hoverRemotes:WaitForChild("GetQuestData") :: RemoteFunction
local questUpdateEvent = hoverRemotes:WaitForChild("QuestUpdateEvent") :: RemoteEvent

local Shared = ReplicatedStorage:WaitForChild("Shared")
local QuestConfig = require(Shared:WaitForChild("QuestConfig"))

-- UI Elements
local questScreenGui = Instance.new("ScreenGui")
questScreenGui.Name = "QuestUI"
questScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
questScreenGui.Parent = PlayerGui

-- Main Panel
local mainPanel = Instance.new("Frame")
mainPanel.Name = "MainPanel"
mainPanel.Size = UDim2.new(0, 750, 0, 450)
mainPanel.Position = UDim2.new(0.5, 0, 0.5, 0)
mainPanel.AnchorPoint = Vector2.new(0.5, 0.5)
mainPanel.BackgroundColor3 = Color3.fromRGB(150, 240, 255)
mainPanel.BackgroundTransparency = 0.5
mainPanel.Visible = false
mainPanel.Parent = questScreenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 24)
mainCorner.Parent = mainPanel

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(0, 0, 0)
mainStroke.Thickness = 8
mainStroke.Parent = mainPanel

-- Title Header
local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(0.6, 0, 0, 60)
header.Position = UDim2.new(0.2, 0, 0, -30)
header.BackgroundColor3 = Color3.fromRGB(40, 180, 255)
header.Parent = mainPanel

local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0.5, 0)
headerCorner.Parent = header

local headerStroke = Instance.new("UIStroke")
headerStroke.Color = Color3.fromRGB(0, 0, 0)
headerStroke.Thickness = 6
headerStroke.Parent = header

local titleText = Instance.new("TextLabel")
titleText.Size = UDim2.new(1, 0, 1, 0)
titleText.BackgroundTransparency = 1
titleText.Text = "QUESTS"
titleText.Font = Enum.Font.FredokaOne
titleText.TextSize = 36
titleText.TextColor3 = Color3.fromRGB(255, 255, 255)
titleText.Parent = header

local titleStroke = Instance.new("UIStroke")
titleStroke.Color = Color3.fromRGB(0, 0, 0)
titleStroke.Thickness = 3
titleStroke.Parent = titleText

-- Close Button
local closeBtn = Instance.new("TextButton")
closeBtn.Name = "CloseBtn"
closeBtn.Size = UDim2.new(0, 50, 0, 50)
closeBtn.Position = UDim2.new(1, -25, 0, -25)
closeBtn.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
closeBtn.Text = "X"
closeBtn.Font = Enum.Font.FredokaOne
closeBtn.TextSize = 28
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Parent = mainPanel

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(1, 0)
closeCorner.Parent = closeBtn

local closeStroke = Instance.new("UIStroke")
closeStroke.Color = Color3.fromRGB(0, 0, 0)
closeStroke.Thickness = 5
closeStroke.Parent = closeBtn

-- Tabs
local tabContainer = Instance.new("Frame")
tabContainer.Size = UDim2.new(1, -40, 0, 50)
tabContainer.Position = UDim2.new(0, 20, 0, 40)
tabContainer.BackgroundTransparency = 1
tabContainer.Parent = mainPanel

local dailyTab = Instance.new("TextButton")
dailyTab.Size = UDim2.new(0.5, -5, 1, 0)
dailyTab.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
dailyTab.Text = "Daily"
dailyTab.Font = Enum.Font.FredokaOne
dailyTab.TextSize = 24
dailyTab.TextColor3 = Color3.fromRGB(255, 255, 255)
dailyTab.Parent = tabContainer

local dailyCorner = Instance.new("UICorner")
dailyCorner.CornerRadius = UDim.new(0, 12)
dailyCorner.Parent = dailyTab
local dailyStroke = Instance.new("UIStroke")
dailyStroke.Color = Color3.fromRGB(0, 0, 0)
dailyStroke.Thickness = 4
dailyStroke.Parent = dailyTab

local weeklyTab = Instance.new("TextButton")
weeklyTab.Size = UDim2.new(0.5, -5, 1, 0)
weeklyTab.Position = UDim2.new(0.5, 5, 0, 0)
weeklyTab.BackgroundColor3 = Color3.fromRGB(210, 220, 230)
weeklyTab.Text = "Weekly"
weeklyTab.Font = Enum.Font.FredokaOne
weeklyTab.TextSize = 24
weeklyTab.TextColor3 = Color3.fromRGB(255, 255, 255)
weeklyTab.Parent = tabContainer

local weeklyCorner = Instance.new("UICorner")
weeklyCorner.CornerRadius = UDim.new(0, 12)
weeklyCorner.Parent = weeklyTab
local weeklyStroke = Instance.new("UIStroke")
weeklyStroke.Color = Color3.fromRGB(0, 0, 0)
weeklyStroke.Thickness = 4
weeklyStroke.Parent = weeklyTab

-- Quest List Scroll
local listContainer = Instance.new("ScrollingFrame")
listContainer.Size = UDim2.new(1, -40, 1, -160)
listContainer.Position = UDim2.new(0, 20, 0, 100)
listContainer.BackgroundTransparency = 1
listContainer.ScrollBarThickness = 6
listContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
listContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
listContainer.Parent = mainPanel

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 10)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = listContainer

local listPadding = Instance.new("UIPadding")
listPadding.PaddingLeft = UDim.new(0, 10)
listPadding.PaddingRight = UDim.new(0, 10)
listPadding.PaddingTop = UDim.new(0, 10)
listPadding.PaddingBottom = UDim.new(0, 10)
listPadding.Parent = listContainer

-- Timer Label
local timerLabel = Instance.new("TextLabel")
timerLabel.Size = UDim2.new(1, 0, 0, 40)
timerLabel.Position = UDim2.new(0, 0, 1, -50)
timerLabel.BackgroundTransparency = 1
timerLabel.Text = "Resets in: --:--:--"
timerLabel.Font = Enum.Font.FredokaOne
timerLabel.TextSize = 22
timerLabel.TextColor3 = Color3.fromRGB(30, 30, 30)
timerLabel.Parent = mainPanel

local timerStroke = Instance.new("UIStroke")
timerStroke.Color = Color3.fromRGB(255, 255, 255)
timerStroke.Thickness = 2
timerStroke.Parent = timerLabel

local currentTab = "Daily"
local cachedQuestData = nil

local function createQuestCard(questInfo, config, isWeekly)
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, 0, 0, 100)
	card.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	if questInfo.claimed then
		card.BackgroundColor3 = Color3.fromRGB(220, 220, 220) -- Silver for claimed
	end

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 16)
	cardCorner.Parent = card

	local cardStroke = Instance.new("UIStroke")
	cardStroke.Color = Color3.fromRGB(0, 0, 0)
	cardStroke.Thickness = 4
	cardStroke.Parent = card
	
	-- Title & Desc Combined
	local qTitle = Instance.new("TextLabel")
	qTitle.Size = UDim2.new(1, -150, 0, 36)
	qTitle.Position = UDim2.new(0, 20, 0, 15)
	qTitle.BackgroundTransparency = 1
	qTitle.RichText = true
	qTitle.Text = config.title .. ": <font face='Montserrat' size='20' color='#505050'>" .. config.desc .. "</font>"
	qTitle.Font = Enum.Font.FredokaOne
	qTitle.TextSize = 26
	qTitle.TextColor3 = Color3.fromRGB(20, 20, 20)
	qTitle.TextXAlignment = Enum.TextXAlignment.Left
	qTitle.Parent = card
	
	-- Progress Text
	local progText = Instance.new("TextLabel")
	progText.Size = UDim2.new(0, 100, 0, 30)
	progText.Position = UDim2.new(1, -230, 0, 55)
	progText.BackgroundTransparency = 1
	progText.Text = string.format("%d / %d", questInfo.progress, config.target)
	progText.Font = Enum.Font.FredokaOne
	progText.TextSize = 20
	progText.TextColor3 = Color3.fromRGB(20, 20, 20)
	progText.Parent = card
	
	-- Progress Bar BG
	local barBg = Instance.new("Frame")
	barBg.Size = UDim2.new(1, -250, 0, 24)
	barBg.Position = UDim2.new(0, 20, 0, 58)
	barBg.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
	barBg.Parent = card
	
	local barBgCorner = Instance.new("UICorner")
	barBgCorner.CornerRadius = UDim.new(0.5, 0)
	barBgCorner.Parent = barBg
	local barBgStroke = Instance.new("UIStroke")
	barBgStroke.Color = Color3.fromRGB(0, 0, 0)
	barBgStroke.Thickness = 3
	barBgStroke.Parent = barBg
	
	-- Progress Bar Fill
	local pct = math.clamp(questInfo.progress / config.target, 0, 1)
	local barFill = Instance.new("Frame")
	barFill.Size = UDim2.new(pct, 0, 1, 0)
	barFill.BackgroundColor3 = Color3.fromRGB(40, 180, 255)
	barFill.Parent = barBg
	
	local barFillCorner = Instance.new("UICorner")
	barFillCorner.CornerRadius = UDim.new(0.5, 0)
	barFillCorner.Parent = barFill
	
	-- Claim Button
	local claimBtn = Instance.new("TextButton")
	claimBtn.Size = UDim2.new(0, 100, 0, 50)
	claimBtn.Position = UDim2.new(1, -120, 0.5, -25)
	claimBtn.Font = Enum.Font.FredokaOne
	claimBtn.TextSize = 20
	claimBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	claimBtn.Parent = card
	
	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 12)
	btnCorner.Parent = claimBtn
	local btnStroke = Instance.new("UIStroke")
	btnStroke.Color = Color3.fromRGB(0, 0, 0)
	btnStroke.Thickness = 4
	btnStroke.Parent = claimBtn
	
	if questInfo.claimed then
		claimBtn.Text = "Clear!"
		claimBtn.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
		claimBtn.Active = false
	elseif questInfo.completed then
		claimBtn.Text = "Claim\n" .. config.reward .. "G"
		claimBtn.BackgroundColor3 = Color3.fromRGB(100, 220, 110)
		-- Pulsing effect
		task.spawn(function()
			while claimBtn.Parent and not questInfo.claimed do
				TweenService:Create(claimBtn, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {BackgroundColor3 = Color3.fromRGB(150, 255, 150)}):Play()
				task.wait(1.6)
			end
		end)
		
		claimBtn.MouseButton1Click:Connect(function()
			local success, result = claimQuestRemote:InvokeServer(questInfo.id, isWeekly)
			if success then
				questInfo.claimed = true
				refreshUI()
			end
		end)
	else
		claimBtn.Text = config.reward .. "G"
		claimBtn.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
		claimBtn.Active = false
	end
	
	return card
end

function refreshUI()
	for _, child in ipairs(listContainer:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	
	if not cachedQuestData then return end
	
	local list = currentTab == "Daily" and cachedQuestData.DailyQuests or cachedQuestData.WeeklyQuests
	local cfgList = currentTab == "Daily" and QuestConfig.Daily or QuestConfig.Weekly
	
	if list then
		for _, q in ipairs(list) do
			local cfg
			for _, c in ipairs(cfgList) do
				if c.id == q.id then cfg = c; break end
			end
			if cfg then
				local card = createQuestCard(q, cfg, currentTab == "Weekly")
				card.Parent = listContainer
			end
		end
	end
end

local function selectTab(tabName)
	currentTab = tabName
	if tabName == "Daily" then
		dailyTab.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
		weeklyTab.BackgroundColor3 = Color3.fromRGB(210, 220, 230)
	else
		dailyTab.BackgroundColor3 = Color3.fromRGB(210, 220, 230)
		weeklyTab.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
	end
	refreshUI()
end

dailyTab.MouseButton1Click:Connect(function() selectTab("Daily") end)
weeklyTab.MouseButton1Click:Connect(function() selectTab("Weekly") end)

closeBtn.MouseButton1Click:Connect(function()
	mainPanel.Visible = false
end)

local HttpService = game:GetService("HttpService")

local function loadData()
	task.spawn(function()
		local qStr = LocalPlayer:WaitForChild("QuestDataJSON", 5)
		if qStr and qStr.Value and qStr.Value ~= "" and qStr.Value ~= "{}" then
			local success, decoded = pcall(function() return HttpService:JSONDecode(qStr.Value) end)
			if success and decoded then
				cachedQuestData = decoded
			end
		end
		refreshUI()
	end)
end

local function bindToQuestButton()
	-- StarterGui > Quest 위치에 있다고 하셨으므로 PlayerGui.Quest 를 찾습니다.
	local questNode = PlayerGui:FindFirstChild("Quest")
	if not questNode then return false end
	
	local existingQuestBtn = nil
	if questNode:IsA("GuiButton") then
		existingQuestBtn = questNode
	elseif questNode:IsA("ScreenGui") or questNode:IsA("Frame") then
		-- 만약 Quest가 ScreenGui 이고 그 안에 버튼이 있다면 가장 먼저 발견되는 버튼을 타겟으로 잡습니다.
		for _, desc in ipairs(questNode:GetDescendants()) do
			if desc:IsA("GuiButton") then
				existingQuestBtn = desc
				break
			end
		end
	end
	
	if existingQuestBtn then
		-- 기존에 연결된 이벤트가 중복되지 않도록 방지
		if not existingQuestBtn:GetAttribute("IsQuestBound") then
			existingQuestBtn:SetAttribute("IsQuestBound", true)
			existingQuestBtn.MouseButton1Click:Connect(function()
				mainPanel.Visible = not mainPanel.Visible
				if mainPanel.Visible then
					loadData()
				end
			end)
		end
		return true
	end
	return false
end

-- Try binding immediately, or wait if it hasn't loaded
if not bindToQuestButton() then
	task.spawn(function()
		local bound = false
		for i = 1, 10 do
			task.wait(1)
			if bindToQuestButton() then
				bound = true
				break
			end
		end
		
		if not bound then
			-- Create a fallback button just in case
			local fallbackBtn = Instance.new("TextButton")
			fallbackBtn.Size = UDim2.new(0, 80, 0, 80)
			fallbackBtn.Position = UDim2.new(0, 20, 0.5, 0)
			fallbackBtn.Text = "Quests"
			fallbackBtn.Parent = questScreenGui
			fallbackBtn.MouseButton1Click:Connect(function()
				mainPanel.Visible = not mainPanel.Visible
				if mainPanel.Visible then
					loadData()
				end
			end)
		end
	end)
end

-- Bind to QuestDataJSON changes instead of RemoteEvent
task.spawn(function()
	local qStr = LocalPlayer:WaitForChild("QuestDataJSON", 10)
	if qStr then
		qStr:GetPropertyChangedSignal("Value"):Connect(function()
			loadData()
		end)
	end
end)

-- Timer loop
RunService.RenderStepped:Connect(function()
	if not mainPanel.Visible or not cachedQuestData then return end
	local resetTime = nil
	if currentTab == "Daily" then
		resetTime = cachedQuestData.DailyResetTime
	else
		resetTime = cachedQuestData.WeeklyResetTime
	end
	
	if resetTime then
		local diff = (resetTime + (currentTab == "Daily" and 86400 or 604800)) - os.time()
		if diff < 0 then diff = 0 end
		local h = math.floor(diff / 3600)
		local m = math.floor((diff % 3600) / 60)
		local s = diff % 60
		timerLabel.Text = string.format("Resets in: %02d:%02d:%02d", h, m, s)
	else
		timerLabel.Text = "Resets in: --:--:--"
	end
end)
