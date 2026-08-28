--!strict
-- StoreController.client.luau
-- Displays the Hoverboard Store UI

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local playerGui = LocalPlayer:WaitForChild("PlayerGui")

local remotesFolder = ReplicatedStorage:WaitForChild("HoverboardRemotes")
local openStoreRemote = remotesFolder:WaitForChild("OpenStore") :: RemoteEvent
local purchaseItemRemote = remotesFolder:WaitForChild("PurchaseItem") :: RemoteFunction
local equipItemRemote = remotesFolder:WaitForChild("EquipItem") :: RemoteFunction

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StoreConfig = require(Shared:WaitForChild("StoreConfig") :: ModuleScript)

-- Create the Store UI
local storeGui = Instance.new("ScreenGui")
storeGui.Name = "HoverboardStoreGui"
storeGui.ResetOnSpawn = false
storeGui.Enabled = false
storeGui.Parent = playerGui

local bgFrame = Instance.new("Frame")
bgFrame.Name = "Background"
bgFrame.Size = UDim2.new(0, 800, 0, 500)
bgFrame.Position = UDim2.new(0.5, -400, 0.5, -250)
bgFrame.BackgroundColor3 = Color3.fromRGB(15, 20, 30)
bgFrame.BackgroundTransparency = 0.05
bgFrame.BorderSizePixel = 0
bgFrame.Parent = storeGui

local bgCorner = Instance.new("UICorner")
bgCorner.CornerRadius = UDim.new(0, 12)
bgCorner.Parent = bgFrame

local bgStroke = Instance.new("UIStroke")
bgStroke.Color = Color3.fromRGB(255, 215, 0)
bgStroke.Thickness = 3
bgStroke.Parent = bgFrame

-- Title
local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(1, 0, 0, 50)
titleLabel.Position = UDim2.new(0, 0, 0, 10)
titleLabel.BackgroundTransparency = 1
titleLabel.Font = Enum.Font.GothamBlack
titleLabel.Text = "🛒 HOVERBOARD STORE"
titleLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
titleLabel.TextSize = 28
titleLabel.Parent = bgFrame

-- Close Button
local closeBtn = Instance.new("TextButton")
closeBtn.Name = "CloseButton"
closeBtn.Size = UDim2.new(0, 40, 0, 40)
closeBtn.Position = UDim2.new(1, -50, 0, 10)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.TextSize = 20
closeBtn.Parent = bgFrame

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 8)
closeCorner.Parent = closeBtn

closeBtn.MouseButton1Click:Connect(function()
	storeGui.Enabled = false
end)

-- Scroll Frame for Items
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Name = "ItemsScroll"
scrollFrame.Size = UDim2.new(1, -40, 1, -80)
scrollFrame.Position = UDim2.new(0, 20, 0, 60)
scrollFrame.BackgroundTransparency = 1
scrollFrame.ScrollBarThickness = 8
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrollFrame.Parent = bgFrame

-- Grid Layout (3 per row)
local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.new(0, 240, 0, 280)
gridLayout.CellPadding = UDim2.new(0, 15, 0, 20)
gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = scrollFrame

-- Populate Store Items
for idx, item in ipairs(StoreConfig.Items) do
	local card = Instance.new("Frame")
	card.Name = "ItemCard_" .. item.id
	card.BackgroundColor3 = Color3.fromRGB(25, 30, 45)
	card.LayoutOrder = idx
	card.Parent = scrollFrame
	
	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 10)
	cardCorner.Parent = card
	
	local cardStroke = Instance.new("UIStroke")
	cardStroke.Color = Color3.fromRGB(100, 120, 150)
	cardStroke.Thickness = 2
	cardStroke.Parent = card
	
	-- Item Name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 0, 40)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Text = item.name
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextSize = 18
	nameLabel.Parent = card
	
	-- Item Image
	local img = Instance.new("ImageLabel")
	img.Size = UDim2.new(1, -20, 0, 140)
	img.Position = UDim2.new(0, 10, 0, 40)
	img.BackgroundColor3 = Color3.fromRGB(15, 20, 30)
	img.Image = item.imageId
	img.ScaleType = Enum.ScaleType.Fit
	img.Parent = card
	
	local imgCorner = Instance.new("UICorner")
	imgCorner.CornerRadius = UDim.new(0, 8)
	imgCorner.Parent = img
	
	-- Buy Buttons Container
	local btnsFrame = Instance.new("Frame")
	btnsFrame.Size = UDim2.new(1, -20, 0, 70)
	btnsFrame.Position = UDim2.new(0, 10, 1, -80)
	btnsFrame.BackgroundTransparency = 1
	btnsFrame.Parent = card
	
	-- Gold Button
	local goldBtn = Instance.new("TextButton")
	goldBtn.Size = UDim2.new(1, 0, 0, 30)
	goldBtn.Position = UDim2.new(0, 0, 0, 0)
	goldBtn.BackgroundColor3 = Color3.fromRGB(255, 180, 0)
	goldBtn.Font = Enum.Font.GothamBold
	goldBtn.Text = "🟡 " .. item.goldPrice .. " G"
	goldBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
	goldBtn.TextSize = 16
	goldBtn.Parent = btnsFrame
	
	local gCorner = Instance.new("UICorner")
	gCorner.CornerRadius = UDim.new(0, 6)
	gCorner.Parent = goldBtn
	
	-- Robux Button
	local robuxBtn = Instance.new("TextButton")
	robuxBtn.Size = UDim2.new(1, 0, 0, 30)
	robuxBtn.Position = UDim2.new(0, 0, 0, 40)
	robuxBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 80)
	robuxBtn.Font = Enum.Font.GothamBold
	robuxBtn.Text = "💸 " .. item.robuxPrice .. " R$"
	robuxBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	robuxBtn.TextSize = 16
	robuxBtn.Parent = btnsFrame
	
	local rCorner = Instance.new("UICorner")
	rCorner.CornerRadius = UDim.new(0, 6)
	rCorner.Parent = robuxBtn

	-- Status Button (Owned / Equipped)
	local statusBtn = Instance.new("TextButton")
	statusBtn.Size = UDim2.new(1, 0, 1, 0)
	statusBtn.Position = UDim2.new(0, 0, 0, 0)
	statusBtn.Font = Enum.Font.GothamBold
	statusBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	statusBtn.TextSize = 18
	statusBtn.Visible = false
	statusBtn.Parent = btnsFrame

	local sCorner = Instance.new("UICorner")
	sCorner.CornerRadius = UDim.new(0, 8)
	sCorner.Parent = statusBtn
	
	-- Update function for this card
	local function updateCardState()
		local ownedFolder = LocalPlayer:FindFirstChild("OwnedHoverboards")
		local equippedId = LocalPlayer:FindFirstChild("EquippedHoverboardId") :: StringValue?
		
		if ownedFolder and ownedFolder:FindFirstChild(item.id) then
			-- Owned!
			goldBtn.Visible = false
			robuxBtn.Visible = false
			statusBtn.Visible = true
			
			if equippedId and equippedId.Value == item.id then
				-- Equipped
				statusBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
				statusBtn.Text = "✅ 장착중"
				statusBtn.AutoButtonColor = false
			else
				-- Owned, not equipped
				statusBtn.BackgroundColor3 = Color3.fromRGB(30, 120, 255)
				statusBtn.Text = "🧰 보유중"
				statusBtn.AutoButtonColor = true
			end
		else
			-- Not owned
			goldBtn.Visible = true
			robuxBtn.Visible = true
			statusBtn.Visible = false
		end
	end
	
	-- Hook events to update state
	local function bindStateEvents()
		local ownedFolder = LocalPlayer:WaitForChild("OwnedHoverboards")
		ownedFolder.ChildAdded:Connect(updateCardState)
		ownedFolder.ChildRemoved:Connect(updateCardState)
		
		local equippedId = LocalPlayer:WaitForChild("EquippedHoverboardId") :: StringValue
		equippedId.Changed:Connect(updateCardState)
	end
	task.spawn(bindStateEvents)
	task.spawn(updateCardState)
	
	local function buy(currency)
		local success, msg = purchaseItemRemote:InvokeServer(item.id, currency)
		if success then
			-- Flash green
			cardStroke.Color = Color3.fromRGB(0, 255, 0)
			nameLabel.Text = "✅ Purchased!"
			task.wait(1)
			nameLabel.Text = item.name
			cardStroke.Color = Color3.fromRGB(100, 120, 150)
		else
			-- Flash red
			cardStroke.Color = Color3.fromRGB(255, 0, 0)
			nameLabel.Text = "❌ " .. msg
			task.wait(1)
			nameLabel.Text = item.name
			cardStroke.Color = Color3.fromRGB(100, 120, 150)
		end
	end
	
	goldBtn.MouseButton1Click:Connect(function() buy("Gold") end)
	robuxBtn.MouseButton1Click:Connect(function() buy("Robux") end)
	
	statusBtn.MouseButton1Click:Connect(function()
		local equippedId = LocalPlayer:FindFirstChild("EquippedHoverboardId") :: StringValue?
		if equippedId and equippedId.Value ~= item.id then
			local success, msg = equipItemRemote:InvokeServer(item.id)
			if success then
				cardStroke.Color = Color3.fromRGB(0, 255, 0)
				task.wait(0.5)
				cardStroke.Color = Color3.fromRGB(100, 120, 150)
			end
		end
	end)
end

-- Open Store Event
openStoreRemote.OnClientEvent:Connect(function()
	storeGui.Enabled = true
end)
