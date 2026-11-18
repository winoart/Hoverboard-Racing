--!strict
-- GameLoopController.client.luau
-- 3-Map Voting UI, Majority Vote Winner Detection, 5s Animated Map Loading Screen, & 110s Race Match Sync

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")

-- 맵 선택 시 재생할 사운드 설정
local MAP_SELECT_SOUND_ID = "rbxassetid://762117042"
local mapSelectSound = Instance.new("Sound")
mapSelectSound.Name = "MapSelectSound"
mapSelectSound.SoundId = MAP_SELECT_SOUND_ID
mapSelectSound.Volume = 0.9
mapSelectSound.Parent = SoundService
ContentProvider:PreloadAsync({ mapSelectSound })

local function playMapSelectSound()
	mapSelectSound.TimePosition = 0
	mapSelectSound:Play()
end

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
local reopenVoteButton: TextButton? = nil

local votingModalFrame: Frame? = nil
local modalFooterTimerLabel: TextLabel? = nil

local errorModalFrame: Frame? = nil

type VoterInfo = { userId: number, name: string }
type MapVoteData = { [string]: { VoterInfo } }

local currentPhase = "INTERMISSION"
local phaseTimeLeft = 0
local currentChosenMap = "Oval Speedway"
local currentMapVotes: MapVoteData = {
	["Oval Speedway"] = {},
	["Pirate Treasure Island"] = {},
	["Cyber City"] = {},
	["Magma Ridge"] = {},
	["Desert Track"] = {},
}
local selectedMapName = ""
local isVotingModalDismissed = false
local cardContainer: Frame? = nil

-- Map Card Configurations
local PRESET_CARD_COLORS = {
	Color3.fromRGB(0, 220, 255),   -- Cyan
	Color3.fromRGB(255, 200, 50),  -- Gold/Yellow
	Color3.fromRGB(255, 120, 30),  -- Orange
	Color3.fromRGB(180, 90, 255),  -- Purple
	Color3.fromRGB(60, 220, 120),  -- Green
	Color3.fromRGB(255, 90, 150),  -- Pink
}

local currentCandidateMaps: { any } = {
	{
		id = "Oval Speedway",
		name = "🏎️ Oval Speedway",
		desc = "4-Lane Circuit Track",
		color = Color3.fromRGB(0, 220, 255),
	},
	{
		id = "Desert Track",
		name = "🏜️ Desert Track",
		desc = "Sandy Dunes",
		color = Color3.fromRGB(255, 200, 50),
	},
}

local cardFrames: { [string]: Frame } = {}
local cardVoteLabels: { [string]: TextLabel } = {}
local cardAvatarContainers: { [string]: Frame } = {}
local cardStrokes: { [string]: UIStroke } = {}

type ViewportCamEntry = {
	vpf: ViewportFrame,
	cam: Camera,
	focusPos: Vector3,
	radius: number,
	height: number,
	baseAngle: number,
}

local VIEWPORT_SHOWCASE_PRESETS: {
	[string]: {
		sky: Color3,
		focus: Vector3,
		radius: number,
		height: number,
		baseAngle: number,
		fov: number,
	},
} = {
	["Oval Speedway"] = {
		sky = Color3.fromRGB(35, 62, 105),
		focus = Vector3.new(235, 16, -8),
		radius = 115,
		height = 36,
		baseAngle = math.rad(35),
		fov = 50,
	},
	["Desert Track"] = {
		sky = Color3.fromRGB(72, 50, 36),
		focus = Vector3.new(-45, 16, 10),
		radius = 120,
		height = 38,
		baseAngle = math.rad(25),
		fov = 50,
	},
	["Frost Glacier"] = {
		sky = Color3.fromRGB(22, 42, 76),
		focus = Vector3.new(-70, 42, -15),
		radius = 155,
		height = 46,
		baseAngle = math.rad(-35),
		fov = 52,
	},
	["Autobahn Highway"] = {
		sky = Color3.fromRGB(28, 48, 82),
		focus = Vector3.new(0, 22, -45),
		radius = 125,
		height = 36,
		baseAngle = math.rad(35),
		fov = 50,
	},
	["Pirate Treasure Island"] = {
		sky = Color3.fromRGB(24, 85, 140),
		focus = Vector3.new(0, 32, -300),
		radius = 110,
		height = 28,
		baseAngle = math.rad(-75),
		fov = 52,
	},
	["Emerald Lake Haven"] = {
		sky = Color3.fromRGB(32, 75, 110),
		focus = Vector3.new(0, 24, -295),
		radius = 115,
		height = 30,
		baseAngle = math.rad(-70),
		fov = 52,
	},
	["Cyber City"] = {
		sky = Color3.fromRGB(18, 12, 38),
		focus = Vector3.new(125, 48, 20),
		radius = 165,
		height = 48,
		baseAngle = math.rad(25),
		fov = 52,
	},
}

local activeViewportCams: { ViewportCamEntry } = {}
local viewportSpinConn: RBXScriptConnection? = nil

local function stopViewportSpin()
	if viewportSpinConn then
		viewportSpinConn:Disconnect()
		viewportSpinConn = nil
	end
	table.clear(activeViewportCams)
end

local function startViewportSpin()
	if viewportSpinConn then return end
	viewportSpinConn = RunService.RenderStepped:Connect(function()
		if not votingModalFrame or not votingModalFrame.Visible or currentPhase ~= "MAP_VOTING" then
			return
		end
		local t = os.clock()
		for _, entry in ipairs(activeViewportCams) do
			if entry.vpf.Parent and entry.cam.Parent then
				-- Silky smooth cinematic crane sway (+/- 14 degrees) showcasing the hero landmarks
				local ang = entry.baseAngle + math.sin(t * 0.75 + entry.baseAngle) * 0.22
				local swayH = entry.height + math.sin(t * 0.55 + entry.baseAngle) * 1.8
				local offset = Vector3.new(math.cos(ang) * entry.radius, swayH, math.sin(ang) * entry.radius)
				entry.cam.CFrame = CFrame.lookAt(entry.focusPos + offset, entry.focusPos)
			end
		end
	end)
end

-- Update Avatar Thumbnails & Vote Count Labels (with change detection to eliminate 1s GC hitches)
local lastRenderedVoteKey = ""

local function updateMapCardAvatars(mapVotes: MapVoteData)
	pcall(function()
		local sigParts = {}
		for _, config in ipairs(currentCandidateMaps) do
			local mId = tostring(config.id)
			local voterList = mapVotes[mId] or {}
			table.insert(sigParts, mId .. ":" .. #voterList)
			for _, v in ipairs(voterList) do
				table.insert(sigParts, tostring(v.userId or 0))
			end
		end
		local currentSig = table.concat(sigParts, "_")
		local votesChanged = (currentSig ~= lastRenderedVoteKey)
		lastRenderedVoteKey = currentSig

		for _, config in ipairs(currentCandidateMaps) do
			local mId = tostring(config.id)
			local voterList = mapVotes[mId] or {}
			local container = cardAvatarContainers[mId]
			local voteLabel = cardVoteLabels[mId]

			if voteLabel then
				voteLabel.Text = string.format("🗳️ %d Votes", #voterList)
			end

			if container and votesChanged then
				for _, child in ipairs(container:GetChildren()) do
					if child:IsA("ImageLabel") then
						child:Destroy()
					end
				end

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

-- Dynamically Render Map Voting Cards
local function renderMapCards(candidates: { any })
	if not cardContainer then return end

	stopViewportSpin()

	cardFrames = {}
	cardVoteLabels = {}
	cardAvatarContainers = {}
	cardStrokes = {}

	for _, child in ipairs(cardContainer:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	local cardLayout = Instance.new("UIListLayout")
	cardLayout.FillDirection = Enum.FillDirection.Horizontal
	cardLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	cardLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	cardLayout.Padding = UDim.new(0, 12)
	cardLayout.SortOrder = Enum.SortOrder.LayoutOrder
	cardLayout.Parent = cardContainer

	local count = #candidates
	if count == 0 then return end

	local totalAvailableWidth = 940
	local cardWidth = math.min(250, math.floor((totalAvailableWidth - (count - 1) * 12) / count))
	if cardWidth < 170 then cardWidth = 170 end

	for idx, config in ipairs(candidates) do
		local mId = tostring(config.id)
		local themeColor = config.color or PRESET_CARD_COLORS[((idx - 1) % #PRESET_CARD_COLORS) + 1]

		local card = Instance.new("Frame")
		card.Name = "MapCard_" .. mId
		card.Size = UDim2.new(0, cardWidth, 1, 0)
		card.BackgroundColor3 = themeColor
		card.BorderSizePixel = 0
		card.ZIndex = 37
		card.LayoutOrder = idx
		card.Parent = cardContainer

		local cCorner = Instance.new("UICorner")
		cCorner.CornerRadius = UDim.new(0, 16)
		cCorner.Parent = card

		local isSelected = (selectedMapName == mId)
		local cStroke = Instance.new("UIStroke")
		cStroke.Color = isSelected and Color3.fromRGB(255, 200, 50) or Color3.fromRGB(0, 0, 0)
		cStroke.Thickness = isSelected and 8 or 4
		cStroke.Transparency = 0
		cStroke.Parent = card
		cardStrokes[mId] = cStroke

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

		local previewFrame: GuiObject
		local hasCustomImage = config.imageId and config.imageId ~= "" and config.imageId ~= "rbxassetid://" and config.imageId:sub(1, 10) == "rbxassetid"
		
		if hasCustomImage then
			local mapImage = Instance.new("ImageLabel")
			mapImage.Name = "MapImage"
			mapImage.Size = UDim2.new(1, -16, 0, 142)
			mapImage.Position = UDim2.new(0, 8, 0, 10)
			mapImage.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
			mapImage.Image = config.imageId
			mapImage.ScaleType = Enum.ScaleType.Crop
			mapImage.BorderSizePixel = 0
			mapImage.ZIndex = 38
			mapImage.Parent = card
			previewFrame = mapImage
		else
			local preset = VIEWPORT_SHOWCASE_PRESETS[mId]
			local vpf = Instance.new("ViewportFrame")
			vpf.Name = "MapViewport"
			vpf.Size = UDim2.new(1, -16, 0, 142)
			vpf.Position = UDim2.new(0, 8, 0, 10)
			vpf.BackgroundColor3 = preset and preset.sky or Color3.fromRGB(22, 26, 35)
			vpf.BorderSizePixel = 0
			vpf.ZIndex = 38
			vpf.Ambient = Color3.fromRGB(195, 200, 215)
			vpf.LightColor = Color3.fromRGB(255, 250, 240)
			vpf.LightDirection = Vector3.new(-1, -2, -1).Unit
			vpf.Parent = card
			previewFrame = vpf

			-- Load map model from ReplicatedStorage.Maps or Workspace
			task.spawn(function()
				local mapsFolder = ReplicatedStorage:FindFirstChild("Maps")
				local mapTemplate = mapsFolder and mapsFolder:FindFirstChild(mId)
				if not mapTemplate then
					mapTemplate = mapsFolder and mapsFolder:FindFirstChild(config.name or "")
				end
				if not mapTemplate then
					mapTemplate = Workspace:FindFirstChild(mId)
				end

				if mapTemplate and mapTemplate:IsA("Model") then
					local activePreset = preset or VIEWPORT_SHOWCASE_PRESETS[mapTemplate.Name]
					if activePreset then
						vpf.BackgroundColor3 = activePreset.sky
					end

					local focusPos: Vector3
					local radius: number
					local height: number
					local baseAngle: number
					local fov: number

					if activePreset then
						focusPos = activePreset.focus
						radius = activePreset.radius
						height = activePreset.height
						baseAngle = activePreset.baseAngle
						fov = activePreset.fov
					else
						local sp = mapTemplate:FindFirstChild("StartingPoint") or mapTemplate:FindFirstChild("TrackStartGridPart")
						if sp and sp:IsA("Model") then
							focusPos = sp:GetPivot().Position
						elseif sp and sp:IsA("BasePart") then
							focusPos = sp.Position
						else
							local bbCf = mapTemplate:GetBoundingBox()
							focusPos = bbCf.Position
						end
						radius = 130
						height = 40
						baseAngle = 0
						fov = 50
					end

					local maxRadius = radius * 1.55
					local mapClone = mapTemplate:Clone()

					-- Aggressive distance culling: strip 95%+ of distant parts to make ViewportFrame render instantly with 0 lag
					for _, d in ipairs(mapClone:GetDescendants()) do
						if d:IsA("Sound")
							or d:IsA("Script")
							or d:IsA("LocalScript")
							or d:IsA("TouchTransmitter")
							or d:IsA("Light")
							or d:IsA("ParticleEmitter")
							or d.Name == "TrackGuardWall"
							or d.Name == "TrackStartGridPart"
							or string.find(d.Name, "^SnowEmitterPart") ~= nil
							or (d.Parent and d.Parent.Name == "Checkpoints")
						then
							d:Destroy()
						elseif d:IsA("BasePart") then
							local dist = (d.Position - focusPos).Magnitude
							if dist > maxRadius or d.Position.Y < -500 or (d.Size.Magnitude < 3.0 and not d:IsA("MeshPart")) then
								d:Destroy()
							else
								d.CanCollide = false
								d.CanTouch = false
								d.CanQuery = false
								d.Anchored = true
								d.CastShadow = false
								if d.Name == "GlacierSnowPlain" then
									d.Color = Color3.fromRGB(175, 210, 242)
								end
							end
						end
					end

					if not vpf.Parent then
						mapClone:Destroy()
						return
					end

					mapClone.Parent = vpf

					-- Set cinematic camera angle and register for smooth dynamic sway
					local cam = Instance.new("Camera")
					cam.FieldOfView = fov
					local initialOffset = Vector3.new(math.cos(baseAngle) * radius, height, math.sin(baseAngle) * radius)
					cam.CFrame = CFrame.lookAt(focusPos + initialOffset, focusPos)
					cam.Parent = vpf
					vpf.CurrentCamera = cam

					table.insert(activeViewportCams, {
						vpf = vpf,
						cam = cam,
						focusPos = focusPos,
						radius = radius,
						height = height,
						baseAngle = baseAngle,
					})
					startViewportSpin()
				end
			end)
		end

		local imgCorner = Instance.new("UICorner")
		imgCorner.CornerRadius = UDim.new(0, 12)
		imgCorner.Parent = previewFrame
		
		local imgStroke = Instance.new("UIStroke")
		imgStroke.Color = Color3.fromRGB(0, 0, 0)
		imgStroke.Thickness = 3
		imgStroke.Parent = previewFrame

		local avatarFrame = Instance.new("Frame")
		avatarFrame.Name = "AvatarContainer"
		avatarFrame.Size = UDim2.new(1, -10, 1, -10)
		avatarFrame.Position = UDim2.new(0, 5, 0, 5)
		avatarFrame.BackgroundTransparency = 1
		avatarFrame.ZIndex = 42
		avatarFrame.Parent = previewFrame
		cardAvatarContainers[mId] = avatarFrame
		
		local avatarLayout = Instance.new("UIGridLayout")
		avatarLayout.CellSize = UDim2.new(0, 32, 0, 32)
		avatarLayout.CellPadding = UDim2.new(0, 5, 0, 5)
		avatarLayout.SortOrder = Enum.SortOrder.LayoutOrder
		avatarLayout.Parent = avatarFrame

		local mapTitleLabel = Instance.new("TextLabel")
		mapTitleLabel.Size = UDim2.new(1, -16, 0, 28)
		mapTitleLabel.Position = UDim2.new(0, 8, 0, 158)
		mapTitleLabel.BackgroundTransparency = 1
		mapTitleLabel.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
		mapTitleLabel.Text = config.name or config.title or mId
		mapTitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		mapTitleLabel.TextSize = (cardWidth < 200) and 16 or 20
		mapTitleLabel.TextTruncate = Enum.TextTruncate.AtEnd
		mapTitleLabel.ZIndex = 39
		mapTitleLabel.Parent = card
		
		local mapTitleStroke = Instance.new("UIStroke")
		mapTitleStroke.Color = Color3.fromRGB(0, 0, 0)
		mapTitleStroke.Thickness = 3
		mapTitleStroke.Parent = mapTitleLabel

		local mapSubLabel = Instance.new("TextLabel")
		mapSubLabel.Size = UDim2.new(1, -16, 0, 20)
		mapSubLabel.Position = UDim2.new(0, 8, 0, 187)
		mapSubLabel.BackgroundTransparency = 1
		mapSubLabel.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
		local subText = config.desc or config.sub or ""
		if subText == "" and config.laps then
			subText = tostring(config.laps) .. " Laps"
		end
		mapSubLabel.Text = subText
		mapSubLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		mapSubLabel.TextSize = (cardWidth < 200) and 12 or 14
		mapSubLabel.TextTruncate = Enum.TextTruncate.AtEnd
		mapSubLabel.ZIndex = 39
		mapSubLabel.Parent = card
		
		local mapSubStroke = Instance.new("UIStroke")
		mapSubStroke.Color = Color3.fromRGB(0, 0, 0)
		mapSubStroke.Thickness = 2
		mapSubStroke.Parent = mapSubLabel

		local vLabel = Instance.new("TextLabel")
		vLabel.Size = UDim2.new(1, -16, 0, 30)
		vLabel.Position = UDim2.new(0, 8, 0, 216)
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
		cardVoteLabels[mId] = vLabel

		local clickBtn = Instance.new("TextButton")
		clickBtn.Size = UDim2.new(1, 0, 1, 0)
		clickBtn.BackgroundTransparency = 1
		clickBtn.Text = ""
		clickBtn.ZIndex = 45
		clickBtn.Parent = card

		clickBtn.MouseButton1Click:Connect(function()
			playMapSelectSound()
			selectedMapName = mId

			-- Local Optimistic Vote Update
			for curId, voterList in pairs(currentMapVotes) do
				for i = #voterList, 1, -1 do
					if voterList[i].userId == LocalPlayer.UserId then
						table.remove(voterList, i)
					end
				end
			end

			if not currentMapVotes[mId] then
				currentMapVotes[mId] = {}
			end
			table.insert(currentMapVotes[mId], {
				userId = LocalPlayer.UserId,
				name = LocalPlayer.DisplayName or LocalPlayer.Name,
			})

			for curId, stroke in pairs(cardStrokes) do
				if curId == mId then
					stroke.Color = Color3.fromRGB(255, 200, 50) -- Gold for selected
					stroke.Thickness = 8
				else
					stroke.Color = Color3.fromRGB(0, 0, 0)
					stroke.Thickness = 4
				end
			end

			updateMapCardAvatars(currentMapVotes)
			voteRemote:FireServer(mId)
		end)

		cardFrames[mId] = card
	end

	updateMapCardAvatars(currentMapVotes)
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
			local shouldShowModal = (currentPhase == "MAP_VOTING" and not isVotingModalDismissed and not LocalPlayer:GetAttribute("IsAFK"))
			votingModalFrame.Visible = shouldShowModal

			-- X로 닫았지만 아직 투표 시간(MAP_VOTING)이 남아있는 경우, 상단 타이머 옆에 [🗳️ Vote] 버튼 노출
			if reopenVoteButton then
				reopenVoteButton.Visible = (currentPhase == "MAP_VOTING" and isVotingModalDismissed and not LocalPlayer:GetAttribute("IsAFK"))
			end
		end

		if currentPhase ~= "MAP_VOTING" then
			stopViewportSpin()
		elseif #activeViewportCams > 0 then
			startViewportSpin()
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
	headerBannerFrame.AnchorPoint = Vector2.new(0.5, 0)
	headerBannerFrame.Position = UDim2.new(0.5, 0, 0.02, 0)
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

	-- 🗳️ 투표창을 X로 닫았을 때 다시 열 수 있는 상단 바 [🗳️ Vote Map] 버튼
	reopenVoteButton = Instance.new("TextButton")
	reopenVoteButton.Name = "ReopenVoteButton"
	reopenVoteButton.Size = UDim2.new(0, 130, 0, 42)
	reopenVoteButton.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
	reopenVoteButton.Font = Enum.Font.FredokaOne
	reopenVoteButton.Text = "🗳️ Vote"
	reopenVoteButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	reopenVoteButton.TextSize = 22
	reopenVoteButton.LayoutOrder = 3
	reopenVoteButton.ZIndex = 32
	reopenVoteButton.Visible = false
	reopenVoteButton.Parent = headerBannerFrame

	local reopenCorner = Instance.new("UICorner")
	reopenCorner.CornerRadius = UDim.new(0, 12)
	reopenCorner.Parent = reopenVoteButton

	local reopenStroke = Instance.new("UIStroke")
	reopenStroke.Color = Color3.fromRGB(0, 0, 0)
	reopenStroke.Thickness = 3
	reopenStroke.Parent = reopenVoteButton

	reopenVoteButton.MouseButton1Click:Connect(function()
		isVotingModalDismissed = false
		refreshDisplays()
	end)

	-- [2] MAP VOTING MODAL UI (15s)
	votingModalFrame = Instance.new("Frame")
	votingModalFrame.Name = "VotingModal"
	votingModalFrame.Size = UDim2.new(0, 980, 0, 390)
	votingModalFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	votingModalFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
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
	closeBtn.AnchorPoint = Vector2.new(0.5, 0.5)
	closeBtn.Size = UDim2.new(0, 46, 0, 46)
	closeBtn.Position = UDim2.new(1, 0, 0, 0)
	closeBtn.BackgroundColor3 = Color3.fromRGB(255, 75, 75)
	closeBtn.Font = Enum.Font.FredokaOne
	closeBtn.Text = "X"
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.TextSize = 26
	closeBtn.TextStrokeTransparency = 1
	closeBtn.ZIndex = 40
	closeBtn.Parent = votingModalFrame
	
	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(1, 0)
	closeCorner.Parent = closeBtn
	
	local closeBorderStroke = Instance.new("UIStroke")
	closeBorderStroke.Name = "BorderStroke"
	closeBorderStroke.Color = Color3.fromRGB(0, 0, 0)
	closeBorderStroke.Thickness = 4.0
	closeBorderStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	closeBorderStroke.Parent = closeBtn

	local closeTextStroke = Instance.new("UIStroke")
	closeTextStroke.Name = "TextStroke"
	closeTextStroke.Color = Color3.fromRGB(0, 0, 0)
	closeTextStroke.Thickness = 3.0
	closeTextStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	closeTextStroke.Parent = closeBtn
	
	closeBtn.MouseButton1Click:Connect(function()
		isVotingModalDismissed = true
		refreshDisplays()
	end)

	cardContainer = Instance.new("Frame")
	cardContainer.Name = "CardContainer"
	cardContainer.Size = UDim2.new(1, -30, 0, 260)
	cardContainer.Position = UDim2.new(0, 15, 0, 100)
	cardContainer.BackgroundTransparency = 1
	cardContainer.ZIndex = 36
	cardContainer.Parent = votingModalFrame

	renderMapCards(currentCandidateMaps)


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

	-- =========================================================================
	-- 📱 [5] RESPONSIVE UI SCALING
	-- =========================================================================
	local headerScale = Instance.new("UIScale", headerBannerFrame)
	local voteScale = Instance.new("UIScale", votingModalFrame)
	local errorScale = Instance.new("UIScale", errorModalFrame)

	local function updateResponsiveScale()
		local viewport = workspace.CurrentCamera.ViewportSize
		if viewport.X == 0 or viewport.Y == 0 then return end
		
		-- Base reference resolution: 1280x720
		local scale = math.min(viewport.X / 1280, viewport.Y / 720)
		local finalScale = math.clamp(scale, 0.4, 1.1) -- Limit how small or big it gets on mobile
		
		headerScale.Scale = finalScale
		voteScale.Scale = finalScale
		errorScale.Scale = finalScale
	end

	local resizeConn = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveScale)
	updateResponsiveScale()
	task.delay(0.1, updateResponsiveScale)
	
	-- Clean up on destroy
	mainGuiScreen.Destroying:Connect(function()
		if resizeConn then resizeConn:Disconnect() end
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
phaseRemote.OnClientEvent:Connect(function(phase: string, timeLeft: number, mapVotes: MapVoteData, chosenMap: string?, candidateMaps: { any }?)
	if phase == "MAP_VOTING" and currentPhase ~= "MAP_VOTING" then
		isVotingModalDismissed = false
		selectedMapName = ""
	end

	if phase == "MAP_VOTING" and candidateMaps and #candidateMaps > 0 then
		local changed = (#candidateMaps ~= #currentCandidateMaps)
		if not changed then
			for idx, c in ipairs(candidateMaps) do
				if not currentCandidateMaps[idx] or currentCandidateMaps[idx].id ~= c.id or currentCandidateMaps[idx].name ~= c.name then
					changed = true
					break
				end
			end
		end
		if changed or currentPhase ~= "MAP_VOTING" then
			currentCandidateMaps = candidateMaps
			renderMapCards(currentCandidateMaps)
		end
	elseif phase == "RACE_MATCH" and #currentCandidateMaps > 0 then
		-- 레이스 중에는 투표창 3D ViewportFrame 복제 모델(~18,500 파트)을 즉시 해제해 메모리/렌더 부하를 제거
		currentCandidateMaps = {}
		cardFrames = {}
		cardVoteLabels = {}
		cardAvatarContainers = {}
		cardStrokes = {}
		if cardContainer then
			for _, child in ipairs(cardContainer:GetChildren()) do
				if child:IsA("GuiObject") then
					child:Destroy()
				end
			end
		end
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
