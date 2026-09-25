--!strict
-- RobuxShopController.client.lua
-- 로복스 상점 하이브리드 UI 컨트롤러 (템플릿 복제 방식)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")

local StoreConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("StoreConfig"))
local SkillStoreConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SkillStoreConfig"))

local player = Players.LocalPlayer

-- 서버 통신 설정
local hoverRemotes = ReplicatedStorage:WaitForChild("HoverboardRemotes")
local getActivePromosFunc = hoverRemotes:WaitForChild("GetActivePromotions") :: RemoteFunction

-- 상점 데이터와 타이머 관리
local shopData = nil
local firstJoinTime = 0
local timerConnections = {} -- RunService 커넥션 관리용

-- UI 초기화 및 데이터 로드 함수
local function initializeShop()
	local playerGui = player:WaitForChild("PlayerGui")
	-- 유저가 스튜디오에서 만들 RobuxShopUI
	local shopGui = playerGui:WaitForChild("RobuxShopUI")
	local mainFrame = shopGui:WaitForChild("MainFrame")
	
	-- 탭 및 컨텐츠 영역
	local tabs = mainFrame:WaitForChild("Tabs")
	local contentArea = mainFrame:WaitForChild("ContentArea")
	
	local eventScroll = contentArea:WaitForChild("EventScroll")
	local passScroll = contentArea:WaitForChild("PassScroll")
	local goldScroll = contentArea:WaitForChild("GoldScroll")
	
	-- 숨겨둔 템플릿
	local templates = shopGui:WaitForChild("Templates")
	local eventTemplate = templates:WaitForChild("EventTemplate")
	local itemTemplate = templates:WaitForChild("ItemTemplate")
	
	local emptyMessageLabel = Instance.new("TextLabel")
	emptyMessageLabel.Name = "EmptyMessage"
	emptyMessageLabel.Size = UDim2.new(1, 0, 1, 0)
	emptyMessageLabel.BackgroundTransparency = 1
	emptyMessageLabel.Text = "Coming Soon..."
	emptyMessageLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	emptyMessageLabel.Font = Enum.Font.GothamBold
	emptyMessageLabel.TextSize = 42
	emptyMessageLabel.Visible = false
	emptyMessageLabel.ZIndex = 10
	emptyMessageLabel.Parent = contentArea
	
	local function checkEmptyState()
		local activeScroll = nil
		if eventScroll.Visible then activeScroll = eventScroll
		elseif passScroll.Visible then activeScroll = passScroll
		elseif goldScroll.Visible then activeScroll = goldScroll end
		
		if activeScroll then
			local count = 0
			for _, child in ipairs(activeScroll:GetChildren()) do
				if child:IsA("Frame") then count += 1 end
			end
			emptyMessageLabel.Visible = (count == 0)
		end
	end
	
	-- 1. 서버에서 최신 상점 데이터 가져오기
	shopData = getActivePromosFunc:InvokeServer()
	
	-- 2. FirstJoinTime 가져오기 (타이머용)
	local firstJoinTimeValue = player:WaitForChild("FirstJoinTime", 10) :: IntValue?
	if firstJoinTimeValue then
		firstJoinTime = firstJoinTimeValue.Value
	else
		firstJoinTime = os.time()
	end
	
	local function switchTab(tabName)
		eventScroll.Visible = (tabName == "Event")
		passScroll.Visible = (tabName == "Pass")
		goldScroll.Visible = (tabName == "Gold")
		
		-- 탭 색상 변경
		local goldColor = Color3.fromRGB(255, 200, 50)
		local silverColor = Color3.fromRGB(210, 220, 230)
		
		tabs:WaitForChild("EventButton").BackgroundColor3 = (tabName == "Event") and goldColor or silverColor
		tabs:WaitForChild("PassButton").BackgroundColor3 = (tabName == "Pass") and goldColor or silverColor
		tabs:WaitForChild("GoldButton").BackgroundColor3 = (tabName == "Gold") and goldColor or silverColor
		
		checkEmptyState()
	end
	
	tabs:WaitForChild("EventButton").MouseButton1Click:Connect(function() switchTab("Event") end)
	tabs:WaitForChild("PassButton").MouseButton1Click:Connect(function() switchTab("Pass") end)
	tabs:WaitForChild("GoldButton").MouseButton1Click:Connect(function() switchTab("Gold") end)
	
	-- 닫기 버튼 연결
	local closeBtn = mainFrame:WaitForChild("CloseButton")
	closeBtn.MouseButton1Click:Connect(function()
		shopGui.Enabled = false
	end)
	
	shopGui.Enabled = false
	
	-- 초기 탭 설정
	switchTab("Event")
	
	-- 4. 상품 생성 함수
	local function populateEvents()
		-- 기존 항목 초기화
		for _, child in ipairs(eventScroll:GetChildren()) do
			if child:IsA("Frame") then child:Destroy() end
		end
		
		for _, item in ipairs(shopData.Events or {}) do
			local currentTime = os.time()
			local sDate = item.startDate or 0
			local eDate = item.endDate or 4102412400
			
			-- 현재 시간이 기간 내에 있고 숨김 상태가 아닌 이벤트만 노출
			if currentTime >= sDate and currentTime <= eDate and item.isVisible ~= false then
				local clone = eventTemplate:Clone()
				clone.Visible = true
			
			-- 기본 정보 세팅
			clone.Title.Text = item.promotionName or "이름 없음"
			clone.HookText.Text = item.hookText or item.adminDesc or ""
			clone.BannerImage.Image = item.bannerImage or ""
			
			local rContainer = clone:FindFirstChild("RewardsContainer")
			if rContainer then
				local bSlot = rContainer:FindFirstChild("BoardReward")
				local sSlot = rContainer:FindFirstChild("SkillReward")
				local gSlot = rContainer:FindFirstChild("GoldReward")
				
				if item.rewards then
					for _, r in ipairs(item.rewards) do
						if r.type == "Gold" and gSlot then
							gSlot.Visible = true
							gSlot.Label.Text = tostring(r.value)
							gSlot.Icon.Image = "rbxassetid://15402852027" -- 골드 아이콘
						elseif r.type == "Hoverboard" and bSlot then
							bSlot.Visible = true
							
							-- StoreConfig에서 보드 정보 찾기
							local bName = tostring(r.value)
							local bIcon = "rbxassetid://13511855909"
							if StoreConfig and StoreConfig.Items then
								for _, itemData in ipairs(StoreConfig.Items) do
									if itemData.id == r.value then
										bName = itemData.name or bName
										bIcon = itemData.imageId or bIcon
										break
									end
								end
							end
							
							bSlot.Label.Text = bName
							bSlot.Icon.Image = bIcon
						elseif r.type == "Skill" and sSlot then
							sSlot.Visible = true
							
							-- SkillStoreConfig에서 스킬 정보 찾기
							local sName = tostring(r.value)
							local sIcon = "rbxassetid://13511855909"
							if SkillStoreConfig and SkillStoreConfig.Skills then
								for _, skillData in ipairs(SkillStoreConfig.Skills) do
									if skillData.id == r.value then
										sName = skillData.name or sName
										sIcon = skillData.imageId or sIcon
										break
									end
								end
							end
							
							sSlot.Label.Text = sName
							sSlot.Icon.Image = sIcon
						end
					end
				end
			end
			
			clone.PriceButton.TextLabel.Text = tostring(item.price)
			
			-- 결제 연동
			clone.PriceButton.MouseButton1Click:Connect(function()
				local pId = tonumber(item.id) or 0
				if pId > 0 then
					MarketplaceService:PromptProductPurchase(player, pId)
				else
					warn("상품 ID가 유효하지 않습니다: " .. tostring(item.id))
				end
			end)
			
			-- 스타터팩 24시간 타이머 처리
			if item.isStarter then
				local timerLabel = clone:FindFirstChild("TimerLabel")
				if timerLabel then
					local connectionName = "StarterTimer_" .. item.id
					timerConnections[connectionName] = RunService.Heartbeat:Connect(function()
						local currentTime = os.time()
						local elapsedTime = currentTime - firstJoinTime
						local timeRemaining = 86400 - elapsedTime -- 24시간(86400초) 기준
						
						if timeRemaining > 0 then
							local hours = math.floor(timeRemaining / 3600)
							local minutes = math.floor((timeRemaining % 3600) / 60)
							local seconds = timeRemaining % 60
							timerLabel.Text = string.format("%02d:%02d:%02d 남음", hours, minutes, seconds)
						else
							-- 시간이 다 되면 숨김 처리 및 타이머 종료
							clone.Visible = false
							if timerConnections[connectionName] then
								timerConnections[connectionName]:Disconnect()
								timerConnections[connectionName] = nil
							end
						end
					end)
				end
			end
			
			clone.Parent = eventScroll
			end
		end
	end
	
	local function populateItems(dataList, parentScroll)
		for _, child in ipairs(parentScroll:GetChildren()) do
			if child:IsA("Frame") then child:Destroy() end
		end
		
		for _, item in ipairs(dataList or {}) do
			if item.isVisible ~= false then
				local clone = itemTemplate:Clone()
				clone.Visible = true
			
			clone.ItemName.Text = item.name
			clone.ItemIcon.Image = item.icon
			clone.PriceButton.TextLabel.Text = tostring(item.price)
			
			local bgImage = clone:FindFirstChild("BackgroundImage")
			if bgImage then
				if item.bgImage and item.bgImage ~= "" then
					bgImage.Image = item.bgImage
					bgImage.Visible = true
				else
					bgImage.Visible = false
				end
			end
			
			clone.PriceButton.MouseButton1Click:Connect(function()
				local pId = tonumber(item.id) or 0
				if pId > 0 then
					MarketplaceService:PromptProductPurchase(player, pId)
				else
					warn("상품 ID가 유효하지 않습니다: " .. tostring(item.id))
				end
			end)
			
			clone.Parent = parentScroll
			end
		end
	end
	
	-- 데이터 기반으로 UI 생성
	populateEvents()
	populateItems(shopData.Passes, passScroll)
	populateItems(shopData.Golds, goldScroll)
	checkEmptyState()
	
	-- =========================================================================
	-- 📱 RESPONSIVE UI SCALING (출석체크와 동일한 스케일 적용)
	-- =========================================================================
	local uiScale = mainFrame:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	uiScale.Parent = mainFrame

	local function updateResponsiveScale()
		local viewport = workspace.CurrentCamera.ViewportSize
		if viewport.X == 0 or viewport.Y == 0 then return end
		
		local scale = math.min(viewport.X / 1280, viewport.Y / 720)
		uiScale.Scale = math.clamp(scale, 0.4, 1.1)
	end

	local resizeConn = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveScale)
	updateResponsiveScale()
	task.delay(0.1, updateResponsiveScale)

	shopGui.Destroying:Connect(function()
		if resizeConn then resizeConn:Disconnect() end
	end)
	
	-- 상점 열기 버튼 연결 (UI 생성 및 함수 정의 완료 후 호출)
	task.spawn(function()
		local oldShopGui = playerGui:WaitForChild("RobuxShop", 10)
		if oldShopGui then
			local btn = nil
			for _, desc in ipairs(oldShopGui:GetDescendants()) do
				if desc:IsA("GuiButton") then
					btn = desc
					break
				end
			end
			
			if btn then
				btn.MouseButton1Click:Connect(function()
					shopGui.Enabled = not shopGui.Enabled
					if shopGui.Enabled then
						-- 상점 오픈 시 최신 데이터로 새로고침
						shopData = getActivePromosFunc:InvokeServer()
						populateEvents()
						populateItems(shopData.Passes, passScroll)
						populateItems(shopData.Golds, goldScroll)
						checkEmptyState()
					end
				end)
			end
		end
	end)
end

-- UI가 스튜디오에 완전히 로드될 때까지 기다렸다가 실행
task.spawn(function()
	local playerGui = player:WaitForChild("PlayerGui")
	playerGui:WaitForChild("RobuxShopUI")
	initializeShop()
end)
