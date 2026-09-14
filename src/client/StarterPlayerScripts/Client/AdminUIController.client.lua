--!strict
-- AdminUIController.client.lua
-- 관리자 전용 인게임 패널 UI

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("HoverboardRemotes")

local adminAuthRemote = remotes:WaitForChild("AdminAuthStatus") :: RemoteEvent
local updatePromoFunc = remotes:WaitForChild("UpdatePromotionData") :: RemoteFunction
local getPromoFunc = remotes:WaitForChild("GetPromotionData") :: RemoteFunction

local isAdmin = false
local adminGui = nil

adminAuthRemote.OnClientEvent:Connect(function(status)
	isAdmin = status
	if isAdmin then
		print("👑 [AdminUI] 관리자 권한 확인됨. 채팅창에 /admin 을 입력해 패널을 여세요.")
	end
end)

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
	
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 50)
	title.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
	title.Text = " ADMIN PANEL - 상점 관리"
	title.TextColor3 = Color3.new(1,1,1)
	title.TextSize = 24
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = mainFrame
	
	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 50, 0, 50)
	closeBtn.Position = UDim2.new(1, -50, 0, 0)
	closeBtn.Text = "X"
	closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	closeBtn.TextColor3 = Color3.new(1,1,1)
	closeBtn.TextSize = 24
	closeBtn.Parent = mainFrame
	closeBtn.MouseButton1Click:Connect(function() adminGui.Enabled = false end)

	-- 좌측 리스트 (등록된 상품들)
	local listFrame = Instance.new("ScrollingFrame")
	listFrame.Size = UDim2.new(0, 300, 1, -50)
	listFrame.Position = UDim2.new(0, 0, 0, 50)
	listFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
	listFrame.Parent = mainFrame
	
	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 5)
	listLayout.Parent = listFrame
	
	-- 우측 폼 (편집 영역) - 내용이 길어질 수 있으므로 스크롤 프레임으로 변경
	local editFrame = Instance.new("ScrollingFrame")
	editFrame.Size = UDim2.new(1, -300, 1, -50)
	editFrame.Position = UDim2.new(0, 300, 0, 50)
	editFrame.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
	editFrame.ScrollBarThickness = 8
	editFrame.CanvasSize = UDim2.new(0, 0, 0, 650) -- 스크롤 가능하도록 높이 확보
	editFrame.Parent = mainFrame
	
	local function createInput(name, placeholder, yPos)
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(0, 160, 0, 50)
		label.Position = UDim2.new(0, 10, 0, yPos)
		label.Text = name
		label.TextColor3 = Color3.new(1,1,1)
		label.BackgroundTransparency = 1
		label.TextXAlignment = Enum.TextXAlignment.Right
		label.TextSize = 22
		label.Font = Enum.Font.GothamBold
		label.Parent = editFrame
		
		local box = Instance.new("TextBox")
		box.Size = UDim2.new(1, -200, 0, 50)
		box.Position = UDim2.new(0, 180, 0, yPos)
		box.PlaceholderText = placeholder
		box.PlaceholderColor3 = Color3.fromRGB(220, 220, 220)
		box.Text = ""
		box.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
		box.TextColor3 = Color3.fromRGB(255, 255, 255)
		box.ClearTextOnFocus = false
		box.TextSize = 22
		box.Font = Enum.Font.Gotham
		box.TextXAlignment = Enum.TextXAlignment.Left
		box.Parent = editFrame
		
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, 15)
		padding.Parent = box
		
		return box
	end
	
	local boxId = createInput("상품 ID", "Developer Product ID (예: 123456)", 20)
	local boxName = createInput("프로모션 명", "유저에게 보여질 이벤트 이름", 80)
	local boxDesc = createInput("관리자 메모", "나만 볼 메모", 140)
	local boxStart = createInput("시작 날짜", "예) 2026-10-01 15:30 (상시면 0)", 200)
	local boxEnd = createInput("종료 날짜", "예) 2026-10-31 23:59 (상시면 무제한)", 260)
	local boxImage = createInput("배너 이미지", "rbxassetid://...", 320)
	local boxPrice = createInput("가격 (R$)", "UI 표기용 가격", 380)
	local boxLimit = createInput("한정 수량", "선착순 개수 (무제한은 빈칸)", 440)
	local boxGoldReward = createInput("보상: 골드량", "예) 5000 (없으면 빈칸)", 500)
	local boxBoardReward = createInput("보상: 보드 ID", "예) Hoverboard_001 (없으면 빈칸)", 560)
	local boxSkillReward = createInput("보상: 스킬 ID", "예) Skill_Premium (없으면 빈칸)", 620)
	
	local saveBtn = Instance.new("TextButton")
	saveBtn.Size = UDim2.new(0, 200, 0, 50)
	saveBtn.Position = UDim2.new(0.5, -220, 0, 710)
	saveBtn.Text = "저장하기 (SAVE)"
	saveBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
	saveBtn.TextColor3 = Color3.new(1,1,1)
	saveBtn.TextSize = 22
	saveBtn.Font = Enum.Font.GothamBold
	saveBtn.Parent = editFrame
	
	local deleteBtn = Instance.new("TextButton")
	deleteBtn.Size = UDim2.new(0, 200, 0, 50)
	deleteBtn.Position = UDim2.new(0.5, 20, 0, 710)
	deleteBtn.Text = "삭제 (DELETE)"
	deleteBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	deleteBtn.TextColor3 = Color3.new(1,1,1)
	deleteBtn.TextSize = 22
	deleteBtn.Font = Enum.Font.GothamBold
	deleteBtn.Parent = editFrame
	
	editFrame.CanvasSize = UDim2.new(0, 0, 0, 810)
	
	local currentPromotions = {}
	
	-- 날짜 파싱 헬퍼 함수
	local function parseDateToUnix(dateStr, defaultUnix)
		if not dateStr or dateStr == "" or dateStr == "0" or dateStr == "무제한" then
			return defaultUnix
		end
		local y, m, d, h, min = string.match(dateStr, "(%d+)%-(%d+)%-(%d+)%s*(%d*):*(%d*)")
		if y and m and d then
			h = tonumber(h) or 0
			min = tonumber(min) or 0
			return DateTime.fromUniversalTime(tonumber(y), tonumber(m), tonumber(d), h - 9, min, 0).UnixTimestamp
		end
		return defaultUnix
	end

	local function unixToKSTString(unix)
		if not unix or unix == 0 then return "0" end
		if unix >= 4102412400 then return "무제한" end
		local dt = DateTime.fromUnixTimestamp(unix + (9 * 3600))
		return string.format("%04d-%02d-%02d %02d:%02d", dt:ToUniversalTime().Year, dt:ToUniversalTime().Month, dt:ToUniversalTime().Day, dt:ToUniversalTime().Hour, dt:ToUniversalTime().Minute)
	end
	
	local function refreshList()
		for _, child in ipairs(listFrame:GetChildren()) do
			if child:IsA("TextButton") then child:Destroy() end
		end
		
		for i, promo in ipairs(currentPromotions) do
			local btn = Instance.new("TextButton")
			btn.Size = UDim2.new(1, -10, 0, 50)
			btn.Text = promo.promotionName .. " (" .. tostring(promo.id) .. ")"
			btn.TextSize = 18
			btn.Font = Enum.Font.GothamSemibold
			btn.Parent = listFrame
			
			btn.MouseButton1Click:Connect(function()
				boxId.Text = tostring(promo.id)
				boxName.Text = promo.promotionName or ""
				boxDesc.Text = promo.adminDesc or ""
				boxStart.Text = unixToKSTString(promo.startDate)
				boxEnd.Text = unixToKSTString(promo.endDate)
				boxImage.Text = promo.bannerImage or ""
				boxPrice.Text = tostring(promo.price)
				boxLimit.Text = promo.maxQuantity and tostring(promo.maxQuantity) or ""
				
				-- 보상 파싱하여 텍스트박스에 분배
				boxGoldReward.Text = ""
				boxBoardReward.Text = ""
				boxSkillReward.Text = ""
				if promo.rewards then
					for _, r in ipairs(promo.rewards) do
						if r.type == "Gold" then
							boxGoldReward.Text = tostring(r.value)
						elseif r.type == "Hoverboard" then
							boxBoardReward.Text = tostring(r.value)
						elseif r.type == "Skill" then
							boxSkillReward.Text = tostring(r.value)
						end
					end
				end
			end)
		end
		listFrame.CanvasSize = UDim2.new(0, 0, 0, #currentPromotions * 55 + 50)
	end
	
	local function loadData()
		local data = getPromoFunc:InvokeServer()
		if data then
			currentPromotions = data
			refreshList()
		end
	end
	
	saveBtn.MouseButton1Click:Connect(function()
		local parsedRewards = {}
		
		-- 골드 보상 파싱
		local goldVal = tonumber(boxGoldReward.Text)
		if goldVal and goldVal > 0 then
			table.insert(parsedRewards, { type = "Gold", value = goldVal })
		end
		
		-- 보드 보상 파싱
		local boardVal = boxBoardReward.Text
		if boardVal and boardVal ~= "" then
			table.insert(parsedRewards, { type = "Hoverboard", value = boardVal })
		end
		
		-- 스킬 보상 파싱
		local skillVal = boxSkillReward.Text
		if skillVal and skillVal ~= "" then
			table.insert(parsedRewards, { type = "Skill", value = skillVal })
		end
		
		local newPromo = {
			id = tonumber(boxId.Text) or 0,
			promotionName = boxName.Text,
			adminDesc = boxDesc.Text,
			startDate = parseDateToUnix(boxStart.Text, 0),
			endDate = parseDateToUnix(boxEnd.Text, 4102412400),
			bannerImage = boxImage.Text,
			price = tonumber(boxPrice.Text) or 0,
			maxQuantity = tonumber(boxLimit.Text),
			rewards = parsedRewards
		}
		
		-- 덮어쓰거나 추가
		local found = false
		for i, p in ipairs(currentPromotions) do
			if p.id == newPromo.id then
				currentPromotions[i] = newPromo
				found = true
				break
			end
		end
		
		if not found then
			table.insert(currentPromotions, newPromo)
		end
		
		local s, msg = updatePromoFunc:InvokeServer(currentPromotions)
		if s then
			saveBtn.Text = "SAVED!"
			task.delay(1, function() saveBtn.Text = "저장하기 (SAVE)" end)
			refreshList()
		end
	end)
	
	deleteBtn.MouseButton1Click:Connect(function()
		local targetId = tonumber(boxId.Text)
		for i, p in ipairs(currentPromotions) do
			if p.id == targetId then
				table.remove(currentPromotions, i)
				break
			end
		end
		
		local s, msg = updatePromoFunc:InvokeServer(currentPromotions)
		if s then
			deleteBtn.Text = "DELETED!"
			task.delay(1, function() deleteBtn.Text = "DELETE PROMO" end)
			refreshList()
		end
	end)
	
	-- 빈 공간(새로 작성용) 리셋 버튼
	local newBtn = Instance.new("TextButton")
	newBtn.Size = UDim2.new(1, -10, 0, 40)
	newBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 255)
	newBtn.TextColor3 = Color3.new(1,1,1)
	newBtn.Text = "+ 새 프로모션 만들기"
	newBtn.LayoutOrder = -1 -- 가장 위에 위치
	newBtn.Parent = listFrame
	
	newBtn.MouseButton1Click:Connect(function()
		boxId.Text = ""
		boxName.Text = ""
		boxDesc.Text = ""
		boxStart.Text = "0"
		boxEnd.Text = "4102412400"
		boxImage.Text = "rbxassetid://"
		boxPrice.Text = ""
		boxLimit.Text = ""
		boxRewards.Text = '[{"type":"Gold", "value":1000}]'
	end)
	
	loadData()
end

-- 채팅창 이벤트 연결
LocalPlayer.Chatted:Connect(function(msg)
	if msg == "/admin" and isAdmin then
		if adminGui then
			adminGui.Enabled = not adminGui.Enabled
		else
			buildAdminUI()
		end
	end
end)
