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

local currentPhase = "MAP_VOTING"
local phaseTimeLeft = 15
local currentChosenMap = "Oval Speedway"
local currentMapVotes: MapVoteData = {
	["Oval Speedway"] = {},
	["Cyber City"] = {},
	["Magma Ridge"] = {},
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
		id = "Cyber City",
		title = "⚡ Cyber City",
		sub = "Futuristic Highway",
		color = Color3.fromRGB(220, 80, 255),
		bgGrad = Color3.fromRGB(55, 15, 75),
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
					imgLabel.Size = UDim2.new(0, iconSize, 0, iconSize)
					imgLabel.Position = UDim2.new(0, (idx - 1) * (iconSize + 5), 0, 4)
					imgLabel.BackgroundColor3 = Color3.fromRGB(30, 40, 60)
					imgLabel.BackgroundTransparency = 0.2
					imgLabel.Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(voter.userId or 1) .. "&w=150&h=150"
					imgLabel.ZIndex = 40
					imgLabel.Parent = container

					local imgCorner = Instance.new("UICorner")
					imgCorner.CornerRadius = UDim.new(1, 0)
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
		local boardModel = character and character:FindFirstChild("EquippedHoverboard")
		local isPlayerInRace = (boardModel ~= nil)

		-- Top Header Banner
		if headerStatusLabel and headerTimerLabel then
			if currentPhase == "INTERMISSION" then
				headerStatusLabel.Text = "🛋️ NEXT RACE IN..."
				headerStatusLabel.TextColor3 = Color3.fromRGB(255, 190, 80)
				headerTimerLabel.Text = string.format("%ds", math.max(0, phaseTimeLeft))
			elseif currentPhase == "MAP_VOTING" then
				headerStatusLabel.Text = "🗳️ MAP VOTING"
				headerStatusLabel.TextColor3 = Color3.fromRGB(255, 220, 80)
				headerTimerLabel.Text = string.format("%ds", math.max(0, phaseTimeLeft))
			elseif currentPhase == "MAP_BUILDING" then
				headerStatusLabel.Text = "🏗️ LOADING MAP..."
				headerStatusLabel.TextColor3 = Color3.fromRGB(80, 220, 255)
				headerTimerLabel.Text = string.format("%ds", math.max(0, phaseTimeLeft))
			elseif currentPhase == "RACE_MATCH" then
				if isPlayerInRace then
					headerStatusLabel.Text = "🏁 RACE IN PROGRESS"
					headerStatusLabel.TextColor3 = Color3.fromRGB(0, 240, 255)
				else
					headerStatusLabel.Text = "🛋️ IN LOUNGE (WAITING RACE)"
					headerStatusLabel.TextColor3 = Color3.fromRGB(255, 190, 80)
				end

				local mins = math.floor(math.max(0, phaseTimeLeft) / 60)
				local secs = math.floor(math.max(0, phaseTimeLeft) % 60)
				headerTimerLabel.Text = string.format("%02d:%02d", mins, secs)
			end
		end

		-- Modal 1: 15s Map Voting Modal
		if votingModalFrame then
			if currentPhase == "MAP_VOTING" and not isVotingModalDismissed then
				votingModalFrame.Visible = true
				if modalFooterTimerLabel then
					modalFooterTimerLabel.Text = string.format("⏱️ Time Remaining: %ds", math.max(0, phaseTimeLeft))
				end
			else
				votingModalFrame.Visible = false
			end
		end

		-- Modal 2: 5s Animated Map Loading Screen Modal
		if loadingModalFrame then
			if currentPhase == "MAP_BUILDING" then
				loadingModalFrame.Visible = true
				if loadingTitleLabel then
					loadingTitleLabel.Text = "🏆 SELECTED MAP: " .. currentChosenMap
				end
				if loadingSubLabel then
					loadingSubLabel.Text = string.format("Building Map & Preparing Starting Grid... (%ds)", math.max(0, phaseTimeLeft))
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
	headerBannerFrame.BackgroundTransparency = 0.1
	headerBannerFrame.BorderSizePixel = 0
	headerBannerFrame.ZIndex = 30
	headerBannerFrame.Parent = mainGuiScreen

	local bannerCorner = Instance.new("UICorner")
	bannerCorner.CornerRadius = UDim.new(0, 10)
	bannerCorner.Parent = headerBannerFrame

	local bannerStroke = Instance.new("UIStroke")
	bannerStroke.Color = Color3.fromRGB(0, 230, 255)
	bannerStroke.Thickness = 2.0
	bannerStroke.Transparency = 0.1
	bannerStroke.Parent = headerBannerFrame

	headerStatusLabel = Instance.new("TextLabel")
	headerStatusLabel.Name = "StatusText"
	headerStatusLabel.Size = UDim2.new(0.68, 0, 1, 0)
	headerStatusLabel.Position = UDim2.new(0.04, 0, 0, 0)
	headerStatusLabel.BackgroundTransparency = 1
	headerStatusLabel.Font = Enum.Font.GothamBlack
	headerStatusLabel.Text = "🗳️ MAP VOTING"
	headerStatusLabel.TextColor3 = Color3.fromRGB(255, 230, 120)
	headerStatusLabel.TextSize = 13
	headerStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
	headerStatusLabel.ZIndex = 31
	headerStatusLabel.Parent = headerBannerFrame

	local statusStroke = Instance.new("UIStroke")
	statusStroke.Color = Color3.fromRGB(0, 0, 0)
	statusStroke.Thickness = 1.5
	statusStroke.Parent = headerStatusLabel

	headerTimerLabel = Instance.new("TextLabel")
	headerTimerLabel.Name = "TimerText"
	headerTimerLabel.Size = UDim2.new(0.28, 0, 1, 0)
	headerTimerLabel.Position = UDim2.new(0.68, 0, 0, 0)
	headerTimerLabel.BackgroundTransparency = 1
	headerTimerLabel.Font = Enum.Font.GothamBlack
	headerTimerLabel.Text = "15s"
	headerTimerLabel.TextColor3 = Color3.fromRGB(0, 240, 255)
	headerTimerLabel.TextSize = 16
	headerTimerLabel.TextXAlignment = Enum.TextXAlignment.Right
	headerTimerLabel.ZIndex = 31
	headerTimerLabel.Parent = headerBannerFrame

	local timerStroke = Instance.new("UIStroke")
	timerStroke.Color = Color3.fromRGB(0, 0, 0)
	timerStroke.Thickness = 1.5
	timerStroke.Parent = headerTimerLabel

	-- [2] 3-CARD MAP VOTING MODAL UI (15s)
	votingModalFrame = Instance.new("Frame")
	votingModalFrame.Name = "VotingModal"
	votingModalFrame.Size = UDim2.new(0, 780, 0, 370)
	votingModalFrame.Position = UDim2.new(0.5, -390, 0.5, -185)
	votingModalFrame.BackgroundColor3 = Color3.fromRGB(14, 18, 28)
	votingModalFrame.BackgroundTransparency = 0.05
	votingModalFrame.BorderSizePixel = 0
	votingModalFrame.Visible = true
	votingModalFrame.ZIndex = 35
	votingModalFrame.Parent = mainGuiScreen

	local modalCorner = Instance.new("UICorner")
	modalCorner.CornerRadius = UDim.new(0, 16)
	modalCorner.Parent = votingModalFrame

	local modalStroke = Instance.new("UIStroke")
	modalStroke.Color = Color3.fromRGB(255, 200, 30)
	modalStroke.Thickness = 2.5
	modalStroke.Parent = votingModalFrame

	local modalTitle = Instance.new("TextLabel")
	modalTitle.Name = "ModalTitle"
	modalTitle.Size = UDim2.new(1, 0, 0, 40)
	modalTitle.Position = UDim2.new(0, 0, 0, 10)
	modalTitle.BackgroundTransparency = 1
	modalTitle.Font = Enum.Font.GothamBlack
	modalTitle.Text = "🗳️ SELECT NEXT MAP"
	modalTitle.TextColor3 = Color3.fromRGB(255, 215, 0)
	modalTitle.TextSize = 20
	modalTitle.ZIndex = 36
	modalTitle.Parent = votingModalFrame

	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseButton"
	closeBtn.Size = UDim2.new(0, 30, 0, 30)
	closeBtn.Position = UDim2.new(1, -40, 0, 10)
	closeBtn.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.Text = "X"
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.TextSize = 16
	closeBtn.ZIndex = 40
	closeBtn.Parent = votingModalFrame
	
	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 8)
	closeCorner.Parent = closeBtn
	
	closeBtn.MouseButton1Click:Connect(function()
		isVotingModalDismissed = true
		refreshDisplays()
	end)

	modalFooterTimerLabel = Instance.new("TextLabel")
	modalFooterTimerLabel.Name = "ModalTimerLabel"
	modalFooterTimerLabel.Size = UDim2.new(1, 0, 0, 24)
	modalFooterTimerLabel.Position = UDim2.new(0, 0, 0.89, 0)
	modalFooterTimerLabel.BackgroundTransparency = 1
	modalFooterTimerLabel.Font = Enum.Font.GothamBold
	modalFooterTimerLabel.Text = "⏱️ Time Remaining: 15s"
	modalFooterTimerLabel.TextColor3 = Color3.fromRGB(0, 230, 255)
	modalFooterTimerLabel.TextSize = 13
	modalFooterTimerLabel.ZIndex = 36
	modalFooterTimerLabel.Parent = votingModalFrame

	local cardContainer = Instance.new("Frame")
	cardContainer.Name = "CardContainer"
	cardContainer.Size = UDim2.new(1, -30, 0, 240)
	cardContainer.Position = UDim2.new(0, 15, 0, 55)
	cardContainer.BackgroundTransparency = 1
	cardContainer.ZIndex = 36
	cardContainer.Parent = votingModalFrame

	for idx, config in ipairs(MAP_CONFIGS) do
		local card = Instance.new("Frame")
		card.Name = "MapCard_" .. config.id
		card.Size = UDim2.new(0, 235, 1, 0)
		card.Position = UDim2.new(0, (idx - 1) * 255, 0, 0)
		card.BackgroundColor3 = config.bgGrad
		card.BorderSizePixel = 0
		card.ZIndex = 37
		card.Parent = cardContainer

		local cCorner = Instance.new("UICorner")
		cCorner.CornerRadius = UDim.new(0, 12)
		cCorner.Parent = card

		local cStroke = Instance.new("UIStroke")
		cStroke.Color = config.color
		cStroke.Thickness = 2.0
		cStroke.Transparency = 0.3
		cStroke.Parent = card
		cardStrokes[config.id] = cStroke

		local mapHeaderFrame = Instance.new("Frame")
		mapHeaderFrame.Size = UDim2.new(1, 0, 0, 80)
		mapHeaderFrame.BackgroundColor3 = config.color
		mapHeaderFrame.BackgroundTransparency = 0.7
		mapHeaderFrame.BorderSizePixel = 0
		mapHeaderFrame.ZIndex = 38
		mapHeaderFrame.Parent = card

		local hCorner = Instance.new("UICorner")
		hCorner.CornerRadius = UDim.new(0, 12)
		hCorner.Parent = mapHeaderFrame

		local mapTitleLabel = Instance.new("TextLabel")
		mapTitleLabel.Size = UDim2.new(1, -10, 0, 30)
		mapTitleLabel.Position = UDim2.new(0, 5, 0, 12)
		mapTitleLabel.BackgroundTransparency = 1
		mapTitleLabel.Font = Enum.Font.GothamBlack
		mapTitleLabel.Text = config.title
		mapTitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		mapTitleLabel.TextSize = 15
		mapTitleLabel.ZIndex = 39
		mapTitleLabel.Parent = mapHeaderFrame

		local mapSubLabel = Instance.new("TextLabel")
		mapSubLabel.Size = UDim2.new(1, -10, 0, 20)
		mapSubLabel.Position = UDim2.new(0, 5, 0, 44)
		mapSubLabel.BackgroundTransparency = 1
		mapSubLabel.Font = Enum.Font.GothamMedium
		mapSubLabel.Text = config.sub
		mapSubLabel.TextColor3 = Color3.fromRGB(200, 220, 240)
		mapSubLabel.TextSize = 11
		mapSubLabel.ZIndex = 39
		mapSubLabel.Parent = mapHeaderFrame

		local vLabel = Instance.new("TextLabel")
		vLabel.Size = UDim2.new(1, 0, 0, 25)
		vLabel.Position = UDim2.new(0, 0, 0.38, 0)
		vLabel.BackgroundTransparency = 1
		vLabel.Font = Enum.Font.GothamBlack
		vLabel.Text = "🗳️ 0 Votes"
		vLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
		vLabel.TextSize = 13
		vLabel.ZIndex = 38
		vLabel.Parent = card
		cardVoteLabels[config.id] = vLabel

		local avatarFrame = Instance.new("Frame")
		avatarFrame.Name = "AvatarContainer"
		avatarFrame.Size = UDim2.new(1, -16, 0, 46)
		avatarFrame.Position = UDim2.new(0, 8, 0.52, 0)
		avatarFrame.BackgroundTransparency = 1
		avatarFrame.ZIndex = 38
		avatarFrame.Parent = card
		cardAvatarContainers[config.id] = avatarFrame

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
					stroke.Color = Color3.fromRGB(255, 215, 0)
					stroke.Thickness = 3.5
					stroke.Transparency = 0.0
				else
					stroke.Color = Color3.fromRGB(100, 110, 130)
					stroke.Thickness = 1.5
					stroke.Transparency = 0.5
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
	loadingModalFrame.BackgroundColor3 = Color3.fromRGB(14, 18, 28)
	loadingModalFrame.BackgroundTransparency = 0.05
	loadingModalFrame.BorderSizePixel = 0
	loadingModalFrame.Visible = false
	loadingModalFrame.ZIndex = 50
	loadingModalFrame.Parent = mainGuiScreen

	local lCorner = Instance.new("UICorner")
	lCorner.CornerRadius = UDim.new(0, 16)
	lCorner.Parent = loadingModalFrame

	local lStroke = Instance.new("UIStroke")
	lStroke.Color = Color3.fromRGB(0, 240, 255)
	lStroke.Thickness = 2.5
	lStroke.Parent = loadingModalFrame

	loadingTitleLabel = Instance.new("TextLabel")
	loadingTitleLabel.Name = "LoadingTitle"
	loadingTitleLabel.Size = UDim2.new(1, -20, 0, 45)
	loadingTitleLabel.Position = UDim2.new(0, 10, 0, 20)
	loadingTitleLabel.BackgroundTransparency = 1
	loadingTitleLabel.Font = Enum.Font.GothamBlack
	loadingTitleLabel.Text = "🏆 SELECTED MAP: Oval Speedway"
	loadingTitleLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	loadingTitleLabel.TextSize = 20
	loadingTitleLabel.ZIndex = 51
	loadingTitleLabel.Parent = loadingModalFrame

	loadingSubLabel = Instance.new("TextLabel")
	loadingSubLabel.Name = "LoadingSub"
	loadingSubLabel.Size = UDim2.new(1, -20, 0, 25)
	loadingSubLabel.Position = UDim2.new(0, 10, 0, 68)
	loadingSubLabel.BackgroundTransparency = 1
	loadingSubLabel.Font = Enum.Font.GothamMedium
	loadingSubLabel.Text = "Building Map & Preparing Starting Grid..."
	loadingSubLabel.TextColor3 = Color3.fromRGB(180, 220, 255)
	loadingSubLabel.TextSize = 13
	loadingSubLabel.ZIndex = 51
	loadingSubLabel.Parent = loadingModalFrame

	-- Loading Progress Bar Track
	local loadTrack = Instance.new("Frame")
	loadTrack.Name = "LoadTrack"
	loadTrack.Size = UDim2.new(0.86, 0, 0, 28)
	loadTrack.Position = UDim2.new(0.07, 0, 0.58, 0)
	loadTrack.BackgroundColor3 = Color3.fromRGB(25, 35, 50)
	loadTrack.BorderSizePixel = 0
	loadTrack.ZIndex = 51
	loadTrack.Parent = loadingModalFrame

	local tCorner = Instance.new("UICorner")
	tCorner.CornerRadius = UDim.new(0, 10)
	tCorner.Parent = loadTrack

	local tStroke = Instance.new("UIStroke")
	tStroke.Color = Color3.fromRGB(0, 200, 240)
	tStroke.Thickness = 1.5
	tStroke.Parent = loadTrack

	loadingFillBar = Instance.new("Frame")
	loadingFillBar.Name = "LoadFill"
	loadingFillBar.Size = UDim2.new(0, 0, 1, 0)
	loadingFillBar.BackgroundColor3 = Color3.fromRGB(0, 230, 255)
	loadingFillBar.BorderSizePixel = 0
	loadingFillBar.ZIndex = 52
	loadingFillBar.Parent = loadTrack

	local fCorner = Instance.new("UICorner")
	fCorner.CornerRadius = UDim.new(0, 10)
	fCorner.Parent = loadingFillBar

	loadingPercentLabel = Instance.new("TextLabel")
	loadingPercentLabel.Name = "LoadPercent"
	loadingPercentLabel.Size = UDim2.new(1, 0, 1, 0)
	loadingPercentLabel.BackgroundTransparency = 1
	loadingPercentLabel.Font = Enum.Font.GothamBlack
	loadingPercentLabel.Text = "0%"
	loadingPercentLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	loadingPercentLabel.TextSize = 13
	loadingPercentLabel.ZIndex = 53
	loadingPercentLabel.Parent = loadTrack
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
