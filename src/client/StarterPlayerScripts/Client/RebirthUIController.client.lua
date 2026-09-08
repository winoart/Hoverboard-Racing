--!strict
-- RebirthUIController.client.luau

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RebirthConfig = require(Shared:WaitForChild("RebirthConfig"))

local hoverRemotes = ReplicatedStorage:WaitForChild("HoverboardRemotes")
local requestRebirthRemote = hoverRemotes:WaitForChild("RequestRebirth") :: RemoteFunction

local rebirthButton = nil
local rebirthWindow = nil
local isWindowOpen = false

local function formatDistance(meters: number): string
	if meters >= 1000 then
		return string.format("%.1fkm", meters / 1000)
	else
		return string.format("%dm", meters)
	end
end

local function getRebirthButton(): TextButton?
	if not rebirthButton then
		-- Search for the Rebirth button in PlayerGui
		for _, gui in ipairs(PlayerGui:GetChildren()) do
			if gui:IsA("ScreenGui") then
				local btn = gui:FindFirstChild("Rebirth", true)
				if btn and btn:IsA("TextButton") then
					rebirthButton = btn
					break
				end
			end
		end
	end
	return rebirthButton
end

local function createRebirthWindow()
	if rebirthWindow then return rebirthWindow end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "RebirthWindowGui"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = PlayerGui

	local bg = Instance.new("Frame")
	bg.Name = "Background"
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = Color3.new(0, 0, 0)
	bg.BackgroundTransparency = 0.5
	bg.Visible = false
	bg.Parent = screenGui
	rebirthWindow = bg

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.new(0, 700, 0, 450)
	panel.Position = UDim2.new(0.5, -350, 0.5, -225)
	panel.BackgroundColor3 = Color3.fromRGB(20, 25, 35)
	panel.Parent = bg

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = panel

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(0, 240, 255)
	stroke.Thickness = 3
	stroke.Parent = panel

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 60)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.Text = "REBIRTH"
	title.TextColor3 = Color3.fromRGB(0, 240, 255)
	title.TextSize = 40
	title.Parent = panel

	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseBtn"
	closeBtn.Size = UDim2.new(0, 50, 0, 50)
	closeBtn.Position = UDim2.new(1, -60, 0, 10)
	closeBtn.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.Text = "X"
	closeBtn.TextColor3 = Color3.new(1, 1, 1)
	closeBtn.TextSize = 24
	closeBtn.Parent = panel
	
	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 8)
	closeCorner.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(function()
		bg.Visible = false
		isWindowOpen = false
	end)

	-- Info Container
	local infoContainer = Instance.new("Frame")
	infoContainer.Name = "InfoContainer"
	infoContainer.Size = UDim2.new(1, -40, 0, 250)
	infoContainer.Position = UDim2.new(0, 20, 0, 80)
	infoContainer.BackgroundTransparency = 1
	infoContainer.Parent = panel

	-- Layout: Prev, Current, Next
	local function createCard(name, pos, color)
		local card = Instance.new("Frame")
		card.Name = name
		card.Size = UDim2.new(0, 200, 1, 0)
		card.Position = pos
		card.BackgroundColor3 = Color3.fromRGB(30, 35, 45)
		card.Parent = infoContainer

		local cCorner = Instance.new("UICorner")
		cCorner.CornerRadius = UDim.new(0, 12)
		cCorner.Parent = card
		
		local cStroke = Instance.new("UIStroke")
		cStroke.Color = color
		cStroke.Thickness = 2
		cStroke.Parent = card

		local rTitle = Instance.new("TextLabel")
		rTitle.Name = "RebirthLevel"
		rTitle.Size = UDim2.new(1, 0, 0, 40)
		rTitle.Position = UDim2.new(0, 0, 0, 10)
		rTitle.BackgroundTransparency = 1
		rTitle.Font = Enum.Font.GothamBold
		rTitle.Text = "환생 X"
		rTitle.TextColor3 = color
		rTitle.TextSize = 28
		rTitle.Parent = card
		
		local benefit = Instance.new("TextLabel")
		benefit.Name = "BenefitText"
		benefit.Size = UDim2.new(1, -20, 0, 150)
		benefit.Position = UDim2.new(0, 10, 0, 60)
		benefit.BackgroundTransparency = 1
		benefit.Font = Enum.Font.GothamMedium
		benefit.Text = "이점 내역"
		benefit.TextColor3 = Color3.new(1, 1, 1)
		benefit.TextSize = 18
		benefit.TextWrapped = true
		benefit.TextYAlignment = Enum.TextYAlignment.Top
		benefit.Parent = card

		return card
	end

	createCard("PrevCard", UDim2.new(0, 0, 0, 0), Color3.fromRGB(150, 150, 150))
	createCard("CurrentCard", UDim2.new(0.5, -100, 0, 0), Color3.fromRGB(255, 215, 0))
	createCard("NextCard", UDim2.new(1, -200, 0, 0), Color3.fromRGB(0, 240, 255))
	
	-- Arrows
	local arrow1 = Instance.new("TextLabel")
	arrow1.Size = UDim2.new(0, 60, 0, 60)
	arrow1.Position = UDim2.new(0, 200, 0.5, -30)
	arrow1.BackgroundTransparency = 1
	arrow1.Font = Enum.Font.GothamBlack
	arrow1.Text = "→"
	arrow1.TextColor3 = Color3.new(1, 1, 1)
	arrow1.TextSize = 50
	arrow1.Parent = infoContainer
	
	local arrow2 = arrow1:Clone()
	arrow2.Position = UDim2.new(1, -260, 0.5, -30)
	arrow2.Parent = infoContainer

	-- Action Button
	local doRebirthBtn = Instance.new("TextButton")
	doRebirthBtn.Name = "DoRebirthBtn"
	doRebirthBtn.Size = UDim2.new(0, 300, 0, 60)
	doRebirthBtn.Position = UDim2.new(0.5, -150, 1, -80)
	doRebirthBtn.BackgroundColor3 = Color3.fromRGB(0, 240, 255)
	doRebirthBtn.Font = Enum.Font.GothamBlack
	doRebirthBtn.Text = "환생하기"
	doRebirthBtn.TextColor3 = Color3.new(0, 0, 0)
	doRebirthBtn.TextSize = 30
	doRebirthBtn.Parent = panel

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 12)
	btnCorner.Parent = doRebirthBtn
	
	doRebirthBtn.MouseButton1Click:Connect(function()
		local success, msg = requestRebirthRemote:InvokeServer()
		if success then
			doRebirthBtn.Text = "환생 성공!"
			doRebirthBtn.BackgroundColor3 = Color3.fromRGB(0, 255, 100)
			task.delay(1.5, function()
				if rebirthWindow then rebirthWindow.Visible = false end
				isWindowOpen = false
			end)
		else
			doRebirthBtn.Text = msg
			doRebirthBtn.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
			task.delay(1.5, function()
				doRebirthBtn.Text = "환생하기"
				doRebirthBtn.BackgroundColor3 = Color3.fromRGB(0, 240, 255)
			end)
		end
	end)

	return rebirthWindow
end

local function updateRebirthWindow()
	if not rebirthWindow then return end
	local panel = rebirthWindow:FindFirstChild("Panel")
	if not panel then return end
	
	local infoContainer = panel:FindFirstChild("InfoContainer")
	local doRebirthBtn = panel:FindFirstChild("DoRebirthBtn") :: TextButton
	if not infoContainer or not doRebirthBtn then return end
	
	local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
	local currentRebirths = 0
	local currentDist = 0
	if leaderstats then
		local rVal = leaderstats:FindFirstChild("Rebirths") :: IntValue
		if rVal then currentRebirths = rVal.Value end
		
		local dVal = leaderstats:FindFirstChild("Distance") :: IntValue
		if dVal then currentDist = dVal.Value end
	end
	
	local function setCardData(cardName: string, rLevel: number, isActive: boolean)
		local card = infoContainer:FindFirstChild(cardName)
		if not card then return end
		
		local rTitle = card:FindFirstChild("RebirthLevel") :: TextLabel
		local benefitText = card:FindFirstChild("BenefitText") :: TextLabel
		
		if rLevel < 0 then
			rTitle.Text = "-"
			benefitText.Text = "기록 없음"
			return
		end
		
		local rData = RebirthConfig.GetRebirthData(rLevel)
		rTitle.Text = "환생 " .. rLevel
		
		local bText = ""
		if rLevel == 0 then
			bText = "기본 부스터 스피드"
		else
			bText = string.format("부스터 스피드 +%.1f", rData.BoostSpeedBonus)
			if isActive then
				bText = bText .. string.format("\n\n요구 거리: %s", formatDistance(rData.RequiredDistance))
			end
		end
		benefitText.Text = bText
	end
	
	setCardData("PrevCard", currentRebirths - 1, false)
	setCardData("CurrentCard", currentRebirths, false)
	
	local nextRebirthData = RebirthConfig.GetNextRebirthData(currentRebirths)
	if nextRebirthData then
		setCardData("NextCard", currentRebirths + 1, true)
		
		if currentDist >= nextRebirthData.RequiredDistance then
			doRebirthBtn.Text = "환생하기"
			doRebirthBtn.BackgroundColor3 = Color3.fromRGB(0, 240, 255)
			doRebirthBtn.Active = true
		else
			doRebirthBtn.Text = string.format("거리 부족 (%s / %s)", formatDistance(currentDist), formatDistance(nextRebirthData.RequiredDistance))
			doRebirthBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
			doRebirthBtn.Active = false
		end
	else
		setCardData("NextCard", -1, false)
		doRebirthBtn.Text = "최대 환생 도달!"
		doRebirthBtn.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
		doRebirthBtn.Active = false
	end
end

-- 알람 마커 관리
local notificationMarker: Frame? = nil

local function updateNotification()
	local btn = getRebirthButton()
	if not btn then return end
	
	local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
	if not leaderstats then return end
	
	local currentRebirths = (leaderstats:FindFirstChild("Rebirths") :: IntValue).Value
	local currentDist = (leaderstats:FindFirstChild("Distance") :: IntValue).Value
	
	local nextData = RebirthConfig.GetNextRebirthData(currentRebirths)
	local canRebirth = nextData and (currentDist >= nextData.RequiredDistance)
	
	if canRebirth then
		if not notificationMarker then
			notificationMarker = Instance.new("Frame")
			notificationMarker.Name = "NotiMarker"
			notificationMarker.Size = UDim2.new(0, 20, 0, 20)
			notificationMarker.Position = UDim2.new(1, -10, 0, -10)
			notificationMarker.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
			notificationMarker.Parent = btn
			
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(1, 0)
			corner.Parent = notificationMarker
			
			local stroke = Instance.new("UIStroke")
			stroke.Color = Color3.new(1, 1, 1)
			stroke.Thickness = 2
			stroke.Parent = notificationMarker
		end
		notificationMarker.Visible = true
	else
		if notificationMarker then
			notificationMarker.Visible = false
		end
	end
end

RunService.RenderStepped:Connect(function()
	local btn = getRebirthButton()
	if btn and not btn:GetAttribute("Connected") then
		btn:SetAttribute("Connected", true)
		btn.MouseButton1Click:Connect(function()
			local win = createRebirthWindow()
			updateRebirthWindow()
			win.Visible = not win.Visible
			isWindowOpen = win.Visible
		end)
	end
	
	-- 주기적으로 알림 마커 확인
	if os.clock() % 1 < 0.05 then
		updateNotification()
		if isWindowOpen then
			updateRebirthWindow()
		end
	end
end)
