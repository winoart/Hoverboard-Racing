--!strict
-- SkillActionController.client.luau
-- Manages the Skill UI HUD on the right side and input triggers

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local playerGui = LocalPlayer:WaitForChild("PlayerGui")
local equippedSkillsFolder = LocalPlayer:WaitForChild("EquippedSkills")
local maxSkillSlots = LocalPlayer:WaitForChild("MaxSkillSlots")

local hoverRemotes = ReplicatedStorage:WaitForChild("HoverboardRemotes")
local phaseRemote = hoverRemotes:WaitForChild("GamePhaseChanged") :: RemoteEvent
local countdownRemote = hoverRemotes:WaitForChild("StartCountdownSignal") :: RemoteEvent
local useSkillRemote = hoverRemotes:WaitForChild("UseSkill") :: RemoteEvent
local skillWarningRemote = hoverRemotes:WaitForChild("SkillWarning") :: RemoteEvent

-- Temporary Product ID for unlocking the 3rd slot
local UNLOCK_SLOT3_PRODUCT_ID = 123456789 

-- Store config to get image/name
local SkillStoreConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SkillStoreConfig"))

local isRaceStarted = false
local clientCooldowns = {}
local SKILL_COOLDOWNS = {
	Skill_IceBomb = 10,
}

-- Create UI
local gui = Instance.new("ScreenGui")
gui.Name = "SkillActionGui"
gui.ResetOnSpawn = false
gui.Parent = playerGui

local container = Instance.new("Frame")
container.Name = "SlotsContainer"
container.Size = UDim2.new(0, 80, 0, 260)
container.Position = UDim2.new(1, -100, 0.5, -130)
container.BackgroundTransparency = 1
container.Parent = gui

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 15)
listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = container

local slots = {}
local hotkeys = { Enum.KeyCode.Q, Enum.KeyCode.E, Enum.KeyCode.R }
local hotkeyStrs = { "Q", "E", "R" }

local function showSkillToast(skillName: string)
	local toast = Instance.new("TextLabel")
	toast.Size = UDim2.new(0, 400, 0, 60)
	toast.Position = UDim2.new(0.5, -200, 0.7, 0)
	toast.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
	toast.BackgroundTransparency = 0.2
	toast.Font = Enum.Font.GothamBlack
	toast.Text = "🔥 [" .. skillName .. "] 발동!"
	toast.TextColor3 = Color3.fromRGB(255, 200, 50)
	toast.TextSize = 24
	toast.Parent = gui
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 15)
	corner.Parent = toast
	
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 150, 0)
	stroke.Thickness = 2
	stroke.Parent = toast
	
	-- Animate up and fade out
	TweenService:Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, -200, 0.65, 0) }):Play()
	task.delay(1.5, function()
		local t = TweenService:Create(toast, TweenInfo.new(0.5), { TextTransparency = 1, BackgroundTransparency = 1 })
		TweenService:Create(stroke, TweenInfo.new(0.5), { Transparency = 1 }):Play()
		t:Play()
		t.Completed:Connect(function()
			toast:Destroy()
		end)
	end)
end

local function showWarningToast(message: string)
	local toast = Instance.new("TextLabel")
	toast.Size = UDim2.new(0, 500, 0, 70)
	toast.Position = UDim2.new(0.5, -250, 0.3, 0)
	toast.BackgroundColor3 = Color3.fromRGB(50, 20, 20)
	toast.BackgroundTransparency = 0.2
	toast.Font = Enum.Font.GothamBlack
	toast.Text = "⚠️ " .. message
	toast.TextColor3 = Color3.fromRGB(255, 100, 100)
	toast.TextSize = 24
	toast.Parent = gui
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 15)
	corner.Parent = toast
	
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 50, 50)
	stroke.Thickness = 3
	stroke.Parent = toast
	
	-- Flashing effect
	local flashTween = TweenService:Create(toast, TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { BackgroundColor3 = Color3.fromRGB(100, 20, 20) })
	flashTween:Play()
	
	-- Animate up and fade out
	TweenService:Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, -250, 0.25, 0) }):Play()
	task.delay(2.5, function()
		flashTween:Cancel()
		local t = TweenService:Create(toast, TweenInfo.new(0.5), { TextTransparency = 1, BackgroundTransparency = 1 })
		TweenService:Create(stroke, TweenInfo.new(0.5), { Transparency = 1 }):Play()
		t:Play()
		t.Completed:Connect(function()
			toast:Destroy()
		end)
	end)
end

local function createSlot(index: number)
	local slotFrame = Instance.new("ImageButton")
	slotFrame.Name = "Slot" .. index
	slotFrame.Size = UDim2.new(0, 70, 0, 70)
	slotFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	slotFrame.BackgroundTransparency = 0.2
	slotFrame.LayoutOrder = index
	slotFrame.Parent = container
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0) -- Circle
	corner.Parent = slotFrame
	
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(150, 150, 150)
	stroke.Thickness = 2
	stroke.Parent = slotFrame
	
	local icon = Instance.new("ImageLabel")
	icon.Size = UDim2.new(1, -10, 1, -10)
	icon.Position = UDim2.new(0.5, 0, 0.5, 0)
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.BackgroundTransparency = 1
	icon.Image = ""
	icon.Parent = slotFrame
	
	local cornerIcon = Instance.new("UICorner")
	cornerIcon.CornerRadius = UDim.new(0.5, 0)
	cornerIcon.Parent = icon
	
	local hotkeyLabel = Instance.new("TextLabel")
	hotkeyLabel.Size = UDim2.new(0, 24, 0, 24)
	hotkeyLabel.Position = UDim2.new(1, -10, 0, -5)
	hotkeyLabel.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
	hotkeyLabel.Font = Enum.Font.GothamBlack
	hotkeyLabel.Text = hotkeyStrs[index]
	hotkeyLabel.TextColor3 = Color3.fromRGB(0, 0, 0)
	hotkeyLabel.TextSize = 14
	hotkeyLabel.Parent = slotFrame
	
	local hkCorner = Instance.new("UICorner")
	hkCorner.CornerRadius = UDim.new(1, 0)
	hkCorner.Parent = hotkeyLabel
	
	local overlay = Instance.new("Frame")
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	overlay.BackgroundTransparency = 0.5
	overlay.Visible = true -- Default locked in lobby
	overlay.Parent = slotFrame
	
	local overlayCorner = Instance.new("UICorner")
	overlayCorner.CornerRadius = UDim.new(0.5, 0)
	overlayCorner.Parent = overlay
	
	-- For slot 3 lock
	local lockIcon = Instance.new("TextLabel")
	lockIcon.Size = UDim2.new(1, 0, 1, 0)
	lockIcon.BackgroundTransparency = 1
	lockIcon.Font = Enum.Font.GothamBold
	lockIcon.Text = "🔒\n50 R$"
	lockIcon.TextColor3 = Color3.fromRGB(255, 100, 100)
	lockIcon.TextSize = 16
	lockIcon.Visible = false
	lockIcon.Parent = slotFrame
	
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 0, 20)
	nameLabel.Position = UDim2.new(0, 0, 1, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Text = ""
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextSize = 12
	nameLabel.Parent = slotFrame
	
	slots[index] = {
		frame = slotFrame,
		icon = icon,
		stroke = stroke,
		overlay = overlay,
		lock = lockIcon,
		nameLabel = nameLabel,
		skillId = nil
	}
	


	slotFrame.MouseButton1Click:Connect(function()
		if index == 3 and maxSkillSlots.Value < 3 then
			-- Prompt Purchase
			MarketplaceService:PromptProductPurchase(LocalPlayer, UNLOCK_SLOT3_PRODUCT_ID)
			return
		end
		
		if slots[index].skillId and isRaceStarted then
			local skillId = slots[index].skillId
			
			local lastUsed = clientCooldowns[skillId]
			local cooldown = SKILL_COOLDOWNS[skillId] or 10
			if lastUsed and (os.clock() - lastUsed) < cooldown then
				print("⏳ 아직 쿨타임 중입니다!")
				return
			end
			
			clientCooldowns[skillId] = os.clock()
			
			local sInfo = getSkillInfo(skillId)
			local sName = sInfo and sInfo.name or skillId
			print("🔥 스킬 사용: " .. sName)
			showSkillToast(sName)
			
			useSkillRemote:FireServer(skillId)
			
			-- Cooldown UI logic
			slotFrame.overlay.Visible = true
			local fillRatio = 1
			local conn
			conn = game:GetService("RunService").RenderStepped:Connect(function()
				local elapsed = os.clock() - clientCooldowns[skillId]
				if elapsed >= cooldown then
					slotFrame.overlay.Visible = false
					conn:Disconnect()
				else
					-- We could animate overlay size or transparency here
				end
			end)
		end
	end)
end

for i = 1, 3 do
	createSlot(i)
end

-- Function to get skill info from Config
local function getSkillInfo(skillId: string)
	for _, skill in ipairs(SkillStoreConfig.Skills) do
		if skill.id == skillId then
			return skill
		end
	end
	return nil
end

-- Refresh UI based on equipped skills and max slots
local function refreshSlots()
	local equipped = equippedSkillsFolder:GetChildren()
	local currentMax = maxSkillSlots.Value
	
	for i = 1, 3 do
		local slot = slots[i]
		
		-- Manage Lock status for Slot 3
		if i > currentMax then
			slot.lock.Visible = true
			slot.icon.Image = ""
			slot.nameLabel.Text = ""
			slot.skillId = nil
			slot.stroke.Color = Color3.fromRGB(80, 80, 80)
			slot.overlay.Visible = true
		else
			slot.lock.Visible = false
			
			local skillVal = equipped[i]
			if skillVal then
				slot.skillId = skillVal.Name
				local info = getSkillInfo(skillVal.Name)
				if info then
					slot.icon.Image = info.imageId
					slot.nameLabel.Text = info.name
					slot.stroke.Color = Color3.fromRGB(255, 215, 0)
				end
			else
				slot.skillId = nil
				slot.icon.Image = ""
				slot.nameLabel.Text = ""
				slot.stroke.Color = Color3.fromRGB(150, 150, 150)
			end
			
			-- Overlay logic (darken if not racing or if empty)
			if not isRaceStarted or not slot.skillId then
				slot.overlay.Visible = true
			else
				slot.overlay.Visible = false
			end
		end
	end
end

-- Listen for equipped skills changes
equippedSkillsFolder.ChildAdded:Connect(refreshSlots)
equippedSkillsFolder.ChildRemoved:Connect(refreshSlots)
maxSkillSlots.Changed:Connect(refreshSlots)

-- Listen for Game Phase
phaseRemote.OnClientEvent:Connect(function(phase, timeLeft)
	if phase ~= "RACE_MATCH" then
		isRaceStarted = false
		refreshSlots()
	end
end)

countdownRemote.OnClientEvent:Connect(function(count)
	if count == 0 then
		isRaceStarted = true
		refreshSlots()
	end
end)

skillWarningRemote.OnClientEvent:Connect(function(casterName: string, skillId: string)
	local sInfo = getSkillInfo(skillId)
	local sName = sInfo and sInfo.name or skillId
	showWarningToast(casterName .. "님이 당신에게 " .. sName .. "을(를) 사용했습니다!")
end)

-- Key inputs
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if not isRaceStarted then return end
	
	for i, key in ipairs(hotkeys) do
		if input.KeyCode == key then
			if slots[i] and slots[i].skillId and maxSkillSlots.Value >= i then
				local skillId = slots[i].skillId
				local lastUsed = clientCooldowns[skillId]
				local cooldown = SKILL_COOLDOWNS[skillId] or 10
				if lastUsed and (os.clock() - lastUsed) < cooldown then
					print("⏳ 쿨타임 중입니다!")
					continue
				end
				
				clientCooldowns[skillId] = os.clock()
				
				local sInfo = getSkillInfo(skillId)
				local sName = sInfo and sInfo.name or skillId
				print("🔥 단축키로 스킬 사용: " .. sName)
				showSkillToast(sName)
				
				useSkillRemote:FireServer(skillId)
				
				-- Cooldown UI logic
				slots[i].overlay.Visible = true
				local conn
				conn = game:GetService("RunService").RenderStepped:Connect(function()
					if not clientCooldowns[skillId] then conn:Disconnect(); return end
					local elapsed = os.clock() - clientCooldowns[skillId]
					if elapsed >= cooldown then
						slots[i].overlay.Visible = false
						conn:Disconnect()
					end
				end)
			end
		end
	end
end)

-- Initial refresh
refreshSlots()
