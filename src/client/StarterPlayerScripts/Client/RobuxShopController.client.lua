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
	
	-- 토스트 알림 표시 함수
	local function showToast(message: string, isSuccess: boolean)
		local toast = Instance.new("Frame")
		toast.Size = UDim2.new(0, 360, 0, 48)
		toast.Position = UDim2.new(0.5, 0, 0.15, 0)
		toast.AnchorPoint = Vector2.new(0.5, 0.5)
		toast.BackgroundColor3 = isSuccess and Color3.fromRGB(30, 160, 60) or Color3.fromRGB(200, 50, 50)
		toast.ZIndex = 100
		toast.Parent = shopGui
		Instance.new("UICorner", toast).CornerRadius = UDim.new(0, 10)
		local tStroke = Instance.new("UIStroke", toast)
		tStroke.Color = Color3.fromRGB(0, 0, 0)
		tStroke.Thickness = 3

		local lbl = Instance.new("TextLabel", toast)
		lbl.Size = UDim2.new(1, -20, 1, 0)
		lbl.Position = UDim2.new(0, 10, 0, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text = message
		lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
		lbl.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
		lbl.TextSize = 18
		lbl.ZIndex = 101

		task.delay(2.5, function()
			if toast.Parent then toast:Destroy() end
		end)
	end
	
	local simulatePurchaseFunc = hoverRemotes:FindFirstChild("SimulatePurchase") :: RemoteFunction?
	
	-- 스마트 구매 처리 함수 (정식 로블록스 상품 프롬프트 + 미등록/테스트 상품 자동 시뮬레이션 지원)
	local function handleSmartPurchase(item: any, priceButton: TextButton, category: string)
		local pId = tonumber(item.id) or 0
		if pId <= 0 then
			warn("상품 ID가 유효하지 않습니다: " .. tostring(item.id))
			showToast("상품 ID가 유효하지 않습니다.", false)
			return
		end

		-- 이미 소유한 패스/이벤트인 경우 무시
		local isOwned = player:GetAttribute("OwnsPass_" .. tostring(pId)) == true 
			or player:GetAttribute("PurchasedEvent_" .. tostring(pId)) == true
		if not isOwned and item.rewards then
			local ownedBoards = player:FindFirstChild("OwnedHoverboards") or (player:FindFirstChild("Inventory") and player.Inventory:FindFirstChild("OwnedHoverboards"))
			for _, r in ipairs(item.rewards) do
				if r.type == "Hoverboard" and ownedBoards and ownedBoards:FindFirstChild(tostring(r.value)) then
					isOwned = true
					break
				end
			end
		end

		if (item.isGamePass or category == "Passes" or category == "Events") and isOwned then
			showToast("이미 보유하고 있는 상품입니다!", true)
			return
		end

		task.spawn(function()
			local isRealProduct = false
			local isPass = (category == "Passes" or item.isGamePass == true)

			-- GamePass 여부 조회
			local okPass, passInfo = pcall(function()
				return MarketplaceService:GetProductInfo(pId, Enum.InfoType.GamePass)
			end)
			if okPass and passInfo and passInfo.PriceInRobux then
				isRealProduct = true
				isPass = true
			else
				-- Developer Product 여부 조회
				local okProd, prodInfo = pcall(function()
					return MarketplaceService:GetProductInfo(pId, Enum.InfoType.Product)
				end)
				if okProd and prodInfo and prodInfo.PriceInRobux then
					isRealProduct = true
					isPass = false
				end
			end

			if isRealProduct then
				-- 정식 로블록스 상품: 공식 프롬프트 호출
				if isPass then
					item.isGamePass = true
					MarketplaceService:PromptGamePassPurchase(player, pId)
				else
					item.isGamePass = false
					MarketplaceService:PromptProductPurchase(player, pId)
				end
			else
				-- 미등록 상품/테스트 ID: 가상 구매 시뮬레이션 즉시 처리
				print("🛠️ [RobuxShop] 미등록 상품/테스트 상품 -> 가상 구매 처리: " .. tostring(pId))
				if simulatePurchaseFunc then
					local success, msg, prodData = simulatePurchaseFunc:InvokeServer(pId, category)
					if success then
						if isPass or category == "Passes" or category == "Events" then
							player:SetAttribute("OwnsPass_" .. tostring(pId), true)
							player:SetAttribute("PurchasedEvent_" .. tostring(pId), true)
							local tLbl = priceButton:FindFirstChild("TextLabel") :: TextLabel?
							if tLbl then tLbl.Text = "OWNED" end
							priceButton.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
							showToast("🎉 [테스트 결제] 구매 완료!", true)
						else
							showToast("💰 [테스트 결제] 골드가 충전되었습니다!", true)
						end
					else
						showToast("❌ 결제 실패: " .. tostring(msg), false)
					end
				end
			end
		end)
	end
	
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
	
	local hideRewardBubble = nil

	local function switchTab(tabName)
		if hideRewardBubble then hideRewardBubble(true) end
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
	
	-- 💬 글로벌 보상 설명 말풍선 툴팁 (PC 호버 / 모바일 탭)
	local rewardBubble = mainFrame:FindFirstChild("RewardBubbleTooltip")
	if not rewardBubble then
		rewardBubble = Instance.new("Frame")
		rewardBubble.Name = "RewardBubbleTooltip"
		rewardBubble.Size = UDim2.new(0, 280, 0, 95)
		rewardBubble.AnchorPoint = Vector2.new(0.5, 1)
		rewardBubble.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		rewardBubble.ZIndex = 100
		rewardBubble.Visible = false
		rewardBubble.Parent = mainFrame

		local bCorner = Instance.new("UICorner")
		bCorner.CornerRadius = UDim.new(0, 12)
		bCorner.Parent = rewardBubble

		local bStroke = Instance.new("UIStroke")
		bStroke.Color = Color3.fromRGB(0, 0, 0)
		bStroke.Thickness = 2.5
		bStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		bStroke.Parent = rewardBubble

		-- 제목 (Title)
		local titleLbl = Instance.new("TextLabel")
		titleLbl.Name = "Title"
		titleLbl.Size = UDim2.new(1, -38, 0, 22)
		titleLbl.Position = UDim2.new(0, 14, 0, 10)
		titleLbl.BackgroundTransparency = 1
		titleLbl.Font = Enum.Font.FredokaOne
		titleLbl.TextSize = 16
		titleLbl.TextColor3 = Color3.fromRGB(25, 25, 35)
		titleLbl.TextXAlignment = Enum.TextXAlignment.Left
		titleLbl.ZIndex = 102
		titleLbl.Parent = rewardBubble

		-- 설명 (Description)
		local descLbl = Instance.new("TextLabel")
		descLbl.Name = "Description"
		descLbl.Size = UDim2.new(1, -28, 0, 54)
		descLbl.Position = UDim2.new(0, 14, 0, 32)
		descLbl.BackgroundTransparency = 1
		descLbl.Font = Enum.Font.GothamMedium
		descLbl.TextSize = 13
		descLbl.TextColor3 = Color3.fromRGB(60, 65, 75)
		descLbl.TextXAlignment = Enum.TextXAlignment.Left
		descLbl.TextYAlignment = Enum.TextYAlignment.Top
		descLbl.TextWrapped = true
		descLbl.ZIndex = 102
		descLbl.Parent = rewardBubble

		-- 닫기 버튼 [X]
		local closeBubbleBtn = Instance.new("TextButton")
		closeBubbleBtn.Name = "CloseBtn"
		closeBubbleBtn.Size = UDim2.new(0, 20, 0, 20)
		closeBubbleBtn.Position = UDim2.new(1, -26, 0, 8)
		closeBubbleBtn.BackgroundColor3 = Color3.fromRGB(240, 60, 60)
		closeBubbleBtn.Text = "X"
		closeBubbleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		closeBubbleBtn.Font = Enum.Font.GothamBold
		closeBubbleBtn.TextSize = 12
		closeBubbleBtn.ZIndex = 103
		closeBubbleBtn.Parent = rewardBubble

		local cCorner = Instance.new("UICorner")
		cCorner.CornerRadius = UDim.new(1, 0)
		cCorner.Parent = closeBubbleBtn
	end

	local currentPinnedSlot = nil

	local function showRewardBubble(slot, title, desc, isClick)
		rewardBubble.Title.Text = title
		rewardBubble.Description.Text = desc

		local slotCenter = slot.AbsolutePosition + slot.AbsoluteSize * Vector2.new(0.5, 0)
		local mainPos = mainFrame.AbsolutePosition
		local relX = slotCenter.X - mainPos.X
		local relY = slot.AbsolutePosition.Y - mainPos.Y

		local bubbleWidth = rewardBubble.AbsoluteSize.X > 0 and rewardBubble.AbsoluteSize.X or 280
		local halfWidth = bubbleWidth / 2
		local mainWidth = mainFrame.AbsoluteSize.X > 0 and mainFrame.AbsoluteSize.X or 720
		local clampedX = math.clamp(relX, halfWidth + 10, mainWidth - halfWidth - 10)

		rewardBubble.Position = UDim2.new(0, clampedX, 0, relY - 8)
		rewardBubble.Visible = true

		if isClick then
			currentPinnedSlot = slot
		end
	end

	hideRewardBubble = function(force)
		if force or not currentPinnedSlot then
			rewardBubble.Visible = false
			currentPinnedSlot = nil
		end
	end

	rewardBubble.CloseBtn.Activated:Connect(function()
		hideRewardBubble(true)
	end)

	eventScroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		hideRewardBubble(true)
	end)

	closeBtn.MouseButton1Click:Connect(function()
		hideRewardBubble(true)
		shopGui.Enabled = false
	end)
	
	shopGui.Enabled = false
	shopGui:GetPropertyChangedSignal("Enabled"):Connect(function()
		if shopGui.Enabled then
			mainFrame.Visible = true
		end
	end)
	
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
			clone.Title.Text = item.promotionName or "No Name"
			clone.HookText.Text = item.hookText or item.adminDesc or ""
			clone.BannerImage.Image = item.bannerImage or ""
			
			local rContainer = clone:FindFirstChild("RewardsContainer")
			if rContainer then
				local bSlot = rContainer:FindFirstChild("BoardReward")
				local sSlot = rContainer:FindFirstChild("SkillReward")
				local gSlot = rContainer:FindFirstChild("GoldReward")
				
				-- 3개 보상 슬롯 모두 화이트 배경 & 라운드 테두리로 스타일 통일
				for _, slot in ipairs({bSlot, sSlot, gSlot}) do
					if slot then
						slot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
						slot.BackgroundTransparency = 0
						slot.ClipsDescendants = false
						
						local corner = slot:FindFirstChildOfClass("UICorner")
						if not corner then
							corner = Instance.new("UICorner")
							corner.Parent = slot
						end
						corner.CornerRadius = UDim.new(0, 12)
						
						local stroke = slot:FindFirstChildOfClass("UIStroke")
						if not stroke then
							stroke = Instance.new("UIStroke")
							stroke.Parent = slot
						end
						stroke.Color = Color3.fromRGB(0, 0, 0)
						stroke.Thickness = 2.0
						stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
					end
				end
				
				local function bindSlotTooltip(slot, title, desc)
					local hitBtn = slot:FindFirstChild("TooltipHitArea")
					if not hitBtn then
						hitBtn = Instance.new("TextButton")
						hitBtn.Name = "TooltipHitArea"
						hitBtn.Size = UDim2.new(1, 0, 1, 0)
						hitBtn.BackgroundTransparency = 1
						hitBtn.Text = ""
						hitBtn.ZIndex = 15
						hitBtn.Parent = slot
					end

					-- 1. PC: 마우스 호버 시 표시 / 마우스 벗어날 시 숨김
					hitBtn.MouseEnter:Connect(function()
						if currentPinnedSlot ~= slot then
							showRewardBubble(slot, title, desc, false)
						end
					end)

					hitBtn.MouseLeave:Connect(function()
						if currentPinnedSlot ~= slot then
							hideRewardBubble(false)
						end
					end)

					-- 2. 모바일: 탭 시 말풍선 토글 (열기 / 닫기)
					hitBtn.Activated:Connect(function()
						if currentPinnedSlot == slot and rewardBubble.Visible then
							hideRewardBubble(true)
						else
							showRewardBubble(slot, title, desc, true)
						end
					end)
				end
				
				if item.rewards then
					for _, r in ipairs(item.rewards) do
						if r.type == "Gold" and gSlot then
							gSlot.Visible = true
							local val = tonumber(r.value) or 0
							local formattedVal = tostring(val)
							if val >= 1000 then
								local kVal = val / 1000
								if kVal == math.floor(kVal) then
									formattedVal = tostring(kVal) .. "k"
								else
									formattedVal = string.format("%.1fk", kVal)
								end
							end
							gSlot.Label.Text = formattedVal
							gSlot.Icon.Image = "rbxassetid://127099213486402" -- 골드 아이콘
							gSlot.Icon.AnchorPoint = Vector2.new(0.5, 0.5)
							gSlot.Icon.Position = UDim2.new(0.5, 0, 0.38, 0)
							gSlot.Icon.Size = UDim2.new(0.85, 0, 0.62, 0)
							gSlot.Icon.ScaleType = Enum.ScaleType.Fit
							gSlot.Icon.BackgroundTransparency = 1

							local goldTitle = string.format("%s Gold", formattedVal)
							local goldDesc = (r.desc and r.desc ~= "") and r.desc or "Gold currency used to unlock and upgrade hoverboards, or purchase special skills in the shop!"
							bindSlotTooltip(gSlot, goldTitle, goldDesc)
						elseif r.type == "Hoverboard" and bSlot then
							bSlot.Visible = true
							
							-- StoreConfig에서 보드 정보 찾기
							local bName = tostring(r.value)
							local bIcon = "rbxassetid://13511855909"
							local bRarity = "Super Rare"
							local bDesc = "A luxurious gold-plated VIP hoverboard with booster speed +150 km/h!"
							if StoreConfig and StoreConfig.Items then
								for _, itemData in ipairs(StoreConfig.Items) do
									if itemData.id == r.value or (r.value == "Hoverboard_Starter" and itemData.id == "StarterPac_Board") then
										bName = itemData.name or bName
										bIcon = itemData.imageId or bIcon
										bRarity = itemData.rarity or bRarity
										bDesc = itemData.desc or bDesc
										break
									end
								end
							end
							
							bSlot.Label.Text = bName
							bSlot.Icon.Image = bIcon
							
							-- 보드가 잘리지 않고 라운드 테두리 안에 쏙 들어가도록 배치
							bSlot.Icon.AnchorPoint = Vector2.new(0.5, 0.5)
							bSlot.Icon.Position = UDim2.new(0.5, 0, 0.38, 0)
							bSlot.Icon.Size = UDim2.new(0.96, 0, 0.72, 0)
							bSlot.Icon.ScaleType = Enum.ScaleType.Fit
							bSlot.Icon.BackgroundTransparency = 1

							local boardTitle = string.format("%s [%s]", bName, bRarity)
							local boardDesc = (r.desc and r.desc ~= "") and r.desc or bDesc
							bindSlotTooltip(bSlot, boardTitle, boardDesc)
						elseif r.type == "Skill" and sSlot then
							sSlot.Visible = true
							
							-- SkillStoreConfig에서 스킬 정보 찾기
							local sName = tostring(r.value)
							local sIcon = "rbxassetid://76040627389377"
							local sDesc = "Freezes the lead opponent in golden ice for 5 seconds! (Max 3 uses per race)"
							if SkillStoreConfig and SkillStoreConfig.Skills then
								for _, skillData in ipairs(SkillStoreConfig.Skills) do
									if skillData.id == r.value then
										sName = skillData.name or sName
										sIcon = skillData.imageId or sIcon
										sDesc = skillData.description or sDesc
										break
									end
								end
							end
							
							sSlot.Label.Text = sName
							sSlot.Icon.Image = sIcon
							sSlot.Icon.AnchorPoint = Vector2.new(0.5, 0.5)
							sSlot.Icon.Position = UDim2.new(0.5, 0, 0.38, 0)
							sSlot.Icon.Size = UDim2.new(0.85, 0, 0.62, 0)
							sSlot.Icon.ScaleType = Enum.ScaleType.Fit
							sSlot.Icon.BackgroundTransparency = 1

							local skillTitle = string.format("%s [Exclusive]", sName)
							local skillDesc = (r.desc and r.desc ~= "") and r.desc or sDesc
							bindSlotTooltip(sSlot, skillTitle, skillDesc)
						end
					end
				end
			end
			
			-- 구매 완료 여부 스마트 판별 (Attribute, Pass, 또는 보상 보드 보유 여부)
			local isAlreadyOwned = player:GetAttribute("PurchasedEvent_" .. tostring(item.id)) == true
				or player:GetAttribute("OwnsPass_" .. tostring(item.id)) == true
			
			if not isAlreadyOwned and item.rewards then
				local ownedBoards = player:FindFirstChild("OwnedHoverboards") or (player:FindFirstChild("Inventory") and player.Inventory:FindFirstChild("OwnedHoverboards"))
				for _, r in ipairs(item.rewards) do
					if r.type == "Hoverboard" and ownedBoards and ownedBoards:FindFirstChild(tostring(r.value)) then
						isAlreadyOwned = true
						break
					end
				end
			end
			
			if isAlreadyOwned then
				clone.PriceButton.TextLabel.Text = "OWNED"
				clone.PriceButton.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
			else
				clone.PriceButton.TextLabel.Text = tostring(item.price)
			end
			
			-- 스마트 결제 연동 (GamePass / Developer Product / 가상 시뮬레이션 지원)
			clone.PriceButton.MouseButton1Click:Connect(function()
				if isAlreadyOwned or player:GetAttribute("PurchasedEvent_" .. tostring(item.id)) == true or player:GetAttribute("OwnsPass_" .. tostring(item.id)) == true then
					showToast("이미 구매한 상품입니다!", true)
					return
				end
				handleSmartPurchase(item, clone.PriceButton, "Events")
			end)
			
			-- 스타터팩 24시간 타이머 처리
			if item.isStarter then
				local timerLabel = clone:FindFirstChild("TimerLabel")
				if timerLabel then
					if isAlreadyOwned then
						timerLabel.Text = "<font color=\"#00FF88\">구매 완료</font>"
					else
						local connectionName = "StarterTimer_" .. item.id
						timerConnections[connectionName] = RunService.Heartbeat:Connect(function()
							local currentTime = os.time()
							local elapsedTime = currentTime - firstJoinTime
							local timeRemaining = 86400 - elapsedTime -- 24시간(86400초) 기준
							
							if timeRemaining > 0 then
								local hours = math.floor(timeRemaining / 3600)
								local minutes = math.floor((timeRemaining % 3600) / 60)
								local seconds = timeRemaining % 60
								timerLabel.Text = string.format("%02d<font color=\"#FFFFFF\">h</font> %02d<font color=\"#FFFFFF\">m</font> %02d<font color=\"#FFFFFF\">s</font>", hours, minutes, seconds)
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
			end
			
			clone.Parent = eventScroll
			end
		end
	end
	
	local function populateItems(dataList, parentScroll, isGoldTab)
		for _, child in ipairs(parentScroll:GetChildren()) do
			if child:IsA("Frame") then child:Destroy() end
		end
		
		for _, item in ipairs(dataList or {}) do
			if item.isVisible ~= false then
				local clone = itemTemplate:Clone()
				clone.Visible = true
			
			if isGoldTab then
				clone.ItemName.Text = "+" .. tostring(item.name) .. " Golds"
			else
				clone.ItemName.Text = item.name
			end
			clone.ItemIcon.Image = item.icon
			local isPassOwned = (item.isGamePass or not isGoldTab) and (
				player:GetAttribute("OwnsPass_" .. tostring(item.id)) == true
				or (item.name == "x2 Distance" and player:GetAttribute("OwnsPass_x2Distance") == true)
				or (item.name == "x2 Acceleration" and player:GetAttribute("OwnsPass_x2Acceleration") == true)
				or (item.name == "x2 Race Prize" and player:GetAttribute("OwnsPass_x2RacePrize") == true)
			)
			if isPassOwned then
				clone.PriceButton.TextLabel.Text = "OWNED"
				clone.PriceButton.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
			else
				clone.PriceButton.TextLabel.Text = tostring(item.price)
			end
			
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
				local category = isGoldTab and "Golds" or "Passes"
				handleSmartPurchase(item, clone.PriceButton, category)
			end)
			
			clone.Parent = parentScroll
			end
		end
	end
	
	-- 데이터 기반으로 UI 생성
	populateEvents()
	populateItems(shopData.Passes, passScroll, false)
	populateItems(shopData.Golds, goldScroll, true)
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
	
	-- 구매 완료 이벤트 수신 시 UI 즉시 갱신
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(plr, passId, wasPurchased)
		if plr == player and wasPurchased then
			player:SetAttribute("OwnsPass_" .. tostring(passId), true)
			player:SetAttribute("PurchasedEvent_" .. tostring(passId), true)
			task.wait(0.2)
			populateEvents()
			populateItems(shopData.Passes, passScroll, false)
			showToast("🎉 구매가 완료되었습니다!", true)
		end
	end)

	-- 상점 열기 버튼 연결 (UI 생성 및 함수 정의 완료 후 호출)
	local function bindShopButton()
		local shopToggleGui = playerGui:FindFirstChild("RobuxShop")
		if shopToggleGui then
			local btn = nil
			for _, desc in ipairs(shopToggleGui:GetDescendants()) do
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
						populateItems(shopData.Passes, passScroll, false)
						populateItems(shopData.Golds, goldScroll, true)
						checkEmptyState()
					end
				end)
			end
		end
	end
	
	task.spawn(function()
		-- 초기 1회 바인드
		task.wait(1)
		bindShopButton()
		
		-- 리스폰 시 재생성된 버튼에 즉시 다시 바인드
		playerGui.ChildAdded:Connect(function(child)
			if child.Name == "RobuxShop" then
				task.defer(bindShopButton)
			end
		end)
		player.CharacterAdded:Connect(function()
			task.defer(bindShopButton)
		end)
	end)
end

-- UI가 스튜디오에 완전히 로드될 때까지 기다렸다가 실행
task.spawn(function()
	local playerGui = player:WaitForChild("PlayerGui")
	playerGui:WaitForChild("RobuxShopUI")
	initializeShop()
end)
