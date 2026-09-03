--!strict
-- SkillStoreController.client.luau
-- Displays the Skill Store UI (Purchase Only)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local playerGui = LocalPlayer:WaitForChild("PlayerGui")

local remotesFolder = ReplicatedStorage:WaitForChild("SkillRemotes")
local openStoreRemote = remotesFolder:WaitForChild("OpenSkillStore") :: RemoteEvent
local purchaseItemRemote = remotesFolder:WaitForChild("PurchaseSkill") :: RemoteFunction

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SkillStoreConfig = require(Shared:WaitForChild("SkillStoreConfig") :: ModuleScript)

print("💻 [SkillStoreController] 스킬상점 UI 클라이언트 스크립트 가동 시작!")

local storeGui = playerGui:WaitForChild("SkillStoreGui")
local bgFrame = storeGui:WaitForChild("Background")
local closeBtn = bgFrame:WaitForChild("CloseButton") :: TextButton

closeBtn.MouseButton1Click:Connect(function()
	storeGui.Enabled = false
end)

local scrollFrame = bgFrame:WaitForChild("ItemsScroll") :: ScrollingFrame

-- Populate Store Items
for idx, item in ipairs(SkillStoreConfig.Skills) do
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
	nameLabel.TextSize = 28
	nameLabel.Parent = card
	
	-- Item Image
	local img = Instance.new("ImageLabel")
	img.Size = UDim2.new(1, -20, 0, 120)
	img.Position = UDim2.new(0, 10, 0, 40)
	img.BackgroundColor3 = Color3.fromRGB(15, 20, 30)
	img.Image = item.imageId
	img.ScaleType = Enum.ScaleType.Fit
	img.Parent = card
	
	local imgCorner = Instance.new("UICorner")
	imgCorner.CornerRadius = UDim.new(0, 8)
	imgCorner.Parent = img

	-- Description
	local descLabel = Instance.new("TextLabel")
	descLabel.Size = UDim2.new(1, -20, 0, 40)
	descLabel.Position = UDim2.new(0, 10, 0, 160)
	descLabel.BackgroundTransparency = 1
	descLabel.Font = Enum.Font.Gotham
	descLabel.Text = item.description
	descLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	descLabel.TextSize = 12
	descLabel.TextWrapped = true
	descLabel.Parent = card
	
	-- Buy Buttons Container
	local btnsFrame = Instance.new("Frame")
	btnsFrame.Size = UDim2.new(1, -20, 0, 70)
	btnsFrame.Position = UDim2.new(0, 10, 1, -80)
	btnsFrame.BackgroundTransparency = 1
	btnsFrame.Parent = card
	
	-- Gold Button
	local goldBtn = Instance.new("TextButton")
	goldBtn.Size = UDim2.new(1, 0, 0, 30)
	goldBtn.Position = UDim2.new(0, 0, 0, 20)
	goldBtn.BackgroundColor3 = Color3.fromRGB(255, 180, 0)
	goldBtn.Font = Enum.Font.GothamBold
	goldBtn.Text = "🟡 " .. item.goldPrice .. " G"
	goldBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
	goldBtn.TextSize = 16
	goldBtn.Parent = btnsFrame
	
	local gCorner = Instance.new("UICorner")
	gCorner.CornerRadius = UDim.new(0, 6)
	gCorner.Parent = goldBtn

	-- Status Label (Owned)
	local statusLabel = Instance.new("TextLabel")
	statusLabel.Size = UDim2.new(1, 0, 1, 0)
	statusLabel.Position = UDim2.new(0, 0, 0, 0)
	statusLabel.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
	statusLabel.Font = Enum.Font.GothamBold
	statusLabel.Text = "✅ 보유중"
	statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	statusLabel.TextSize = 18
	statusLabel.Visible = false
	statusLabel.Parent = btnsFrame

	local sCorner = Instance.new("UICorner")
	sCorner.CornerRadius = UDim.new(0, 8)
	sCorner.Parent = statusLabel
	
	-- Update function for this card
	local function updateCardState()
		local ownedFolder = LocalPlayer:FindFirstChild("OwnedSkills")
		
		if ownedFolder and ownedFolder:FindFirstChild(item.id) then
			-- Owned!
			goldBtn.Visible = false
			statusLabel.Visible = true
		else
			-- Not owned
			goldBtn.Visible = true
			statusLabel.Visible = false
		end
	end
	
	-- Hook events to update state
	local function bindStateEvents()
		local ownedFolder = LocalPlayer:WaitForChild("OwnedSkills")
		ownedFolder.ChildAdded:Connect(updateCardState)
		ownedFolder.ChildRemoved:Connect(updateCardState)
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
end

-- Open Store Event
openStoreRemote.OnClientEvent:Connect(function()
	storeGui.Enabled = true
end)

