--!strict
-- InventoryController.client.luau
-- Displays the Unified Inventory UI for equipping Hoverboards and Skills

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local playerGui = LocalPlayer:WaitForChild("PlayerGui")

local hoverRemotes = ReplicatedStorage:WaitForChild("HoverboardRemotes")
local equipBoardRemote = hoverRemotes:WaitForChild("EquipItem") :: RemoteFunction

local skillRemotes = ReplicatedStorage:WaitForChild("SkillRemotes")
local equipSkillRemote = skillRemotes:WaitForChild("EquipSkill") :: RemoteFunction
local buySkillRemote = skillRemotes:WaitForChild("PurchaseSkill") :: RemoteFunction

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StoreConfig = require(Shared:WaitForChild("StoreConfig") :: ModuleScript)
local SkillStoreConfig = require(Shared:WaitForChild("SkillStoreConfig") :: ModuleScript)
local HoverboardBuilder = require(Shared:WaitForChild("HoverboardBuilder") :: ModuleScript)
local RunService = game:GetService("RunService")

-- Folder for custom models
local customModelsFolder = ReplicatedStorage:FindFirstChild("HoverboardModels")

-- Main Toggle Button (HUD)
local hudGui = playerGui:WaitForChild("InventoryHUD")
local toggleBtn = hudGui:WaitForChild("InventoryToggle")

-- Hover Effects on HUD (Removed per user request)
-- State
local currentTab = "Board"
local selectedItem: any = nil
local selectedItemType: string = "Board"

-- Inventory UI References
local invGui = playerGui:WaitForChild("InventoryGui")
invGui.Enabled = false

-- Helper to find UI elements recursively
local function findUI(name)
	for _, desc in ipairs(invGui:GetDescendants()) do
		if desc.Name == name then
			return desc
		end
	end
	return nil
end

local bgFrame = findUI("Background") or invGui:FindFirstChildWhichIsA("Frame")
local closeBtn = findUI("CloseButton")

if closeBtn then
	closeBtn.MouseButton1Click:Connect(function()
		invGui.Enabled = false
	end)
end

toggleBtn.MouseButton1Click:Connect(function()
	invGui.Enabled = not invGui.Enabled
	invGui.DisplayOrder = 100 -- Ensure it renders above other GUIs
	if bgFrame then
		bgFrame.Visible = true
	end
end)

-- Tabs
local boardsTabBtn = findUI("BoardsTab") or findUI("BoardsTab frame")
local skillsTabBtn = findUI("SkillsTab") or findUI("SkillsTab frame")

-- Force translate static text and fonts
if boardsTabBtn and boardsTabBtn:IsA("TextLabel") or (boardsTabBtn and boardsTabBtn:IsA("TextButton")) then
	boardsTabBtn.Text = "HOVERBOARDS"
	boardsTabBtn.Font = Enum.Font.FredokaOne
	boardsTabBtn.TextSize = 22
end
if skillsTabBtn and skillsTabBtn:IsA("TextLabel") or (skillsTabBtn and skillsTabBtn:IsA("TextButton")) then
	skillsTabBtn.Text = "SKILLS"
	skillsTabBtn.Font = Enum.Font.FredokaOne
	skillsTabBtn.TextSize = 22
end

-- Helper for clicking (Supports both Buttons and normal Frames)
local function bindClick(guiObject, callback)
	if not guiObject then return end
	if guiObject:IsA("GuiButton") then
		guiObject.MouseButton1Click:Connect(callback)
	else
		guiObject.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				callback()
			end
		end)
	end
end

-- Scrolls
local boardsScroll = findUI("BoardsScroll")
local skillsScroll = findUI("SkillsScroll")

-- Tab Logic
local function switchTab(tabName)
	currentTab = tabName
	if tabName == "Board" then
		if boardsScroll then boardsScroll.Visible = true end
		if skillsScroll then skillsScroll.Visible = false end
		if boardsTabBtn then boardsTabBtn.BackgroundColor3 = Color3.fromRGB(255, 200, 50) end
		if skillsTabBtn then skillsTabBtn.BackgroundColor3 = Color3.fromRGB(210, 220, 230) end
	else
		if boardsScroll then boardsScroll.Visible = false end
		if skillsScroll then skillsScroll.Visible = true end
		if boardsTabBtn then boardsTabBtn.BackgroundColor3 = Color3.fromRGB(210, 220, 230) end
		if skillsTabBtn then skillsTabBtn.BackgroundColor3 = Color3.fromRGB(255, 200, 50) end
	end
end

-- (Bindings moved to bottom to prevent race condition)

switchTab("Board")

-- Right Column (Details)
local rImage = findUI("ItemImage")
local rViewport = findUI("ItemViewport")

local rCamera = rViewport and rViewport:FindFirstChild("ViewportCamera")
if rViewport and not rCamera then
	rCamera = Instance.new("Camera")
	rCamera.Name = "ViewportCamera"
	rCamera.Parent = rViewport
end
if rViewport and rCamera then
	rViewport.CurrentCamera = rCamera
end

local rName = findUI("ItemName")
local rDesc = findUI("ItemDesc")
local actionBtn = findUI("ActionButton")

if rName and rName:IsA("TextLabel") then
	rName.Font = Enum.Font.FredokaOne
	rName.Text = "Select an Item"
end
if rDesc and rDesc:IsA("TextLabel") then
	rDesc.Font = Enum.Font.FredokaOne
	rDesc.Text = "Description text will appear here. Please select an item from the list on the left."
end
if actionBtn and actionBtn:IsA("TextButton") then
	actionBtn.Font = Enum.Font.FredokaOne
end

local allCards = {}
local renderConnections = {}

local function checkOwnsBoard(id)
	if id == "DefaultHoverboard" then return true end
	local ownBoard = LocalPlayer:FindFirstChild("OwnedHoverboards")
	if ownBoard and ownBoard:FindFirstChild(id) then return true end
	return false
end

local function checkEquippedBoard(id)
	local eqBoard = LocalPlayer:FindFirstChild("EquippedHoverboardId")
	if eqBoard and eqBoard.Value == id then return true end
	return false
end

local function checkOwnsSkill(id)
	local ownSkill = LocalPlayer:FindFirstChild("OwnedSkills")
	if ownSkill and ownSkill:FindFirstChild(id) then return true end
	return false
end

local function checkEquippedSkill(id)
	local eqSkill = LocalPlayer:FindFirstChild("EquippedSkills")
	if eqSkill and eqSkill:FindFirstChild(id) then return true end
	return false
end

local function clearRenderConnections()
	for _, conn in ipairs(renderConnections) do
		conn:Disconnect()
	end
	table.clear(renderConnections)
end

local function updateRightColumn()
	clearRenderConnections()
	
	if not selectedItem then
		if rImage then rImage.Image = "" end
		if rName then rName.Text = (currentTab == "Skill") and "Select a Skill" or "Select a Hoverboard" end
		if rDesc then rDesc.Text = (currentTab == "Skill") and "Description text will appear here. Please select a skill from the list on the left." or "Description text will appear here. Please select a hoverboard from the list on the left." end
		if rViewport then rViewport.Visible = false end
		if rImage then rImage.Visible = true end
		if actionBtn then actionBtn.Visible = false end
		return
	end
	
	local info = selectedItem
	if rName then rName.Text = info.name end
	if rDesc then rDesc.Text = info.desc or info.description or "No description available." end

	local isEquipped = false
	local isOwned = false
	
	if selectedItemType == "Board" then
		isOwned = checkOwnsBoard(info.id)
		isEquipped = checkEquippedBoard(info.id)
	else
		isOwned = checkOwnsSkill(info.id)
		isEquipped = checkEquippedSkill(info.id)
	end
	
	if actionBtn then
		actionBtn.Visible = true
		if isEquipped then
			actionBtn.Text = "UNEQUIP"
			actionBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
		elseif isOwned then
			actionBtn.Text = "EQUIP"
			actionBtn.BackgroundColor3 = Color3.fromRGB(60, 200, 60)
		else
			actionBtn.Text = "BUY IN STORE"
			actionBtn.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
		end
	end
	
	if selectedItemType == "Board" then
		if rImage then 
			rImage.Visible = true 
			rImage.Image = info.imageId
		end
		if rViewport then rViewport.Visible = false end
	else
		if rImage then 
			rImage.Visible = true 
			rImage.Image = info.imageId 
		end
		if rViewport then rViewport.Visible = false end
	end
	
	-- ?熬곣뫗逾???꾩룆???????夷?? ??ル봾鍮띸춯濡ル뾼?????節뗪땁 ?怨뺣뼺?
	if rImage then
		local startTick = tick()
		local basePos = UDim2.new(0.05, 0, 0.05, 0)
		local conn = RunService.RenderStepped:Connect(function()
			local t = tick() - startTick
			local bounce = math.sin(t * 2.5) * 0.04 -- ???쒖┣ 2.5, 嶺뚯쉳?든뙴?4% (嶺뚳퐣裕뉓뜎???遊붋??類ㅼ벀??
			rImage.Position = UDim2.new(basePos.X.Scale, basePos.X.Offset, basePos.Y.Scale + bounce, basePos.Y.Offset)
		end)
		table.insert(renderConnections, conn)
	end
end

if actionBtn then
	local function playInventorySound(isEquipping)
		local sound = Instance.new("Sound")
		if isEquipping then
			sound.SoundId = "rbxassetid://120577963256631" -- ?μ갑 ?뚮━
		else
			sound.SoundId = "rbxassetid://124307033081669" -- ?댁젣 ?뚮━
		end
		sound.Volume = 0.8
		sound.Parent = workspace
		sound:Play()
		game:GetService("Debris"):AddItem(sound, 3)
	end

	actionBtn.MouseButton1Click:Connect(function()
		if not selectedItem then return end
		local info = selectedItem
		
		if selectedItemType == "Board" then
			if checkOwnsBoard(info.id) then
				local wasEquipped = checkEquippedBoard(info.id)
				local success, msg = equipBoardRemote:InvokeServer(info.id)
				if success then
					playInventorySound(not wasEquipped)
				elseif not success and msg then
					pcall(function()
						game:GetService("StarterGui"):SetCore("SendNotification", {
							Title = "Notification",
							Text = msg,
							Duration = 3
						})
					end)
				end
			end
		else
			if checkOwnsSkill(info.id) then
				local wasEquipped = checkEquippedSkill(info.id)
				local success, msg = equipSkillRemote:InvokeServer(info.id)
				if success then
					playInventorySound(not wasEquipped)
				elseif not success and msg then
					pcall(function()
						game:GetService("StarterGui"):SetCore("SendNotification", {
							Title = "Notification",
							Text = msg,
							Duration = 3
						})
					end)
				end
			end
		end
		updateRightColumn()
	end)
end

local function selectItem(item, iType)
	selectedItem = item
	selectedItemType = iType
	
	for _, data in ipairs(allCards) do
		if data.item.id == item.id then
			data.stroke.Thickness = 8
		else
			data.stroke.Thickness = 5
		end
	end
	
	updateRightColumn()
end

local cardTemplate = invGui:FindFirstChild("CardTemplate")

local function createInvCard(item, itemType, parentScroll, layoutOrder)
	if not cardTemplate then return end
	local cardBtn = cardTemplate:Clone()
	cardBtn.Name = "Card_" .. item.id
	cardBtn.LayoutOrder = layoutOrder or 0
	cardBtn.Parent = parentScroll
	cardBtn.Visible = true
	
	local cardStroke = cardBtn:FindFirstChild("UIStroke")
	if cardStroke then cardStroke.Thickness = 5 end
	
	local img = cardBtn:FindFirstChild("Image")
	if not img then
		img = Instance.new("ImageLabel")
		img.Name = "Image"
		img.Size = UDim2.new(1, -20, 0, 110)
		img.Position = UDim2.new(0, 10, 0, 10)
		img.BackgroundTransparency = 1
		img.ScaleType = Enum.ScaleType.Fit
		img.ZIndex = 10 -- ?筌????꾩룄?쀧몭?Viewport)?곌랜?????쒕샍??롮퀪??熬곣뫖?????살┣??ZIndex 10
		img.Parent = cardBtn
	else
		img.ZIndex = 10
	end
	
	local vpf = cardBtn:FindFirstChild("Viewport")
	
	-- ?곌랜?????븐슙?? ???꾪뀬???????筌뤾퍔?붺솻洹?獄?씛??濡?뱿 ????덧 ?筌????꾩룆踰??낆쾸? ?곌랜??議얠물???????
	if itemType == "Board" then
		img.Visible = true
		img.Image = item.imageId
		if vpf then vpf.Visible = true end
	else
		img.Visible = true
		img.Image = item.imageId
		if vpf then vpf.Visible = true end
	end
	
	local nameLabel = cardBtn:FindFirstChild("ItemName", true)
	if nameLabel then 
		nameLabel.Text = string.gsub(item.name, "%s*%([a-zA-Z?띠럾?-??s]+%)", "")
		nameLabel.Font = Enum.Font.FredokaOne
	end
	
	local statusLabel = cardBtn:FindFirstChild("Status")
	if statusLabel then 
		statusLabel.Visible = false 
		statusLabel.Font = Enum.Font.FredokaOne
	end
	
	local checkIcon = Instance.new("ImageLabel")
	checkIcon.Name = "EquippedCheck"
	checkIcon.Size = UDim2.new(0, 64, 0, 64)
	checkIcon.Position = UDim2.new(0, 8, 0, 8)
	checkIcon.BackgroundTransparency = 1
	checkIcon.Image = "rbxassetid://17368190066"
	checkIcon.Visible = false
	checkIcon.ZIndex = 10 -- ?곸궠?獄??嶺뚮ㅄ維獄???븐슜爰?ZIndex 8,9)?곌랜????熬곣뫖?????녹┣?????깆젧
	checkIcon.Parent = cardBtn
	
	table.insert(allCards, {card = cardBtn, stroke = cardStroke, item = item, itemType = itemType, checkIcon = checkIcon, img = img})
	
	cardBtn.MouseButton1Click:Connect(function()
		selectItem(item, itemType)
	end)
end

local function refreshCardsVisibility()
	for _, data in ipairs(allCards) do
		local isOwned = data.itemType == "Board" and checkOwnsBoard(data.item.id) or checkOwnsSkill(data.item.id)
		local isEquipped = data.itemType == "Board" and checkEquippedBoard(data.item.id) or checkEquippedSkill(data.item.id)
		
		data.card.Visible = isOwned and true or false -- ?곌랜??????熬곣뫗逾??類ㅼ떳 ??戮?뻣
		data.checkIcon.Visible = isEquipped
	end
	if selectedItem then updateRightColumn() end
end

local function getItemById(config, id)
	for _, item in ipairs(config) do
		if item.id == id then return item end
	end
	return nil
end

local function initializeInventoryCards()
	local ownBoard = LocalPlayer:WaitForChild("OwnedHoverboards")
	local ownSkill = LocalPlayer:WaitForChild("OwnedSkills")

	-- UIGridLayout SortOrder??LayoutOrder???띠룆踰?????깆젧
	if boardsScroll then
		local grid = boardsScroll:FindFirstChildOfClass("UIGridLayout")
		if grid then grid.SortOrder = Enum.SortOrder.LayoutOrder end
	end
	if skillsScroll then
		local grid = skillsScroll:FindFirstChildOfClass("UIGridLayout")
		if grid then grid.SortOrder = Enum.SortOrder.LayoutOrder end
	end

	if boardsScroll then
		-- 1. ??곕?塋??ル봾鍮?DefaultHoverboard) ??쒕샍??롮퀪?嶺???(LayoutOrder = 0)
		local defaultBoard = getItemById(StoreConfig.Items, "DefaultHoverboard")
		if defaultBoard then
			createInvCard(defaultBoard, "Board", boardsScroll, 0)
		end
		-- 2. ???쒓덫???筌뤾퍔?붺솻洹?獄?쓣紐?OwnedHoverboards ???????戮?맋(???쒓덫 ??????
		local boardOrder = 1
		for _, child in ipairs(ownBoard:GetChildren()) do
			if child.Name ~= "DefaultHoverboard" then
				local item = getItemById(StoreConfig.Items, child.Name)
				if item then
					createInvCard(item, "Board", boardsScroll, boardOrder)
					boardOrder += 1
				end
			end
		end
		-- ???됱Ŧ ???쒓덫 ???곸궠?獄????됱쓤 ?怨뺣뼺?
		local nextBoardOrder = boardOrder
		ownBoard.ChildAdded:Connect(function(child)
			if child.Name ~= "DefaultHoverboard" then
				local item = getItemById(StoreConfig.Items, child.Name)
				if item then
					createInvCard(item, "Board", boardsScroll, nextBoardOrder)
					nextBoardOrder += 1
					refreshCardsVisibility()
				end
			end
		end)
	end

	if skillsScroll then
		-- ???꾪뀬?? OwnedSkills ???????戮?맋(???쒓덫 ??????
		local skillOrder = 0
		for _, child in ipairs(ownSkill:GetChildren()) do
			local item = getItemById(SkillStoreConfig.Skills, child.Name)
			if item then
				createInvCard(item, "Skill", skillsScroll, skillOrder)
				skillOrder += 1
			end
		end
		-- ???됱Ŧ ???쒓덫 ???곸궠?獄????됱쓤 ?怨뺣뼺?
		local nextSkillOrder = skillOrder
		ownSkill.ChildAdded:Connect(function(child)
			local item = getItemById(SkillStoreConfig.Skills, child.Name)
			if item then
				createInvCard(item, "Skill", skillsScroll, nextSkillOrder)
				nextSkillOrder += 1
				refreshCardsVisibility()
			end
		end)
	end

	refreshCardsVisibility()
end

task.spawn(initializeInventoryCards)

-- Bind updates
task.spawn(function()
	local eqBoard = LocalPlayer:WaitForChild("EquippedHoverboardId")
	eqBoard.Changed:Connect(refreshCardsVisibility)

	local eqSkill = LocalPlayer:WaitForChild("EquippedSkills")
	eqSkill.ChildAdded:Connect(refreshCardsVisibility)
	eqSkill.ChildRemoved:Connect(refreshCardsVisibility)
	local ownSkill = LocalPlayer:WaitForChild("OwnedSkills")
	ownSkill.ChildRemoved:Connect(refreshCardsVisibility)

	refreshCardsVisibility()
end)

-- Game Phase Integration
local phaseRemote = hoverRemotes:WaitForChild("GamePhaseChanged") :: RemoteEvent
phaseRemote.OnClientEvent:Connect(function(phase, timeLeft)
	local char = LocalPlayer.Character; local isDead = (not char) or (char:FindFirstChild("Humanoid") and char.Humanoid.Health <= 0); if (phase == "INTERMISSION" or phase == "MAP_VOTING") and not isDead then hudGui.Enabled = true
	else
		-- ???깅턄??繞?RACE_MATCH ???????? ??????얜?爰?????リ옇???????덈츎 ??????筌뤾퍔???? ???됱죨 繞벿살탳????????筌뤾퍒萸??ル벣遊뷸뤆?쎛 ?곌랜?삭굢????紐껊퉵??
		local isRacing = LocalPlayer:GetAttribute("IsRacing") == true
		local isSpectating = LocalPlayer:GetAttribute("IsSpectating") == true
		
		if isRacing or isSpectating or isDead then hudGui.Enabled = false
			invGui.Enabled = false
		else
			hudGui.Enabled = true
		end
	end
end)

LocalPlayer:GetAttributeChangedSignal("IsSpectating"):Connect(function()
	if LocalPlayer:GetAttribute("IsSpectating") == true then
		hudGui.Enabled = false
		invGui.Enabled = false
	else
		local isRacing = LocalPlayer:GetAttribute("IsRacing") == true
		if not isRacing then
			hudGui.Enabled = true
		end
	end
end)

-- ?筌뤾퍒萸??ル벣遊??洹먮봾裕?筌뤾쑬?????덈츎 嶺뚮ㅄ維獄??곸궠?獄???熬곣뫗逾?袁⑷섭????꾩룆??????ル봾鍮띸춯濡ル뾼?????좊닁????節뗪땁) ??⑤챷??
RunService.RenderStepped:Connect(function()
	local t = tick()
	for i, data in ipairs(allCards) do
		if data.img and data.card.Visible then
			-- ???곸궠?獄?씛彛??덈펲 i(?筌뤾퍓??? ?띠룆????뿉??熬곣뫕留?嶺뚢뼰維?醫귣ご?繞벿쇨섭?????利꿰뇖?닿섬甕?Wave) ?遊붋??類ㅼ벀????嶺뚯쉳??議얠물???紐껊퉵??
			-- 嶺뚯쉳?든뙴?4???, ???쒖┣ 3
			local bounce = math.sin(t * 3 + (i * 0.5)) * 4
			data.img.Position = UDim2.new(0, 10, 0, 10 + bounce)
		end
	end
end)

-- =========================================================================
-- ?甕?RESPONSIVE UI SCALING
-- =========================================================================
if bgFrame then
	bgFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	bgFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	
	local uiScale = bgFrame:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", bgFrame)
	local function updateResponsiveScale()
		local viewport = workspace.CurrentCamera.ViewportSize
		if viewport.X == 0 or viewport.Y == 0 then return end
		local scale = math.min(viewport.X / 1280, viewport.Y / 720)
		uiScale.Scale = math.clamp(scale, 0.4, 1.1)
	end
	
	local resizeConn = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveScale)
	updateResponsiveScale()
	task.delay(0.1, updateResponsiveScale)
	
	invGui.Destroying:Connect(function()
		if resizeConn then resizeConn:Disconnect() end
	end)
end

-- ?諭?癰귣똻???遺욧퍕: ?紐껉뭣?醫듼봺????곷??????怨쀫? ?怨멸쉭 ??ㅺ섯????쑴堉??? ??꾪? ?酉琉?紐껋쨮 ?袁⑹삺 ?關媛???袁⑹뵠??뽰뵠 ??ㅻ즲嚥??癒?짗 ?醫뤾문 疫꿸퀡???곕떽?
local function autoSelectEquipped()
	if currentTab == "Board" then
		local eq = LocalPlayer:FindFirstChild("EquippedHoverboardId")
		if eq and eq.Value ~= "" then
			local item = getItemById(StoreConfig.Items, eq.Value)
			if item then selectItem(item, "Board") end
		end
	elseif currentTab == "Skill" then
		selectedItem = nil
		updateRightColumn()
		for _, data in ipairs(allCards) do
			if data.stroke then data.stroke.Thickness = 5 end
		end
	end
end

invGui:GetPropertyChangedSignal("Enabled"):Connect(function()
	if invGui.Enabled then autoSelectEquipped() end
end)

if boardsTabBtn then bindClick(boardsTabBtn, function() switchTab("Board"); autoSelectEquipped() end) end
if skillsTabBtn then bindClick(skillsTabBtn, function() switchTab("Skill"); autoSelectEquipped() end) end

