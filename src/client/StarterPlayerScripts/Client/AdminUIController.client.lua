--!strict
-- AdminUIController.client.lua
-- 관리자 전용 상점 마스터 패널 UI (게시판/페이지 전환 형태)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("HoverboardRemotes")

local adminAuthRemote = remotes:WaitForChild("AdminAuthStatus") :: RemoteEvent
local updatePromoFunc = remotes:WaitForChild("UpdatePromotionData") :: RemoteFunction
local getPromoFunc = remotes:WaitForChild("GetPromotionData") :: RemoteFunction

local isAdmin = false
local adminGui = nil

local currentShopData = { Events = {}, Passes = {}, Golds = {} }
local currentTab = "Events" -- "Events", "Passes", "Golds"
local currentSelectedIndex = nil -- nil이면 새 항목 추가

local function buildAdminUI()
	adminGui = Instance.new("ScreenGui")
	adminGui.Name = "AdminPanelGui"
	adminGui.ResetOnSpawn = false
	adminGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
	
	local mainFrame = Instance.new("Frame")
	mainFrame.Size = UDim2.new(0, 900, 0, 600)
	mainFrame.Position = UDim2.new(0.5, -450, 0.5, -300)
	mainFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
	mainFrame.Parent = adminGui
	Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 12)
	
	-- 상단 타이틀 바
	local titleBar = Instance.new("Frame")
	titleBar.Size = UDim2.new(1, 0, 0, 50)
	titleBar.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
	titleBar.Parent = mainFrame
	Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 12)
	
	local titleBlocker = Instance.new("Frame")
	titleBlocker.Size = UDim2.new(1, 0, 0, 10)
	titleBlocker.Position = UDim2.new(0, 0, 1, -10)
	titleBlocker.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
	titleBlocker.BorderSizePixel = 0
	titleBlocker.Parent = titleBar
	
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(0, 250, 1, 0)
	title.Position = UDim2.new(0, 20, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = " 👑 상점 마스터 관리자"
	title.TextColor3 = Color3.new(1,1,1)
	title.TextSize = 22
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = titleBar
	
	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 50, 0, 50)
	closeBtn.Position = UDim2.new(1, -50, 0, 0)
	closeBtn.Text = "X"
	closeBtn.BackgroundTransparency = 1
	closeBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
	closeBtn.TextSize = 24
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.Parent = titleBar
	closeBtn.MouseButton1Click:Connect(function() adminGui.Enabled = false end)
	
	-- 탭 메뉴
	local tabsFrame = Instance.new("Frame")
	tabsFrame.Size = UDim2.new(0, 300, 1, 0)
	tabsFrame.Position = UDim2.new(0, 250, 0, 0)
	tabsFrame.BackgroundTransparency = 1
	tabsFrame.Parent = titleBar
	
	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Padding = UDim.new(0, 10)
	tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	tabLayout.Parent = tabsFrame
	
	local viewContainer = Instance.new("Frame")
	viewContainer.Size = UDim2.new(1, 0, 1, -50)
	viewContainer.Position = UDim2.new(0, 0, 0, 50)
	viewContainer.BackgroundTransparency = 1
	viewContainer.Parent = mainFrame
	
	-- ==========================================
	-- 1. 목록 화면 (List View)
	-- ==========================================
	local listView = Instance.new("Frame")
	listView.Size = UDim2.new(1, 0, 1, 0)
	listView.BackgroundTransparency = 1
	listView.Parent = viewContainer
	
	local topBar = Instance.new("Frame")
	topBar.Size = UDim2.new(1, 0, 0, 60)
	topBar.BackgroundTransparency = 1
	topBar.Parent = listView
	
	local btnAddNew = Instance.new("TextButton")
	btnAddNew.Size = UDim2.new(0, 160, 0, 40)
	btnAddNew.Position = UDim2.new(1, -180, 0, 10)
	btnAddNew.BackgroundColor3 = Color3.fromRGB(50, 200, 100)
	btnAddNew.TextColor3 = Color3.new(1,1,1)
	btnAddNew.Text = "+ 새 상품 추가"
	btnAddNew.Font = Enum.Font.GothamBold
	btnAddNew.TextSize = 16
	btnAddNew.Parent = topBar
	Instance.new("UICorner", btnAddNew).CornerRadius = UDim.new(0, 8)
	
	local scrollList = Instance.new("ScrollingFrame")
	scrollList.Size = UDim2.new(1, -40, 1, -70)
	scrollList.Position = UDim2.new(0, 20, 0, 60)
	scrollList.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
	scrollList.ScrollBarThickness = 8
	scrollList.BorderSizePixel = 0
	scrollList.Parent = listView
	Instance.new("UICorner", scrollList).CornerRadius = UDim.new(0, 8)
	
	local scrollLayout = Instance.new("UIListLayout")
	scrollLayout.Padding = UDim.new(0, 5)
	scrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
	scrollLayout.Parent = scrollList
	
	local scrollPadding = Instance.new("UIPadding")
	scrollPadding.PaddingTop = UDim.new(0, 10)
	scrollPadding.PaddingLeft = UDim.new(0, 10)
	scrollPadding.PaddingRight = UDim.new(0, 10)
	scrollPadding.Parent = scrollList
	
	-- ==========================================
	-- 2. 작성/수정 화면 (Form View)
	-- ==========================================
	local formView = Instance.new("Frame")
	formView.Size = UDim2.new(1, 0, 1, 0)
	formView.BackgroundTransparency = 1
	formView.Visible = false
	formView.Parent = viewContainer
	
	local formScroll = Instance.new("ScrollingFrame")
	formScroll.Size = UDim2.new(1, -40, 1, -80)
	formScroll.Position = UDim2.new(0, 20, 0, 20)
	formScroll.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
	formScroll.ScrollBarThickness = 8
	formScroll.BorderSizePixel = 0
	formScroll.Parent = formView
	Instance.new("UICorner", formScroll).CornerRadius = UDim.new(0, 8)
	
	local bottomBar = Instance.new("Frame")
	bottomBar.Size = UDim2.new(1, 0, 0, 60)
	bottomBar.Position = UDim2.new(0, 0, 1, -60)
	bottomBar.BackgroundTransparency = 1
	bottomBar.Parent = formView
	
	local btnBack = Instance.new("TextButton")
	btnBack.Size = UDim2.new(0, 120, 0, 40)
	btnBack.Position = UDim2.new(0, 20, 0, 10)
	btnBack.BackgroundColor3 = Color3.fromRGB(100, 100, 105)
	btnBack.TextColor3 = Color3.new(1,1,1)
	btnBack.Text = "← 뒤로 가기"
	btnBack.Font = Enum.Font.GothamBold
	btnBack.TextSize = 16
	btnBack.Parent = bottomBar
	Instance.new("UICorner", btnBack).CornerRadius = UDim.new(0, 8)
	
	local btnSave = Instance.new("TextButton")
	btnSave.Size = UDim2.new(0, 160, 0, 40)
	btnSave.Position = UDim2.new(1, -200, 0, 10)
	btnSave.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
	btnSave.TextColor3 = Color3.new(1,1,1)
	btnSave.Text = "저장 (SAVE)"
	btnSave.Font = Enum.Font.GothamBold
	btnSave.TextSize = 16
	btnSave.Parent = bottomBar
	Instance.new("UICorner", btnSave).CornerRadius = UDim.new(0, 8)
	
	local function createInput(name, placeholder, yPos)
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(0, 180, 0, 40)
		label.Position = UDim2.new(0, 20, 0, yPos)
		label.Text = name
		label.TextColor3 = Color3.new(1,1,1)
		label.BackgroundTransparency = 1
		label.TextXAlignment = Enum.TextXAlignment.Right
		label.TextSize = 16
		label.Font = Enum.Font.GothamBold
		label.Parent = formScroll
		
		local box = Instance.new("TextBox")
		box.Size = UDim2.new(1, -250, 0, 40)
		box.Position = UDim2.new(0, 220, 0, yPos)
		box.PlaceholderText = placeholder
		box.Text = ""
		box.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
		box.TextColor3 = Color3.fromRGB(255, 255, 255)
		box.ClearTextOnFocus = false
		box.TextSize = 16
		box.Font = Enum.Font.Gotham
		box.TextXAlignment = Enum.TextXAlignment.Left
		box.Parent = formScroll
		Instance.new("UICorner", box).CornerRadius = UDim.new(0, 6)
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, 10)
		padding.Parent = box
		
		return box, label
	end
	
	local function createToggle(name, yPos)
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(0, 180, 0, 40)
		label.Position = UDim2.new(0, 20, 0, yPos)
		label.Text = name
		label.TextColor3 = Color3.new(1,1,1)
		label.BackgroundTransparency = 1
		label.TextXAlignment = Enum.TextXAlignment.Right
		label.TextSize = 16
		label.Font = Enum.Font.GothamBold
		label.Parent = formScroll
		
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, -250, 0, 40)
		btn.Position = UDim2.new(0, 220, 0, yPos)
		btn.Text = "ON (노출)"
		btn.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
		btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		btn.TextSize = 16
		btn.Font = Enum.Font.GothamBold
		btn.Parent = formScroll
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
		
		local val = true
		local function updateUI()
			btn.Text = val and "ON (노출)" or "OFF (숨김)"
			btn.BackgroundColor3 = val and Color3.fromRGB(50, 200, 50) or Color3.fromRGB(200, 50, 50)
		end
		
		btn.MouseButton1Click:Connect(function()
			val = not val
			updateUI()
		end)
		
		return btn, label, function() return val end, function(newVal)
			val = (newVal ~= false)
			updateUI()
		end
	end
	
	-- 폼 필드들
	local boxId, lblId = createInput("상품 ID (필수)", "Developer Product ID", 20)
	local boxName, lblName = createInput("상품/이벤트 명", "노출될 텍스트", 70)
	local boxDesc, lblDesc = createInput("관리자 메모(HookText)", "단 한 번의 기회! 등", 120)
	local boxImage, lblImage = createInput("메인 썸네일", "rbxassetid:// (배너 또는 아이콘)", 170)
	local boxBgImage, lblBgImage = createInput("배경 이미지", "rbxassetid:// (없으면 빈칸)", 220)
	local boxPrice, lblPrice = createInput("가격 (R$)", "UI 표기용", 270)
	
	local boxStart, lblStart = createInput("시작 날짜", "0 = 상시", 320)
	local boxEnd, lblEnd = createInput("종료 날짜", "4102412400 = 무제한", 370)
	
	local boxGoldReward, lblGoldReward = createInput("보상: 골드량", "지급할 골드 (없으면 빈칸)", 420)
	local boxBoardReward, lblBoardReward = createInput("보상: 보드 ID", "예) Hoverboard_001", 470)
	local boxSkillReward, lblSkillReward = createInput("보상: 스킬 ID", "예) Skill_Premium", 520)
	local tglVisible, lblVisible, getVisible, setVisible = createToggle("노출 상태 (상점 표시)", 570)
	
	formScroll.CanvasSize = UDim2.new(0, 0, 0, 650)
	
	-- ==========================================
	-- 함수들
	-- ==========================================
	local refreshList, loadDetailForm
	
	local function openFormView(index)
		currentSelectedIndex = index
		listView.Visible = false
		formView.Visible = true
		loadDetailForm()
	end
	
	local function openListView()
		listView.Visible = true
		formView.Visible = false
		refreshList()
	end
	
	local function createTabBtn(name, text, layoutOrder)
		local btn = Instance.new("TextButton")
		btn.Name = name
		btn.Size = UDim2.new(0, 80, 0, 34)
		btn.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
		btn.TextColor3 = Color3.fromRGB(200, 200, 200)
		btn.Text = text
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 16
		btn.LayoutOrder = layoutOrder
		btn.Parent = tabsFrame
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
		
		btn.MouseButton1Click:Connect(function()
			for _, child in ipairs(tabsFrame:GetChildren()) do
				if child:IsA("TextButton") then
					child.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
					child.TextColor3 = Color3.fromRGB(200, 200, 200)
				end
			end
			btn.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
			btn.TextColor3 = Color3.fromRGB(0, 0, 0)
			
			currentTab = name
			openListView()
		end)
		return btn
	end
	
	local tabEvent = createTabBtn("Events", "EVENT", 1)
	local tabPass = createTabBtn("Passes", "PASS", 2)
	local tabGold = createTabBtn("Golds", "GOLD", 3)
	
	tabEvent.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
	tabEvent.TextColor3 = Color3.fromRGB(0, 0, 0)
	
	btnAddNew.MouseButton1Click:Connect(function()
		openFormView(nil)
	end)
	
	btnBack.MouseButton1Click:Connect(function()
		openListView()
	end)
	
	local function deleteItem(index)
		if currentShopData[currentTab] then
			table.remove(currentShopData[currentTab], index)
			local success, msg = updatePromoFunc:InvokeServer(currentShopData)
			if success then
				refreshList()
			end
		end
	end
	
	refreshList = function()
		for _, child in ipairs(scrollList:GetChildren()) do
			if child:IsA("Frame") then child:Destroy() end
		end
		
		local list = currentShopData[currentTab] or {}
		
		for i, item in ipairs(list) do
			local itemFrame = Instance.new("Frame")
			itemFrame.Size = UDim2.new(1, 0, 0, 60)
			itemFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
			itemFrame.LayoutOrder = i
			itemFrame.Parent = scrollList
			Instance.new("UICorner", itemFrame).CornerRadius = UDim.new(0, 8)
			
			local thumb = Instance.new("ImageLabel")
			thumb.Size = UDim2.new(0, 50, 0, 50)
			thumb.Position = UDim2.new(0, 5, 0, 5)
			thumb.Image = item.bannerImage or item.icon or ""
			thumb.ScaleType = Enum.ScaleType.Crop
			thumb.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
			thumb.Parent = itemFrame
			Instance.new("UICorner", thumb).CornerRadius = UDim.new(0, 6)
			
			local lblTitle = Instance.new("TextLabel")
			lblTitle.Size = UDim2.new(1, -170, 0, 30)
			lblTitle.Position = UDim2.new(0, 65, 0, 5)
			lblTitle.BackgroundTransparency = 1
			local titleText = item.promotionName or item.name or "이름 없음"
			if item.isVisible == false then
				titleText = "[숨김] " .. titleText
			end
			lblTitle.Text = titleText
			lblTitle.TextColor3 = Color3.new(1,1,1)
			lblTitle.Font = Enum.Font.GothamBold
			lblTitle.TextSize = 18
			lblTitle.TextXAlignment = Enum.TextXAlignment.Left
			lblTitle.Parent = itemFrame
			
			local lblSub = Instance.new("TextLabel")
			lblSub.Size = UDim2.new(1, -170, 0, 20)
			lblSub.Position = UDim2.new(0, 65, 0, 35)
			lblSub.BackgroundTransparency = 1
			lblSub.Text = "R$ " .. tostring(item.price or 0) .. " | ID: " .. tostring(item.id)
			lblSub.TextColor3 = Color3.fromRGB(150, 255, 150)
			lblSub.Font = Enum.Font.Gotham
			lblSub.TextSize = 14
			lblSub.TextXAlignment = Enum.TextXAlignment.Left
			lblSub.Parent = itemFrame
			
			local btnEdit = Instance.new("TextButton")
			btnEdit.Size = UDim2.new(0, 70, 0, 36)
			btnEdit.Position = UDim2.new(1, -155, 0, 12)
			btnEdit.BackgroundColor3 = Color3.fromRGB(70, 130, 200)
			btnEdit.TextColor3 = Color3.new(1,1,1)
			btnEdit.Text = "수정"
			btnEdit.Font = Enum.Font.GothamBold
			btnEdit.TextSize = 14
			btnEdit.Parent = itemFrame
			Instance.new("UICorner", btnEdit).CornerRadius = UDim.new(0, 6)
			btnEdit.MouseButton1Click:Connect(function() openFormView(i) end)
			
			local btnDel = Instance.new("TextButton")
			btnDel.Size = UDim2.new(0, 70, 0, 36)
			btnDel.Position = UDim2.new(1, -75, 0, 12)
			btnDel.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
			btnDel.TextColor3 = Color3.new(1,1,1)
			btnDel.Text = "삭제"
			btnDel.Font = Enum.Font.GothamBold
			btnDel.TextSize = 14
			btnDel.Parent = itemFrame
			Instance.new("UICorner", btnDel).CornerRadius = UDim.new(0, 6)
			btnDel.MouseButton1Click:Connect(function() deleteItem(i) end)
		end
		
		scrollList.CanvasSize = UDim2.new(0, 0, 0, 10 + (#list * 65))
	end
	
	loadDetailForm = function()
		local list = currentShopData[currentTab] or {}
		local item = currentSelectedIndex and list[currentSelectedIndex] or nil
		
		local isEvent = (currentTab == "Events")
		
		boxStart.Visible = isEvent; lblStart.Visible = isEvent
		boxEnd.Visible = isEvent; lblEnd.Visible = isEvent
		boxDesc.Visible = isEvent; lblDesc.Visible = isEvent
		boxBoardReward.Visible = isEvent; lblBoardReward.Visible = isEvent
		boxSkillReward.Visible = isEvent; lblSkillReward.Visible = isEvent
		
		if item then
			boxId.Text = tostring(item.id or "")
			boxName.Text = item.promotionName or item.name or ""
			boxDesc.Text = item.adminDesc or item.hookText or ""
			boxStart.Text = tostring(item.startDate or "0")
			boxEnd.Text = tostring(item.endDate or "4102412400")
			boxImage.Text = item.bannerImage or item.icon or ""
			boxBgImage.Text = item.bgImage or ""
			boxPrice.Text = tostring(item.price or "")
			setVisible(item.isVisible ~= false)
			
			boxGoldReward.Text = ""
			boxBoardReward.Text = ""
			boxSkillReward.Text = ""
			
			if item.rewards then
				for _, r in ipairs(item.rewards) do
					if r.type == "Gold" then boxGoldReward.Text = tostring(r.value)
					elseif r.type == "Hoverboard" then boxBoardReward.Text = tostring(r.value)
					elseif r.type == "Skill" then boxSkillReward.Text = tostring(r.value)
					end
				end
			end
		else
			boxId.Text = ""
			boxName.Text = ""
			boxDesc.Text = ""
			boxStart.Text = "0"
			boxEnd.Text = "4102412400"
			boxImage.Text = "rbxassetid://"
			boxBgImage.Text = ""
			boxPrice.Text = ""
			setVisible(true)
			boxGoldReward.Text = ""
			boxBoardReward.Text = ""
			boxSkillReward.Text = ""
		end
	end
	
	btnSave.MouseButton1Click:Connect(function()
		local newObj = {}
		newObj.id = tonumber(boxId.Text) or 0
		newObj.price = tonumber(boxPrice.Text) or 0
		newObj.isVisible = getVisible()
		
		if currentTab == "Events" then
			newObj.promotionName = boxName.Text
			newObj.hookText = boxDesc.Text
			newObj.adminDesc = boxDesc.Text
			newObj.bannerImage = boxImage.Text
			newObj.startDate = tonumber(boxStart.Text) or 0
			newObj.endDate = tonumber(boxEnd.Text) or 4102412400
		else
			newObj.name = boxName.Text
			newObj.icon = boxImage.Text
			if boxBgImage.Text ~= "" then
				newObj.bgImage = boxBgImage.Text
			end
		end
		
		local rArray = {}
		if boxGoldReward.Text ~= "" then table.insert(rArray, {type="Gold", value=tonumber(boxGoldReward.Text)}) end
		if boxBoardReward.Text ~= "" then table.insert(rArray, {type="Hoverboard", value=boxBoardReward.Text}) end
		if boxSkillReward.Text ~= "" then table.insert(rArray, {type="Skill", value=boxSkillReward.Text}) end
		if #rArray > 0 then newObj.rewards = rArray end
		
		if not currentShopData[currentTab] then currentShopData[currentTab] = {} end
		
		if currentSelectedIndex then
			currentShopData[currentTab][currentSelectedIndex] = newObj
		else
			table.insert(currentShopData[currentTab], newObj)
		end
		
		local success, msg = updatePromoFunc:InvokeServer(currentShopData)
		if success then
			openListView()
		else
			warn("❌ 저장 실패:", msg)
		end
	end)
	
	local data = getPromoFunc:InvokeServer()
	if data and data.Events then
		currentShopData = data
	end
	openListView()
end

adminAuthRemote.OnClientEvent:Connect(function(status)
	isAdmin = status
	if isAdmin then
		local toggleGui = Instance.new("ScreenGui")
		toggleGui.Name = "AdminToggleGui"
		toggleGui.ResetOnSpawn = false
		toggleGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
		
		local toggleBtn = Instance.new("TextButton")
		toggleBtn.Size = UDim2.new(0, 100, 0, 40)
		toggleBtn.Position = UDim2.new(0, 20, 1, -60)
		toggleBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
		toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		toggleBtn.Text = "상점 관리"
		toggleBtn.Font = Enum.Font.SourceSansBold
		toggleBtn.TextSize = 16
		toggleBtn.Parent = toggleGui
		Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 8)
		
		toggleBtn.MouseButton1Click:Connect(function()
			if adminGui then
				adminGui.Enabled = not adminGui.Enabled
			else
				buildAdminUI()
			end
		end)
	end
end)
