--!strict
-- MoneyLeaderboardServer.server.luau
-- Fetches top 10 players from OrderedDataStore and updates the SurfaceGui in the Lounge

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local Workspace = game:GetService("Workspace")

local GoldOrderedStore = DataStoreService:GetOrderedDataStore("HoverboardGold_Ordered_v1")

local UPDATE_INTERVAL = 15

local function createRow(rank: number, username: string, wins: number, userId: number)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -40, 0, 70)
	row.BorderSizePixel = 0
	row.BackgroundColor3 = Color3.fromRGB(240, 245, 255)
	
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0, 15)
	uiCorner.Parent = row
	
	-- Styling for Top 3
	local rankText = tostring(rank)
	local iconSize = UDim2.new(0, 50, 0, 50)
	
	if rank == 1 then
		row.BackgroundColor3 = Color3.fromRGB(255, 215, 0) -- Gold
		rankText = "🏆 1"
	elseif rank == 2 then
		row.BackgroundColor3 = Color3.fromRGB(192, 192, 192) -- Silver
		rankText = "🥈 2"
	elseif rank == 3 then
		row.BackgroundColor3 = Color3.fromRGB(205, 127, 50) -- Bronze
		rankText = "🥉 3"
	else
		-- Gradient for 4-10
		local uiGradient = Instance.new("UIGradient")
		uiGradient.Color = ColorSequence.new{
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 240, 255))
		}
		uiGradient.Parent = row
	end
	
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(30, 60, 90)
	stroke.Thickness = 2
	stroke.Parent = row
	
	-- Rank Label
	local rankLabel = Instance.new("TextLabel")
	rankLabel.Size = UDim2.new(0, 80, 1, 0)
	rankLabel.Position = UDim2.new(0, 20, 0, 0)
	rankLabel.BackgroundTransparency = 1
	rankLabel.Text = rankText
	rankLabel.Font = Enum.Font.GothamBlack
	rankLabel.TextSize = 35
	rankLabel.TextColor3 = Color3.fromRGB(30, 30, 30)
	rankLabel.TextXAlignment = Enum.TextXAlignment.Center
	rankLabel.Parent = row
	
	-- Profile Pic
	local profilePic = Instance.new("ImageLabel")
	profilePic.Size = iconSize
	profilePic.Position = UDim2.new(0, 110, 0.5, -25)
	profilePic.BackgroundTransparency = 1
	
	local success, thumb = pcall(function()
		return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
	end)
	if success then
		profilePic.Image = thumb
	else
		profilePic.Image = "rbxassetid://0" -- Placeholder
	end
	
	local picCorner = Instance.new("UICorner")
	picCorner.CornerRadius = UDim.new(1, 0)
	picCorner.Parent = profilePic
	
	local picStroke = Instance.new("UIStroke")
	picStroke.Color = Color3.fromRGB(50, 50, 50)
	picStroke.Thickness = 2
	picStroke.Parent = profilePic
	
	profilePic.Parent = row
	
	-- Name Label
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(0, 500, 1, 0)
	nameLabel.Position = UDim2.new(0.5, -250, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = username
	nameLabel.Font = Enum.Font.GothamBlack
	nameLabel.TextSize = 30
	nameLabel.TextColor3 = Color3.fromRGB(30, 30, 30)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Center
	nameLabel.Parent = row
	
	-- Wins Label
	local winsLabel = Instance.new("TextLabel")
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

-- generateHeader 함수는 삭제되었습니다. (GenerateThickCartoonLeaderboard가 UI를 전담합니다)

local function updateLeaderboard()
	local board = Workspace:FindFirstChild("MoneyLeaderboard", true) or Workspace:FindFirstChild("MoneyBoard", true)
	if not board then return end
	
	local surfaceGui = board:FindFirstChild("RaceBoard", true) or board:FindFirstChild("LeaderboardSurfaceGui", true) or board:FindFirstChildWhichIsA("SurfaceGui", true)
	if not surfaceGui then return end
	
	local root = surfaceGui:FindFirstChild("Root", true)
	if not root then return end
	
	local container = root:FindFirstChild("Container") or root
	local rowTemplate = container:FindFirstChild("RowTemplate") or root:FindFirstChild("RowTemplate")
	
	-- Fetch Data
	local success, pages = pcall(function()
		return GoldOrderedStore:GetSortedAsync(false, 10)
	end)
	
	if not success then
		warn("🚨 [MoneyLeaderboardServer] Failed to fetch OrderedDataStore! (Make sure Studio API Access is enabled)")
		return
	end
	
	-- Fetch current page data
	local currentPage = pages and pages:GetCurrentPage() or {}
	
	-- 테스트/프리뷰 용도: 데이터가 아예 없을 경우 가짜 데이터 10개 생성
	if #currentPage == 0 then
		for i = 1, 10 do
			table.insert(currentPage, {
				key = "1", -- 로블록스 기본 계정 (Roblox)
				value = 1000 - (i * 50)
			})
		end
	end
	
	-- Clear old UI rows (only dynamic rows, keep layout, corners, headers, and template)
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("Frame") and child.Name ~= "ColumnHeader" and child.Name ~= "RowTemplate" and not child.Name:match("Spacer") then
			child:Destroy()
		end
	end
	
	for rank, data in ipairs(currentPage) do
		local userId = tonumber(data.key) or 0
		local wins = data.value
		
		-- Try to get username
		local username = "Unknown"
		pcall(function()
			username = Players:GetNameFromUserIdAsync(userId)
		end)
		
		local row
		if rowTemplate then
			-- Use user's custom template from StarterGui/Workspace
			row = rowTemplate:Clone()
			row.Name = "Row_" .. rank
			row.Visible = true
			
			-- Update Rank
			local rankLabel = row:FindFirstChild("Rank")
			if rankLabel and rankLabel:IsA("TextLabel") then
				if rank == 1 then rankLabel.Text = "🏆 1"
				elseif rank == 2 then rankLabel.Text = "🥈 2"
				elseif rank == 3 then rankLabel.Text = "🥉 3"
				else rankLabel.Text = tostring(rank)
				end
			end
			
			-- Coloring based on rank (Cartoon Simulator Style)
			local bg = row
			
			-- 카툰 스타일에 맞춘 플랫(Flat) 색상 적용
			if rank == 1 then 
				bg.BackgroundColor3 = Color3.fromRGB(255, 200, 50) -- Vibrant Gold
			elseif rank == 2 then 
				bg.BackgroundColor3 = Color3.fromRGB(210, 220, 230) -- Cool Silver
			elseif rank == 3 then 
				bg.BackgroundColor3 = Color3.fromRGB(220, 140, 90) -- Warm Bronze
			else 
				bg.BackgroundColor3 = Color3.fromRGB(150, 240, 255) -- Bright Cyan (4th~10th)
			end
			
			-- 닉네임 12자 제한 및 '...' 생략 로직
			local displayName = username
			if string.len(displayName) > 12 then
				displayName = string.sub(displayName, 1, 12) .. "..."
			end
			
			-- Update Username
			local nameLabel = bg:FindFirstChild("PlayerName")
			if nameLabel and nameLabel:IsA("TextLabel") then
				nameLabel.Text = displayName
			end
			
			-- Update Money
			local moneyLabel = bg:FindFirstChild("Money") or row:FindFirstChild("Money")
			if moneyLabel and moneyLabel:IsA("TextLabel") then
				moneyLabel.Text = tostring(wins)
			end
			
			-- Update Profile Pic
			local profilePic = bg:FindFirstChild("ProfilePic") or row:FindFirstChild("ProfilePic")
			if profilePic and profilePic:IsA("ImageLabel") then
				local s, thumb = pcall(function()
					return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
				end)
				if s then
					profilePic.Image = thumb
				end
			end
		else
			-- Fallback to script generated row
			row = createRow(rank, username, wins, userId)
		end
		
		row.LayoutOrder = rank + 1
		row.Parent = container
	end
	
	print("✅ [MoneyLeaderboardServer] 글로벌 머니 리더보드 갱신 완료!")
end

task.spawn(function()
	-- Give LoungeGenerator some time to spawn the board
	task.wait(10)
	while true do
		updateLeaderboard()
		task.wait(UPDATE_INTERVAL)
	end
end)
