print("==================================================")
print("🚀 [SettingsUIController] SCRIPT LOADED & INITIALIZING!")
print("==================================================")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local remotesFolder = ReplicatedStorage:WaitForChild("HoverboardRemotes", 10) :: Folder?
local redeemRemote: RemoteFunction? = nil

task.spawn(function()
	if remotesFolder then
		redeemRemote = remotesFolder:WaitForChild("RedeemPromoCode", 5) :: RemoteFunction?
	end
end)

-- =========================================================================
-- 🎨 DEFAULT ATTRIBUTES INITIALIZATION
-- =========================================================================
if LocalPlayer:GetAttribute("SteerSensitivity") == nil then
	LocalPlayer:SetAttribute("SteerSensitivity", 1.0)
end
if LocalPlayer:GetAttribute("AutoForward") == nil then
	LocalPlayer:SetAttribute("AutoForward", false)
end
if LocalPlayer:GetAttribute("BGMEnabled") == nil then
	LocalPlayer:SetAttribute("BGMEnabled", true)
end
if LocalPlayer:GetAttribute("BoosterFOVEnabled") == nil then
	LocalPlayer:SetAttribute("BoosterFOVEnabled", true)
end
if LocalPlayer:GetAttribute("ScreenShakeEnabled") == nil then
	LocalPlayer:SetAttribute("ScreenShakeEnabled", true)
end

-- =========================================================================
-- 🖼️ UI CONTAINER CREATION (Thick Cartoon Style)
-- =========================================================================
local settingsGui = Instance.new("ScreenGui")
settingsGui.Name = "SettingsGui"
settingsGui.ResetOnSpawn = false
settingsGui.DisplayOrder = 100
settingsGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
settingsGui.Enabled = false
settingsGui.Parent = PlayerGui

-- Main Panel
local mainPanel = Instance.new("Frame")
mainPanel.Name = "MainPanel"
mainPanel.Size = UDim2.new(0, 720, 0, 480)
mainPanel.Position = UDim2.new(0.5, 0, 0.5, 0)
mainPanel.AnchorPoint = Vector2.new(0.5, 0.5)
mainPanel.BackgroundColor3 = Color3.fromRGB(150, 240, 255)
mainPanel.BackgroundTransparency = 0.5
mainPanel.Visible = true
mainPanel.Parent = settingsGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 24)
mainCorner.Parent = mainPanel

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(0, 0, 0)
mainStroke.Thickness = 8
mainStroke.Parent = mainPanel

-- Pill-Shaped Header
local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(0, 320, 0, 60)
header.Position = UDim2.new(0.5, 0, 0, -30)
header.AnchorPoint = Vector2.new(0.5, 0)
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
titleText.Text = "⚙️ SETTINGS"
titleText.Font = Enum.Font.FredokaOne
titleText.TextSize = 32
titleText.TextColor3 = Color3.fromRGB(255, 255, 255)
titleText.Parent = header

local titleStroke = Instance.new("UIStroke")
titleStroke.Color = Color3.fromRGB(0, 0, 0)
titleStroke.Thickness = 3
titleStroke.Parent = titleText

-- Circular Close Button
local closeBtn = Instance.new("TextButton")
closeBtn.Name = "CloseBtn"
closeBtn.Size = UDim2.new(0, 50, 0, 50)
closeBtn.Position = UDim2.new(1, -20, 0, -20)
closeBtn.AnchorPoint = Vector2.new(0.5, 0.5)
closeBtn.BackgroundColor3 = Color3.fromRGB(255, 75, 75)
closeBtn.Text = "X"
closeBtn.Font = Enum.Font.FredokaOne
closeBtn.TextSize = 28
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.AutoButtonColor = false
closeBtn.Parent = mainPanel

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(1, 0)
closeCorner.Parent = closeBtn

local closeStroke = Instance.new("UIStroke")
closeStroke.Color = Color3.fromRGB(0, 0, 0)
closeStroke.Thickness = 5
closeStroke.Parent = closeBtn

closeBtn.Activated:Connect(function()
	mainPanel.Visible = false
	settingsGui.Enabled = false
end)

closeBtn.MouseEnter:Connect(function()
	TweenService:Create(closeBtn, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(255, 110, 110) }):Play()
end)
closeBtn.MouseLeave:Connect(function()
	TweenService:Create(closeBtn, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(255, 75, 75) }):Play()
end)

-- =========================================================================
-- 📑 TAB NAVIGATION BAR
-- =========================================================================
local tabContainer = Instance.new("Frame")
tabContainer.Name = "TabContainer"
tabContainer.Size = UDim2.new(1, -40, 0, 50)
tabContainer.Position = UDim2.new(0, 20, 0, 42)
tabContainer.BackgroundTransparency = 1
tabContainer.Parent = mainPanel

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
tabLayout.Padding = UDim.new(0, 10)
tabLayout.Parent = tabContainer

-- Page Container
local pageContainer = Instance.new("Frame")
pageContainer.Name = "PageContainer"
pageContainer.Size = UDim2.new(1, -40, 1, -110)
pageContainer.Position = UDim2.new(0, 20, 0, 100)
pageContainer.BackgroundTransparency = 1
pageContainer.Parent = mainPanel

local tabButtons: { [string]: TextButton } = {}
local tabPages: { [string]: ScrollingFrame } = {}

local function createTabPage(name: string): ScrollingFrame
	local page = Instance.new("ScrollingFrame")
	page.Name = name .. "Page"
	page.Size = UDim2.new(1, 0, 1, 0)
	page.BackgroundTransparency = 1
	page.BorderSizePixel = 0
	page.ScrollBarThickness = 6
	page.ScrollBarImageColor3 = Color3.fromRGB(40, 180, 255)
	page.Visible = false
	page.Parent = pageContainer

	local listLayout = Instance.new("UIListLayout")
	listLayout.FillDirection = Enum.FillDirection.Vertical
	listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	listLayout.Padding = UDim.new(0, 12)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = page

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 5)
	padding.PaddingBottom = UDim.new(0, 15)
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.Parent = page

	listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		page.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 25)
	end)

	return page
end

local function switchTab(tabName: string)
	for tName, page in pairs(tabPages) do
		page.Visible = (tName == tabName)
	end
	for tName, btn in pairs(tabButtons) do
		local isSelected = (tName == tabName)
		local targetColor = isSelected and Color3.fromRGB(255, 140, 30) or Color3.fromRGB(80, 160, 200)
		local targetTextSize = isSelected and 20 or 18
		TweenService:Create(btn, TweenInfo.new(0.2), { BackgroundColor3 = targetColor }):Play()
		btn.TextSize = targetTextSize
	end
end

local TAB_CONFIGS = {
	{ id = "Controls", text = "🏎️ 조작", order = 1 },
	{ id = "Audio",    text = "🎵 사운드", order = 2 },
	{ id = "Visuals",  text = "✨ 연출", order = 3 },
	{ id = "Codes",    text = "🎁 코드", order = 4 },
}

for _, cfg in ipairs(TAB_CONFIGS) do
	local tabBtn = Instance.new("TextButton")
	tabBtn.Name = cfg.id .. "Tab"
	tabBtn.LayoutOrder = cfg.order
	tabBtn.Size = UDim2.new(0.235, -5, 1, 0)
	tabBtn.BackgroundColor3 = Color3.fromRGB(80, 160, 200)
	tabBtn.Text = cfg.text
	tabBtn.Font = Enum.Font.FredokaOne
	tabBtn.TextSize = 18
	tabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	tabBtn.AutoButtonColor = false
	tabBtn.Parent = tabContainer

	local tabCorner = Instance.new("UICorner")
	tabCorner.CornerRadius = UDim.new(0, 14)
	tabCorner.Parent = tabBtn

	local tabStroke = Instance.new("UIStroke")
	tabStroke.Color = Color3.fromRGB(0, 0, 0)
	tabStroke.Thickness = 4
	tabStroke.Parent = tabBtn

	local tabTextStroke = Instance.new("UIStroke")
	tabTextStroke.Color = Color3.fromRGB(0, 0, 0)
	tabTextStroke.Thickness = 2
	tabTextStroke.Parent = tabBtn

	tabBtn.MouseButton1Click:Connect(function()
		switchTab(cfg.id)
	end)

	tabButtons[cfg.id] = tabBtn
	tabPages[cfg.id] = createTabPage(cfg.id)
end

-- =========================================================================
-- 🛠️ HELPER: CARD CREATION (Thick Cartoon Card)
-- =========================================================================
local function createSettingCard(parent: ScrollingFrame, order: number, title: string, subtitle: string, height: number): (Frame, Frame)
	local card = Instance.new("Frame")
	card.Name = "Card_" .. tostring(order)
	card.LayoutOrder = order
	card.Size = UDim2.new(1, 0, 0, height or 82)
	card.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	card.BackgroundTransparency = 0.15
	card.Parent = parent

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 16)
	cardCorner.Parent = card

	local cardStroke = Instance.new("UIStroke")
	cardStroke.Color = Color3.fromRGB(0, 0, 0)
	cardStroke.Thickness = 4
	cardStroke.Parent = card

	local titleLbl = Instance.new("TextLabel")
	titleLbl.Size = UDim2.new(0.65, 0, 0, 32)
	titleLbl.Position = UDim2.new(0, 20, 0, 12)
	titleLbl.BackgroundTransparency = 1
	titleLbl.Font = Enum.Font.FredokaOne
	titleLbl.Text = title
	titleLbl.TextColor3 = Color3.fromRGB(30, 40, 60)
	titleLbl.TextSize = 22
	titleLbl.TextXAlignment = Enum.TextXAlignment.Left
	titleLbl.Parent = card

	local subLbl = Instance.new("TextLabel")
	subLbl.Size = UDim2.new(0.65, 0, 0, 24)
	subLbl.Position = UDim2.new(0, 20, 0, 44)
	subLbl.BackgroundTransparency = 1
	subLbl.Font = Enum.Font.FredokaOne
	subLbl.Text = subtitle
	subLbl.TextColor3 = Color3.fromRGB(110, 125, 145)
	subLbl.TextSize = 14
	subLbl.TextXAlignment = Enum.TextXAlignment.Left
	subLbl.Parent = card

	local rightContainer = Instance.new("Frame")
	rightContainer.Name = "RightContainer"
	rightContainer.Size = UDim2.new(0.32, -15, 1, -20)
	rightContainer.Position = UDim2.new(0.68, 0, 0, 10)
	rightContainer.BackgroundTransparency = 1
	rightContainer.Parent = card

	return card, rightContainer
end

-- Helper: ON/OFF Toggle Switch
local function createToggleSwitch(parent: Frame, attributeName: string, defaultValue: boolean)
	local currentVal = LocalPlayer:GetAttribute(attributeName)
	if currentVal == nil then currentVal = defaultValue end

	local toggleBtn = Instance.new("TextButton")
	toggleBtn.Size = UDim2.new(0, 110, 0, 48)
	toggleBtn.Position = UDim2.new(1, -110, 0.5, -24)
	toggleBtn.Font = Enum.Font.FredokaOne
	toggleBtn.TextSize = 20
	toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	toggleBtn.AutoButtonColor = false
	toggleBtn.Parent = parent

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0.5, 0)
	btnCorner.Parent = toggleBtn

	local btnStroke = Instance.new("UIStroke")
	btnStroke.Color = Color3.fromRGB(0, 0, 0)
	btnStroke.Thickness = 4
	btnStroke.Parent = toggleBtn

	local textStroke = Instance.new("UIStroke")
	textStroke.Color = Color3.fromRGB(0, 0, 0)
	textStroke.Thickness = 2
	textStroke.Parent = toggleBtn

	local function updateVisual(val: boolean)
		if val then
			toggleBtn.Text = "ON"
			toggleBtn.BackgroundColor3 = Color3.fromRGB(60, 200, 90)
		else
			toggleBtn.Text = "OFF"
			toggleBtn.BackgroundColor3 = Color3.fromRGB(220, 80, 80)
		end
	end
	updateVisual(currentVal)

	toggleBtn.MouseButton1Click:Connect(function()
		local newVal = not (LocalPlayer:GetAttribute(attributeName) == true)
		LocalPlayer:SetAttribute(attributeName, newVal)
		updateVisual(newVal)

		-- Click Bounce Animation
		toggleBtn.Size = UDim2.new(0, 100, 0, 44)
		toggleBtn.Position = UDim2.new(1, -105, 0.5, -22)
		TweenService:Create(toggleBtn, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.new(0, 110, 0, 48),
			Position = UDim2.new(1, -110, 0.5, -24),
		}):Play()
	end)

	LocalPlayer:GetAttributeChangedSignal(attributeName):Connect(function()
		local val = LocalPlayer:GetAttribute(attributeName) == true
		updateVisual(val)
	end)
end

-- =========================================================================
-- 🏎️ TAB 1: CONTROLS SETUP
-- =========================================================================
local controlsPage = tabPages["Controls"]

-- 1. Steering Sensitivity Step Slider (- / +)
local _, sensRight = createSettingCard(
	controlsPage, 1,
	"🏎️ 스티어링 회전 감도",
	"좌우 회전 민감도를 조절합니다 (기본 1.0x / 0.5x ~ 1.5x)",
	86
)

local sensContainer = Instance.new("Frame")
sensContainer.Size = UDim2.new(1, 0, 1, 0)
sensContainer.BackgroundTransparency = 1
sensContainer.Parent = sensRight

local minusBtn = Instance.new("TextButton")
minusBtn.Size = UDim2.new(0, 44, 0, 44)
minusBtn.Position = UDim2.new(0, 0, 0.5, -22)
minusBtn.BackgroundColor3 = Color3.fromRGB(255, 120, 50)
minusBtn.Text = "-"
minusBtn.Font = Enum.Font.FredokaOne
minusBtn.TextSize = 28
minusBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
minusBtn.AutoButtonColor = false
minusBtn.Parent = sensContainer

local minusCorner = Instance.new("UICorner")
minusCorner.CornerRadius = UDim.new(0, 12)
minusCorner.Parent = minusBtn

local minusStroke = Instance.new("UIStroke")
minusStroke.Color = Color3.fromRGB(0, 0, 0)
minusStroke.Thickness = 3
minusStroke.Parent = minusBtn

local sensValueLabel = Instance.new("TextLabel")
sensValueLabel.Size = UDim2.new(0, 85, 0, 44)
sensValueLabel.Position = UDim2.new(0, 50, 0.5, -22)
sensValueLabel.BackgroundColor3 = Color3.fromRGB(40, 180, 255)
sensValueLabel.Font = Enum.Font.FredokaOne
sensValueLabel.Text = "1.0x"
sensValueLabel.TextSize = 22
sensValueLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
sensValueLabel.Parent = sensContainer

local sensValCorner = Instance.new("UICorner")
sensValCorner.CornerRadius = UDim.new(0, 12)
sensValCorner.Parent = sensValueLabel

local sensValStroke = Instance.new("UIStroke")
sensValStroke.Color = Color3.fromRGB(0, 0, 0)
sensValStroke.Thickness = 3
sensValStroke.Parent = sensValueLabel

local sensValTextStroke = Instance.new("UIStroke")
sensValTextStroke.Color = Color3.fromRGB(0, 0, 0)
sensValTextStroke.Thickness = 2
sensValTextStroke.Parent = sensValueLabel

local plusBtn = Instance.new("TextButton")
plusBtn.Size = UDim2.new(0, 44, 0, 44)
plusBtn.Position = UDim2.new(0, 141, 0.5, -22)
plusBtn.BackgroundColor3 = Color3.fromRGB(60, 200, 90)
plusBtn.Text = "+"
plusBtn.Font = Enum.Font.FredokaOne
plusBtn.TextSize = 28
plusBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
plusBtn.AutoButtonColor = false
plusBtn.Parent = sensContainer

local plusCorner = Instance.new("UICorner")
plusCorner.CornerRadius = UDim.new(0, 12)
plusCorner.Parent = plusBtn

local plusStroke = Instance.new("UIStroke")
plusStroke.Color = Color3.fromRGB(0, 0, 0)
plusStroke.Thickness = 3
plusStroke.Parent = plusBtn

local function updateSensDisplay()
	local s = LocalPlayer:GetAttribute("SteerSensitivity") or 1.0
	sensValueLabel.Text = string.format("%.1fx", s)
end
updateSensDisplay()

minusBtn.MouseButton1Click:Connect(function()
	local current = LocalPlayer:GetAttribute("SteerSensitivity") or 1.0
	local newVal = math.clamp(math.round((current - 0.1) * 10) / 10, 0.5, 1.5)
	LocalPlayer:SetAttribute("SteerSensitivity", newVal)
	updateSensDisplay()
end)

plusBtn.MouseButton1Click:Connect(function()
	local current = LocalPlayer:GetAttribute("SteerSensitivity") or 1.0
	local newVal = math.clamp(math.round((current + 0.1) * 10) / 10, 0.5, 1.5)
	LocalPlayer:SetAttribute("SteerSensitivity", newVal)
	updateSensDisplay()
end)

LocalPlayer:GetAttributeChangedSignal("SteerSensitivity"):Connect(updateSensDisplay)

-- 2. Auto-Forward Toggle
local _, autoFwdRight = createSettingCard(
	controlsPage, 2,
	"⚡ 자동 전진 (Auto-Forward)",
	"레이스 중 전진 키(W)를 누르지 않아도 자동으로 달립니다.",
	86
)
createToggleSwitch(autoFwdRight, "AutoForward", false)

-- =========================================================================
-- 🎵 TAB 2: AUDIO SETUP
-- =========================================================================
local audioPage = tabPages["Audio"]

-- 1. BGM Toggle
local _, bgmRight = createSettingCard(
	audioPage, 1,
	"🎵 배경 음악 (BGM)",
	"대기실 및 레이스 트랙의 테마 음악을 재생합니다.",
	86
)
createToggleSwitch(bgmRight, "BGMEnabled", true)

-- =========================================================================
-- ✨ TAB 3: VISUALS SETUP
-- =========================================================================
local visualsPage = tabPages["Visuals"]

-- 1. Booster FOV Warp Toggle
local _, fovRight = createSettingCard(
	visualsPage, 1,
	"🚀 부스터 시야 왜곡 (Booster FOV)",
	"부스터 가속 시 다이내믹 광각 카메라 왜곡 효과를 켭니다.",
	86
)
createToggleSwitch(fovRight, "BoosterFOVEnabled", true)

-- 2. Screen Shake Toggle
local _, shakeRight = createSettingCard(
	visualsPage, 2,
	"📳 화면 진동 (Screen Shake)",
	"부스터 질주 시 카메라를 흔들어 박진감을 높입니다.",
	86
)
createToggleSwitch(shakeRight, "ScreenShakeEnabled", true)

-- =========================================================================
-- 🎁 TAB 4: PROMO CODES SETUP
-- =========================================================================
local codesPage = tabPages["Codes"]

local codeCard = Instance.new("Frame")
codeCard.Name = "CodeCard"
codeCard.LayoutOrder = 1
codeCard.Size = UDim2.new(1, 0, 0, 220)
codeCard.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
codeCard.BackgroundTransparency = 0.15
codeCard.Parent = codesPage

local codeCardCorner = Instance.new("UICorner")
codeCardCorner.CornerRadius = UDim.new(0, 16)
codeCardCorner.Parent = codeCard

local codeCardStroke = Instance.new("UIStroke")
codeCardStroke.Color = Color3.fromRGB(0, 0, 0)
codeCardStroke.Thickness = 4
codeCardStroke.Parent = codeCard

local codeHeaderTitle = Instance.new("TextLabel")
codeHeaderTitle.Size = UDim2.new(1, -40, 0, 32)
codeHeaderTitle.Position = UDim2.new(0, 20, 0, 16)
codeHeaderTitle.BackgroundTransparency = 1
codeHeaderTitle.Font = Enum.Font.FredokaOne
codeHeaderTitle.Text = "🎁 프로모션 쿠폰 코드 등록"
codeHeaderTitle.TextColor3 = Color3.fromRGB(30, 40, 60)
codeHeaderTitle.TextSize = 22
codeHeaderTitle.TextXAlignment = Enum.TextXAlignment.Left
codeHeaderTitle.Parent = codeCard

local codeSubtitle = Instance.new("TextLabel")
codeSubtitle.Size = UDim2.new(1, -40, 0, 24)
codeSubtitle.Position = UDim2.new(0, 20, 0, 48)
codeSubtitle.BackgroundTransparency = 1
codeSubtitle.Font = Enum.Font.FredokaOne
codeSubtitle.Text = "쿠폰 코드를 입력하면 즉시 골드 보상을 지급받을 수 있습니다!"
codeSubtitle.TextColor3 = Color3.fromRGB(110, 125, 145)
codeSubtitle.TextSize = 14
codeSubtitle.TextXAlignment = Enum.TextXAlignment.Left
codeSubtitle.Parent = codeCard

-- Input Box + Button Container
local inputRow = Instance.new("Frame")
inputRow.Size = UDim2.new(1, -40, 0, 52)
inputRow.Position = UDim2.new(0, 20, 0, 84)
inputRow.BackgroundTransparency = 1
inputRow.Parent = codeCard

local codeTextBox = Instance.new("TextBox")
codeTextBox.Name = "CodeTextBox"
codeTextBox.Size = UDim2.new(0.68, 0, 1, 0)
codeTextBox.BackgroundColor3 = Color3.fromRGB(240, 248, 255)
codeTextBox.Font = Enum.Font.FredokaOne
codeTextBox.PlaceholderText = "코드를 입력하세요 (예: WELCOME)"
codeTextBox.PlaceholderColor3 = Color3.fromRGB(160, 180, 200)
codeTextBox.Text = ""
codeTextBox.TextColor3 = Color3.fromRGB(30, 30, 30)
codeTextBox.TextSize = 20
codeTextBox.ClearTextOnFocus = false
codeTextBox.Parent = inputRow

local tbCorner = Instance.new("UICorner")
tbCorner.CornerRadius = UDim.new(0, 14)
tbCorner.Parent = codeTextBox

local tbStroke = Instance.new("UIStroke")
tbStroke.Color = Color3.fromRGB(0, 0, 0)
tbStroke.Thickness = 3
tbStroke.Parent = codeTextBox

local tbPadding = Instance.new("UIPadding")
tbPadding.PaddingLeft = UDim.new(0, 15)
tbPadding.PaddingRight = UDim.new(0, 15)
tbPadding.Parent = codeTextBox

local redeemBtn = Instance.new("TextButton")
redeemBtn.Name = "RedeemBtn"
redeemBtn.Size = UDim2.new(0.29, 0, 1, 0)
redeemBtn.Position = UDim2.new(0.71, 0, 0, 0)
redeemBtn.BackgroundColor3 = Color3.fromRGB(255, 160, 20)
redeemBtn.Font = Enum.Font.FredokaOne
redeemBtn.Text = "등록하기"
redeemBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
redeemBtn.TextSize = 20
redeemBtn.AutoButtonColor = false
redeemBtn.Parent = inputRow

local rBtnCorner = Instance.new("UICorner")
rBtnCorner.CornerRadius = UDim.new(0, 14)
rBtnCorner.Parent = redeemBtn

local rBtnStroke = Instance.new("UIStroke")
rBtnStroke.Color = Color3.fromRGB(0, 0, 0)
rBtnStroke.Thickness = 3
rBtnStroke.Parent = redeemBtn

local rBtnTextStroke = Instance.new("UIStroke")
rBtnTextStroke.Color = Color3.fromRGB(0, 0, 0)
rBtnTextStroke.Thickness = 2
rBtnTextStroke.Parent = redeemBtn

-- Result / Status Label
local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "StatusLabel"
statusLabel.Size = UDim2.new(1, -40, 0, 32)
statusLabel.Position = UDim2.new(0, 20, 0, 146)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.FredokaOne
statusLabel.Text = ""
statusLabel.TextSize = 16
statusLabel.Parent = codeCard

local isRedeeming = false
local function handleRedeem()
	if isRedeeming then return end
	local codeText = codeTextBox.Text
	if string.gsub(codeText, "%s+", "") == "" then
		statusLabel.Text = "⚠️ 코드를 입력해 주세요."
		statusLabel.TextColor3 = Color3.fromRGB(255, 120, 50)
		return
	end

	isRedeeming = true
	redeemBtn.Text = "확인 중..."
	statusLabel.Text = ""

	task.spawn(function()
		local remote = redeemRemote
		if not remote and remotesFolder then
			remote = remotesFolder:FindFirstChild("RedeemPromoCode") :: RemoteFunction?
		end

		if not remote then
			isRedeeming = false
			redeemBtn.Text = "등록하기"
			statusLabel.Text = "❌ 쿠폰 서버와 연결할 수 없습니다. (재접속 필요)"
			statusLabel.TextColor3 = Color3.fromRGB(230, 60, 60)
			return
		end

		local success, msg, reward = pcall(function()
			return remote:InvokeServer(codeText)
		end)

		isRedeeming = false
		redeemBtn.Text = "등록하기"

		if success and type(msg) == "string" then
			if string.find(msg, "성공") then
				statusLabel.Text = msg
				statusLabel.TextColor3 = Color3.fromRGB(40, 190, 70)
				codeTextBox.Text = ""
			else
				statusLabel.Text = msg
				statusLabel.TextColor3 = Color3.fromRGB(230, 60, 60)
			end
		else
			statusLabel.Text = "❌ 서버와 통신할 수 없습니다."
			statusLabel.TextColor3 = Color3.fromRGB(230, 60, 60)
		end
	end)
end

redeemBtn.MouseButton1Click:Connect(handleRedeem)
codeTextBox.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		handleRedeem()
	end
end)

-- Default initial tab
switchTab("Controls")

-- =========================================================================
-- 🔗 CONNECT TO HUD BUTTON: StarterGui > UtilityBarGui > SettingButton
-- =========================================================================
local function findSettingButton(): GuiObject?
	-- 1. Look in UtilityBarGui
	local utilityBarGui = PlayerGui:FindFirstChild("UtilityBarGui")
	if utilityBarGui then
		-- A. Direct child named SettingButton
		local direct = utilityBarGui:FindFirstChild("SettingButton")
		if direct and direct:IsA("GuiObject") then return direct end

		-- B. In UtilityBarContainer
		local container = utilityBarGui:FindFirstChild("UtilityBarContainer")
		if container then
			local cb = container:FindFirstChild("SettingButton") or container:FindFirstChild("SettingsButton") or container:FindFirstChild("Setting")
			if cb and cb:IsA("GuiObject") then return cb end
			for _, child in ipairs(container:GetChildren()) do
				if string.find(child.Name:lower(), "setting") and child:IsA("GuiObject") then
					return child
				end
			end
		end

		-- C. Recursive search anywhere in UtilityBarGui
		local recursive = utilityBarGui:FindFirstChild("SettingButton", true)
		if recursive and recursive:IsA("GuiObject") then return recursive end

		-- D. Fuzzy match any object with "setting" in name
		for _, desc in ipairs(utilityBarGui:GetDescendants()) do
			if desc:IsA("GuiObject") and string.find(desc.Name:lower(), "setting") then
				return desc
			end
		end
	end

	-- 2. Fallback search across all ScreenGuis in PlayerGui
	for _, gui in ipairs(PlayerGui:GetChildren()) do
		if gui:IsA("ScreenGui") and gui.Name ~= "SettingsGui" then
			for _, desc in ipairs(gui:GetDescendants()) do
				if desc:IsA("GuiObject") and string.find(desc.Name:lower(), "setting") then
					return desc
				end
			end
		end
	end

	return nil
end

local isHooked = false
local function tryHookSettingButton(): boolean
	if isHooked then return true end

	local settingObj = findSettingButton()
	if not settingObj then
		return false
	end

	if settingObj:GetAttribute("SettingsHooked") then
		isHooked = true
		return true
	end
	settingObj:SetAttribute("SettingsHooked", true)
	isHooked = true
	print("🎯 [SettingsUIController] SUCCESSFULLY HOOKED SettingButton at:", settingObj:GetFullName(), "[" .. settingObj.ClassName .. "]")

	local lastToggleTime = 0
	local function toggleUI()
		local now = os.clock()
		if now - lastToggleTime < 0.3 then
			return
		end
		lastToggleTime = now

		local nextState = not settingsGui.Enabled
		settingsGui.Enabled = nextState
		mainPanel.Visible = nextState
		print("🖱️ [SettingsUIController] UI Toggled! Enabled =", nextState)
		if nextState then
			switchTab("Controls")
		end
	end

	if settingObj:IsA("GuiButton") then
		settingObj.Activated:Connect(toggleUI)
	else
		local innerBtn = settingObj:FindFirstChildWhichIsA("GuiButton", true)
		if innerBtn then
			innerBtn.Activated:Connect(toggleUI)
		else
			settingObj.Active = true
			settingObj.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					toggleUI()
				end
			end)
		end
	end

	return true
end

-- Hook loop with diagnostic output
task.spawn(function()
	local attempts = 0
	while not isHooked and attempts < 60 do
		attempts += 1
		local uGui = PlayerGui:FindFirstChild("UtilityBarGui")
		if uGui then
			local container = uGui:FindFirstChild("UtilityBarContainer")
			if container then
				local names = {}
				for _, c in ipairs(container:GetChildren()) do
					table.insert(names, c.Name .. "(" .. c.ClassName .. ")")
				end
				print("🔍 [SettingsUI] Attempt " .. attempts .. " | UtilityBarContainer:", table.concat(names, ", "))
			else
				local names = {}
				for _, c in ipairs(uGui:GetChildren()) do
					table.insert(names, c.Name .. "(" .. c.ClassName .. ")")
				end
				print("🔍 [SettingsUI] Attempt " .. attempts .. " | UtilityBarGui:", table.concat(names, ", "))
			end
		else
			print("🔍 [SettingsUI] Attempt " .. attempts .. " | Waiting for UtilityBarGui in PlayerGui...")
		end

		if tryHookSettingButton() then
			print("🎉 [SettingsUIController] Hook successfully established on attempt " .. attempts .. "!")
			break
		end

		task.wait(0.5)
	end
end)

PlayerGui.ChildAdded:Connect(function(child)
	if not isHooked then
		task.delay(0.2, tryHookSettingButton)
	end
end)

PlayerGui.DescendantAdded:Connect(function(desc)
	if not isHooked and desc:IsA("GuiObject") and string.find(desc.Name:lower(), "setting") then
		task.delay(0.1, tryHookSettingButton)
	end
end)


-- =========================================================================
-- 📱 RESPONSIVE UI SCALING
-- =========================================================================
local uiScale = Instance.new("UIScale")
uiScale.Parent = mainPanel

local function updateResponsiveScale()
	local camera = workspace.CurrentCamera
	if not camera then return end
	local viewport = camera.ViewportSize
	local baseHeight = 800
	local scale = math.clamp(viewport.Y / baseHeight, 0.55, 1.15)
	uiScale.Scale = scale
end

workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveScale)
updateResponsiveScale()
