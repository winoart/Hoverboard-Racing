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
	-- 만약 기존에 캐싱한 버튼이 삭제(Destroy)되었다면 캐시를 초기화합니다.
	if rebirthButton and rebirthButton.Parent == nil then
		print("🐛 [RebirthUI] 기존 환생 버튼이 파괴되었습니다! (리스폰 추정) 다시 찾습니다.")
		rebirthButton = nil
	end

	if not rebirthButton then
		-- 고정 경로에서 버튼 찾기
		local rebirthGui = PlayerGui:FindFirstChild("Rebirth")
		if rebirthGui then
			local btn = rebirthGui:FindFirstChild("Rebirth")
			if btn and btn:IsA("TextButton") then
				print("✅ [RebirthUI] 새로운 환생 버튼을 성공적으로 찾았습니다!")
				rebirthButton = btn
			end
		end
	end
	return rebirthButton
end

local function createRebirthWindow()
	if rebirthWindow then
		if rebirthWindow.Parent and rebirthWindow.Parent.Parent then
			return rebirthWindow
		else
			print("🐛 [RebirthUI] 기존 환생 창이 파괴되었습니다! 새로 생성합니다.")
			rebirthWindow = nil
		end
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "RebirthWindowGui"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = PlayerGui

	local bg = Instance.new("Frame")
	bg.Name = "Background"
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = Color3.new(0, 0, 0)
	bg.BackgroundTransparency = 1 -- Fully transparent to remove the black overlay
	bg.Visible = false
	bg.Parent = screenGui
	rebirthWindow = bg

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.new(0, 740, 0, 480)
	panel.Position = UDim2.new(0.5, -370, 0.5, -240)
	panel.BackgroundColor3 = Color3.fromRGB(150, 240, 255)
	panel.BackgroundTransparency = 0.5
	panel.Parent = bg

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 24)
	corner.Parent = panel

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Thickness = 8
	stroke.Parent = panel
	
	local titleFrame = Instance.new("Frame")
	titleFrame.Name = "TitleFrame"
	titleFrame.Size = UDim2.new(1, -60, 0, 60)
	titleFrame.Position = UDim2.new(0, 30, 0, 20)
	titleFrame.BackgroundColor3 = Color3.fromRGB(40, 180, 255)
	titleFrame.BorderSizePixel = 0
	titleFrame.ZIndex = 2
	titleFrame.Parent = panel
	
	local titleCorner = Instance.new("UICorner")
	titleCorner.CornerRadius = UDim.new(0.5, 0)
	titleCorner.Parent = titleFrame
	
	local titleFrameStroke = Instance.new("UIStroke")
	titleFrameStroke.Color = Color3.fromRGB(0, 0, 0)
	titleFrameStroke.Thickness = 6
	titleFrameStroke.Parent = titleFrame

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 1, 0)
	title.BackgroundTransparency = 1
	title.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	title.Text = "REBIRTH"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextSize = 42
	title.ZIndex = 3
	title.Parent = titleFrame
	
	local titleTextStroke = Instance.new("UIStroke")
	titleTextStroke.Color = Color3.fromRGB(0, 0, 0)
	titleTextStroke.Thickness = 3
	titleTextStroke.Parent = title

	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseBtn"
	closeBtn.Size = UDim2.new(0, 44, 0, 44)
	closeBtn.Position = UDim2.new(1, -22, 0, -22)
	closeBtn.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
	closeBtn.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	closeBtn.Text = "X"
	closeBtn.TextColor3 = Color3.new(1, 1, 1)
	closeBtn.TextSize = 28
	closeBtn.ZIndex = 5
	closeBtn.Parent = panel
	
	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(1, 0)
	closeCorner.Parent = closeBtn
	
	local closeStroke = Instance.new("UIStroke")
	closeStroke.Color = Color3.fromRGB(0, 0, 0)
	closeStroke.Thickness = 4
	closeStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	closeStroke.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(function()
		bg.Visible = false
		isWindowOpen = false
	end)

	-- Info Container
	local infoContainer = Instance.new("Frame")
	infoContainer.Name = "InfoContainer"
	infoContainer.Size = UDim2.new(1, -60, 0, 250)
	infoContainer.Position = UDim2.new(0, 30, 0, 100)
	infoContainer.BackgroundTransparency = 1
	infoContainer.Parent = panel

	-- Layout: Prev, Current, Next
	local function createCard(name, pos, color)
		local card = Instance.new("Frame")
		card.Name = name
		card.Size = UDim2.new(0, 210, 1, 0)
		card.Position = pos
		card.BackgroundColor3 = color
		card.Parent = infoContainer

		local cCorner = Instance.new("UICorner")
		cCorner.CornerRadius = UDim.new(0, 16)
		cCorner.Parent = card
		
		local cStroke = Instance.new("UIStroke")
		cStroke.Color = Color3.fromRGB(0, 0, 0)
		cStroke.Thickness = 4
		cStroke.Parent = card
		
		-- UIGradient Stripes
		local patternBg = Instance.new("Frame", card)
		patternBg.Size = UDim2.new(1, 0, 1, 0)
		patternBg.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		patternBg.BorderSizePixel = 0
		Instance.new("UICorner", patternBg).CornerRadius = UDim.new(0, 16)
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

		local rTitle = Instance.new("TextLabel")
		rTitle.Name = "RebirthLevel"
		rTitle.Size = UDim2.new(1, 0, 0, 40)
		rTitle.Position = UDim2.new(0, 0, 0, 15)
		rTitle.BackgroundTransparency = 1
		rTitle.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
		rTitle.Text = "Rebirth X"
		rTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
		rTitle.TextSize = 32
		rTitle.ZIndex = 2
		rTitle.Parent = card
		
		local rtStroke = Instance.new("UIStroke")
		rtStroke.Color = Color3.fromRGB(0, 0, 0)
		rtStroke.Thickness = 3
		rtStroke.Parent = rTitle
		
		local benefit = Instance.new("TextLabel")
		benefit.Name = "BenefitText"
		benefit.Size = UDim2.new(1, -20, 0, 150)
		benefit.Position = UDim2.new(0, 10, 0, 70)
		benefit.BackgroundTransparency = 1
		benefit.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
		benefit.Text = "Benefit Details"
		benefit.TextColor3 = Color3.new(1, 1, 1)
		benefit.TextSize = 22
		benefit.TextWrapped = true
		benefit.TextYAlignment = Enum.TextYAlignment.Center
		benefit.ZIndex = 2
		benefit.Parent = card
		
		local bStroke = Instance.new("UIStroke")
		bStroke.Color = Color3.fromRGB(0, 0, 0)
		bStroke.Thickness = 2
		bStroke.Parent = benefit

		return card
	end

	createCard("PrevCard", UDim2.new(0, 0, 0, 0), Color3.fromRGB(70, 80, 90))
	createCard("CurrentCard", UDim2.new(0.5, -105, 0, 0), Color3.fromRGB(255, 140, 20))
	createCard("NextCard", UDim2.new(1, -210, 0, 0), Color3.fromRGB(40, 180, 255))
	
	-- Arrows
	local arrow1 = Instance.new("TextLabel")
	arrow1.Size = UDim2.new(0, 50, 0, 60)
	arrow1.Position = UDim2.new(0, 215, 0.5, -30)
	arrow1.BackgroundTransparency = 1
	arrow1.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	arrow1.Text = "→"
	arrow1.TextColor3 = Color3.new(1, 1, 1)
	arrow1.TextSize = 50
	arrow1.Parent = infoContainer
	
	local a1Stroke = Instance.new("UIStroke")
	a1Stroke.Color = Color3.fromRGB(0, 0, 0)
	a1Stroke.Thickness = 4
	a1Stroke.Parent = arrow1
	
	local arrow2 = arrow1:Clone()
	arrow2.Position = UDim2.new(1, -265, 0.5, -30)
	arrow2.Parent = infoContainer

	-- Action Button
	local doRebirthBtn = Instance.new("TextButton")
	doRebirthBtn.Name = "DoRebirthBtn"
	doRebirthBtn.Size = UDim2.new(0, 320, 0, 70)
	doRebirthBtn.Position = UDim2.new(0.5, -160, 1, -95)
	doRebirthBtn.BackgroundColor3 = Color3.fromRGB(100, 220, 110)
	doRebirthBtn.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	doRebirthBtn.Text = "REBIRTH"
	doRebirthBtn.TextColor3 = Color3.new(1, 1, 1)
	doRebirthBtn.TextSize = 36
	doRebirthBtn.Parent = panel

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 20)
	btnCorner.Parent = doRebirthBtn
	
	local btnStroke = Instance.new("UIStroke")
	btnStroke.Color = Color3.fromRGB(0, 0, 0)
	btnStroke.Thickness = 6
	btnStroke.Parent = doRebirthBtn
	
	local btnTextStroke = Instance.new("UIStroke")
	btnTextStroke.Color = Color3.fromRGB(0, 0, 0)
	btnTextStroke.Thickness = 3
	btnTextStroke.Parent = doRebirthBtn
	
	doRebirthBtn.MouseButton1Click:Connect(function()
		local success, msg = requestRebirthRemote:InvokeServer()
		if success then
			doRebirthBtn.Text = "REBIRTH SUCCESS!"
			doRebirthBtn.BackgroundColor3 = Color3.fromRGB(50, 255, 50)
			task.delay(1.5, function()
				if rebirthWindow then rebirthWindow.Visible = false end
				isWindowOpen = false
			end)
		else
			-- doRebirthBtn.Text = msg -- Removed so it just says "환생하기" as requested by user
			doRebirthBtn.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
			task.delay(1.5, function()
				doRebirthBtn.Text = "REBIRTH"
				doRebirthBtn.BackgroundColor3 = Color3.fromRGB(100, 220, 110)
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
			benefitText.Text = "No Record"
			return
		end
		
		local rData = RebirthConfig.GetRebirthData(rLevel)
		rTitle.Text = "Rebirth " .. rLevel
		
		local bText = ""
		if rLevel == 0 then
			bText = "Base\nBooster Speed"
		else
			bText = string.format("Booster Speed\n+%.1f", rData.BoostSpeedBonus)
			if isActive then
				bText = bText .. string.format("\n\nReq. Distance:\n%s", formatDistance(rData.RequiredDistance))
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
			doRebirthBtn.Text = "REBIRTH"
			doRebirthBtn.BackgroundColor3 = Color3.fromRGB(100, 220, 110)
			doRebirthBtn.Active = true
		else
			doRebirthBtn.Text = "REBIRTH"
			doRebirthBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
			doRebirthBtn.Active = false
		end
	else
		setCardData("NextCard", -1, false)
		doRebirthBtn.Text = "MAX REBIRTH REACHED!"
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

task.spawn(function()
	while task.wait(1) do
		local btn = getRebirthButton()
		if btn and not btn:GetAttribute("Connected") then
			print("🔗 [RebirthUI] 환생 버튼에 클릭 이벤트를 연결합니다!")
			btn:SetAttribute("Connected", true)
			btn.MouseButton1Click:Connect(function()
				print("🖱️ [RebirthUI] 환생 버튼 클릭됨!")
				local win = createRebirthWindow()
				
				-- 리스폰 후 UI가 가려지거나 비활성화(Enabled=false)되는 현상 방지
				if win and win.Parent and win.Parent:IsA("ScreenGui") then
					win.Parent.Enabled = true
					win.Parent.DisplayOrder = 999
				end
				
				updateRebirthWindow()
				win.Visible = not win.Visible
				isWindowOpen = win.Visible
				
				print("🪟 [RebirthUI] 창 상태 변경 - Visible:", win.Visible, "ScreenGui Enabled:", win.Parent and win.Parent.Enabled)
			end)
		end
	end
end)

RunService.RenderStepped:Connect(function()
	-- 주기적으로 알림 마커 확인
	if os.clock() % 1 < 0.05 then
		updateNotification()
		if isWindowOpen then
			updateRebirthWindow()
		end
	end
end)
