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
			if currentPhase == "INTERMISSION" then
				headerStatusLabel.Text = "INTERMISSION"
				headerStatusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
				headerTimerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
				headerTimerLabel.Text = string.format("%d", math.max(0, phaseTimeLeft))
			elseif currentPhase == "MAP_VOTING" then
				headerStatusLabel.Text = "MAP VOTING"
				headerStatusLabel.TextColor3 = Color3.fromRGB(255, 220, 80)
				headerTimerLabel.Text = string.format("%ds", math.max(0, phaseTimeLeft))
			elseif currentPhase == "MAP_BUILDING" then
				headerStatusLabel.Text = "LOADING MAP..."
				headerStatusLabel.TextColor3 = Color3.fromRGB(80, 220, 255)
				headerTimerLabel.Text = string.format("%ds", math.max(0, phaseTimeLeft))
			elseif currentPhase == "RACE_MATCH" then
				if isPlayerInRace then
					headerStatusLabel.Text = "ROUND ENDS IN"
					headerStatusLabel.TextColor3 = Color3.fromRGB(0, 240, 255)
				else
					headerStatusLabel.Text = "ROUND ENDS IN (LOUNGE)"
					headerStatusLabel.TextColor3 = Color3.fromRGB(255, 190, 80)
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

		-- Modal 2: 5s Animated Map Loading Screen Modal
		if loadingModalFrame then
			if currentPhase == "MAP_BUILDING" and not LocalPlayer:GetAttribute("IsAFK") then
				loadingModalFrame.Visible = true
				if loadingTitleLabel then
					loadingTitleLabel.Text = "🏆 SELECTED MAP: " .. currentChosenMap
				end
				if loadingSubLabel then
					loadingSubLabel.Text = string.format("Loading Map (%ds)", math.max(0, phaseTimeLeft))
				end

				if loadingFillBar and loadingPercentLabel then
					local pct = math.clamp((5 - phaseTimeLeft) / 5, 0.1, 1)
					loadingFillBar.Size = UDim2.new(pct, 0, 1, 0)
					loadingPercentLabel.Text = string.format("%d%%", math.floor(pct * 100))
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

	-- [1] TOP CENTER COUNTDOWN HEADER BANNER
	headerBannerFrame = Instance.new("Frame")
	headerBannerFrame.Name = "HeaderBanner"
	headerBannerFrame.Size = UDim2.new(0, 380, 0, 42)
	headerBannerFrame.Position = UDim2.new(0.5, -190, 0.02, 0)
	headerBannerFrame.BackgroundColor3 = Color3.fromRGB(12, 16, 26)
	headerBannerFrame.BackgroundTransparency = 1
	headerBannerFrame.BorderSizePixel = 0
	headerBannerFrame.ZIndex = 30
	headerBannerFrame.Parent = mainGuiScreen

	local bannerCorner = Instance.new("UICorner")
	bannerCorner.CornerRadius = UDim.new(0, 10)
	bannerCorner.Parent = headerBannerFrame

	local bannerStroke = Instance.new("UIStroke")
	bannerStroke.Color = Color3.fromRGB(0, 230, 255)
	bannerStroke.Thickness = 2.0
	bannerStroke.Transparency = 1
	bannerStroke.Parent = headerBannerFrame

	headerStatusLabel = Instance.new("TextLabel")
	headerStatusLabel.Name = "StatusText"
	headerStatusLabel.Size = UDim2.new(0.5, -10, 1, 0)
	headerStatusLabel.Position = UDim2.new(0, 0, 0, 0)
	headerStatusLabel.BackgroundTransparency = 1
	headerStatusLabel.Font = Enum.Font.FredokaOne
	headerStatusLabel.Text = "INTERMISSION"
	headerStatusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	headerStatusLabel.TextSize = 40
	headerStatusLabel.TextXAlignment = Enum.TextXAlignment.Right
	headerStatusLabel.ZIndex = 31
	headerStatusLabel.Parent = headerBannerFrame

	local statusStroke = Instance.new("UIStroke")
	statusStroke.Color = Color3.fromRGB(0, 0, 0)
	statusStroke.Thickness = 6
	statusStroke.Parent = headerStatusLabel

	headerTimerLabel = Instance.new("TextLabel")
	headerTimerLabel.Name = "TimerText"
	headerTimerLabel.Size = UDim2.new(0.5, -10, 1, 0)
	headerTimerLabel.Position = UDim2.new(0.5, 10, 0, 0)
	headerTimerLabel.BackgroundTransparency = 1
	headerTimerLabel.Font = Enum.Font.FredokaOne
	headerTimerLabel.Text = "15"
	headerTimerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	headerTimerLabel.TextSize = 40
	headerTimerLabel.TextXAlignment = Enum.TextXAlignment.Left
	headerTimerLabel.ZIndex = 31
	headerTimerLabel.Parent = headerBannerFrame

	local timerStroke = Instance.new("UIStroke")
	timerStroke.Color = Color3.fromRGB(0, 0, 0)
	timerStroke.Thickness = 6
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
	-- 🏗️ [3] 5-SECOND ANIMATED MAP LOADING SCREEN MODAL UI
	-- =========================================================================
	loadingModalFrame = Instance.new("Frame")
	loadingModalFrame.Name = "LoadingModal"
	loadingModalFrame.Size = UDim2.new(0, 540, 0, 210)
	loadingModalFrame.Position = UDim2.new(0.5, -270, 0.5, -105)
	loadingModalFrame.BackgroundColor3 = Color3.fromRGB(150, 240, 255)
	loadingModalFrame.BackgroundTransparency = 0.5
	loadingModalFrame.BorderSizePixel = 0
	loadingModalFrame.Visible = false
	loadingModalFrame.ZIndex = 50
	loadingModalFrame.Parent = mainGuiScreen

	local lCorner = Instance.new("UICorner")
	lCorner.CornerRadius = UDim.new(0, 24)
	lCorner.Parent = loadingModalFrame

	local lStroke = Instance.new("UIStroke")
	lStroke.Color = Color3.fromRGB(0, 0, 0)
	lStroke.Thickness = 8
	lStroke.Parent = loadingModalFrame

	loadingTitleLabel = Instance.new("TextLabel")
	loadingTitleLabel.Name = "LoadingTitle"
	loadingTitleLabel.Size = UDim2.new(1, -20, 0, 45)
	loadingTitleLabel.Position = UDim2.new(0, 10, 0, 30)
	loadingTitleLabel.BackgroundTransparency = 1
	loadingTitleLabel.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	loadingTitleLabel.Text = "🏆 SELECTED MAP: Oval Speedway"
	loadingTitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	loadingTitleLabel.TextSize = 28
	loadingTitleLabel.ZIndex = 51
	loadingTitleLabel.Parent = loadingModalFrame
	
	local loadTitleStroke = Instance.new("UIStroke")
	loadTitleStroke.Color = Color3.fromRGB(0, 0, 0)
	loadTitleStroke.Thickness = 4
	loadTitleStroke.Parent = loadingTitleLabel

	loadingSubLabel = Instance.new("TextLabel")
	loadingSubLabel.Name = "LoadingSub"
	loadingSubLabel.Size = UDim2.new(1, -20, 0, 25)
	loadingSubLabel.Position = UDim2.new(0, 10, 0, 75)
	loadingSubLabel.BackgroundTransparency = 1
	loadingSubLabel.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	loadingSubLabel.Text = "Loading Map (5s)"
	loadingSubLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	loadingSubLabel.TextSize = 18
	loadingSubLabel.ZIndex = 51
	loadingSubLabel.Parent = loadingModalFrame
	
	local loadSubStroke = Instance.new("UIStroke")
	loadSubStroke.Color = Color3.fromRGB(0, 0, 0)
	loadSubStroke.Thickness = 3
	loadSubStroke.Parent = loadingSubLabel

	-- Loading Progress Bar Track
	local loadTrack = Instance.new("Frame")
	loadTrack.Name = "LoadTrack"
	loadTrack.Size = UDim2.new(0.86, 0, 0, 36)
	loadTrack.Position = UDim2.new(0.07, 0, 0.62, 0)
	loadTrack.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	loadTrack.BorderSizePixel = 0
	loadTrack.ZIndex = 51
	loadTrack.Parent = loadingModalFrame

	local tCorner = Instance.new("UICorner")
	tCorner.CornerRadius = UDim.new(0, 18)
	tCorner.Parent = loadTrack

	local tStroke = Instance.new("UIStroke")
	tStroke.Color = Color3.fromRGB(0, 0, 0)
	tStroke.Thickness = 4
	tStroke.Parent = loadTrack

	loadingFillBar = Instance.new("Frame")
	loadingFillBar.Name = "LoadFill"
	loadingFillBar.Size = UDim2.new(0, 0, 1, 0)
	loadingFillBar.BackgroundColor3 = Color3.fromRGB(255, 200, 50) -- Gold fill
	loadingFillBar.BorderSizePixel = 0
	loadingFillBar.ZIndex = 52
	loadingFillBar.Parent = loadTrack

	local fCorner = Instance.new("UICorner")
	fCorner.CornerRadius = UDim.new(0, 18)
	fCorner.Parent = loadingFillBar

	loadingPercentLabel = Instance.new("TextLabel")
	loadingPercentLabel.Name = "LoadPercent"
	loadingPercentLabel.Size = UDim2.new(1, 0, 1, 0)
	loadingPercentLabel.BackgroundTransparency = 1
	loadingPercentLabel.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	loadingPercentLabel.Text = "0%"
	loadingPercentLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	loadingPercentLabel.TextSize = 18
	loadingPercentLabel.ZIndex = 53
	loadingPercentLabel.Parent = loadTrack
	
	local pctStroke = Instance.new("UIStroke")
	pctStroke.Color = Color3.fromRGB(0, 0, 0)
	pctStroke.Thickness = 3
	pctStroke.Parent = loadingPercentLabel
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
	
	if phase ~= currentPhase and (phase == "MAP_VOTING" or phase == "MAP_BUILDING") then
		-- 이전 숨김 로직 제거: 이제 UIManager.client.lua가 IsRacing 속성 등을 기반으로 일괄 관리합니다.
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

print("⏱️ [GameLoopController] 5초 애니메이션 맵 로딩 스크린 연출 완료!")
