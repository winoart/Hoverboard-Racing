--!strict
-- SkillStoreController.client.luau
-- Displays the Skill Store UI (Thick Cartoon Style / Glass Aesthetic)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local playerGui = LocalPlayer:WaitForChild("PlayerGui")

local remotesFolder = ReplicatedStorage:WaitForChild("SkillRemotes")
local openStoreRemote = remotesFolder:WaitForChild("OpenSkillStore") :: RemoteEvent
local purchaseItemRemote = remotesFolder:WaitForChild("PurchaseSkill") :: RemoteFunction

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SkillStoreConfig = require(Shared:WaitForChild("SkillStoreConfig") :: ModuleScript)

print("💻 [SkillStoreController] Thick Cartoon Style 스킬상점 UI 가동 시작!")

-- Helper: Format numbers with commas (e.g., 2000 -> 2,000)
local function formatNumber(n: number): string
	local formatted = tostring(n)
	while true do
		local k
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
		if k == 0 then break end
	end
	return formatted
end

-- Helper: Create or ensure UIStroke
local function applyStroke(parent: Instance, thickness: number, color: Color3, mode: Enum.ApplyStrokeMode?): UIStroke
	local stroke = parent:FindFirstChildOfClass("UIStroke")
	if not stroke then
		stroke = Instance.new("UIStroke")
		stroke.Parent = parent
	end
	stroke.Thickness = thickness
	stroke.Color = color
	if mode then
		stroke.ApplyStrokeMode = mode
	end
	return stroke
end

-- Helper: Create or ensure UICorner
local function applyCorner(parent: Instance, radius: UDim): UICorner
	local corner = parent:FindFirstChildOfClass("UICorner")
	if not corner then
		corner = Instance.new("UICorner")
		corner.Parent = parent
	end
	corner.CornerRadius = radius
	return corner
end

-- 1. Ensure SkillStoreGui exists and matches Design Guide
local storeGui = playerGui:FindFirstChild("SkillStoreGui") :: ScreenGui?
if not storeGui then
	storeGui = Instance.new("ScreenGui")
	storeGui.Name = "SkillStoreGui"
	storeGui.ResetOnSpawn = false
	storeGui.Enabled = false
	storeGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	storeGui.Parent = playerGui
else
	storeGui.ResetOnSpawn = false
	storeGui.Enabled = false
	storeGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
end

-- Main Panel (Glass Cyan + Thick Black Stroke)
local bgFrame = storeGui:FindFirstChild("Background") :: Frame?
if not bgFrame then
	bgFrame = Instance.new("Frame")
	bgFrame.Name = "Background"
	bgFrame.Parent = storeGui
end

bgFrame.Size = UDim2.new(0, 840, 0, 480)
bgFrame.AnchorPoint = Vector2.new(0.5, 0.5)
bgFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
bgFrame.BackgroundColor3 = Color3.fromRGB(150, 240, 255) -- Glass Sky Blue
bgFrame.BackgroundTransparency = 0.5 -- Glass effect
bgFrame.BorderSizePixel = 0
applyCorner(bgFrame, UDim.new(0, 24))
applyStroke(bgFrame, 8, Color3.fromRGB(0, 0, 0))

-- Title Frame (Pill shape)
local titleFrame = bgFrame:FindFirstChild("TitleFrame") :: Frame?
if not titleFrame then
	titleFrame = Instance.new("Frame")
	titleFrame.Name = "TitleFrame"
	titleFrame.Parent = bgFrame
end
titleFrame.Size = UDim2.new(1, -60, 0, 60)
titleFrame.Position = UDim2.new(0, 30, 0, 20)
titleFrame.BackgroundColor3 = Color3.fromRGB(40, 180, 255)
titleFrame.BorderSizePixel = 0
titleFrame.ZIndex = 2
applyCorner(titleFrame, UDim.new(0.5, 0))
applyStroke(titleFrame, 6, Color3.fromRGB(0, 0, 0))

local titleLabel = titleFrame:FindFirstChild("Title") :: TextLabel?
if not titleLabel then
	titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Parent = titleFrame
end
titleLabel.Size = UDim2.new(1, 0, 1, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
titleLabel.Text = "SKILL STORE"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextSize = 36
titleLabel.ZIndex = 3
applyStroke(titleLabel, 3, Color3.fromRGB(0, 0, 0))

-- Close Button (Round Red, Protruding Top-Right)
local closeBtn = bgFrame:FindFirstChild("CloseButton") :: TextButton?
if not closeBtn then
	closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseButton"
	closeBtn.Parent = bgFrame
end
closeBtn.Size = UDim2.new(0, 44, 0, 44)
closeBtn.Position = UDim2.new(1, -22, 0, -22)
closeBtn.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
closeBtn.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.TextSize = 28
closeBtn.ZIndex = 5
applyCorner(closeBtn, UDim.new(1, 0))
applyStroke(closeBtn, 4, Color3.fromRGB(0, 0, 0), Enum.ApplyStrokeMode.Border)

local closeTextStroke = closeBtn:FindFirstChild("TextStroke") :: UIStroke?
if not closeTextStroke then
	closeTextStroke = Instance.new("UIStroke")
	closeTextStroke.Name = "TextStroke"
	closeTextStroke.Parent = closeBtn
end
closeTextStroke.Color = Color3.fromRGB(0, 0, 0)
closeTextStroke.Thickness = 2

closeBtn.MouseButton1Click:Connect(function()
	storeGui.Enabled = false
end)

-- Scrolling Frame
local scrollFrame = bgFrame:FindFirstChild("ItemsScroll") :: ScrollingFrame?
if not scrollFrame then
	scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Name = "ItemsScroll"
	scrollFrame.Parent = bgFrame
end
scrollFrame.Size = UDim2.new(1, -30, 1, -96)
scrollFrame.Position = UDim2.new(0, 15, 0, 86)
scrollFrame.BackgroundTransparency = 1
scrollFrame.ScrollBarThickness = 8
scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(40, 180, 255)
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y

local padding = scrollFrame:FindFirstChildOfClass("UIPadding")
if not padding then
	padding = Instance.new("UIPadding")
	padding.Parent = scrollFrame
end
padding.PaddingTop = UDim.new(0, 6)
padding.PaddingBottom = UDim.new(0, 16)
padding.PaddingLeft = UDim.new(0, 6)
padding.PaddingRight = UDim.new(0, 6)

local gridLayout = scrollFrame:FindFirstChildOfClass("UIGridLayout")
if not gridLayout then
	gridLayout = Instance.new("UIGridLayout")
	gridLayout.Parent = scrollFrame
end
gridLayout.CellSize = UDim2.new(0, 245, 0, 360)
gridLayout.CellPadding = UDim2.new(0, 15, 0, 18)
gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder

-- Clear any old placeholder items
for _, child in ipairs(scrollFrame:GetChildren()) do
	if child:IsA("Frame") then
		child:Destroy()
	end
end

-- Helper to create diagonal stripe pattern
local function createStripePattern(parent: Instance)
	local patternBg = Instance.new("Frame")
	patternBg.Name = "PatternBg"
	patternBg.Size = UDim2.new(1, 0, 1, 0)
	patternBg.BackgroundColor3 = Color3.fromRGB(225, 242, 255) -- Soft cartoon pastel sky
	patternBg.BorderSizePixel = 0
	patternBg.ZIndex = 1
	applyCorner(patternBg, UDim.new(0, 16))

	local grad = Instance.new("UIGradient")
	grad.Rotation = 45
	local keypoints = { NumberSequenceKeypoint.new(0, 0.4) }
	for i = 1, 9 do
		local p = i / 10
		if i % 2 == 1 then
			table.insert(keypoints, NumberSequenceKeypoint.new(p, 0.4))
			table.insert(keypoints, NumberSequenceKeypoint.new(p + 0.001, 1))
		else
			table.insert(keypoints, NumberSequenceKeypoint.new(p, 1))
			table.insert(keypoints, NumberSequenceKeypoint.new(p + 0.001, 0.4))
		end
	end
	table.insert(keypoints, NumberSequenceKeypoint.new(1, 1))
	grad.Transparency = NumberSequence.new(keypoints)
	grad.Parent = patternBg
	patternBg.Parent = parent
end

local cardUpdaters: { () -> () } = {}

-- Populate Store Items with Thick Cartoon Cards (Bright Theme)
for idx, item in ipairs(SkillStoreConfig.Skills) do
	if item.isExclusive then continue end
	local card = Instance.new("Frame")
	card.Name = "ItemCard_" .. item.id
	card.BackgroundColor3 = Color3.fromRGB(255, 255, 255) -- Bright crisp white
	card.LayoutOrder = idx
	card.Parent = scrollFrame

	applyCorner(card, UDim.new(0, 16))
	applyStroke(card, 4, Color3.fromRGB(0, 0, 0))

	-- Diagonal stripe overlay (soft pastel sky)
	createStripePattern(card)

	-- Item Name Label (Matching Image 2: FredokaOne, TextSize 22, White, 3px Black UIStroke)
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "ItemName"
	nameLabel.Size = UDim2.new(1, -16, 0, 32)
	nameLabel.Position = UDim2.new(0, 8, 0, 8)
	nameLabel.BackgroundTransparency = 1
	nameLabel.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	nameLabel.Text = item.name
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextSize = 22
	nameLabel.ZIndex = 2
	applyStroke(nameLabel, 3, Color3.fromRGB(0, 0, 0))
	nameLabel.Parent = card

	-- Image Container Box (Vibrant Gold/Yellow)
	local imgContainer = Instance.new("Frame")
	imgContainer.Name = "ImageContainer"
	imgContainer.Size = UDim2.new(1, -24, 0, 115)
	imgContainer.Position = UDim2.new(0, 12, 0, 48)
	imgContainer.BackgroundColor3 = Color3.fromRGB(255, 225, 100) -- Bright cheerful yellow
	imgContainer.BorderSizePixel = 0
	imgContainer.ZIndex = 2
	applyCorner(imgContainer, UDim.new(0, 12))
	applyStroke(imgContainer, 3, Color3.fromRGB(0, 0, 0))
	imgContainer.Parent = card

	-- Skill Icon Image
	local img = Instance.new("ImageLabel")
	img.Name = "SkillIcon"
	img.Size = UDim2.new(0.85, 0, 0.85, 0)
	img.Position = UDim2.new(0.075, 0, 0.075, 0)
	img.BackgroundTransparency = 1
	img.Image = item.imageId
	img.ScaleType = Enum.ScaleType.Fit
	img.ZIndex = 3
	img.Parent = imgContainer

	-- Description Label (Enlarged to 16px, comfortable line height)
	local descLabel = Instance.new("TextLabel")
	descLabel.Name = "Description"
	descLabel.Size = UDim2.new(1, -24, 0, 115)
	descLabel.Position = UDim2.new(0, 12, 0, 172)
	descLabel.BackgroundTransparency = 1
	descLabel.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	descLabel.Text = item.description
	descLabel.TextColor3 = Color3.fromRGB(45, 50, 60) -- High contrast clear text
	descLabel.TextSize = 16
	descLabel.TextWrapped = true
	descLabel.ZIndex = 2
	applyStroke(descLabel, 1, Color3.fromRGB(255, 255, 255))
	descLabel.Parent = card

	-- Buy / Owned Buttons Container
	local btnContainer = Instance.new("Frame")
	btnContainer.Name = "ButtonContainer"
	btnContainer.Size = UDim2.new(1, -40, 0, 46)
	btnContainer.Position = UDim2.new(0, 20, 1, -56)
	btnContainer.BackgroundTransparency = 1
	btnContainer.ZIndex = 2
	btnContainer.Parent = card

	-- 🔘 Unified Action Button (BUY or ✓ OWNED)
	local actionBtn = Instance.new("TextButton")
	actionBtn.Name = "ActionButton"
	actionBtn.Size = UDim2.new(1, 0, 1, 0)
	actionBtn.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	actionBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	actionBtn.ZIndex = 3
	applyCorner(actionBtn, UDim.new(0, 12))
	applyStroke(actionBtn, 4, Color3.fromRGB(0, 0, 0), Enum.ApplyStrokeMode.Border)

	local btnTextStroke = Instance.new("UIStroke")
	btnTextStroke.Color = Color3.fromRGB(0, 0, 0)
	btnTextStroke.Thickness = 2
	btnTextStroke.Parent = actionBtn
	actionBtn.Parent = btnContainer

	-- Hover Tween Effect
	local hoverInTween = TweenService:Create(actionBtn, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(1.04, 0, 1.06, 0),
		Position = UDim2.new(-0.02, 0, -0.03, 0),
	})
	local hoverOutTween = TweenService:Create(actionBtn, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(1, 0, 1, 0),
		Position = UDim2.new(0, 0, 0, 0),
	})

	actionBtn.MouseEnter:Connect(function()
		if actionBtn.Active then hoverInTween:Play() end
	end)
	actionBtn.MouseLeave:Connect(function()
		hoverOutTween:Play()
	end)

	-- Check ownership
	local function checkOwnsSkill(): boolean
		local ownedFolder = LocalPlayer:FindFirstChild("OwnedSkills")
		return (ownedFolder ~= nil and ownedFolder:FindFirstChild(item.id) ~= nil)
	end

	-- Update function for card state
	local function updateCardState()
		if checkOwnsSkill() then
			actionBtn.Text = "✓ OWNED"
			actionBtn.TextSize = 20
			actionBtn.BackgroundColor3 = Color3.fromRGB(210, 220, 230)
			actionBtn.Active = false
			actionBtn.AutoButtonColor = false
		else
			actionBtn.Text = "🟡 " .. formatNumber(item.goldPrice) .. " G"
			actionBtn.TextSize = 22
			actionBtn.BackgroundColor3 = Color3.fromRGB(100, 220, 110)
			actionBtn.Active = true
			actionBtn.AutoButtonColor = true
		end
	end
	table.insert(cardUpdaters, updateCardState)

	-- Purchase Click Handler
	local isBuying = false
	actionBtn.MouseButton1Click:Connect(function()
		-- 🛑 이미 보유 중이면 절대 동작하지 않고 즉시 차단!
		if checkOwnsSkill() then
			updateCardState()
			return
		end

		if isBuying then return end
		isBuying = true

		local success, msg = purchaseItemRemote:InvokeServer(item.id, "Gold")
		if success then
			-- Flash Gold
			actionBtn.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
			actionBtn.Text = "✨ PURCHASED!"
			task.wait(0.6)
			updateCardState()
		else
			-- If already owned, immediately transition to OWNED and lock
			if msg and tostring(msg):lower():find("already owned") then
				local ownedFolder = LocalPlayer:FindFirstChild("OwnedSkills")
				if ownedFolder and not ownedFolder:FindFirstChild(item.id) then
					local s = Instance.new("StringValue")
					s.Name = item.id
					s.Parent = ownedFolder
				end
				updateCardState()
			else
				-- Flash Red with message
				local originalText = actionBtn.Text
				local originalColor = actionBtn.BackgroundColor3
				actionBtn.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
				actionBtn.Text = "❌ " .. tostring(msg or "FAILED")
				task.wait(1.2)
				if not checkOwnsSkill() then
					actionBtn.BackgroundColor3 = originalColor
					actionBtn.Text = originalText
				else
					updateCardState()
				end
			end
		end

		isBuying = false
	end)
end

-- Refresh all cards ownership state
local function refreshAllCards()
	for _, updater in ipairs(cardUpdaters) do
		updater()
	end
end

-- Bind to ownership changes (when folder is created or items added/removed)
task.spawn(function()
	local ownedFolder = LocalPlayer:WaitForChild("OwnedSkills", 15)
	if ownedFolder then
		refreshAllCards()
		ownedFolder.ChildAdded:Connect(refreshAllCards)
		ownedFolder.ChildRemoved:Connect(refreshAllCards)
	end
end)

-- Open Store Event: Always refresh card states on open
openStoreRemote.OnClientEvent:Connect(function()
	refreshAllCards()
	storeGui.Enabled = true
end)

-- =========================================================================
-- 📱 RESPONSIVE UI SCALING
-- =========================================================================
local uiScale = Instance.new("UIScale", bgFrame)

local function updateResponsiveScale()
	local viewport = workspace.CurrentCamera.ViewportSize
	if viewport.X == 0 or viewport.Y == 0 then return end
	local scale = math.min(viewport.X / 1280, viewport.Y / 720)
	uiScale.Scale = math.clamp(scale, 0.4, 1.1)
end

local resizeConn = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveScale)
updateResponsiveScale()
task.delay(0.1, updateResponsiveScale)

storeGui.Destroying:Connect(function()
	if resizeConn then resizeConn:Disconnect() end
end)
