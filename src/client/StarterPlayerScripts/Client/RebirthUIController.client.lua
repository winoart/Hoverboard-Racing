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

	-- Keypoints for background gradient stripes
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

	-- =========================================================================
	-- 1. 왼쪽: 현재 레벨 (CurrentCard) - 순수하게 방패 & 현재 레벨만 깔끔하게 표시
	-- =========================================================================
	local currentCard = Instance.new("Frame")
	currentCard.Name = "CurrentCard"
	currentCard.Size = UDim2.new(0, 260, 0, 240)
	currentCard.Position = UDim2.new(0, 20, 0, 0)
	currentCard.BackgroundColor3 = Color3.fromRGB(245, 175, 25)
	currentCard.Parent = infoContainer

	local curCorner = Instance.new("UICorner")
	curCorner.CornerRadius = UDim.new(0, 16)
	curCorner.Parent = currentCard
	
	local curStroke = Instance.new("UIStroke")
	curStroke.Color = Color3.fromRGB(0, 0, 0)
	curStroke.Thickness = 4
	curStroke.Parent = currentCard
	
	local curPattern = Instance.new("Frame", currentCard)
	curPattern.Size = UDim2.new(1, 0, 1, 0)
	curPattern.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	curPattern.BorderSizePixel = 0
	Instance.new("UICorner", curPattern).CornerRadius = UDim.new(0, 16)
	local curGrad = Instance.new("UIGradient", curPattern)
	curGrad.Rotation = 45
	curGrad.Transparency = NumberSequence.new(keypoints)

	local curCrest = Instance.new("ImageLabel")
	curCrest.Name = "CrestImage"
	curCrest.Size = UDim2.new(0, 170, 0, 170)
	curCrest.Position = UDim2.new(0.5, -85, 0.5, -85)
	curCrest.BackgroundTransparency = 1
	curCrest.Image = "rbxassetid://133639398193053" -- Golden Crest
	curCrest.ZIndex = 2
	curCrest.Parent = currentCard

	local curLvlTitle = Instance.new("TextLabel")
	curLvlTitle.Name = "RebirthLevel"
	curLvlTitle.Size = UDim2.new(1, 0, 0, 48)
	curLvlTitle.Position = UDim2.new(0, 0, 0.5, -20)
	curLvlTitle.BackgroundTransparency = 1
	curLvlTitle.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	curLvlTitle.Text = "X"
	curLvlTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
	curLvlTitle.TextSize = 46
	curLvlTitle.ZIndex = 3
	curLvlTitle.Parent = curCrest
	
	local cltStroke = Instance.new("UIStroke")
	cltStroke.Color = Color3.fromRGB(0, 0, 0)
	cltStroke.Thickness = 3
	cltStroke.Parent = curLvlTitle

	-- =========================================================================
	-- 중앙: 화살표 (→)
	-- =========================================================================
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
	-- 2. 오른쪽: 다음 레벨 (NextCard) - 부스터스피드 / HoverShop Open / 요구거리
	-- =========================================================================
	local nextCard = Instance.new("Frame")
	nextCard.Name = "NextCard"
	nextCard.Size = UDim2.new(0, 260, 0, 240)
	nextCard.Position = UDim2.new(1, -280, 0, 0)
	nextCard.BackgroundColor3 = Color3.fromRGB(160, 225, 255)
	nextCard.Parent = infoContainer

	local nxtCorner = Instance.new("UICorner")
	nxtCorner.CornerRadius = UDim.new(0, 16)
	nxtCorner.Parent = nextCard
	
	local nxtStroke = Instance.new("UIStroke")
	nxtStroke.Color = Color3.fromRGB(0, 0, 0)
	nxtStroke.Thickness = 4
	nxtStroke.Parent = nextCard
	
	local nxtPattern = Instance.new("Frame", nextCard)
	nxtPattern.Size = UDim2.new(1, 0, 1, 0)
	nxtPattern.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	nxtPattern.BorderSizePixel = 0
	Instance.new("UICorner", nxtPattern).CornerRadius = UDim.new(0, 16)
	local nxtGrad = Instance.new("UIGradient", nxtPattern)
	nxtGrad.Rotation = 45
	nxtGrad.Transparency = NumberSequence.new(keypoints)

	local nextCrest = Instance.new("ImageLabel")
	nextCrest.Name = "CrestImage"
	nextCrest.Size = UDim2.new(0, 115, 0, 115)
	nextCrest.Position = UDim2.new(0.5, -57, 0, 2)
	nextCrest.BackgroundTransparency = 1
	nextCrest.Image = "rbxassetid://104751050024730" -- Ice Blue Crest
	nextCrest.ZIndex = 2
	nextCrest.Parent = nextCard

	local nextLvlTitle = Instance.new("TextLabel")
	nextLvlTitle.Name = "RebirthLevel"
	nextLvlTitle.Size = UDim2.new(1, 0, 0, 36)
	nextLvlTitle.Position = UDim2.new(0, 0, 0.5, -16)
	nextLvlTitle.BackgroundTransparency = 1
	nextLvlTitle.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	nextLvlTitle.Text = "X"
	nextLvlTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
	nextLvlTitle.TextSize = 34
	nextLvlTitle.ZIndex = 3
	nextLvlTitle.Parent = nextCrest
	
	local nltStroke = Instance.new("UIStroke")
	nltStroke.Color = Color3.fromRGB(0, 0, 0)
	nltStroke.Thickness = 3
	nltStroke.Parent = nextLvlTitle

	-- 세로 정렬 컨테이너 (부스터스피드 -> HoverShop Rare Open -> 요구거리)
	local detailsContainer = Instance.new("Frame")
	detailsContainer.Name = "DetailsContainer"
	detailsContainer.Size = UDim2.new(1, -20, 0, 115)
	detailsContainer.Position = UDim2.new(0, 10, 0, 118)
	detailsContainer.BackgroundTransparency = 1
	detailsContainer.ZIndex = 2
	detailsContainer.Parent = nextCard

	local dLayout = Instance.new("UIListLayout")
	dLayout.FillDirection = Enum.FillDirection.Vertical
	dLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	dLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	dLayout.SortOrder = Enum.SortOrder.LayoutOrder
	dLayout.Padding = UDim.new(0, 4)
	dLayout.Parent = detailsContainer

	-- 1. 부스터스피드
	local boostSpeedLabel = Instance.new("TextLabel")
	boostSpeedLabel.Name = "BoostSpeedLabel"
	boostSpeedLabel.LayoutOrder = 1
	boostSpeedLabel.Size = UDim2.new(1, 0, 0, 26)
	boostSpeedLabel.BackgroundTransparency = 1
	boostSpeedLabel.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	boostSpeedLabel.Text = "Booster Speed: +18.0 km/h"
	boostSpeedLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	boostSpeedLabel.TextSize = 18
	boostSpeedLabel.ZIndex = 3
	boostSpeedLabel.Parent = detailsContainer

	local bstStroke = Instance.new("UIStroke")
	bstStroke.Color = Color3.fromRGB(0, 0, 0)
	bstStroke.Thickness = 2
	bstStroke.Parent = boostSpeedLabel

	-- 2. HoverShop [Rarity] Open (해당 레벨에서 상점 해금 시에만 표시)
	local shopOpenLabel = Instance.new("TextLabel")
	shopOpenLabel.Name = "ShopOpenLabel"
	shopOpenLabel.LayoutOrder = 2
	shopOpenLabel.Size = UDim2.new(1, -12, 0, 28)
	shopOpenLabel.BackgroundColor3 = Color3.fromRGB(25, 30, 45)
	shopOpenLabel.BackgroundTransparency = 0.2
	shopOpenLabel.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	shopOpenLabel.Text = "HoverShop Rare Open"
	shopOpenLabel.TextColor3 = Color3.fromRGB(255, 230, 80)
	shopOpenLabel.TextSize = 15
	shopOpenLabel.Visible = false
	shopOpenLabel.ZIndex = 3
	shopOpenLabel.Parent = detailsContainer

	local soCorner = Instance.new("UICorner")
	soCorner.CornerRadius = UDim.new(0, 8)
	soCorner.Parent = shopOpenLabel

	local soStroke = Instance.new("UIStroke")
	soStroke.Color = Color3.fromRGB(0, 0, 0)
	soStroke.Thickness = 2
	soStroke.Parent = shopOpenLabel

	-- 3. 요구거리
	local reqDistLabel = Instance.new("TextLabel")
	reqDistLabel.Name = "ReqDistLabel"
	reqDistLabel.LayoutOrder = 3
	reqDistLabel.Size = UDim2.new(1, 0, 0, 26)
	reqDistLabel.BackgroundTransparency = 1
	reqDistLabel.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	reqDistLabel.Text = "Req. Distance: 78.8km"
	reqDistLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	reqDistLabel.TextSize = 17
	reqDistLabel.ZIndex = 3
	reqDistLabel.Parent = detailsContainer

	local rdtStroke = Instance.new("UIStroke")
	rdtStroke.Color = Color3.fromRGB(0, 0, 0)
	rdtStroke.Thickness = 2
	rdtStroke.Parent = reqDistLabel

	-- =========================================================================
	-- 3. 하단: Common, Uncommon, Rare, Super Rare 순서로 보여줄것
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
	guideTitle.Text = "🛹 HOVERBOARD SHOP UNLOCK MILESTONES"
	guideTitle.TextColor3 = Color3.fromRGB(255, 230, 100)
	guideTitle.TextSize = 16
	guideTitle.Parent = shopGuideFrame

	local gtStroke = Instance.new("UIStroke")
	gtStroke.Color = Color3.fromRGB(0, 0, 0)
	gtStroke.Thickness = 2
	gtStroke.Parent = guideTitle

	-- Badges Container (Horizontal List) - LayoutOrder 순서대로 엄격 정렬
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
	badgeLayout.SortOrder = Enum.SortOrder.LayoutOrder -- 🌟 LayoutOrder 순서로 정렬
	badgeLayout.Padding = UDim.new(0, 8)
	badgeLayout.Parent = badgesContainer

	-- Create 4 Rarity Milestone Cards strictly: 1.Common -> 2.Uncommon -> 3.Rare -> 4.Super Rare
	for orderIdx, unlock in ipairs(HOVERBOARD_UNLOCKS) do
		local badge = Instance.new("Frame")
		badge.Name = "Badge_" .. unlock.rarity
		badge.LayoutOrder = orderIdx -- 🌟 순서 고정 (1: Common, 2: Uncommon, 3: Rare, 4: Super Rare)
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
	guideTip.Text = "⚡ Reach the required distance to level up automatically & unlock new boards in shop!"
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
	if leaderstats then
		local rVal = (leaderstats:FindFirstChild("Level") or leaderstats:FindFirstChild("Rebirths")) :: IntValue
		if rVal then currentRebirths = rVal.Value end
	end
	
	-- 1. 왼쪽: 현재 레벨 (CurrentCard) - 순수하게 방패에 현재 레벨만 갱신
	local currentCard = infoContainer:FindFirstChild("CurrentCard")
	if currentCard then
		local curCrest = currentCard:FindFirstChild("CrestImage")
		local curLvlTitle = curCrest and curCrest:FindFirstChild("RebirthLevel") :: TextLabel?
		if curLvlTitle then
			curLvlTitle.Text = tostring(currentRebirths)
		end
	end
	
	-- 2. 오른쪽: 다음 레벨 (NextCard) - 부스터스피드, HoverShop Open(조건부), 요구거리
	local nextCard = infoContainer:FindFirstChild("NextCard")
	if nextCard then
		local nextCrest = nextCard:FindFirstChild("CrestImage")
		local nextLvlTitle = nextCrest and nextCrest:FindFirstChild("RebirthLevel") :: TextLabel?
		local details = nextCard:FindFirstChild("DetailsContainer")
		local boostSpeedLabel = details and details:FindFirstChild("BoostSpeedLabel") :: TextLabel?
		local shopOpenLabel = details and details:FindFirstChild("ShopOpenLabel") :: TextLabel?
		local reqDistLabel = details and details:FindFirstChild("ReqDistLabel") :: TextLabel?
		
		local nextRebirthData = RebirthConfig.GetNextRebirthData(currentRebirths)
		if nextRebirthData then
			local nextLevel = currentRebirths + 1
			if nextLvlTitle then
				nextLvlTitle.Text = tostring(nextLevel)
			end
			if boostSpeedLabel then
				boostSpeedLabel.Text = string.format("Booster Speed: +%.1f km/h", nextRebirthData.BoostSpeedBonus)
			end
			if reqDistLabel then
				reqDistLabel.Text = string.format("Req. Distance: %s", formatDistance(nextRebirthData.RequiredDistance))
			end
			
			-- HoverShop [Rarity] Open (해당 레벨에서 상점 등급 해금되는 경우에만 표시, 없으면 숨김)
			local exactUnlock = getExactUnlock(nextLevel)
			if shopOpenLabel then
				if exactUnlock then
					shopOpenLabel.Text = string.format("HoverShop %s Open", exactUnlock.name)
					shopOpenLabel.TextColor3 = exactUnlock.color
					shopOpenLabel.Visible = true
				else
					shopOpenLabel.Visible = false
				end
			end
		else
			-- 만렙 도달 시
			if nextLvlTitle then nextLvlTitle.Text = "-" end
			if boostSpeedLabel then boostSpeedLabel.Text = "MAX LEVEL REACHED" end
			if shopOpenLabel then shopOpenLabel.Visible = false end
			if reqDistLabel then reqDistLabel.Text = "Max Level Reached!" end
		end
	end

	-- 3. 하단 4개 마일스톤 뱃지 갱신 (Common -> Uncommon -> Rare -> Super Rare 엄격한 순서 유지)
	local badgesContainer = shopGuideFrame:FindFirstChild("BadgesContainer")
	if badgesContainer then
		for orderIdx, unlock in ipairs(HOVERBOARD_UNLOCKS) do
			local badge = badgesContainer:FindFirstChild("Badge_" .. unlock.rarity) :: Frame?
			if badge then
				badge.LayoutOrder = orderIdx
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
				if win.Visible then
					local innerPanel = win:FindFirstChild("Panel")
					if innerPanel and innerPanel:IsA("GuiObject") then
						innerPanel.Visible = true
					end
				end
				
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
