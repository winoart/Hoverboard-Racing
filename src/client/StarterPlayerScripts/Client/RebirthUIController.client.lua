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

local rebirthButton = nil
local rebirthWindow = nil
local isWindowOpen = false

-- 🛹 호버보드 등급 해금 레벨 설정 (StoreConfig와 동기화)
local HOVERBOARD_UNLOCKS = {
	{ level = 1, rarity = "Common", name = "Common", krName = "일반", color = Color3.fromRGB(250, 195, 25), bg = Color3.fromRGB(150, 115, 10) },
	{ level = 10, rarity = "Uncommon", name = "Uncommon", krName = "고급", color = Color3.fromRGB(0, 165, 255), bg = Color3.fromRGB(10, 85, 150) },
	{ level = 50, rarity = "Rare", name = "Rare", krName = "희귀", color = Color3.fromRGB(180, 75, 255), bg = Color3.fromRGB(95, 30, 145) },
	{ level = 90, rarity = "Super Rare", name = "Super Rare", krName = "초희귀", color = Color3.fromRGB(255, 75, 75), bg = Color3.fromRGB(150, 30, 30) },
}

local function getExactUnlock(level: number)
	for _, u in ipairs(HOVERBOARD_UNLOCKS) do
		if u.level == level then return u end
	end
	return nil
end

local function getHighestUnlocked(level: number)
	local highest = HOVERBOARD_UNLOCKS[1]
	for _, u in ipairs(HOVERBOARD_UNLOCKS) do
		if level >= u.level then
			highest = u
		end
	end
	return highest
end

local function getNextUnlock(level: number)
	for _, u in ipairs(HOVERBOARD_UNLOCKS) do
		if u.level > level then
			return u
		end
	end
	return nil
end

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
				print("✅ [LevelUI] 새로운 레벨 버튼을 성공적으로 찾았습니다!")
				local titleLbl = btn:FindFirstChild("TitleText")
				if titleLbl and titleLbl:IsA("TextLabel") then
					titleLbl.Text = "LEVEL"
				end
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
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.new(0.5, 0, 0.5, 0)
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
	title.Text = "LEVEL"
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
	closeBtn.AnchorPoint = Vector2.new(0.5, 0.5)
	closeBtn.Size = UDim2.new(0, 46, 0, 46)
	closeBtn.Position = UDim2.new(1, 0, 0, 0)
	closeBtn.BackgroundColor3 = Color3.fromRGB(255, 75, 75)
	closeBtn.Font = Enum.Font.FredokaOne
	closeBtn.Text = "X"
	closeBtn.TextColor3 = Color3.new(1, 1, 1)
	closeBtn.TextSize = 26
	closeBtn.TextStrokeTransparency = 1
	closeBtn.ZIndex = 25
	closeBtn.Parent = panel
	
	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(1, 0)
	closeCorner.Parent = closeBtn
	
	local closeBorderStroke = Instance.new("UIStroke")
	closeBorderStroke.Name = "BorderStroke"
	closeBorderStroke.Color = Color3.fromRGB(0, 0, 0)
	closeBorderStroke.Thickness = 4.0
	closeBorderStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	closeBorderStroke.Parent = closeBtn

	local closeTextStroke = Instance.new("UIStroke")
	closeTextStroke.Name = "TextStroke"
	closeTextStroke.Color = Color3.fromRGB(0, 0, 0)
	closeTextStroke.Thickness = 3.0
	closeTextStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	closeTextStroke.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(function()
		bg.Visible = false
		isWindowOpen = false
	end)

	-- Info Container
	local infoContainer = Instance.new("Frame")
	infoContainer.Name = "InfoContainer"
	infoContainer.Size = UDim2.new(1, -60, 0, 240)
	infoContainer.Position = UDim2.new(0, 30, 0, 95)
	infoContainer.BackgroundTransparency = 1
	infoContainer.Parent = panel

	-- Layout: Prev, Current, Next
	local function createCard(name, pos, color, imageId)
		local card = Instance.new("Frame")
		card.Name = name
		card.Size = UDim2.new(0, 260, 0, 240)
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

		local crest = Instance.new("ImageLabel")
		crest.Name = "CrestImage"
		crest.Size = UDim2.new(0, 140, 0, 140)
		crest.Position = UDim2.new(0.5, -70, 0, -10)
		crest.BackgroundTransparency = 1
		crest.Image = imageId
		crest.ZIndex = 2
		crest.Parent = card

		local rTitle = Instance.new("TextLabel")
		rTitle.Name = "RebirthLevel"
		rTitle.Size = UDim2.new(1, 0, 0, 36)
		rTitle.Position = UDim2.new(0, 0, 0.5, -18)
		rTitle.BackgroundTransparency = 1
		rTitle.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
		rTitle.Text = "X"
		rTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
		rTitle.TextSize = 38
		rTitle.ZIndex = 3
		rTitle.Parent = crest
		
		local rtStroke = Instance.new("UIStroke")
		rtStroke.Color = Color3.fromRGB(0, 0, 0)
		rtStroke.Thickness = 3
		rtStroke.Parent = rTitle
		
		local benefit = Instance.new("TextLabel")
		benefit.Name = "BenefitText"
		benefit.Size = UDim2.new(1, -20, 0, 68)
		benefit.Position = UDim2.new(0, 10, 0, 122)
		benefit.BackgroundTransparency = 1
		benefit.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
		benefit.Text = "Benefit Details"
		benefit.TextColor3 = Color3.new(1, 1, 1)
		benefit.TextSize = 18
		benefit.RichText = true
		benefit.TextWrapped = true
		benefit.TextYAlignment = Enum.TextYAlignment.Center
		benefit.ZIndex = 2
		benefit.Parent = card
		
		local bStroke = Instance.new("UIStroke")
		bStroke.Color = Color3.fromRGB(0, 0, 0)
		bStroke.Thickness = 2
		bStroke.Parent = benefit

		-- 🛹 Hoverboard Unlock Badge under the Level / Benefit
		local unlockBadge = Instance.new("Frame")
		unlockBadge.Name = "UnlockBadge"
		unlockBadge.Size = UDim2.new(1, -20, 0, 34)
		unlockBadge.Position = UDim2.new(0, 10, 0, 194)
		unlockBadge.BackgroundColor3 = Color3.fromRGB(30, 35, 48)
		unlockBadge.ZIndex = 3
		unlockBadge.Parent = card

		local ubCorner = Instance.new("UICorner")
		ubCorner.CornerRadius = UDim.new(0, 8)
		ubCorner.Parent = unlockBadge

		local ubStroke = Instance.new("UIStroke")
		ubStroke.Name = "Stroke"
		ubStroke.Color = Color3.fromRGB(0, 0, 0)
		ubStroke.Thickness = 2
		ubStroke.Parent = unlockBadge

		local ubText = Instance.new("TextLabel")
		ubText.Name = "UnlockText"
		ubText.Size = UDim2.new(1, 0, 1, 0)
		ubText.BackgroundTransparency = 1
		ubText.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
		ubText.Text = ""
		ubText.TextColor3 = Color3.fromRGB(255, 255, 255)
		ubText.TextSize = 13
		ubText.ZIndex = 4
		ubText.Parent = unlockBadge

		local ubtStroke = Instance.new("UIStroke")
		ubtStroke.Color = Color3.fromRGB(0, 0, 0)
		ubtStroke.Thickness = 2
		ubtStroke.Parent = ubText

		return card
	end

	createCard("CurrentCard", UDim2.new(0, 20, 0, 0), Color3.fromRGB(245, 175, 25), "rbxassetid://133639398193053") -- 골드 (Golden)
	createCard("NextCard", UDim2.new(1, -280, 0, 0), Color3.fromRGB(160, 225, 255), "rbxassetid://104751050024730") -- 얼음 (Ice Blue)
	
	-- Arrows
	local arrow1 = Instance.new("TextLabel")
	arrow1.Size = UDim2.new(0, 60, 0, 60)
	arrow1.Position = UDim2.new(0.5, -30, 0.5, -30)
	arrow1.BackgroundTransparency = 1
	arrow1.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	arrow1.Text = "→"
	arrow1.TextColor3 = Color3.new(1, 1, 1)
	arrow1.TextSize = 65
	arrow1.Parent = infoContainer
	
	local a1Stroke = Instance.new("UIStroke")
	a1Stroke.Color = Color3.fromRGB(0, 0, 0)
	a1Stroke.Thickness = 4
	a1Stroke.Parent = arrow1

	-- =========================================================================
	-- 🛹 HOVERBOARD SHOP UNLOCK MILESTONE GUIDE (기존 불필요한 레벨업 버튼 대체)
	-- =========================================================================
	local shopGuideFrame = Instance.new("Frame")
	shopGuideFrame.Name = "ShopGuideFrame"
	shopGuideFrame.Size = UDim2.new(1, -60, 0, 115)
	shopGuideFrame.Position = UDim2.new(0, 30, 0, 345)
	shopGuideFrame.BackgroundColor3 = Color3.fromRGB(24, 30, 44)
	shopGuideFrame.BackgroundTransparency = 0.25
	shopGuideFrame.Parent = panel

	local guideCorner = Instance.new("UICorner")
	guideCorner.CornerRadius = UDim.new(0, 16)
	guideCorner.Parent = shopGuideFrame

	local guideStroke = Instance.new("UIStroke")
	guideStroke.Color = Color3.fromRGB(0, 0, 0)
	guideStroke.Thickness = 4
	guideStroke.Parent = shopGuideFrame

	-- Title Bar inside Guide
	local guideTitle = Instance.new("TextLabel")
	guideTitle.Name = "GuideTitle"
	guideTitle.Size = UDim2.new(1, -20, 0, 22)
	guideTitle.Position = UDim2.new(0, 10, 0, 8)
	guideTitle.BackgroundTransparency = 1
	guideTitle.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	guideTitle.Text = "🛹 호버보드 상점 등급 해금 단계 (Shop Unlocks)"
	guideTitle.TextColor3 = Color3.fromRGB(255, 230, 100)
	guideTitle.TextSize = 16
	guideTitle.Parent = shopGuideFrame

	local gtStroke = Instance.new("UIStroke")
	gtStroke.Color = Color3.fromRGB(0, 0, 0)
	gtStroke.Thickness = 2
	gtStroke.Parent = guideTitle

	-- Badges Container (Horizontal List)
	local badgesContainer = Instance.new("Frame")
	badgesContainer.Name = "BadgesContainer"
	badgesContainer.Size = UDim2.new(1, -16, 0, 42)
	badgesContainer.Position = UDim2.new(0, 8, 0, 34)
	badgesContainer.BackgroundTransparency = 1
	badgesContainer.Parent = shopGuideFrame

	local badgeLayout = Instance.new("UIListLayout")
	badgeLayout.FillDirection = Enum.FillDirection.Horizontal
	badgeLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	badgeLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	badgeLayout.Padding = UDim.new(0, 8)
	badgeLayout.Parent = badgesContainer

	-- Create 4 Rarity Milestone Cards
	for _, unlock in ipairs(HOVERBOARD_UNLOCKS) do
		local badge = Instance.new("Frame")
		badge.Name = "Badge_" .. unlock.rarity
		badge.Size = UDim2.new(0.23, -2, 1, 0)
		badge.BackgroundColor3 = Color3.fromRGB(35, 40, 52)
		badge.Parent = badgesContainer

		local bCorner = Instance.new("UICorner")
		bCorner.CornerRadius = UDim.new(0, 10)
		bCorner.Parent = badge

		local bStroke = Instance.new("UIStroke")
		bStroke.Name = "Stroke"
		bStroke.Color = Color3.fromRGB(0, 0, 0)
		bStroke.Thickness = 2
		bStroke.Parent = badge

		local bLabel = Instance.new("TextLabel")
		bLabel.Name = "BadgeLabel"
		bLabel.Size = UDim2.new(1, 0, 1, 0)
		bLabel.BackgroundTransparency = 1
		bLabel.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
		bLabel.Text = string.format("Lv.%d %s", unlock.level, unlock.name)
		bLabel.TextColor3 = Color3.fromRGB(160, 170, 185)
		bLabel.TextSize = 13
		bLabel.Parent = badge

		local blStroke = Instance.new("UIStroke")
		blStroke.Color = Color3.fromRGB(0, 0, 0)
		blStroke.Thickness = 2
		blStroke.Parent = bLabel
	end

	-- Subtitle Info (Auto Level Up explanation)
	local guideTip = Instance.new("TextLabel")
	guideTip.Name = "GuideTip"
	guideTip.Size = UDim2.new(1, -20, 0, 20)
	guideTip.Position = UDim2.new(0, 10, 1, -24)
	guideTip.BackgroundTransparency = 1
	guideTip.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	guideTip.Text = "⚡ 누적 거리를 채우면 자동 레벨업! 해당 레벨 달성 시 호버보드 상점에서 새 등급 구매 가능"
	guideTip.TextColor3 = Color3.fromRGB(180, 240, 255)
	guideTip.TextSize = 13
	guideTip.Parent = shopGuideFrame

	local gTipStroke = Instance.new("UIStroke")
	gTipStroke.Color = Color3.fromRGB(0, 0, 0)
	gTipStroke.Thickness = 1.5
	gTipStroke.Parent = guideTip

	-- =========================================================================
	-- 📱 RESPONSIVE UI SCALING
	-- =========================================================================
	local uiScale = Instance.new("UIScale", panel)
	local function updateResponsiveScale()
		local viewport = workspace.CurrentCamera.ViewportSize
		if viewport.X == 0 or viewport.Y == 0 then return end
		local scale = math.min(viewport.X / 1280, viewport.Y / 720)
		uiScale.Scale = math.clamp(scale, 0.4, 1.1)
	end
	local resizeConn = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveScale)
	updateResponsiveScale()
	task.delay(0.1, updateResponsiveScale)
	
	screenGui.Destroying:Connect(function()
		if resizeConn then resizeConn:Disconnect() end
	end)

	return rebirthWindow
end

local function updateRebirthWindow()
	if not rebirthWindow then return end
	local panel = rebirthWindow:FindFirstChild("Panel")
	if not panel then return end
	
	local infoContainer = panel:FindFirstChild("InfoContainer")
	local shopGuideFrame = panel:FindFirstChild("ShopGuideFrame")
	if not infoContainer or not shopGuideFrame then return end
	
	local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
	local currentRebirths = 0
	local currentDist = 0
	if leaderstats then
		local rVal = (leaderstats:FindFirstChild("Level") or leaderstats:FindFirstChild("Rebirths")) :: IntValue
		if rVal then currentRebirths = rVal.Value end
		
		local dVal = leaderstats:FindFirstChild("Distance") :: IntValue
		if dVal then currentDist = dVal.Value end
	end
	
	local function setCardData(cardName: string, rLevel: number, isActive: boolean)
		local card = infoContainer:FindFirstChild(cardName)
		if not card then return end
		
		local crest = card:FindFirstChild("CrestImage")
		local rTitle = crest and crest:FindFirstChild("RebirthLevel") :: TextLabel
		local benefitText = card:FindFirstChild("BenefitText") :: TextLabel
		local unlockBadge = card:FindFirstChild("UnlockBadge") :: Frame
		local ubText = unlockBadge and unlockBadge:FindFirstChild("UnlockText") :: TextLabel
		
		if not rTitle or not benefitText or not unlockBadge or not ubText then return end
		
		if rLevel < 0 then
			rTitle.Text = "-"
			benefitText.Text = "최대 레벨 도달!"
			unlockBadge.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
			ubText.Text = "🎉 모든 등급 해금 완료!"
			ubText.TextColor3 = Color3.fromRGB(0, 0, 0)
			return
		end
		
		local rData = RebirthConfig.GetRebirthData(rLevel)
		rTitle.Text = tostring(rLevel)
		
		local bText = ""
		if rLevel == 0 then
			bText = "Base\n<font size=\"20\">Booster Speed</font>"
		else
			if isActive then
				bText = string.format("Booster Speed: <b>+%.1f km/h</b>\nReq. Distance:\n<font size=\"20\"><b>%s</b></font>", rData.BoostSpeedBonus, formatDistance(rData.RequiredDistance))
			else
				bText = string.format("Booster Speed\n<font size=\"26\"><b>+%.1f km/h</b></font>", rData.BoostSpeedBonus)
			end
		end
		benefitText.Text = bText

		-- 🛹 Hoverboard Shop Unlock 안내 (해당 레벨 밑 안내)
		local exactUnlock = getExactUnlock(rLevel)
		if isActive then
			-- NextCard
			if exactUnlock then
				unlockBadge.BackgroundColor3 = exactUnlock.color
				ubText.Text = string.format("🎉 달성 시 [%s] 보드 해금!", exactUnlock.name)
				ubText.TextColor3 = Color3.fromRGB(255, 255, 255)
			else
				local nextU = getNextUnlock(currentRebirths)
				if nextU then
					local remain = nextU.level - currentRebirths
					unlockBadge.BackgroundColor3 = Color3.fromRGB(36, 32, 48)
					ubText.Text = string.format("다음 보드: Lv.%d [%s] (%d Lv)", nextU.level, nextU.name, remain)
					ubText.TextColor3 = Color3.fromRGB(255, 205, 100)
				else
					unlockBadge.BackgroundColor3 = Color3.fromRGB(25, 45, 30)
					ubText.Text = "모든 보드 등급 해금 완료!"
					ubText.TextColor3 = Color3.fromRGB(120, 255, 140)
				end
			end
		else
			-- CurrentCard
			if exactUnlock then
				unlockBadge.BackgroundColor3 = exactUnlock.bg
				ubText.Text = string.format("✨ 샵 [%s] 등급 해금됨!", exactUnlock.name)
				ubText.TextColor3 = Color3.fromRGB(255, 255, 255)
			else
				local highestU = getHighestUnlocked(rLevel)
				unlockBadge.BackgroundColor3 = Color3.fromRGB(28, 36, 52)
				ubText.Text = string.format("🛒 샵 해금: [%s] 등급", highestU.name)
				ubText.TextColor3 = highestU.color
			end
		end
	end
	
	setCardData("CurrentCard", currentRebirths, false)
	
	local nextRebirthData = RebirthConfig.GetNextRebirthData(currentRebirths)
	if nextRebirthData then
		setCardData("NextCard", currentRebirths + 1, true)
	else
		setCardData("NextCard", -1, true)
	end

	-- 하단 4개 마일스톤 뱃지 갱신
	local badgesContainer = shopGuideFrame:FindFirstChild("BadgesContainer")
	if badgesContainer then
		for _, unlock in ipairs(HOVERBOARD_UNLOCKS) do
			local badge = badgesContainer:FindFirstChild("Badge_" .. unlock.rarity) :: Frame?
			if badge then
				local bLabel = badge:FindFirstChild("BadgeLabel") :: TextLabel?
				local bStroke = badge:FindFirstChild("Stroke") :: UIStroke?
				if bLabel then
					if currentRebirths >= unlock.level then
						badge.BackgroundColor3 = unlock.color
						if bStroke then bStroke.Color = Color3.fromRGB(0, 0, 0) end
						bLabel.Text = string.format("✓ Lv.%d %s", unlock.level, unlock.name)
						bLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
					else
						badge.BackgroundColor3 = Color3.fromRGB(32, 36, 46)
						if bStroke then bStroke.Color = Color3.fromRGB(50, 55, 68) end
						bLabel.Text = string.format("🔒 Lv.%d %s", unlock.level, unlock.name)
						bLabel.TextColor3 = Color3.fromRGB(140, 150, 165)
					end
				end
			end
		end
	end
end

-- 알람 마커 관리
local notificationMarker: Frame? = nil

local function updateNotification()
	local btn = getRebirthButton()
	if not btn then return end
	
	local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
	if not leaderstats then return end
	
	local rVal = (leaderstats:FindFirstChild("Level") or leaderstats:FindFirstChild("Rebirths")) :: IntValue?
	local dVal = leaderstats:FindFirstChild("Distance") :: IntValue?
	if not rVal or not dVal then return end
	
	local currentRebirths = rVal.Value
	local currentDist = dVal.Value
	
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
