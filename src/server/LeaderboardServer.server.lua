--!strict
-- LeaderboardServer.server.luau
-- Fetches top 10 players from OrderedDataStore and updates the SurfaceGui in the Lounge

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local Workspace = game:GetService("Workspace")
local LocalizationService = game:GetService("LocalizationService")

local WinsOrderedStore = DataStoreService:GetOrderedDataStore("HoverboardWins_Ordered_v1")

local UPDATE_INTERVAL = 60

local SAMPLE_COUNTRIES = {
	"KR", "US", "JP", "GB", "CA", "DE", "FR", "BR", "AU", "VN",
	"TH", "ID", "PH", "MX", "ES", "IT", "TW", "SG", "MY", "NL"
}

local playerCountryCache: { [number]: string } = {}

local function getPlayerCountry(player: Player): string
	local cached = playerCountryCache[player.UserId]
	if cached then return cached end
	local s, code = pcall(function()
		return LocalizationService:GetCountryRegionForPlayerAsync(player)
	end)
	if s and code and #code == 2 then
		playerCountryCache[player.UserId] = code:upper()
		return code:upper()
	end
	return "KR"
end

local function getCountryForUserId(userId: number): string
	if playerCountryCache[userId] then
		return playerCountryCache[userId]
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		return getPlayerCountry(player)
	end
	if userId > 0 then
		local idx = (math.abs(userId) % #SAMPLE_COUNTRIES) + 1
		return SAMPLE_COUNTRIES[idx]
	end
	return "KR"
end

local function getCountryFlagEmoji(countryCode: string?): string
	if not countryCode or #countryCode ~= 2 then
		return "🌐"
	end
	local c1 = string.byte(countryCode:sub(1, 1):upper())
	local c2 = string.byte(countryCode:sub(2, 2):upper())
	if c1 >= 65 and c1 <= 90 and c2 >= 65 and c2 <= 90 then
		return utf8.char(0x1F1E6 + c1 - 65) .. utf8.char(0x1F1E6 + c2 - 65)
	end
	return "🌐"
end

Players.PlayerAdded:Connect(function(player)
	getPlayerCountry(player)
end)
for _, player in ipairs(Players:GetPlayers()) do
	getPlayerCountry(player)
end

local function ensureScrollContainer(container: Instance): ScrollingFrame
	if container:IsA("ScrollingFrame") then
		local scroll = container :: ScrollingFrame
		scroll.ScrollBarThickness = 14
		scroll.ScrollBarImageColor3 = Color3.fromRGB(40, 180, 255)
		scroll.ScrollingDirection = Enum.ScrollingDirection.Y
		scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
		scroll.BorderSizePixel = 0
		scroll.ClipsDescendants = true
		return scroll
	end

	local oldContainer = container :: Frame
	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Name = oldContainer.Name
	scrollFrame.Size = oldContainer.Size
	scrollFrame.Position = oldContainer.Position
	scrollFrame.AnchorPoint = oldContainer.AnchorPoint
	scrollFrame.BackgroundTransparency = oldContainer.BackgroundTransparency
	scrollFrame.BackgroundColor3 = oldContainer.BackgroundColor3
	scrollFrame.BorderSizePixel = 0
	scrollFrame.ScrollBarThickness = 14
	scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(40, 180, 255)
	scrollFrame.ScrollingDirection = Enum.ScrollingDirection.Y
	scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	scrollFrame.ClipsDescendants = true
	scrollFrame.ZIndex = oldContainer.ZIndex
	scrollFrame.Parent = oldContainer.Parent

	for _, child in ipairs(oldContainer:GetChildren()) do
		child.Parent = scrollFrame
	end

	oldContainer:Destroy()
	return scrollFrame
end

local function createRow(rank: number, username: string, wins: number, userId: number, countryCode: string)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -40, 0, 70)
	row.BorderSizePixel = 0
	row.BackgroundColor3 = Color3.fromRGB(240, 245, 255)
	
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0, 15)
	uiCorner.Parent = row
	
	-- Styling for Ranks
	local rankText = tostring(rank)
	
	if rank == 1 then
		row.BackgroundColor3 = Color3.fromRGB(255, 200, 50) -- Vibrant Gold
	elseif rank == 2 then
		row.BackgroundColor3 = Color3.fromRGB(210, 220, 230) -- Cool Silver
	elseif rank == 3 then
		row.BackgroundColor3 = Color3.fromRGB(220, 140, 90) -- Warm Bronze
	elseif rank <= 10 then
		row.BackgroundColor3 = Color3.fromRGB(150, 240, 255) -- Bright Cyan
	else
		-- 11~100위 번갈아가는 깔끔한 색상
		if rank % 2 == 1 then
			row.BackgroundColor3 = Color3.fromRGB(230, 243, 255)
		else
			row.BackgroundColor3 = Color3.fromRGB(245, 250, 255)
		end
	end
	
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(30, 60, 90)
	stroke.Thickness = 2
	stroke.Parent = row
	
	-- Rank Label
	local rankLabel = Instance.new("TextLabel")
	rankLabel.Name = "Rank"
	rankLabel.Size = UDim2.new(0, 80, 1, 0)
	rankLabel.Position = UDim2.new(0, 20, 0, 0)
	rankLabel.BackgroundTransparency = 1
	rankLabel.Text = rankText
	rankLabel.Font = Enum.Font.GothamBlack
	rankLabel.TextSize = rank < 10 and 35 or (rank < 100 and 30 or 26)
	rankLabel.TextColor3 = Color3.fromRGB(30, 30, 30)
	rankLabel.TextXAlignment = Enum.TextXAlignment.Center
	rankLabel.Parent = row
	
	-- Flag Label (국기)
	local flagLabel = Instance.new("TextLabel")
	flagLabel.Name = "Flag"
	flagLabel.Size = UDim2.new(0, 50, 0, 50)
	flagLabel.Position = UDim2.new(0, 110, 0.5, -25)
	flagLabel.BackgroundTransparency = 1
	flagLabel.Font = Enum.Font.GothamBold
	flagLabel.Text = getCountryFlagEmoji(countryCode)
	flagLabel.TextScaled = true
	flagLabel.TextXAlignment = Enum.TextXAlignment.Center
	flagLabel.TextYAlignment = Enum.TextYAlignment.Center
	flagLabel.Parent = row
	
	-- Name Label
	local displayName = username
	if string.len(displayName) > 12 then
		displayName = string.sub(displayName, 1, 12) .. "..."
	end
	
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "PlayerName"
	nameLabel.Size = UDim2.new(0, 500, 1, 0)
	nameLabel.Position = UDim2.new(0.5, -250, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = displayName
	nameLabel.Font = Enum.Font.GothamBlack
	nameLabel.TextSize = 30
	nameLabel.TextColor3 = Color3.fromRGB(30, 30, 30)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Center
	nameLabel.Parent = row
	
	-- Wins Label
	local winsLabel = Instance.new("TextLabel")
	winsLabel.Name = "Wins"
	winsLabel.Size = UDim2.new(0, 150, 1, 0)
	winsLabel.Position = UDim2.new(1, -200, 0, 0)
	winsLabel.BackgroundTransparency = 1
	winsLabel.Text = tostring(wins)
	winsLabel.Font = Enum.Font.GothamBlack
	winsLabel.TextSize = 35
	winsLabel.TextColor3 = Color3.fromRGB(30, 30, 30)
	winsLabel.TextXAlignment = Enum.TextXAlignment.Center
	winsLabel.Parent = row
	
	return row
end

local function updateLeaderboard()
	local board = Workspace:FindFirstChild("HoverboardLeaderboard", true) or Workspace:FindFirstChild("GlovalLeaderBoard", true) or Workspace:FindFirstChild("GlobalLeaderboardBoard", true)
	if not board then return end
	
	local surfaceGui = board:FindFirstChild("RaceBoard", true) or board:FindFirstChild("LeaderboardSurfaceGui", true) or board:FindFirstChildWhichIsA("SurfaceGui", true)
	if not surfaceGui then return end
	
	local root = surfaceGui:FindFirstChild("Root", true)
	if not root then return end
	
	local rawContainer = root:FindFirstChild("Container") or root
	local container = ensureScrollContainer(rawContainer)
	local rowTemplate = container:FindFirstChild("RowTemplate") or root:FindFirstChild("RowTemplate")
	
	-- 기존 헤더 '프로필' 숨김 처리
	for _, desc in ipairs(board:GetDescendants()) do
		if desc:IsA("TextLabel") or desc:IsA("TextButton") then
			local noSpace = desc.Text:gsub("%s+", ""):lower()
			if noSpace:find("프로필") or desc.Name:lower():find("profile") then
				desc.Text = ""
			end
		end
	end
	
	local colHeader = container:FindFirstChild("ColumnHeader") or root:FindFirstChild("ColumnHeader")
	if colHeader then
		local flagHeader = colHeader:FindFirstChild("FlagTitle")
		if not flagHeader then
			flagHeader = Instance.new("TextLabel")
			flagHeader.Name = "FlagTitle"
			flagHeader.Size = UDim2.new(0, 80, 1, 0)
			flagHeader.Position = UDim2.new(0, 160, 0, 0)
			flagHeader.BackgroundTransparency = 1
			flagHeader.Text = ""
			flagHeader.Font = Enum.Font.GothamBlack
			flagHeader.TextSize = 65
			flagHeader.TextColor3 = Color3.fromRGB(30, 30, 30)
			flagHeader.TextXAlignment = Enum.TextXAlignment.Center
			flagHeader.Parent = colHeader
		else
			flagHeader.Text = ""
		end
	end
	
	-- Clear old UI rows (only dynamic rows, keep layout, corners, headers, and template) early to hide dummy data
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("Frame") and child.Name ~= "ColumnHeader" and child.Name ~= "RowTemplate" and not child.Name:match("Spacer") then
			child:Destroy()
		end
	end
	
	-- Fetch Data (최대 100위까지 수집)
	local allEntries = {}
	local success, pages = pcall(function()
		return WinsOrderedStore:GetSortedAsync(false, 100)
	end)
	
	if success and pages then
		while #allEntries < 100 do
			local pageData = pages:GetCurrentPage()
			for _, entry in ipairs(pageData) do
				table.insert(allEntries, entry)
				if #allEntries >= 100 then break end
			end
			if #allEntries >= 100 or pages.IsFinished then
				break
			end
			local advOk = pcall(function()
				pages:AdvanceToNextPageAsync()
			end)
			if not advOk then break end
		end
	else
		warn("🚨 [LeaderboardServer] Failed to fetch OrderedDataStore! (Make sure Studio API Access is enabled)")
	end
	
	-- (프리뷰용 가짜 데이터 채움 로직 제거: 실데이터만 표시되도록 함)
	
	for rank, data in ipairs(allEntries) do
		local userId = tonumber(data.key) or 0
		local wins = data.value
		local countryCode = getCountryForUserId(userId)
		local flagEmoji = getCountryFlagEmoji(countryCode)
		
		-- Try to get username
		local username = "Player" .. tostring(userId)
		pcall(function()
			username = Players:GetNameFromUserIdAsync(userId)
		end)
		
		local row
		if rowTemplate then
			-- Use user's custom template from StarterGui/Workspace
			row = rowTemplate:Clone()
			row.Name = "Row_" .. rank
			row.Visible = true
			
			-- 1. Update Rank (메달 아이콘 제거, 가운데 정렬, 가시성 확보)
			local rankLabel = row:FindFirstChild("Rank")
			if rankLabel and rankLabel:IsA("TextLabel") then
				rankLabel.RichText = false
				rankLabel.Text = tostring(rank)
				rankLabel.TextXAlignment = Enum.TextXAlignment.Center
				
				-- 이전 메달 아이콘이 있다면 완전히 제거하여 순위 텍스트가 가려지지 않게 함
				local medal = rankLabel:FindFirstChild("MedalIcon")
				if medal then medal:Destroy() end
				
				-- 100위까지 글자 크기 유동 조정
				if rank < 10 then
					rankLabel.TextSize = 55
				elseif rank < 100 then
					rankLabel.TextSize = 46
				else
					rankLabel.TextSize = 38
				end
				
				-- 텍스트를 검정색으로 설정하고 외곽선 제거
				rankLabel.TextColor3 = Color3.fromRGB(30, 30, 30)
				local rankStroke = rankLabel:FindFirstChild("UIStroke")
				if rankStroke then
					rankStroke:Destroy()
				end
			end
			
			-- 2. Coloring based on rank (1~3위 금/은/동, 4~10위 하늘색, 11~100위 부드러운 교차색)
			local bg = row
			if rank == 1 then 
				bg.BackgroundColor3 = Color3.fromRGB(255, 200, 50) -- Vibrant Gold
			elseif rank == 2 then 
				bg.BackgroundColor3 = Color3.fromRGB(210, 220, 230) -- Cool Silver
			elseif rank == 3 then 
				bg.BackgroundColor3 = Color3.fromRGB(220, 140, 90) -- Warm Bronze
			elseif rank <= 10 then 
				bg.BackgroundColor3 = Color3.fromRGB(150, 240, 255) -- Bright Cyan
			else
				if rank % 2 == 1 then
					bg.BackgroundColor3 = Color3.fromRGB(230, 243, 255)
				else
					bg.BackgroundColor3 = Color3.fromRGB(245, 250, 255)
				end
			end
			
			-- 3. Flag (국기): 프로필 이미지를 국기로 교체
			local profilePic = bg:FindFirstChild("ProfilePic") or row:FindFirstChild("ProfilePic")
			if profilePic then
				profilePic.Visible = false
			end
			
			local flagLabel = bg:FindFirstChild("Flag") or row:FindFirstChild("Flag")
			if not flagLabel then
				flagLabel = Instance.new("TextLabel")
				flagLabel.Name = "Flag"
				flagLabel.Size = profilePic and profilePic.Size or UDim2.new(0, 60, 0, 60)
				flagLabel.Position = profilePic and profilePic.Position or UDim2.new(0, 170, 0.5, -30)
				flagLabel.AnchorPoint = profilePic and profilePic.AnchorPoint or Vector2.new(0, 0)
				flagLabel.BackgroundTransparency = 1
				flagLabel.Font = Enum.Font.GothamBold
				flagLabel.TextScaled = true
				flagLabel.TextXAlignment = Enum.TextXAlignment.Center
				flagLabel.TextYAlignment = Enum.TextYAlignment.Center
				flagLabel.ZIndex = (profilePic and profilePic.ZIndex or 5) + 1
				flagLabel.Parent = bg
			end
			if flagLabel:IsA("TextLabel") then
				flagLabel.Text = flagEmoji
			end
			
			-- 4. 닉네임 12자 제한 및 '...' 생략 로직
			local displayName = username
			if string.len(displayName) > 12 then
				displayName = string.sub(displayName, 1, 12) .. "..."
			end
			
			local nameLabel = bg:FindFirstChild("PlayerName")
			if nameLabel and nameLabel:IsA("TextLabel") then
				nameLabel.Text = displayName
				nameLabel.TextColor3 = Color3.fromRGB(30, 30, 30)
				local stroke = nameLabel:FindFirstChild("UIStroke")
				if stroke then stroke:Destroy() end
			end
			
			-- 5. Update Wins
			local winsLabel = bg:FindFirstChild("Wins") or row:FindFirstChild("Wins")
			if winsLabel and winsLabel:IsA("TextLabel") then
				winsLabel.Text = tostring(wins)
				winsLabel.TextColor3 = Color3.fromRGB(30, 30, 30)
				local stroke = winsLabel:FindFirstChild("UIStroke")
				if stroke then stroke:Destroy() end
			end
		else
			-- Fallback to script generated row
			row = createRow(rank, username, wins, userId, countryCode)
		end
		
		row.LayoutOrder = rank + 1
		row.Parent = container
	end
	
	print("✅ [LeaderboardServer] 글로벌 리더보드 100위 갱신 완료!")
end

local function getSurfaceGui()
	local board = Workspace:FindFirstChild("HoverboardLeaderboard", true) or Workspace:FindFirstChild("GlovalLeaderBoard", true) or Workspace:FindFirstChild("GlobalLeaderboardBoard", true)
	if not board then return nil end
	return board:FindFirstChild("RaceBoard", true) or board:FindFirstChild("LeaderboardSurfaceGui", true) or board:FindFirstChildWhichIsA("SurfaceGui", true)
end

local function updateRefreshCounter(timeLeft: number)
	local surfaceGui = getSurfaceGui()
	if not surfaceGui then return end
	
	local counter = surfaceGui:FindFirstChild("RefreshCounter")
	if not counter then
		counter = Instance.new("TextLabel")
		counter.Name = "RefreshCounter"
		counter.Size = UDim2.new(1, 0, 0, 80)
		counter.AnchorPoint = Vector2.new(0.5, 1)
		counter.Position = UDim2.new(0.5, 0, 1, -20)
		counter.BackgroundTransparency = 1
		counter.Font = Enum.Font.GothamBlack
		counter.TextColor3 = Color3.fromRGB(255, 255, 255)
		counter.TextScaled = true
		counter.ZIndex = 20
		counter.Parent = surfaceGui
		
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(0, 0, 0)
		stroke.Thickness = 4
		stroke.Parent = counter
	end
	counter.Text = string.format("Refresh in %ds", timeLeft)
end

task.spawn(function()
	-- Wait for the board to be spawned by LoungeGenerator
	for i = 1, 40 do
		if getSurfaceGui() then break end
		task.wait(0.25)
	end
	
	updateLeaderboard()
	
	local timeLeft = UPDATE_INTERVAL
	while true do
		updateRefreshCounter(timeLeft)
		task.wait(1)
		timeLeft -= 1
		if timeLeft <= 0 then
			updateLeaderboard()
			timeLeft = UPDATE_INTERVAL
		end
	end
end)
