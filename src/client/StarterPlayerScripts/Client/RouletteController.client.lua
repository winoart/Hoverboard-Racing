--!strict
-- RouletteController.client.luau
-- Displays the Gacha Roulette UI for Hoverboards

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local playerGui = LocalPlayer:WaitForChild("PlayerGui")

local remotesFolder = ReplicatedStorage:WaitForChild("HoverboardRemotes")
local openStoreRemote = remotesFolder:WaitForChild("OpenStore") :: RemoteEvent
local spinRouletteRemote = remotesFolder:WaitForChild("SpinRoulette") :: RemoteFunction

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StoreConfig = require(Shared:WaitForChild("StoreConfig") :: ModuleScript)

-- Helper: Get valid roulette items
local rouletteItems = {}
for _, item in ipairs(StoreConfig.Items) do
	if item.weight and item.weight > 0 then
		table.insert(rouletteItems, item)
	end
end

local gui = playerGui:WaitForChild("HoverboardRouletteGui")
local bgFrame = gui:WaitForChild("Background")
local closeBtn = bgFrame:WaitForChild("CloseButton") :: TextButton
local viewportFrame = bgFrame:WaitForChild("Viewport") :: Frame
local stripFrame = viewportFrame:WaitForChild("Strip") :: Frame
local spinBtn = bgFrame:WaitForChild("SpinButton") :: TextButton
local msgLabel = bgFrame:WaitForChild("Message") :: TextLabel

closeBtn.MouseButton1Click:Connect(function()
	gui.Enabled = false
end)

local isSpinning = false
local ITEM_WIDTH = 180
local ITEM_PADDING = 20
local TOTAL_ITEM_WIDTH = ITEM_WIDTH + ITEM_PADDING

local function createCard(item, index)
	local card = Instance.new("Frame")
	card.Size = UDim2.new(0, ITEM_WIDTH, 0, 200)
	card.Position = UDim2.new(0, (index - 1) * TOTAL_ITEM_WIDTH + (ITEM_PADDING / 2), 0, 20)
	card.BackgroundColor3 = Color3.fromRGB(25, 30, 45)
	card.Parent = stripFrame
	
	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 10)
	cardCorner.Parent = card
	
	local rColor = StoreConfig.RarityColors[item.rarity] or Color3.fromRGB(200, 200, 200)
	
	local cardStroke = Instance.new("UIStroke")
	cardStroke.Color = rColor
	cardStroke.Thickness = 2
	cardStroke.Parent = card
	
	-- Rarity
	local rLabel = Instance.new("TextLabel")
	rLabel.Size = UDim2.new(1, 0, 0, 25)
	rLabel.BackgroundTransparency = 1
	rLabel.Font = Enum.Font.GothamBold
	rLabel.Text = item.rarity
	rLabel.TextColor3 = rColor
	rLabel.TextSize = 14
	rLabel.Parent = card

	-- Image
	local img = Instance.new("ImageLabel")
	img.Size = UDim2.new(1, -20, 0, 110)
	img.Position = UDim2.new(0, 10, 0, 30)
	img.BackgroundColor3 = Color3.fromRGB(15, 20, 30)
	img.Image = item.imageId
	img.ScaleType = Enum.ScaleType.Fit
	img.Parent = card
	
	local imgCorner = Instance.new("UICorner")
	imgCorner.CornerRadius = UDim.new(0, 8)
	imgCorner.Parent = img
	
	-- Name
	local nLabel = Instance.new("TextLabel")
	nLabel.Size = UDim2.new(1, 0, 0, 30)
	nLabel.Position = UDim2.new(0, 0, 1, -40)
	nLabel.BackgroundTransparency = 1
	nLabel.Font = Enum.Font.GothamBold
	nLabel.Text = item.name
	nLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nLabel.TextSize = 16
	nLabel.Parent = card
end

local function resetStrip()
	for _, child in ipairs(stripFrame:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
	stripFrame.Position = UDim2.new(0, 0, 0, 0)
	
	for i = 1, 10 do
		local rItem = rouletteItems[math.random(1, #rouletteItems)]
		if rItem then
			createCard(rItem, i)
		end
	end
end
resetStrip()

spinBtn.MouseButton1Click:Connect(function()
	if isSpinning then return end
	
	msgLabel.Text = "서버 결과를 기다리는 중..."
	isSpinning = true
	spinBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
	
	local success, wonItemInfo, isDuplicate = spinRouletteRemote:InvokeServer()
	
	if not success then
		msgLabel.Text = "❌ " .. tostring(wonItemInfo) -- Contains error msg
		isSpinning = false
		spinBtn.BackgroundColor3 = Color3.fromRGB(255, 180, 0)
		return
	end
	
	msgLabel.Text = ""
	
	-- Clear strip
	for _, child in ipairs(stripFrame:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
	stripFrame.Position = UDim2.new(0, 0, 0, 0)
	
	-- Generate sequence of 30 items, index 25 is the winner
	local WIN_INDEX = 25
	for i = 1, 30 do
		local rItem
		if i == WIN_INDEX then
			rItem = wonItemInfo
		else
			-- random visual item
			rItem = rouletteItems[math.random(1, #rouletteItems)]
		end
		createCard(rItem, i)
	end
	
	-- Calculate target position so WIN_INDEX is centered
	-- Center of viewport = viewportWidth / 2
	local viewWidth = viewportFrame.AbsoluteSize.X
	local centerOffset = viewWidth / 2
	local targetItemCenter = ((WIN_INDEX - 1) * TOTAL_ITEM_WIDTH) + (ITEM_PADDING / 2) + (ITEM_WIDTH / 2)
	local targetX = -targetItemCenter + centerOffset
	
	-- Add slight random offset for realism (so it doesn't always stop perfectly centered)
	local randOffset = math.random(-30, 30)
	targetX = targetX + randOffset
	
	-- Tween
	local tInfo = TweenInfo.new(4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	local tween = TweenService:Create(stripFrame, tInfo, {Position = UDim2.new(0, targetX, 0, 0)})
	
	tween:Play()
	tween.Completed:Wait()
	
	-- Show Result
	if isDuplicate then
		msgLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
		msgLabel.Text = "이미 보유한 호버보드입니다. " .. StoreConfig.RefundAmount .. " G를 돌려드립니다."
	else
		msgLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
		msgLabel.Text = "🎉 새로운 호버보드 획득! (" .. wonItemInfo.name .. ")"
	end
	
	task.wait(2)
	msgLabel.Text = ""
	isSpinning = false
	spinBtn.BackgroundColor3 = Color3.fromRGB(255, 180, 0)
end)

-- Open Event
openStoreRemote.OnClientEvent:Connect(function()
	if not isSpinning then
		gui.Enabled = true
	end
end)
