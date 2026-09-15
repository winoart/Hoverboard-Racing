--!strict
-- GameLoopController.client.luau
-- 3-Map Voting UI, Majority Vote Winner Detection, 5s Animated Map Loading Screen, & 110s Race Match Sync

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local playerGui = LocalPlayer:WaitForChild("PlayerGui")

local remotesFolder = ReplicatedStorage:WaitForChild("HoverboardRemotes") :: Folder
local phaseRemote = remotesFolder:WaitForChild("GamePhaseChanged") :: RemoteEvent
local voteRemote = remotesFolder:WaitForChild("VoteMapRequest") :: RemoteEvent

-- UI Element References
local mainGuiScreen: ScreenGui? = nil
local headerBannerFrame: Frame? = nil
local headerStatusLabel: TextLabel? = nil
local headerTimerLabel: TextLabel? = nil

local votingModalFrame: Frame? = nil
local modalFooterTimerLabel: TextLabel? = nil

local loadingModalFrame: Frame? = nil
local loadingTitleLabel: TextLabel? = nil
local loadingSubLabel: TextLabel? = nil
local loadingFillBar: Frame? = nil
local loadingPercentLabel: TextLabel? = nil

local errorModalFrame: Frame? = nil

type VoterInfo = { userId: number, name: string }
type MapVoteData = { [string]: { VoterInfo } }

local currentPhase = "INTERMISSION"
local phaseTimeLeft = 0
local currentChosenMap = "Oval Speedway"
local currentMapVotes: MapVoteData = {
	["Oval Speedway"] = {},
	["Cyber City"] = {},
	["Magma Ridge"] = {},
	["Desert Track"] = {},
}
local selectedMapName = ""
local isVotingModalDismissed = false

-- Map Card Configurations
local MAP_CONFIGS = {
	{
		id = "Oval Speedway",
		title = "🏎️ Oval Speedway",
		sub = "4-Lane Circuit Track",
		color = Color3.fromRGB(0, 220, 255),
		bgGrad = Color3.fromRGB(15, 45, 75),
	},
	{
		id = "Desert Track",
		title = "🏜️ Desert Track",
		sub = "Sandy Dunes",
		color = Color3.fromRGB(255, 200, 50),
		bgGrad = Color3.fromRGB(80, 60, 20),
	},
	{
		id = "Magma Ridge",
		title = "🌋 Magma Ridge",
		sub = "Volcanic Canyon",
		color = Color3.fromRGB(255, 120, 30),
		bgGrad = Color3.fromRGB(75, 30, 15),
	},
}

local cardFrames: { [string]: Frame } = {}
local cardVoteLabels: { [string]: TextLabel } = {}
local cardAvatarContainers: { [string]: Frame } = {}
local cardStrokes: { [string]: UIStroke } = {}

-- Update Avatar Thumbnails & Vote Count Labels
local function updateMapCardAvatars(mapVotes: MapVoteData)
	pcall(function()
		for _, config in ipairs(MAP_CONFIGS) do
			local mId = config.id
			local voterList = mapVotes[mId] or {}
			local container = cardAvatarContainers[mId]
			local voteLabel = cardVoteLabels[mId]

			if voteLabel then
				voteLabel.Text = string.format("🗳️ %d Votes", #voterList)
			end

			if container then
				container:ClearAllChildren()

				local iconSize = 36
				local maxIcons = 5

				for idx, voter in ipairs(voterList) do
					if idx > maxIcons then break end

					local imgLabel = Instance.new("ImageLabel")
					imgLabel.Name = "Voter_" .. tostring(voter.userId or 0)
					imgLabel.Size = UDim2.new(0, 32, 0, 32)
					imgLabel.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
					imgLabel.BorderSizePixel = 0
					imgLabel.ZIndex = 42
					imgLabel.Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(voter.userId or 1) .. "&w=150&h=150"
					imgLabel.Parent = container
					
					local imgCorner = Instance.new("UICorner")
					imgCorner.CornerRadius = UDim.new(1, 0) -- Circle
					imgCorner.Parent = imgLabel

					local imgStroke = Instance.new("UIStroke")
					imgStroke.Color = Color3.fromRGB(0, 240, 255)
					imgStroke.Thickness = 2.0
					imgStroke.Parent = imgLabel
				end
			end
		end
	end)
end

-- Refresh Displays & Modals on Screen
local function refreshDisplays()
	pcall(function()
		local character = LocalPlayer.Character
		local isPlayerInRace = LocalPlayer:GetAttribute("IsRacing") == true

		-- Top Header Banner
		if headerStatusLabel and headerTimerLabel then
			headerStatusLabel.TextColor3 = Color3.fromRGB(40, 180, 255) -- Title Blue per user request
			headerTimerLabel.TextColor3 = Color3.fromRGB(255, 255, 255) -- White per user request

			if currentPhase == "INTERMISSION" then
				headerStatusLabel.Text = "INTERMISSION"
				headerTimerLabel.Text = string.format("%d", math.max(0, phaseTimeLeft))
			elseif currentPhase == "MAP_VOTING" then
				headerStatusLabel.Text = "MAP VOTING"
				headerTimerLabel.Text = string.format("%ds", math.max(0, phaseTimeLeft))
			elseif currentPhase == "MAP_BUILDING" then
				headerStatusLabel.Text = "LOADING MAP..."
				headerTimerLabel.Text = string.format("%ds", math.max(0, phaseTimeLeft))
			elseif currentPhase == "PLAYER_SYNC" then
				headerStatusLabel.Text = "WAITING PLAYERS..."
				headerTimerLabel.Text = string.format("%ds", math.max(0, phaseTimeLeft))
			elseif currentPhase == "RACE_MATCH" then
				if isPlayerInRace then
					headerStatusLabel.Text = "ROUND ENDS IN"
				else
					headerStatusLabel.Text = "ROUND ENDS IN (LOUNGE)"
				end

				local mins = math.floor(math.max(0, phaseTimeLeft) / 60)
				local secs = math.floor(math.max(0, phaseTimeLeft) % 60)
				headerTimerLabel.Text = string.format("%02d:%02d", mins, secs)
			end
		end

		-- Modal 1: 15s Map Voting Modal
		if votingModalFrame then
			if currentPhase == "MAP_VOTING" and not isVotingModalDismissed and not LocalPlayer:GetAttribute("IsAFK") then
				votingModalFrame.Visible = true
			else
				votingModalFrame.Visible = false
			end
		end

		-- Modal 2: 5s Animated Map Loading Screen Modal (and 30s Sync)
		if loadingModalFrame then
			if (currentPhase == "MAP_BUILDING" or currentPhase == "PLAYER_SYNC") and not LocalPlayer:GetAttribute("IsAFK") then
				loadingModalFrame.Visible = true
				if loadingSubLabel then
					if currentPhase == "MAP_BUILDING" then
						loadingSubLabel.Text = string.format("Loading Map (%ds)", math.max(0, phaseTimeLeft))
					else
						loadingSubLabel.Text = string.format("다른 플레이어들을 기다리는 중... (%ds)", math.max(0, phaseTimeLeft))
					end
				end
			else
				loadingModalFrame.Visible = false
			end
		end
	end)
end

-- Create UI Elements
local function createGameLoopUI()
	if mainGuiScreen then mainGuiScreen:Destroy() end

	mainGuiScreen = Instance.new("ScreenGui")
	mainGuiScreen.Name = "GameLoopHUD"
	mainGuiScreen.ResetOnSpawn = false
	mainGuiScreen.DisplayOrder = 20
	mainGuiScreen.Parent = playerGui

	-- [1] TOP CENTER COUNTDOWN HEADER BANNER (Perfect Center Alignment)
	headerBannerFrame = Instance.new("Frame")
	headerBannerFrame.Name = "HeaderBanner"
	headerBannerFrame.Size = UDim2.new(1, 0, 0, 50)
	headerBannerFrame.Position = UDim2.new(0, 0, 0.02, 0)
	headerBannerFrame.BackgroundTransparency = 1
	headerBannerFrame.BorderSizePixel = 0
	headerBannerFrame.ZIndex = 30
	headerBannerFrame.Parent = mainGuiScreen

	local bannerLayout = Instance.new("UIListLayout")
	bannerLayout.Name = "BannerLayout"
	bannerLayout.FillDirection = Enum.FillDirection.Horizontal
	bannerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	bannerLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	bannerLayout.SortOrder = Enum.SortOrder.LayoutOrder
	bannerLayout.Padding = UDim.new(0, 14)
	bannerLayout.Parent = headerBannerFrame

	headerStatusLabel = Instance.new("TextLabel")
	headerStatusLabel.Name = "StatusText"
	headerStatusLabel.Size = UDim2.new(0, 0, 1, 0)
	headerStatusLabel.AutomaticSize = Enum.AutomaticSize.X
	headerStatusLabel.BackgroundTransparency = 1
	headerStatusLabel.Font = Enum.Font.FredokaOne
	headerStatusLabel.Text = "INTERMISSION"
	headerStatusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	headerStatusLabel.TextSize = 38
	headerStatusLabel.TextXAlignment = Enum.TextXAlignment.Center
	headerStatusLabel.TextYAlignment = Enum.TextYAlignment.Center
	headerStatusLabel.LayoutOrder = 1
	headerStatusLabel.ZIndex = 31
	headerStatusLabel.Parent = headerBannerFrame

	local statusStroke = Instance.new("UIStroke")
	statusStroke.Color = Color3.fromRGB(0, 0, 0)
	statusStroke.Thickness = 5
	statusStroke.Parent = headerStatusLabel

	headerTimerLabel = Instance.new("TextLabel")
	headerTimerLabel.Name = "TimerText"
	headerTimerLabel.Size = UDim2.new(0, 0, 1, 0)
	headerTimerLabel.AutomaticSize = Enum.AutomaticSize.X
	headerTimerLabel.BackgroundTransparency = 1
	headerTimerLabel.Font = Enum.Font.FredokaOne
	headerTimerLabel.Text = "15"
	headerTimerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	headerTimerLabel.TextSize = 38
	headerTimerLabel.TextXAlignment = Enum.TextXAlignment.Center
	headerTimerLabel.TextYAlignment = Enum.TextYAlignment.Center
	headerTimerLabel.LayoutOrder = 2
	headerTimerLabel.ZIndex = 31
	headerTimerLabel.Parent = headerBannerFrame

	local timerStroke = Instance.new("UIStroke")
	timerStroke.Color = Color3.fromRGB(0, 0, 0)
	timerStroke.Thickness = 5
	timerStroke.Parent = headerTimerLabel

	-- [2] 3-CARD MAP VOTING MODAL UI (15s)
	votingModalFrame = Instance.new("Frame")
	votingModalFrame.Name = "VotingModal"
	votingModalFrame.Size = UDim2.new(0, 780, 0, 390)
	votingModalFrame.Position = UDim2.new(0.5, -390, 0.5, -195)
	votingModalFrame.BackgroundColor3 = Color3.fromRGB(150, 240, 255) -- Cyan Glass
	votingModalFrame.BackgroundTransparency = 0.5
	votingModalFrame.BorderSizePixel = 0
	votingModalFrame.Visible = true
	votingModalFrame.ZIndex = 35
	votingModalFrame.Parent = mainGuiScreen

	local modalCorner = Instance.new("UICorner")
	modalCorner.CornerRadius = UDim.new(0, 24)
	modalCorner.Parent = votingModalFrame

	local modalStroke = Instance.new("UIStroke")
	modalStroke.Color = Color3.fromRGB(0, 0, 0)
	modalStroke.Thickness = 8
	modalStroke.Parent = votingModalFrame

	local titleFrame = Instance.new("Frame")
	titleFrame.Name = "TitleFrame"
	titleFrame.Size = UDim2.new(1, -60, 0, 60)
	titleFrame.Position = UDim2.new(0, 30, 0, 20)
	titleFrame.BackgroundColor3 = Color3.fromRGB(40, 180, 255)
	titleFrame.BorderSizePixel = 0
	titleFrame.ZIndex = 36
	titleFrame.Parent = votingModalFrame
	
	local titleCorner = Instance.new("UICorner")
	titleCorner.CornerRadius = UDim.new(0.5, 0)
	titleCorner.Parent = titleFrame
	
	local titleStroke = Instance.new("UIStroke")
	titleStroke.Color = Color3.fromRGB(0, 0, 0)
	titleStroke.Thickness = 6
	titleStroke.Parent = titleFrame

	local modalTitle = Instance.new("TextLabel")
	modalTitle.Name = "ModalTitle"
	modalTitle.Size = UDim2.new(1, 0, 1, 0)
	modalTitle.BackgroundTransparency = 1
	modalTitle.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	modalTitle.Text = "SELECT NEXT MAP"
	modalTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
	modalTitle.TextSize = 32
	modalTitle.ZIndex = 37
	modalTitle.Parent = titleFrame
	
	local titleTextStroke = Instance.new("UIStroke")
	titleTextStroke.Color = Color3.fromRGB(0, 0, 0)
	titleTextStroke.Thickness = 3
	titleTextStroke.Parent = modalTitle

	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseButton"
	closeBtn.Size = UDim2.new(0, 44, 0, 44)
	closeBtn.Position = UDim2.new(1, -22, 0, -22)
	closeBtn.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
	closeBtn.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	closeBtn.Text = "X"
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.TextSize = 28
	closeBtn.ZIndex = 40
	closeBtn.Parent = votingModalFrame
	
	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(1, 0)
	closeCorner.Parent = closeBtn
	
	local closeStroke = Instance.new("UIStroke")
	closeStroke.Color = Color3.fromRGB(0, 0, 0)
	closeStroke.Thickness = 4
	closeStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	closeStroke.Parent = closeBtn
	
	closeBtn.MouseButton1Click:Connect(function()
		isVotingModalDismissed = true
		refreshDisplays()
	end)

	local cardContainer = Instance.new("Frame")
	cardContainer.Name = "CardContainer"
	cardContainer.Size = UDim2.new(1, -30, 0, 260)
	cardContainer.Position = UDim2.new(0, 15, 0, 100)
	cardContainer.BackgroundTransparency = 1
	cardContainer.ZIndex = 36
	cardContainer.Parent = votingModalFrame

	for idx, config in ipairs(MAP_CONFIGS) do
		local card = Instance.new("Frame")
		card.Name = "MapCard_" .. config.id
		card.Size = UDim2.new(0, 235, 1, 0)
		card.Position = UDim2.new(0, (idx - 1) * 255, 0, 0)
		card.BackgroundColor3 = config.color -- Using brighter theme color
		card.BorderSizePixel = 0
		card.ZIndex = 37
		card.Parent = cardContainer

		local cCorner = Instance.new("UICorner")
		cCorner.CornerRadius = UDim.new(0, 16)
		cCorner.Parent = card

		local cStroke = Instance.new("UIStroke")
		cStroke.Color = Color3.fromRGB(0, 0, 0)
		cStroke.Thickness = 4
		cStroke.Transparency = 0
		cStroke.Parent = card
		cardStrokes[config.id] = cStroke

		-- UIGradient stripes for card background
		local patternBg = Instance.new("Frame", card)
		patternBg.Size = UDim2.new(1, 0, 1, 0)
		patternBg.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		patternBg.BorderSizePixel = 0
		patternBg.ZIndex = 37
		Instance.new("UICorner", patternBg).CornerRadius = UDim.new(0, 16)
		local grad = Instance.new("UIGradient", patternBg)
		grad.Rotation = 45
		local keypoints = {}
		table.insert(keypoints, NumberSequenceKeypoint.new(0, 0.85))
		for i = 1, 9 do
			local pos = i / 10
			if i % 2 == 1 then
				table.insert(keypoints, NumberSequenceKeypoint.new(pos, 0.85))
				table.insert(keypoints, NumberSequenceKeypoint.new(pos + 0.001, 1))
			else
				table.insert(keypoints, NumberSequenceKeypoint.new(pos, 1))
				table.insert(keypoints, NumberSequenceKeypoint.new(pos + 0.001, 0.85))
			end
		end
		table.insert(keypoints, NumberSequenceKeypoint.new(1, 1))
		grad.Transparency = NumberSequence.new(keypoints)

		local mapImage = Instance.new("ImageLabel")
		mapImage.Name = "MapImage"
		mapImage.Size = UDim2.new(1, -20, 0, 120)
		mapImage.Position = UDim2.new(0, 10, 0, 15)
		mapImage.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
		mapImage.Image = config.imageId or ""
		mapImage.ScaleType = Enum.ScaleType.Crop
		mapImage.BorderSizePixel = 0
		mapImage.ZIndex = 38
		mapImage.Parent = card
		
		local imgCorner = Instance.new("UICorner")
		imgCorner.CornerRadius = UDim.new(0, 12)
		imgCorner.Parent = mapImage
		
		local imgStroke = Instance.new("UIStroke")
		imgStroke.Color = Color3.fromRGB(0, 0, 0)
		imgStroke.Thickness = 3
		imgStroke.Parent = mapImage

		local avatarFrame = Instance.new("Frame")
		avatarFrame.Name = "AvatarContainer"
		avatarFrame.Size = UDim2.new(1, -10, 1, -10)
		avatarFrame.Position = UDim2.new(0, 5, 0, 5)
		avatarFrame.BackgroundTransparency = 1
		avatarFrame.ZIndex = 39
		avatarFrame.Parent = mapImage
		cardAvatarContainers[config.id] = avatarFrame
		
		local avatarLayout = Instance.new("UIGridLayout")
		avatarLayout.CellSize = UDim2.new(0, 32, 0, 32)
		avatarLayout.CellPadding = UDim2.new(0, 5, 0, 5)
		avatarLayout.SortOrder = Enum.SortOrder.LayoutOrder
		avatarLayout.Parent = avatarFrame

		local mapTitleLabel = Instance.new("TextLabel")
		mapTitleLabel.Size = UDim2.new(1, -20, 0, 30)
		mapTitleLabel.Position = UDim2.new(0, 10, 0, 145)
		mapTitleLabel.BackgroundTransparency = 1
		mapTitleLabel.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
		mapTitleLabel.Text = config.title
		mapTitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		mapTitleLabel.TextSize = 20
		mapTitleLabel.ZIndex = 39
		mapTitleLabel.Parent = card
		
		local mapTitleStroke = Instance.new("UIStroke")
		mapTitleStroke.Color = Color3.fromRGB(0, 0, 0)
		mapTitleStroke.Thickness = 3
		mapTitleStroke.Parent = mapTitleLabel

		local mapSubLabel = Instance.new("TextLabel")
		mapSubLabel.Size = UDim2.new(1, -20, 0, 20)
		mapSubLabel.Position = UDim2.new(0, 10, 0, 180)
		mapSubLabel.BackgroundTransparency = 1
		mapSubLabel.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
		mapSubLabel.Text = config.sub
		mapSubLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		mapSubLabel.TextSize = 14
		mapSubLabel.ZIndex = 39
		mapSubLabel.Parent = card
		
		local mapSubStroke = Instance.new("UIStroke")
		mapSubStroke.Color = Color3.fromRGB(0, 0, 0)
		mapSubStroke.Thickness = 2
		mapSubStroke.Parent = mapSubLabel

		local vLabel = Instance.new("TextLabel")
		vLabel.Size = UDim2.new(1, -20, 0, 30)
		vLabel.Position = UDim2.new(0, 10, 0, 215)
		vLabel.BackgroundTransparency = 1
		vLabel.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
		vLabel.Text = "🗳️ 0 Votes"
		vLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
		vLabel.TextSize = 18
		vLabel.ZIndex = 38
		vLabel.Parent = card
		
		local vStroke = Instance.new("UIStroke")
		vStroke.Color = Color3.fromRGB(0, 0, 0)
		vStroke.Thickness = 3
		vStroke.Parent = vLabel
		cardVoteLabels[config.id] = vLabel

		local clickBtn = Instance.new("TextButton")
		clickBtn.Size = UDim2.new(1, 0, 1, 0)
		clickBtn.BackgroundTransparency = 1
		clickBtn.Text = ""
		clickBtn.ZIndex = 45
		clickBtn.Parent = card

		clickBtn.MouseButton1Click:Connect(function()
			selectedMapName = config.id

			-- Local Optimistic Vote Update
			for mId, voterList in pairs(currentMapVotes) do
				for i = #voterList, 1, -1 do
					if voterList[i].userId == LocalPlayer.UserId then
						table.remove(voterList, i)
					end
				end
			end

			if not currentMapVotes[config.id] then
				currentMapVotes[config.id] = {}
			end
			table.insert(currentMapVotes[config.id], {
				userId = LocalPlayer.UserId,
				name = LocalPlayer.DisplayName or LocalPlayer.Name,
			})

			for mId, stroke in pairs(cardStrokes) do
				if mId == config.id then
					stroke.Color = Color3.fromRGB(255, 200, 50) -- Gold for selected
					stroke.Thickness = 8
					stroke.Transparency = 0.0
				else
					stroke.Color = Color3.fromRGB(0, 0, 0)
					stroke.Thickness = 4
					stroke.Transparency = 0.0
				end
			end

			updateMapCardAvatars(currentMapVotes)
			voteRemote:FireServer(config.id)
		end)

		cardFrames[config.id] = card
	end

	-- =========================================================================
	-- 🏗️ [3] MAP LOADING / SYNC TEXT UI
	-- =========================================================================
	loadingModalFrame = Instance.new("Frame")
	loadingModalFrame.Name = "LoadingModal"
	loadingModalFrame.Size = UDim2.new(1, 0, 0, 100)
	loadingModalFrame.Position = UDim2.new(0, 0, 0.35, 0)
	loadingModalFrame.BackgroundTransparency = 1
	loadingModalFrame.BorderSizePixel = 0
	loadingModalFrame.Visible = false
	loadingModalFrame.ZIndex = 50
	loadingModalFrame.Parent = mainGuiScreen

	loadingSubLabel = Instance.new("TextLabel")
	loadingSubLabel.Name = "LoadingSub"
	loadingSubLabel.Size = UDim2.new(1, 0, 1, 0)
	loadingSubLabel.BackgroundTransparency = 1
	loadingSubLabel.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	loadingSubLabel.Text = "다른 플레이어들을 기다리는 중... (30s)"
	loadingSubLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	loadingSubLabel.TextSize = 42
	loadingSubLabel.ZIndex = 51
	loadingSubLabel.Parent = loadingModalFrame
	
	local loadSubStroke = Instance.new("UIStroke")
	loadSubStroke.Color = Color3.fromRGB(0, 0, 0)
	loadSubStroke.Thickness = 5
	loadSubStroke.Parent = loadingSubLabel
	
	-- =========================================================================
	-- 🚨 [4] ERROR POPUP MODAL (Timeout Kick)
	-- =========================================================================
	errorModalFrame = Instance.new("Frame")
	errorModalFrame.Name = "ErrorModal"
	errorModalFrame.Size = UDim2.new(0, 500, 0, 220)
	errorModalFrame.Position = UDim2.new(0.5, -250, 0.5, -110)
	errorModalFrame.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
	errorModalFrame.BackgroundTransparency = 0.1
	errorModalFrame.BorderSizePixel = 0
	errorModalFrame.Visible = false
	errorModalFrame.ZIndex = 60
	errorModalFrame.Parent = mainGuiScreen

	local eCorner = Instance.new("UICorner")
	eCorner.CornerRadius = UDim.new(0, 20)
	eCorner.Parent = errorModalFrame

	local eStroke = Instance.new("UIStroke")
	eStroke.Color = Color3.fromRGB(0, 0, 0)
	eStroke.Thickness = 6
	eStroke.Parent = errorModalFrame
	
	local errorTitle = Instance.new("TextLabel")
	errorTitle.Size = UDim2.new(1, 0, 0, 50)
	errorTitle.Position = UDim2.new(0, 0, 0, 15)
	errorTitle.BackgroundTransparency = 1
	errorTitle.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	errorTitle.Text = "⚠️ CONNECTION ERROR"
	errorTitle.TextColor3 = Color3.fromRGB(255, 200, 50)
	errorTitle.TextSize = 28
	errorTitle.ZIndex = 61
	errorTitle.Parent = errorModalFrame
	
	local errTitleStroke = Instance.new("UIStroke")
	errTitleStroke.Color = Color3.fromRGB(0, 0, 0)
	errTitleStroke.Thickness = 3
	errTitleStroke.Parent = errorTitle

	local errorMsg = Instance.new("TextLabel")
	errorMsg.Size = UDim2.new(1, -40, 0, 60)
	errorMsg.Position = UDim2.new(0, 20, 0, 65)
	errorMsg.BackgroundTransparency = 1
	errorMsg.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	errorMsg.Text = "네트워크 지연으로 인해 게임 참여에 실패했습니다."
	errorMsg.TextColor3 = Color3.fromRGB(255, 255, 255)
	errorMsg.TextSize = 20
	errorMsg.TextWrapped = true
	errorMsg.ZIndex = 61
	errorMsg.Parent = errorModalFrame
	
	local errMsgStroke = Instance.new("UIStroke")
	errMsgStroke.Color = Color3.fromRGB(0, 0, 0)
	errMsgStroke.Thickness = 2
	errMsgStroke.Parent = errorMsg
	
	local errOkBtn = Instance.new("TextButton")
	errOkBtn.Size = UDim2.new(0, 140, 0, 45)
	errOkBtn.Position = UDim2.new(0.5, -70, 0, 145)
	errOkBtn.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
	errOkBtn.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	errOkBtn.Text = "OK"
	errOkBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
	errOkBtn.TextSize = 24
	errOkBtn.ZIndex = 62
	errOkBtn.Parent = errorModalFrame
	
	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 12)
	btnCorner.Parent = errOkBtn
	
	local btnStroke = Instance.new("UIStroke")
	btnStroke.Color = Color3.fromRGB(0, 0, 0)
	btnStroke.Thickness = 3
	btnStroke.Parent = errOkBtn
	
	errOkBtn.MouseButton1Click:Connect(function()
		errorModalFrame.Visible = false
	end)
end

createGameLoopUI()
updateMapCardAvatars(currentMapVotes)
refreshDisplays()

-- Local Smooth Timer Countdown Loop
task.spawn(function()
	while true do
		task.wait(1)
		if phaseTimeLeft > 0 then
			phaseTimeLeft -= 1
			refreshDisplays()
		end
	end
end)

-- Server Remote Phase Listener
phaseRemote.OnClientEvent:Connect(function(phase: string, timeLeft: number, mapVotes: MapVoteData, chosenMap: string?)
	if phase == "MAP_VOTING" and currentPhase ~= "MAP_VOTING" then
		isVotingModalDismissed = false
	end
	
	if phase ~= currentPhase and (phase == "MAP_VOTING" or phase == "MAP_BUILDING" or phase == "PLAYER_SYNC") then
		-- 이전 숨김 로직 제거: 이제 UIManager.client.lua가 IsRacing 속성 등을 기반으로 일괄 관리합니다.
	end
	
	if phase == "PLAYER_SYNC" and currentPhase ~= "PLAYER_SYNC" then
		task.spawn(function()
			print("[DEBUG-SYNC-CLIENT] PLAYER_SYNC Phase received at", os.clock())
			print("⏳ [Sync] Map building started. Waiting for ActiveMap to replicate...")
			local activeMap = game.Workspace:WaitForChild("ActiveMap", 10)
			if activeMap then
				print("[DEBUG-SYNC-CLIENT] ActiveMap replicated at", os.clock())
				-- 깨진 사운드/텍스쳐로 인한 무한 렉(PreloadAsync 40초 지연 문제)을 방지하기 위해 
				-- 전체 프리로드 대신 트랙의 물리적 파트(출발선)만 생성되었는지 빠르게 확인합니다.
				print("⏳ [Sync] ActiveMap found! Waiting for track physical parts...")
				local startTick = os.clock()
				activeMap:WaitForChild("StartingPoint", 5)
				print("[DEBUG-SYNC-CLIENT] StartingPoint replicated at", os.clock())
				
				print("⏳ [Sync] Waiting for character and hoverboard to be ready...")
				local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
				character:WaitForChild("EquippedHoverboard", 10)
				
				-- 카메라 및 물리 안정화(텔레포트 후 자리잡기) 대기
				task.wait(1.5)
				
				print(string.format("✅ [Sync] Track structure and character confirmed in %.2f seconds. Notifying server...", os.clock() - startTick))
			else
				print("⚠️ [Sync] ActiveMap not found within 10 seconds.")
			end
			local clientMapLoadedRemote = remotesFolder:WaitForChild("ClientMapLoaded", 5)
			if clientMapLoadedRemote then
				print("[DEBUG-SYNC-CLIENT] Firing ClientMapLoaded at", os.clock())
				clientMapLoadedRemote:FireServer()
			end
		end)
	end
	
	currentPhase = phase
	phaseTimeLeft = timeLeft
	if mapVotes then
		currentMapVotes = mapVotes
	end
	if chosenMap then
		currentChosenMap = chosenMap
	end

	refreshDisplays()
	updateMapCardAvatars(currentMapVotes)
end)

local syncTimeoutRemote = remotesFolder:WaitForChild("SyncTimeoutError", 10)
if syncTimeoutRemote then
	syncTimeoutRemote.OnClientEvent:Connect(function()
		if errorModalFrame then
			errorModalFrame.Visible = true
		end
	end)
end

print("⏱️ [GameLoopController] 5초 애니메이션 맵 로딩 스크린 연출 완료!")
