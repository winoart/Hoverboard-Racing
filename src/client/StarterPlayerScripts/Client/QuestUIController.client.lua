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

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
tabLayout.Padding = UDim.new(0, 10)
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.Parent = tabContainer

local starterTab = Instance.new("TextButton")
starterTab.Name = "StarterTab"
starterTab.LayoutOrder = 1
starterTab.Size = UDim2.new(0.333, -7, 1, 0)
starterTab.BackgroundColor3 = Color3.fromRGB(255, 140, 40)
starterTab.Text = "Starter"
starterTab.Font = Enum.Font.FredokaOne
starterTab.TextSize = 24
starterTab.TextColor3 = Color3.fromRGB(255, 255, 255)
starterTab.Parent = tabContainer

local starterCorner = Instance.new("UICorner")
starterCorner.CornerRadius = UDim.new(0, 12)
starterCorner.Parent = starterTab
local starterStroke = Instance.new("UIStroke")
starterStroke.Color = Color3.fromRGB(0, 0, 0)
starterStroke.Thickness = 4
starterStroke.Parent = starterTab

local dailyTab = Instance.new("TextButton")
dailyTab.Name = "DailyTab"
dailyTab.LayoutOrder = 2
dailyTab.Size = UDim2.new(0.333, -7, 1, 0)
dailyTab.BackgroundColor3 = Color3.fromRGB(220, 225, 235)
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
weeklyTab.Name = "WeeklyTab"
weeklyTab.LayoutOrder = 3
weeklyTab.Size = UDim2.new(0.333, -7, 1, 0)
weeklyTab.BackgroundColor3 = Color3.fromRGB(220, 225, 235)
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

local currentTab = "Starter"
local cachedQuestData = nil

-- Gold Animation Helpers
local function getGoldTarget(): GuiObject?
	local hud = PlayerGui:FindFirstChild("GoldDisplayHUD")
	if hud then
		local frame = hud:FindFirstChild("GoldFrame")
		if frame then
			return frame:FindFirstChild("GoldIcon") or frame:FindFirstChild("GoldTextLabel")
		end
	end
	return nil
end

local function spawnGoldEffect(startPos: Vector2, target: GuiObject?, amount: number)
	if not target or not questScreenGui then return end
	
	local targetPos = UDim2.new(0, target.AbsolutePosition.X + (target.AbsoluteSize.X / 2), 0, target.AbsolutePosition.Y + (target.AbsoluteSize.Y / 2))
	
	-- 골드 개수 (기본 10개)
	local coinCount = 10
	
	for i = 1, coinCount do
		local icon = Instance.new("ImageLabel")
		icon.Size = UDim2.new(0, 50, 0, 50)
		icon.Position = UDim2.new(0, startPos.X, 0, startPos.Y)
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.BackgroundTransparency = 1
		icon.Image = "rbxassetid://17368060122"
		icon.ZIndex = 100
		
		icon.Parent = questScreenGui
		
		-- 1단계: 주변으로 튀어나오기 (Pop-out)
		local randomX = startPos.X + math.random(-60, 60)
		local randomY = startPos.Y + math.random(-60, 60)
		local popPos = UDim2.new(0, randomX, 0, randomY)
		
		local popTweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local popTween = TweenService:Create(icon, popTweenInfo, {
			Position = popPos,
			Size = UDim2.new(0, 60, 0, 60),
			Rotation = math.random(-45, 45)
		})
		
		-- 2단계: 타겟으로 가속하며 날아가기 (Fly-in)
		local flyTweenInfo = TweenInfo.new(0.6, Enum.EasingStyle.Cubic, Enum.EasingDirection.In)
		local flyTween = TweenService:Create(icon, flyTweenInfo, {
			Position = targetPos,
			Size = UDim2.new(0, 30, 0, 30),
			Rotation = 0
		})
		
		popTween.Completed:Connect(function()
			flyTween:Play()
		end)
		
		flyTween.Completed:Connect(function()
			icon:Destroy()
			
			-- 도착 시 골드 아이콘 흔들림 효과 (무한 커짐 방지)
			if target and target.Parent then
				local uiScale = target:FindFirstChild("GoldBounceScale")
				if not uiScale then
					uiScale = Instance.new("UIScale")
					uiScale.Name = "GoldBounceScale"
					uiScale.Scale = 1.0
					uiScale.Parent = target
				end
				
				TweenService:Create(uiScale, TweenInfo.new(0.05, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 1, true), {
					Scale = 1.3
				}):Play()
			end
		end)
		
		task.delay(math.random() * 0.2, function()
			popTween:Play()
		end)
	end
end

local function createQuestCard(questInfo, config, category: string)
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
			local success, result = claimQuestRemote:InvokeServer(questInfo.id, category)
			if success then
				questInfo.claimed = true
				if updateQuestNotification then
					updateQuestNotification()
				end
				
				-- 💥 골드 애니메이션 재생!
				local goldTarget = getGoldTarget()
				if goldTarget then
					local hud = PlayerGui:FindFirstChild("GoldDisplayHUD")
					if hud then
						hud:SetAttribute("PauseGoldUpdate", true)
					end
					
					local startPos = Vector2.new(claimBtn.AbsolutePosition.X + (claimBtn.AbsoluteSize.X / 2), claimBtn.AbsolutePosition.Y + (claimBtn.AbsoluteSize.Y / 2))
					spawnGoldEffect(startPos, goldTarget, config.reward)
					
					task.delay(0.5, function()
						if hud then
							hud:SetAttribute("PauseGoldUpdate", false)
						end
					end)
					
					-- 골드가 날아가는 시간을 주기 위해 1초 뒤에 UI 갱신
					task.delay(1.0, function()
						refreshUI()
					end)
				else
					refreshUI()
				end
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
	
	local list = nil
	local cfgList = nil
	if currentTab == "Starter" then
		list = cachedQuestData.StarterQuests
		cfgList = QuestConfig.Starter
	elseif currentTab == "Weekly" then
		list = cachedQuestData.WeeklyQuests
		cfgList = QuestConfig.Weekly
	else
		list = cachedQuestData.DailyQuests
		cfgList = QuestConfig.Daily
	end
	
	if list and cfgList then
		for _, q in ipairs(list) do
			local cfg
			for _, c in ipairs(cfgList) do
				if c.id == q.id then cfg = c; break end
			end
			if cfg then
				local card = createQuestCard(q, cfg, currentTab)
				card.Parent = listContainer
			end
		end
	end
end

local userSelectedTab = false

local function selectTab(tabName)
	currentTab = tabName
	starterTab.BackgroundColor3 = (tabName == "Starter") and Color3.fromRGB(255, 140, 40) or Color3.fromRGB(220, 225, 235)
	dailyTab.BackgroundColor3 = (tabName == "Daily") and Color3.fromRGB(255, 200, 50) or Color3.fromRGB(220, 225, 235)
	weeklyTab.BackgroundColor3 = (tabName == "Weekly") and Color3.fromRGB(70, 185, 255) or Color3.fromRGB(220, 225, 235)
	refreshUI()
end

starterTab.MouseButton1Click:Connect(function()
	userSelectedTab = true
	selectTab("Starter")
end)
dailyTab.MouseButton1Click:Connect(function()
	userSelectedTab = true
	selectTab("Daily")
end)
weeklyTab.MouseButton1Click:Connect(function()
	userSelectedTab = true
	selectTab("Weekly")
end)

closeBtn.MouseButton1Click:Connect(function()
	mainPanel.Visible = false
end)

local HttpService = game:GetService("HttpService")

local cachedQuestButton: GuiButton? = nil

local function getQuestButton(): GuiButton?
	if cachedQuestButton and cachedQuestButton.Parent then
		return cachedQuestButton
	end
	
	local questNode = PlayerGui:FindFirstChild("Quest")
	if questNode then
		if questNode:IsA("GuiButton") then
			cachedQuestButton = questNode
			return questNode
		elseif questNode:IsA("ScreenGui") or questNode:IsA("Frame") then
			for _, desc in ipairs(questNode:GetDescendants()) do
				if desc:IsA("GuiButton") then
					cachedQuestButton = desc
					return desc
				end
			end
		end
	end
	
	local fallback = questScreenGui:FindFirstChild("FallbackQuestBtn") :: GuiButton?
	if fallback then
		cachedQuestButton = fallback
		return fallback
	end
	
	return nil
end

local function hasClaimableQuests(): boolean
	if not cachedQuestData then return false end
	local categories = {
		cachedQuestData.StarterQuests,
		cachedQuestData.DailyQuests,
		cachedQuestData.WeeklyQuests,
	}
	for _, list in ipairs(categories) do
		if list then
			for _, q in ipairs(list) do
				if q.completed and not q.claimed then
					return true
				end
			end
		end
	end
	return false
end

local questNotiMarker: Frame? = nil

local function updateQuestNotification()
	local btn = getQuestButton()
	if not btn then return end
	
	local canClaim = hasClaimableQuests()
	
	if canClaim then
		if not questNotiMarker or questNotiMarker.Parent ~= btn then
			if questNotiMarker then questNotiMarker:Destroy() end
			questNotiMarker = Instance.new("Frame")
			questNotiMarker.Name = "NotiMarker"
			questNotiMarker.Size = UDim2.new(0, 20, 0, 20)
			questNotiMarker.Position = UDim2.new(1, -10, 0, -10)
			questNotiMarker.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
			questNotiMarker.ZIndex = 10
			questNotiMarker.Parent = btn
			
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(1, 0)
			corner.Parent = questNotiMarker
			
			local stroke = Instance.new("UIStroke")
			stroke.Color = Color3.new(1, 1, 1)
			stroke.Thickness = 2
			stroke.Parent = questNotiMarker
		end
		questNotiMarker.Visible = true
	else
		if questNotiMarker then
			questNotiMarker.Visible = false
		end
	end
end

local function loadData()
	task.spawn(function()
		local qStr = LocalPlayer:WaitForChild("QuestDataJSON", 5)
		if qStr and qStr.Value and qStr.Value ~= "" and qStr.Value ~= "{}" then
			local success, decoded = pcall(function() return HttpService:JSONDecode(qStr.Value) end)
			if success and decoded then
				cachedQuestData = decoded
				if not userSelectedTab and cachedQuestData.StarterQuests then
					local allStarterClaimed = true
					for _, q in ipairs(cachedQuestData.StarterQuests) do
						if not q.claimed then
							allStarterClaimed = false
							break
						end
					end
					if allStarterClaimed then
						currentTab = "Daily"
						selectTab("Daily")
					else
						currentTab = "Starter"
						selectTab("Starter")
					end
				end
			end
		end
		refreshUI()
		updateQuestNotification()
	end)
end

local function bindToQuestButton(): boolean
	local btn = getQuestButton()
	if not btn then return false end
	
	if not btn:GetAttribute("IsQuestBound") then
		btn:SetAttribute("IsQuestBound", true)
		btn.MouseButton1Click:Connect(function()
			mainPanel.Visible = not mainPanel.Visible
			if mainPanel.Visible then
				loadData()
			end
		end)
	end
	return true
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
			fallbackBtn.Name = "FallbackQuestBtn"
			fallbackBtn.Size = UDim2.new(0, 80, 0, 80)
			fallbackBtn.Position = UDim2.new(0, 20, 0.5, 0)
			fallbackBtn.Text = "Quests"
			fallbackBtn.Parent = questScreenGui
			bindToQuestButton()
		end
	end)
end

-- 주기적 알림 갱신 & 버튼 재연결 (리스폰 대응)
task.spawn(function()
	while task.wait(1) do
		bindToQuestButton()
		updateQuestNotification()
	end
end)

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
	
	if currentTab == "Starter" then
		local allClaimed = true
		local completedCount = 0
		local totalCount = (cachedQuestData.StarterQuests and #cachedQuestData.StarterQuests) or 4
		if cachedQuestData.StarterQuests then
			for _, q in ipairs(cachedQuestData.StarterQuests) do
				if q.claimed then
					completedCount += 1
				else
					allClaimed = false
				end
			end
		else
			allClaimed = false
		end
		
		if allClaimed and totalCount > 0 then
			timerLabel.Text = "🎉 ALL STARTER QUESTS COMPLETED! Great job, Rider!"
			timerLabel.TextColor3 = Color3.fromRGB(20, 160, 60)
		else
			timerLabel.Text = string.format("✨ Starter Challenge: %d / %d Claimed", completedCount, totalCount)
			timerLabel.TextColor3 = Color3.fromRGB(30, 30, 30)
		end
		return
	end
	
	timerLabel.TextColor3 = Color3.fromRGB(30, 30, 30)
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

-- =========================================================================
-- 📱 RESPONSIVE UI SCALING
-- =========================================================================
local uiScale = Instance.new("UIScale", mainPanel)

local function updateResponsiveScale()
	local viewport = workspace.CurrentCamera.ViewportSize
	if viewport.X == 0 or viewport.Y == 0 then return end
	local scale = math.min(viewport.X / 1280, viewport.Y / 720)
	uiScale.Scale = math.clamp(scale, 0.4, 1.1)
end

local resizeConn = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveScale)
updateResponsiveScale()
task.delay(0.1, updateResponsiveScale)

questScreenGui.Destroying:Connect(function()
	if resizeConn then resizeConn:Disconnect() end
end)
