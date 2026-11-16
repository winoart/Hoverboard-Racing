--!strict
-- MapBuilder.luau
-- Builds complete Oval Speedway map model with track, grass, inner/outer barriers, grandstands, start arch, and start grid

local MapBuilder = {}

-- Disable unnecessary Touched and spatial query overhead on static/decorative map parts
local function optimizeMapCollisionFlags(mapModel: Model)
	for _, d in ipairs(mapModel:GetDescendants()) do
		if d:IsA("BasePart") then
			if d.Parent and d.Parent.Name == "Checkpoints" then
				d.CanTouch = true
				d.CanQuery = false
			else
				d.CanTouch = false
				if not d.CanCollide then
					d.CanQuery = false
				end
			end
		end
	end
end

function MapBuilder.buildOvalSpeedwayModel(): Model
	local mapModel = Instance.new("Model")
	mapModel.Name = "Oval Speedway"

	-- Map Settings
	local SEGMENT_COUNT = 360
	local RADIUS_X = 280
	local RADIUS_Z = 170
	local TRACK_WIDTH = 64
	local TRACK_THICKNESS = 2
	local CENTER_Y = 5

	local ROAD_COLOR = Color3.fromRGB(42, 45, 50)
	local ROAD_MATERIAL = Enum.Material.Asphalt
	local YELLOW_LINE_COLOR = Color3.fromRGB(250, 200, 30)
	local WHITE_LINE_COLOR = Color3.fromRGB(240, 240, 245)
	local LINE_MATERIAL = Enum.Material.SmoothPlastic

	local function getTrackPointInfo(theta: number)
		local x = math.cos(theta) * RADIUS_X
		local z = math.sin(theta) * RADIUS_Z
		local pos = Vector3.new(x, CENTER_Y, z)

		local dx = -math.sin(theta) * RADIUS_X
		local dz = math.cos(theta) * RADIUS_Z
		local normal = Vector3.new(dz, 0, -dx).Unit
		return pos, normal
	end

	-- 1. HoverboardTrack (Road + Lines)
	local trackFolder = Instance.new("Folder")
	trackFolder.Name = "HoverboardTrack"
	trackFolder.Parent = mapModel

	local halfWidth = TRACK_WIDTH / 2

	for i = 1, SEGMENT_COUNT do
		local t1 = ((i - 1) / SEGMENT_COUNT) * math.pi * 2
		local t2 = (i / SEGMENT_COUNT) * math.pi * 2

		local pos1, normal1 = getTrackPointInfo(t1)
		local pos2, normal2 = getTrackPointInfo(t2)

		local centerPos = (pos1 + pos2) / 2
		local pos1_outer = pos1 + (normal1 * halfWidth)
		local pos2_outer = pos2 + (normal2 * halfWidth)
		local outerDist = (pos2_outer - pos1_outer).Magnitude
		local segmentLength = outerDist + 1.2
		local cframe = CFrame.lookAt(centerPos, pos2)

		local roadPart = Instance.new("Part")
		roadPart.Name = "TrackSegment_" .. i
		roadPart.Anchored = true
		roadPart.CanCollide = true
		roadPart.Material = ROAD_MATERIAL
		roadPart.Color = ROAD_COLOR
		roadPart.Size = Vector3.new(TRACK_WIDTH, TRACK_THICKNESS, segmentLength)
		roadPart.CFrame = cframe
		roadPart.TopSurface = Enum.SurfaceType.Smooth
		roadPart.BottomSurface = Enum.SurfaceType.Smooth
		roadPart.Parent = trackFolder

		local lineYOffset = (TRACK_THICKNESS / 2) + 0.05
		local isDashedOn = (math.floor(i / 4) % 2 == 0)

		-- Yellow center double lines
		for _, offset in ipairs({ -1.5, 1.5 }) do
			local yellowLine = Instance.new("Part")
			yellowLine.Name = "CenterYellowLine"
			yellowLine.Anchored = true
			yellowLine.CanCollide = false
			yellowLine.Material = LINE_MATERIAL
			yellowLine.Color = YELLOW_LINE_COLOR
			yellowLine.Size = Vector3.new(0.8, 0.1, segmentLength)
			yellowLine.CFrame = cframe * CFrame.new(offset, lineYOffset, 0)
			yellowLine.TopSurface = Enum.SurfaceType.Smooth
			yellowLine.BottomSurface = Enum.SurfaceType.Smooth
			yellowLine.Parent = trackFolder
		end

		-- White dashed lines
		if isDashedOn then
			for _, offset in ipairs({ -16, 16 }) do
				local whiteLine = Instance.new("Part")
				whiteLine.Name = "LaneWhiteLine"
				whiteLine.Anchored = true
				whiteLine.CanCollide = false
				whiteLine.Material = LINE_MATERIAL
				whiteLine.Color = WHITE_LINE_COLOR
				whiteLine.Size = Vector3.new(0.8, 0.1, segmentLength)
				whiteLine.CFrame = cframe * CFrame.new(offset, lineYOffset, 0)
				whiteLine.TopSurface = Enum.SurfaceType.Smooth
				whiteLine.BottomSurface = Enum.SurfaceType.Smooth
				whiteLine.Parent = trackFolder
			end
		end

		-- White edge solid lines
		for _, offset in ipairs({ -halfWidth + 1.2, halfWidth - 1.2 }) do
			local edgeLine = Instance.new("Part")
			edgeLine.Name = "EdgeWhiteLine"
			edgeLine.Anchored = true
			edgeLine.CanCollide = false
			edgeLine.Material = LINE_MATERIAL
			edgeLine.Color = WHITE_LINE_COLOR
			edgeLine.Size = Vector3.new(1.0, 0.1, segmentLength)
			edgeLine.CFrame = cframe * CFrame.new(offset, lineYOffset, 0)
			edgeLine.TopSurface = Enum.SurfaceType.Smooth
			edgeLine.BottomSurface = Enum.SurfaceType.Smooth
			edgeLine.Parent = trackFolder
		end
	end

	-- 2. InfieldGrass
	local grassFolder = Instance.new("Folder")
	grassFolder.Name = "InfieldGrass"
	grassFolder.Parent = mapModel

	local RX_GRID = 232.0
	local RZ_GRID = 122.0
	local TILE_SIZE = 12.0
	local GRASS_Y = 5.0
	local GRASS_THICKNESS = 2.0
	local UNIFIED_COLOR = Color3.fromRGB(70, 155, 55)
	local UNIFIED_MATERIAL = Enum.Material.Grass

	for x = -RX_GRID, RX_GRID, TILE_SIZE do
		for z = -RZ_GRID, RZ_GRID, TILE_SIZE do
			local centerX = x + (TILE_SIZE / 2)
			local centerZ = z + (TILE_SIZE / 2)
			local normX = centerX / RX_GRID
			local normZ = centerZ / RZ_GRID

			if (normX * normX) + (normZ * normZ) <= 1.02 then
				local tile = Instance.new("Part")
				tile.Name = "InfieldGrassTile"
				tile.Anchored = true
				tile.CanCollide = true
				tile.Material = UNIFIED_MATERIAL
				tile.Color = UNIFIED_COLOR
				tile.Size = Vector3.new(TILE_SIZE + 0.3, GRASS_THICKNESS, TILE_SIZE + 0.3)
				tile.Position = Vector3.new(centerX, GRASS_Y, centerZ)
				tile.TopSurface = Enum.SurfaceType.Smooth
				tile.BottomSurface = Enum.SurfaceType.Smooth
				tile.Parent = grassFolder
			end
		end
	end

	local RX_INNER_TRACK = 247.5
	local RZ_INNER_TRACK = 137.5
	local ringWidth = 24.0

	for i = 1, 360 do
		local t1 = ((i - 1) / 360) * math.pi * 2
		local t2 = (i / 360) * math.pi * 2

		local p1 = Vector3.new(math.cos(t1) * RX_INNER_TRACK, GRASS_Y, math.sin(t1) * RZ_INNER_TRACK)
		local p2 = Vector3.new(math.cos(t2) * RX_INNER_TRACK, GRASS_Y, math.sin(t2) * RZ_INNER_TRACK)

		local dx = -math.sin(t1) * RX_INNER_TRACK
		local dz = math.cos(t1) * RZ_INNER_TRACK
		local normal = Vector3.new(dz, 0, -dx).Unit

		local centerPos = ((p1 + p2) / 2) - (normal * (ringWidth / 2))
		local segLength = (p2 - p1).Magnitude + 0.6
		local cframe = CFrame.lookAt(centerPos, centerPos + (p2 - p1))

		local edgeTile = Instance.new("Part")
		edgeTile.Name = "GrassEdgeSegment_" .. i
		edgeTile.Anchored = true
		edgeTile.CanCollide = true
		edgeTile.Material = UNIFIED_MATERIAL
		edgeTile.Color = UNIFIED_COLOR
		edgeTile.Size = Vector3.new(ringWidth, GRASS_THICKNESS, segLength)
		edgeTile.CFrame = cframe
		edgeTile.TopSurface = Enum.SurfaceType.Smooth
		edgeTile.BottomSurface = Enum.SurfaceType.Smooth
		edgeTile.Parent = grassFolder
	end

	-- 3. Outer & Inner Track Barriers
	local function createBarrierModel(name: string, isOuter: boolean): Model
		local bModel = Instance.new("Model")
		bModel.Name = name
		bModel.Parent = mapModel

		local BARRIER_OFFSET = isOuter and ((TRACK_WIDTH / 2) + 3) or -((TRACK_WIDTH / 2) + 3)
		local BARRIER_HEIGHT = 22
		local BARRIER_COLOR = Color3.fromRGB(80, 220, 255)
		local BARRIER_MATERIAL = Enum.Material.Glass

		for i = 1, SEGMENT_COUNT do
			local t1 = ((i - 1) / SEGMENT_COUNT) * math.pi * 2
			local t2 = (i / SEGMENT_COUNT) * math.pi * 2

			local pos1, normal1 = getTrackPointInfo(t1)
			local pos2, normal2 = getTrackPointInfo(t2)

			local bPos1 = pos1 + (normal1 * BARRIER_OFFSET)
			local bPos2 = pos2 + (normal2 * BARRIER_OFFSET)

			local centerPos = (bPos1 + bPos2) / 2
			local segmentLength = (bPos2 - bPos1).Magnitude + 1.2
			local cframe = CFrame.lookAt(centerPos, bPos2) * CFrame.new(0, BARRIER_HEIGHT / 2, 0)

			local barrierPart = Instance.new("Part")
			barrierPart.Name = isOuter and ("BarrierSegment_" .. i) or ("InnerBarrierSegment_" .. i)
			barrierPart.Anchored = true
			barrierPart.CanCollide = true
			barrierPart.Material = BARRIER_MATERIAL
			barrierPart.Transparency = 0.75
			barrierPart.Color = BARRIER_COLOR
			barrierPart.Size = Vector3.new(1.0, BARRIER_HEIGHT, segmentLength)
			barrierPart.CFrame = cframe
			barrierPart.TopSurface = Enum.SurfaceType.Smooth
			barrierPart.BottomSurface = Enum.SurfaceType.Smooth
			barrierPart.Parent = bModel

			if i == 1 then
				bModel.PrimaryPart = barrierPart
			end
		end
		return bModel
	end

	createBarrierModel("TrackBarrier", true)
	createBarrierModel("InnerTrackBarrier", false)

	-- 4. Grandstands
	local grandstandModel = Instance.new("Model")
	grandstandModel.Name = "Grandstands"
	grandstandModel.Parent = mapModel

	local GRANDSTAND_SEGMENTS = 180
	local OFFSET_DISTANCE = (TRACK_WIDTH / 2) + 18
	local TIER_COUNT = 6
	local TIER_HEIGHT = 2.5
	local TIER_DEPTH = 3.8
	local SEAT_HEIGHT = 1.2
	local SEAT_COLORS = {
		Color3.fromRGB(220, 45, 45),
		Color3.fromRGB(40, 110, 220),
		Color3.fromRGB(245, 195, 30),
		Color3.fromRGB(235, 235, 240),
	}

	for i = 1, GRANDSTAND_SEGMENTS do
		local t1 = ((i - 1) / GRANDSTAND_SEGMENTS) * math.pi * 2
		local t2 = (i / GRANDSTAND_SEGMENTS) * math.pi * 2

		local pos1, normal1 = getTrackPointInfo(t1)
		local pos2, normal2 = getTrackPointInfo(t2)

		local gPos1 = pos1 + (normal1 * OFFSET_DISTANCE)
		local gPos2 = pos2 + (normal2 * OFFSET_DISTANCE)

		local centerPos = (gPos1 + gPos2) / 2
		local segmentLength = (gPos2 - gPos1).Magnitude + 1.2
		local cframe = CFrame.lookAt(centerPos, gPos2)

		for tier = 1, TIER_COUNT do
			local depthOffset = (tier - 1) * TIER_DEPTH
			local heightOffset = (tier - 1) * TIER_HEIGHT
			local tierCFrame = cframe * CFrame.new(depthOffset, heightOffset + (TIER_HEIGHT / 2), 0)

			local tierStep = Instance.new("Part")
			tierStep.Name = "TierStep_" .. tier
			tierStep.Anchored = true
			tierStep.CanCollide = true
			tierStep.Material = Enum.Material.Concrete
			tierStep.Color = Color3.fromRGB(180, 185, 190)
			tierStep.Size = Vector3.new(TIER_DEPTH, TIER_HEIGHT, segmentLength)
			tierStep.CFrame = tierCFrame
			tierStep.TopSurface = Enum.SurfaceType.Smooth
			tierStep.Parent = grandstandModel

			if i == 1 and tier == 1 then
				grandstandModel.PrimaryPart = tierStep
			end

			local seatColor = SEAT_COLORS[(tier % #SEAT_COLORS) + 1]
			local seatCFrame = cframe * CFrame.new(depthOffset, heightOffset + TIER_HEIGHT + (SEAT_HEIGHT / 2), 0)

			local seatPart = Instance.new("Part")
			seatPart.Name = "StadiumSeat_" .. tier
			seatPart.Anchored = true
			seatPart.CanCollide = true
			seatPart.Material = Enum.Material.SmoothPlastic
			seatPart.Color = seatColor
			seatPart.Size = Vector3.new(TIER_DEPTH * 0.8, SEAT_HEIGHT, segmentLength)
			seatPart.CFrame = seatCFrame
			seatPart.TopSurface = Enum.SurfaceType.Smooth
			seatPart.Parent = grandstandModel
		end

		local totalDepth = TIER_COUNT * TIER_DEPTH
		local totalHeight = TIER_COUNT * TIER_HEIGHT + 12
		local roofCFrame = cframe * CFrame.new(totalDepth / 2 - 2, totalHeight, 0) * CFrame.Angles(0, 0, math.rad(-8))

		local roofPart = Instance.new("Part")
		roofPart.Name = "GrandstandRoof"
		roofPart.Anchored = true
		roofPart.CanCollide = true
		roofPart.Material = Enum.Material.SmoothPlastic
		roofPart.Color = Color3.fromRGB(50, 55, 65)
		roofPart.Size = Vector3.new(totalDepth + 6, 1.5, segmentLength)
		roofPart.CFrame = roofCFrame
		roofPart.TopSurface = Enum.SurfaceType.Smooth
		roofPart.Parent = grandstandModel

		if i % 3 == 0 then
			local pillarCFrame = cframe * CFrame.new(totalDepth, totalHeight / 2, 0)
			local pillar = Instance.new("Part")
			pillar.Name = "SupportPillar"
			pillar.Anchored = true
			pillar.CanCollide = true
			pillar.Material = Enum.Material.Metal
			pillar.Color = Color3.fromRGB(120, 125, 130)
			pillar.Size = Vector3.new(2, totalHeight, 2)
			pillar.CFrame = pillarCFrame
			pillar.Parent = grandstandModel
		end

		local fenceCFrame = cframe * CFrame.new(-2, 2.5, 0)
		local fence = Instance.new("Part")
		fence.Name = "SafetyFence"
		fence.Anchored = true
		fence.CanCollide = true
		fence.Material = Enum.Material.Glass
		fence.Transparency = 0.4
		fence.Color = Color3.fromRGB(200, 220, 245)
		fence.Size = Vector3.new(0.5, 4, segmentLength)
		fence.CFrame = fenceCFrame
		fence.Parent = grandstandModel
	end

	-- 5. StartingPoint Arch & Grid
	local startModel = Instance.new("Model")
	startModel.Name = "StartingPoint"
	startModel.Parent = mapModel

	local startPos = Vector3.new(RADIUS_X, CENTER_Y, 0)
	local lookDir = Vector3.new(0, 0, 1)
	local startCFrame = CFrame.lookAt(startPos, startPos + lookDir)

	local lineLength = 12.0
	local lineWidth = TRACK_WIDTH + 4.0
	local lineYOffset = (2 / 2) + 0.08

	local startLineBase = Instance.new("Part")
	startLineBase.Name = "StartLineBase"
	startLineBase.Anchored = true
	startLineBase.CanCollide = false
	startLineBase.Material = Enum.Material.SmoothPlastic
	startLineBase.Color = Color3.fromRGB(15, 18, 25)
	startLineBase.Size = Vector3.new(lineWidth, 0.15, lineLength)
	startLineBase.CFrame = startCFrame * CFrame.new(0, lineYOffset, 0)
	startLineBase.TopSurface = Enum.SurfaceType.Smooth
	startLineBase.Parent = startModel

	startModel.PrimaryPart = startLineBase

	local rows = 2
	local cols = 10
	local tileW = lineWidth / cols
	local tileL = lineLength / rows

	for r = 1, rows do
		for c = 1, cols do
			local isWhite = ((r + c) % 2 == 0)
			local offsetX = - (lineWidth / 2) + (c - 0.5) * tileW
			local offsetZ = - (lineLength / 2) + (r - 0.5) * tileL

			local tile = Instance.new("Part")
			tile.Name = "CheckerTile"
			tile.Anchored = true
			tile.CanCollide = false
			tile.Material = Enum.Material.SmoothPlastic
			tile.Color = isWhite and Color3.fromRGB(245, 245, 250) or Color3.fromRGB(25, 25, 30)
			tile.Size = Vector3.new(tileW, 0.18, tileL)
			tile.CFrame = startCFrame * CFrame.new(offsetX, lineYOffset + 0.02, offsetZ)
			tile.TopSurface = Enum.SurfaceType.Smooth
			tile.Parent = startModel
		end
	end

	local cyanBorderFront = Instance.new("Part")
	cyanBorderFront.Name = "CyanStartBorder"
	cyanBorderFront.Anchored = true
	cyanBorderFront.CanCollide = false
	cyanBorderFront.Material = Enum.Material.Neon
	cyanBorderFront.Color = Color3.fromRGB(0, 240, 255)
	cyanBorderFront.Size = Vector3.new(lineWidth, 0.2, 0.8)
	cyanBorderFront.CFrame = startCFrame * CFrame.new(0, lineYOffset + 0.03, (lineLength / 2) + 0.4)
	cyanBorderFront.Parent = startModel

	local cyanBorderBack = cyanBorderFront:Clone()
	cyanBorderBack.CFrame = startCFrame * CFrame.new(0, lineYOffset + 0.03, -(lineLength / 2) - 0.4)
	cyanBorderBack.Parent = startModel

	local archAheadZ = 24.0
	local archHeight = 28.0
	local pillarOffset = (lineWidth / 2) + 4.0
	local archCenterCFrame = startCFrame * CFrame.new(0, 0, archAheadZ)

	for _, sideX in ipairs({ -pillarOffset, pillarOffset }) do
		local pillar = Instance.new("Part")
		pillar.Name = "StartArchPillar"
		pillar.Anchored = true
		pillar.CanCollide = true
		pillar.Material = Enum.Material.Metal
		pillar.Color = Color3.fromRGB(40, 45, 55)
		pillar.Size = Vector3.new(5.0, archHeight, 6.0)
		pillar.CFrame = archCenterCFrame * CFrame.new(sideX, archHeight / 2, 0)
		pillar.Parent = startModel

		local neonStripe = Instance.new("Part")
		neonStripe.Name = "PillarNeonStripe"
		neonStripe.Anchored = true
		neonStripe.CanCollide = false
		neonStripe.Material = Enum.Material.Neon
		neonStripe.Color = Color3.fromRGB(0, 240, 255)
		neonStripe.Size = Vector3.new(5.2, archHeight - 4, 0.8)
		neonStripe.CFrame = archCenterCFrame * CFrame.new(sideX, archHeight / 2, -3.1)
		neonStripe.Parent = startModel
	end

	local beamLength = (pillarOffset * 2) + 6.0
	local beamCFrame = archCenterCFrame * CFrame.new(0, archHeight + 3, 0)

	local topBeam = Instance.new("Part")
	topBeam.Name = "StartArchTopBeam"
	topBeam.Anchored = true
	topBeam.CanCollide = true
	topBeam.Material = Enum.Material.SmoothPlastic
	topBeam.Color = Color3.fromRGB(20, 25, 35)
	topBeam.Size = Vector3.new(beamLength, 7.0, 7.0)
	topBeam.CFrame = beamCFrame
	topBeam.Parent = startModel

	local bannerFrame = Instance.new("Part")
	bannerFrame.Name = "BannerSignboard"
	bannerFrame.Anchored = true
	bannerFrame.CanCollide = false
	bannerFrame.Material = Enum.Material.SmoothPlastic
	bannerFrame.Color = Color3.fromRGB(10, 14, 22)
	bannerFrame.Size = Vector3.new(44.0, 6.5, 0.8)
	bannerFrame.CFrame = beamCFrame * CFrame.new(0, 0, -3.6)
	bannerFrame.Parent = startModel

	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Name = "StartSignGui"
	surfaceGui.Face = Enum.NormalId.Back
	surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surfaceGui.PixelsPerStud = 30
	surfaceGui.Parent = bannerFrame

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "TitleText"
	titleLabel.Size = UDim2.new(1, 0, 1, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.Text = "🏁 START POINT 🏁"
	titleLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	titleLabel.TextSize = 52
	titleLabel.ZIndex = 2
	titleLabel.Parent = surfaceGui

	local titleStroke = Instance.new("UIStroke")
	titleStroke.Color = Color3.fromRGB(0, 0, 0)
	titleStroke.Thickness = 3.0
	titleStroke.Parent = titleLabel

	local lightPodCFrame = beamCFrame * CFrame.new(0, -5.5, -3.6)
	local lightPod = Instance.new("Part")
	lightPod.Name = "SignalLightPod"
	lightPod.Anchored = true
	lightPod.CanCollide = false
	lightPod.Material = Enum.Material.SmoothPlastic
	lightPod.Color = Color3.fromRGB(15, 18, 24)
	lightPod.Size = Vector3.new(22.0, 5.0, 2.5)
	lightPod.CFrame = lightPodCFrame
	lightPod.Parent = startModel

	local signalColors = {
		{ name = "RedLight", color = Color3.fromRGB(255, 40, 40), offsetX = -6.5 },
		{ name = "YellowLight", color = Color3.fromRGB(255, 200, 30), offsetX = 0 },
		{ name = "GreenLight", color = Color3.fromRGB(40, 255, 80), offsetX = 6.5 },
	}

	for _, sig in ipairs(signalColors) do
		local lightPart = Instance.new("Part")
		lightPart.Name = sig.name
		lightPart.Anchored = true
		lightPart.CanCollide = false
		lightPart.Shape = Enum.PartType.Ball
		lightPart.Material = Enum.Material.Neon
		lightPart.Color = sig.color
		lightPart.Size = Vector3.new(3.8, 3.8, 3.8)
		lightPart.CFrame = lightPodCFrame * CFrame.new(sig.offsetX, 0, -0.6)
		lightPart.Parent = startModel

		local pLight = Instance.new("PointLight")
		pLight.Color = sig.color
		pLight.Brightness = 3.5
		pLight.Range = 14
		pLight.Parent = lightPart
	end

	-- 6. TrackStartGridPart
	local gridMarker = Instance.new("Part")
	gridMarker.Name = "TrackStartGridPart"
	gridMarker.Anchored = true
	gridMarker.CanCollide = false
	gridMarker.Transparency = 1.0
	gridMarker.Size = Vector3.new(TRACK_WIDTH - 16, 2, 10)
	gridMarker.CFrame = startCFrame * CFrame.new(0, 20.0, -3)
	gridMarker.Parent = mapModel

	mapModel.PrimaryPart = gridMarker
	optimizeMapCollisionFlags(mapModel)
	return mapModel
end

function MapBuilder.addStartingPointToMap(mapModel, startCFrame, trackWidth)
	local startModel = Instance.new("Model")
	startModel.Name = "StartingPoint"
	startModel.Parent = mapModel

	local lineLength = 12.0
	local lineWidth = trackWidth + 4.0
	local lineYOffset = 1.08

	local startLineBase = Instance.new("Part")
	startLineBase.Name = "StartLineBase"
	startLineBase.Anchored = true
	startLineBase.CanCollide = false
	startLineBase.Material = Enum.Material.SmoothPlastic
	startLineBase.Color = Color3.fromRGB(15, 18, 25)
	startLineBase.Size = Vector3.new(lineWidth, 0.15, lineLength)
	startLineBase.CFrame = startCFrame * CFrame.new(0, lineYOffset, 0)
	startLineBase.TopSurface = Enum.SurfaceType.Smooth
	startLineBase.Parent = startModel

	startModel.PrimaryPart = startLineBase

	local rows = 2
	local cols = 10
	local tileW = lineWidth / cols
	local tileL = lineLength / rows

	for r = 1, rows do
		for c = 1, cols do
			local isWhite = ((r + c) % 2 == 0)
			local offsetX = - (lineWidth / 2) + (c - 0.5) * tileW
			local offsetZ = - (lineLength / 2) + (r - 0.5) * tileL

			local tile = Instance.new("Part")
			tile.Name = "CheckerTile"
			tile.Anchored = true
			tile.CanCollide = false
			tile.Material = Enum.Material.SmoothPlastic
			tile.Color = isWhite and Color3.fromRGB(245, 245, 250) or Color3.fromRGB(25, 25, 30)
			tile.Size = Vector3.new(tileW, 0.18, tileL)
			tile.CFrame = startCFrame * CFrame.new(offsetX, lineYOffset + 0.02, offsetZ)
			tile.TopSurface = Enum.SurfaceType.Smooth
			tile.Parent = startModel
		end
	end

	local archAheadZ = 24.0
	local archHeight = 28.0
	local pillarOffset = (lineWidth / 2) + 4.0
	local archCenterCFrame = startCFrame * CFrame.new(0, 0, archAheadZ)

	for _, sideX in ipairs({ -pillarOffset, pillarOffset }) do
		local pillar = Instance.new("Part")
		pillar.Name = "StartArchPillar"
		pillar.Anchored = true
		pillar.CanCollide = true
		pillar.Material = Enum.Material.Metal
		pillar.Color = Color3.fromRGB(40, 45, 55)
		pillar.Size = Vector3.new(5.0, archHeight, 6.0)
		pillar.CFrame = archCenterCFrame * CFrame.new(sideX, archHeight / 2, 0)
		pillar.Parent = startModel
	end

	local beamLength = (pillarOffset * 2) + 6.0
	local beamCFrame = archCenterCFrame * CFrame.new(0, archHeight + 3, 0)

	local topBeam = Instance.new("Part")
	topBeam.Name = "StartArchTopBeam"
	topBeam.Anchored = true
	topBeam.CanCollide = true
	topBeam.Material = Enum.Material.SmoothPlastic
	topBeam.Color = Color3.fromRGB(20, 25, 35)
	topBeam.Size = Vector3.new(beamLength, 7.0, 7.0)
	topBeam.CFrame = beamCFrame
	topBeam.Parent = startModel

	local bannerFrame = Instance.new("Part")
	bannerFrame.Name = "BannerSignboard"
	bannerFrame.Anchored = true
	bannerFrame.CanCollide = false
	bannerFrame.Material = Enum.Material.SmoothPlastic
	bannerFrame.Color = Color3.fromRGB(10, 14, 22)
	bannerFrame.Size = Vector3.new(44.0, 6.5, 0.8)
	bannerFrame.CFrame = beamCFrame * CFrame.new(0, 0, -3.6)
	bannerFrame.Parent = startModel

	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Name = "StartSignGui"
	surfaceGui.Face = Enum.NormalId.Back
	surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surfaceGui.PixelsPerStud = 30
	surfaceGui.Parent = bannerFrame

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "TitleText"
	titleLabel.Size = UDim2.new(1, 0, 1, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.Text = "🏁 START POINT 🏁"
	titleLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	titleLabel.TextSize = 52
	titleLabel.ZIndex = 2
	titleLabel.Parent = surfaceGui

	local lightPodCFrame = beamCFrame * CFrame.new(0, -5.5, -3.6)
	local lightPod = Instance.new("Part")
	lightPod.Name = "SignalLightPod"
	lightPod.Anchored = true
	lightPod.CanCollide = false
	lightPod.Material = Enum.Material.SmoothPlastic
	lightPod.Color = Color3.fromRGB(15, 18, 24)
	lightPod.Size = Vector3.new(22.0, 5.0, 2.5)
	lightPod.CFrame = lightPodCFrame
	lightPod.Parent = startModel

	local signalColors = {
		{ name = "RedLight", color = Color3.fromRGB(255, 40, 40), offsetX = -6.5 },
		{ name = "YellowLight", color = Color3.fromRGB(255, 200, 30), offsetX = 0 },
		{ name = "GreenLight", color = Color3.fromRGB(40, 255, 80), offsetX = 6.5 },
	}

	for _, sig in ipairs(signalColors) do
		local lightPart = Instance.new("Part")
		lightPart.Name = sig.name
		lightPart.Anchored = true
		lightPart.CanCollide = false
		lightPart.Shape = Enum.PartType.Ball
		lightPart.Material = Enum.Material.Neon
		lightPart.Color = sig.color
		lightPart.Size = Vector3.new(3.8, 3.8, 3.8)
		lightPart.CFrame = lightPodCFrame * CFrame.new(sig.offsetX, 0, -0.6)
		lightPart.Parent = startModel

		local pLight = Instance.new("PointLight")
		pLight.Color = sig.color
		pLight.Brightness = 3.5
		pLight.Range = 14
		pLight.Parent = lightPart
	end
end

function MapBuilder.buildFrostGlacierModel(): Model
	local mapModel = Instance.new("Model")
	mapModel.Name = "Frost Glacier"

	local SEGMENTS = 260
	local RADIUS_X = 165
	local RADIUS_Z = 280
	local TRACK_WIDTH = 56
	local TRACK_THICKNESS = 2.5
	local BASE_Y = 25
	local AMP_Y = 16

	local function getPoint(t: number)
		local x = RADIUS_X * math.sin(2 * t)
		local z = RADIUS_Z * math.sin(t)
		local y = BASE_Y + AMP_Y * math.cos(t)
		
		local dx = 2 * RADIUS_X * math.cos(2 * t)
		local dz = RADIUS_Z * math.cos(t)
		local dy = -AMP_Y * math.sin(t)
		
		local pos = Vector3.new(x, y, z)
		local tangent = Vector3.new(dx, dy, dz).Unit
		local hNormal = Vector3.new(-tangent.Z, 0, tangent.X).Unit
		return pos, tangent, hNormal
	end

	local trackFolder = Instance.new("Folder")
	trackFolder.Name = "HoverboardTrack"
	trackFolder.Parent = mapModel

	local iceMaterial = Enum.Material.Glacier
	local roadColor = Color3.fromRGB(225, 245, 255)
	local curbColor = Color3.fromRGB(130, 215, 255)
	local neonCyan = Color3.fromRGB(80, 230, 255)
	local halfW = TRACK_WIDTH / 2

	for i = 1, SEGMENTS do
		local t1 = ((i - 1) / SEGMENTS) * math.pi * 2
		local t2 = (i / SEGMENTS) * math.pi * 2
		
		local p1, tan1 = getPoint(t1)
		local p2, tan2 = getPoint(t2)
		
		local center = (p1 + p2) / 2
		local segLen = (p2 - p1).Magnitude + 0.8
		local cf = CFrame.lookAt(center, p2)
		
		local road = Instance.new("Part")
		road.Name = "IceTrack_" .. i
		road.Anchored = true
		road.CanCollide = true
		road.Material = iceMaterial
		road.Color = roadColor
		road.Size = Vector3.new(TRACK_WIDTH, TRACK_THICKNESS, segLen)
		road.CFrame = cf
		road.TopSurface = Enum.SurfaceType.Smooth
		road.BottomSurface = Enum.SurfaceType.Smooth
		road.Parent = trackFolder
		
		local isBridge = (p1.Y > BASE_Y + 4)
		local barrierHeight = isBridge and 6.0 or 2.5
		
		for _, side in ipairs({ -1, 1 }) do
			local curb = Instance.new("Part")
			curb.Name = "IceBarrier"
			curb.Anchored = true
			curb.CanCollide = true
			curb.Material = Enum.Material.Glass
			curb.Transparency = 0.25
			curb.Color = curbColor
			curb.Size = Vector3.new(2, barrierHeight, segLen)
			curb.CFrame = cf * CFrame.new(side * (halfW - 1), (barrierHeight - TRACK_THICKNESS) / 2 + 0.5, 0)
			curb.Parent = trackFolder
			
			local neonLine = Instance.new("Part")
			neonLine.Name = "NeonEdge"
			neonLine.Anchored = true
			neonLine.CanCollide = false
			neonLine.Material = Enum.Material.Neon
			neonLine.Color = neonCyan
			neonLine.Size = Vector3.new(0.6, 0.4, segLen)
			neonLine.CFrame = cf * CFrame.new(side * (halfW - 1), barrierHeight + 0.2, 0)
			neonLine.Parent = trackFolder

			-- Invisible full-height guard wall to prevent jumping off bridges/curbs onto lower track
			local guardWall = Instance.new("Part")
			guardWall.Name = "TrackGuardWall"
			guardWall.Anchored = true
			guardWall.CanCollide = true
			guardWall.Transparency = 1
			guardWall.Size = Vector3.new(2, 28, segLen)
			guardWall.CFrame = cf * CFrame.new(side * (halfW - 1), 14, 0)
			guardWall.Parent = trackFolder
		end
		
		if math.floor(i / 3) % 2 == 0 then
			local centerNeon = Instance.new("Part")
			centerNeon.Name = "CenterNeon"
			centerNeon.Anchored = true
			centerNeon.CanCollide = false
			centerNeon.Material = Enum.Material.Neon
			centerNeon.Color = neonCyan
			centerNeon.Size = Vector3.new(1.2, 0.15, segLen)
			centerNeon.CFrame = cf * CFrame.new(0, (TRACK_THICKNESS / 2) + 0.08, 0)
			centerNeon.Parent = trackFolder
		end
	end

	local groundFolder = Instance.new("Folder")
	groundFolder.Name = "GroundFloor"
	groundFolder.Parent = mapModel

	-- Vast Base Snow Plain (Top at Y = 7, so tunnel at Y = 9 sits right on top seamlessly)
	local baseSnow = Instance.new("Part")
	baseSnow.Name = "GlacierSnowPlain"
	baseSnow.Anchored = true
	baseSnow.CanCollide = true
	baseSnow.Material = Enum.Material.Snow
	baseSnow.Color = Color3.fromRGB(240, 248, 255)
	baseSnow.Size = Vector3.new(620, 8, 800)
	baseSnow.Position = Vector3.new(0, 3, 0)
	baseSnow.TopSurface = Enum.SurfaceType.Smooth
	baseSnow.BottomSurface = Enum.SurfaceType.Smooth
	baseSnow.Parent = groundFolder

	-- Frozen Glacier Lakes in North and South loop infields
	for _, lakeData in ipairs({
		{ name = "FrozenLake_North", z = 200, size = Vector3.new(160, 0.6, 120) },
		{ name = "FrozenLake_South", z = -200, size = Vector3.new(160, 0.6, 120) },
	}) do
		local lake = Instance.new("Part")
		lake.Name = lakeData.name
		lake.Anchored = true
		lake.CanCollide = true
		lake.Material = Enum.Material.Glacier
		lake.Color = Color3.fromRGB(150, 230, 255)
		lake.Transparency = 0.12
		lake.Reflectance = 0.35
		lake.Size = lakeData.size
		lake.Position = Vector3.new(0, 7.2, lakeData.z)
		lake.TopSurface = Enum.SurfaceType.Smooth
		lake.BottomSurface = Enum.SurfaceType.Smooth
		lake.Parent = groundFolder
	end

	-- Mountain Ridges / Snow Mounds around Perimeter to frame the alpine valley
	local ridgeOffsets = {
		{ x = 0, z = 390, size = Vector3.new(450, 48, 80) },
		{ x = 0, z = -390, size = Vector3.new(450, 48, 80) },
		{ x = 300, z = 0, size = Vector3.new(80, 56, 750) },
		{ x = -300, z = 0, size = Vector3.new(80, 56, 750) },
		{ x = 240, z = 320, size = Vector3.new(120, 42, 120) },
		{ x = -240, z = 320, size = Vector3.new(120, 42, 120) },
		{ x = 240, z = -320, size = Vector3.new(120, 42, 120) },
		{ x = -240, z = -320, size = Vector3.new(120, 42, 120) },
	}
	for i, r in ipairs(ridgeOffsets) do
		local ridge = Instance.new("Part")
		ridge.Name = "SnowMountainRidge_" .. i
		ridge.Anchored = true
		ridge.CanCollide = true
		ridge.Material = Enum.Material.Snow
		ridge.Color = Color3.fromRGB(235, 245, 255)
		ridge.Size = r.size
		ridge.Position = Vector3.new(r.x, 7 + r.size.Y / 2 - 4, r.z)
		ridge.TopSurface = Enum.SurfaceType.Smooth
		ridge.BottomSurface = Enum.SurfaceType.Smooth
		ridge.Parent = groundFolder
	end

	local sceneryFolder = Instance.new("Folder")
	sceneryFolder.Name = "Scenery"
	sceneryFolder.Parent = mapModel

	-- Bridge ice pillars anchored into the ground (Y = 0 to 42)
	for _, offset in ipairs({
		Vector3.new(-38, 0, -25),
		Vector3.new(38, 0, -25),
		Vector3.new(-38, 0, 25),
		Vector3.new(38, 0, 25),
	}) do
		local pillar = Instance.new("Part")
		pillar.Name = "BridgeIcePillar"
		pillar.Anchored = true
		pillar.CanCollide = true
		pillar.Material = Enum.Material.Glacier
		pillar.Color = Color3.fromRGB(150, 225, 255)
		pillar.Size = Vector3.new(8, 42, 8)
		pillar.Position = Vector3.new(offset.X, 21, offset.Z)
		pillar.Parent = sceneryFolder
	end

	-- Pre-calculate track centerline 2D points for strict clearance checks
	local trackCenterPoints = {}
	for i = 1, SEGMENTS do
		local t = (i / SEGMENTS) * math.pi * 2
		local p = getPoint(t)
		table.insert(trackCenterPoints, Vector2.new(p.X, p.Z))
	end

	local function distToTrack(x: number, z: number): number
		local v = Vector2.new(x, z)
		local minDist = math.huge
		for _, tp in ipairs(trackCenterPoints) do
			local d = (v - tp).Magnitude
			if d < minDist then
				minDist = d
			end
		end
		return minDist
	end

	-- Helper: Create Snowy Pine Tree planted firmly on ground
	local function createSnowyPine(parent: Instance, pos: Vector3, scale: number?)
		scale = scale or 1.0
		local model = Instance.new("Model")
		model.Name = "SnowyPine"

		local trunkHeight = 16 * scale
		local trunkWidth = 3.6 * scale
		local groundY = 7.0 -- Base of trunk touches snow ground surface exactly

		local trunk = Instance.new("Part")
		trunk.Name = "Trunk"
		trunk.Anchored = true
		trunk.CanCollide = false
		trunk.Material = Enum.Material.Wood
		trunk.Color = Color3.fromRGB(80, 50, 35)
		trunk.Size = Vector3.new(trunkWidth, trunkHeight, trunkWidth)
		trunk.CFrame = CFrame.new(pos.X, groundY + trunkHeight / 2, pos.Z)
		trunk.TopSurface = Enum.SurfaceType.Smooth
		trunk.BottomSurface = Enum.SurfaceType.Smooth
		trunk.Parent = model

		model.PrimaryPart = trunk

		local tiers = {
			{ w = 22 * scale, h = 6 * scale, snowH = 2.4 * scale, yOff = 8 * scale },
			{ w = 16 * scale, h = 5.5 * scale, snowH = 2.0 * scale, yOff = 13.5 * scale },
			{ w = 10 * scale, h = 5 * scale, snowH = 1.8 * scale, yOff = 18.5 * scale },
		}

		for _, tier in ipairs(tiers) do
			local leaves = Instance.new("Part")
			leaves.Name = "PineLeaves"
			leaves.Anchored = true
			leaves.CanCollide = false
			leaves.Material = Enum.Material.Grass
			leaves.Color = Color3.fromRGB(30, 75, 50)
			leaves.Size = Vector3.new(tier.w, tier.h, tier.w)
			leaves.CFrame = CFrame.new(pos.X, groundY + tier.yOff + tier.h / 2, pos.Z)
			leaves.TopSurface = Enum.SurfaceType.Smooth
			leaves.BottomSurface = Enum.SurfaceType.Smooth
			leaves.Parent = model

			local snowCap = Instance.new("Part")
			snowCap.Name = "SnowCap"
			snowCap.Anchored = true
			snowCap.CanCollide = false
			snowCap.Material = Enum.Material.Snow
			snowCap.Color = Color3.fromRGB(248, 252, 255)
			snowCap.Size = Vector3.new(tier.w * 0.92, tier.snowH, tier.w * 0.92)
			snowCap.CFrame = CFrame.new(pos.X, groundY + tier.yOff + tier.h + tier.snowH / 2 - 0.2, pos.Z)
			snowCap.TopSurface = Enum.SurfaceType.Smooth
			snowCap.BottomSurface = Enum.SurfaceType.Smooth
			snowCap.Parent = model
		end

		model.Parent = parent
		return model
	end

	-- Helper: Create Glowing Ice Crystal
	local function createIceCrystal(parent: Instance, pos: Vector3, scale: number?, addLight: boolean?)
		local s = scale or 1.0
		local crystal = Instance.new("Part")
		crystal.Name = "IceCrystal"
		crystal.Anchored = true
		crystal.CanCollide = false
		crystal.Material = Enum.Material.Neon
		crystal.Color = Color3.fromRGB(80, 230, 255)
		crystal.Size = Vector3.new(3.5 * s, 14 * s, 3.5 * s)
		crystal.CFrame = CFrame.new(pos.X, 7 + (14 * s) / 2, pos.Z) * CFrame.Angles(math.rad(-8), math.rad(45), math.rad(6))
		crystal.TopSurface = Enum.SurfaceType.Smooth
		crystal.BottomSurface = Enum.SurfaceType.Smooth

		if addLight ~= false then
			local pLight = Instance.new("PointLight")
			pLight.Color = Color3.fromRGB(80, 230, 255)
			pLight.Brightness = 2.5
			pLight.Range = 28 * s
			pLight.Parent = crystal
		end

		crystal.Parent = parent
	end

	-- Place Snowy Pines with strict clearance check (min distance >= 44 studs from track centerline)
	local placedPines = {}
	local function tryPlacePine(x: number, z: number, scale: number?)
		if distToTrack(x, z) < 44 then return false end
		for _, prev in ipairs(placedPines) do
			if (Vector2.new(x, z) - prev).Magnitude < 21 then
				return false
			end
		end
		table.insert(placedPines, Vector2.new(x, z))
		createSnowyPine(sceneryFolder, Vector3.new(x, 7, z), scale)
		return true
	end

	-- Infield Groves (North Loop and South Loop)
	for _, centerZ in ipairs({ 200, -200 }) do
		for _, r in ipairs({ 22, 38, 54 }) do
			local n = math.floor(r * 0.45)
			for i = 1, n do
				local ang = (i / n) * math.pi * 2 + 0.35
				local px = r * math.cos(ang)
				local pz = centerZ + r * math.sin(ang)
				tryPlacePine(px, pz, 0.85 + (i % 3) * 0.15)
			end
		end
	end

	-- Flanking groves along the figure-8 perimeter
	for step = 1, 60 do
		local t = (step / 60) * math.pi * 2
		local p, tan = getPoint(t)
		local normal = Vector3.new(-tan.Z, 0, tan.X).Unit
		for _, offset in ipairs({ 55, 80 }) do
			for _, side in ipairs({ -1, 1 }) do
				local px = p.X + side * normal.X * offset
				local pz = p.Z + side * normal.Z * offset
				if math.abs(px) <= 265 and math.abs(pz) <= 365 then
					tryPlacePine(px, pz, 0.9 + ((step + side) % 4) * 0.12)
				end
			end
		end
	end

	-- Place Glowing Ice Crystals alongside track borders (at safe 43~65 studs)
	local crystalPlaced = 0
	for step = 1, 24 do
		local t = (step / 24) * math.pi * 2
		local p, tan = getPoint(t)
		local normal = Vector3.new(-tan.Z, 0, tan.X).Unit
		local side = (step % 2 == 0) and 1 or -1
		local cx = p.X + side * normal.X * 46
		local cz = p.Z + side * normal.Z * 46
		if distToTrack(cx, cz) >= 42 and math.abs(cx) <= 260 and math.abs(cz) <= 360 then
			createIceCrystal(sceneryFolder, Vector3.new(cx, 7, cz), 1.0 + (step % 3) * 0.25, (step % 2 == 0))
			crystalPlaced += 1
		end
	end

	local tunnelArchesFolder = Instance.new("Folder")
	tunnelArchesFolder.Name = "TunnelArches"
	tunnelArchesFolder.Parent = mapModel

	for i = 1, 16 do
		local t = math.pi + ((i - 8.5) / 16) * 0.45
		local p, tan = getPoint(t)
		local cf = CFrame.lookAt(p, p + tan)
		
		local arch = Instance.new("Part")
		arch.Name = "IceCaveArch_" .. i
		arch.Anchored = true
		arch.CanCollide = false
		arch.Material = Enum.Material.Glacier
		arch.Transparency = 0.3
		arch.Color = Color3.fromRGB(100, 200, 255)
		arch.Size = Vector3.new(TRACK_WIDTH + 14, 2, 6)
		arch.CFrame = cf * CFrame.new(0, 18, 0)
		arch.Parent = tunnelArchesFolder
		
		for _, side in ipairs({ -1, 1 }) do
			local wall = Instance.new("Part")
			wall.Name = "CaveWall"
			wall.Anchored = true
			wall.CanCollide = true
			wall.Material = Enum.Material.Glacier
			wall.Color = Color3.fromRGB(120, 210, 255)
			wall.Size = Vector3.new(6, 20, 6)
			wall.CFrame = cf * CFrame.new(side * (halfW + 5), 9, 0)
			wall.Parent = tunnelArchesFolder
		end
		
		if i % 3 == 0 then
			local pLight = Instance.new("PointLight")
			pLight.Color = Color3.fromRGB(100, 220, 255)
			pLight.Brightness = 4.0
			pLight.Range = 40
			pLight.Parent = arch
		end
	end

	local startT = 1.85 * math.pi
	local startPos, startTan = getPoint(startT)
	local flatForward = Vector3.new(startTan.X, 0, startTan.Z).Unit
	-- +Z (-LookVector) of startCFrame points along +flatForward (towards Start Arch, Bridge, and Checkpoint 1)
	local startCFrame = CFrame.lookAt(startPos, startPos - flatForward)

	local cpFolder = Instance.new("Folder")
	cpFolder.Name = "Checkpoints"
	cpFolder.Parent = mapModel

	local cpIndices = {
		{ name = "1", t = 0.20 * math.pi }, -- Bridge descent into North loop
		{ name = "2", t = 0.50 * math.pi }, -- North loop far apex (Z = +280)
		{ name = "3", t = 0.80 * math.pi }, -- North loop exit heading into Tunnel
		{ name = "4", t = 1.20 * math.pi }, -- Tunnel exit into South loop
		{ name = "5", t = 1.50 * math.pi }, -- South loop far apex (Z = -280)
		{ name = "6", t = 1.85 * math.pi }, -- EXACTLY AT START/FINISH LINE ARCH!
	}

	for _, cpData in ipairs(cpIndices) do
		local p, tan = getPoint(cpData.t)
		local cf = CFrame.lookAt(p, p + tan)
		
		local cpPart = Instance.new("Part")
		cpPart.Name = cpData.name
		cpPart.Anchored = true
		cpPart.CanCollide = false
		cpPart.Transparency = 1
		cpPart.Size = Vector3.new(TRACK_WIDTH + 10, 20, 20)
		cpPart.CFrame = cf * CFrame.new(0, 10, 0)
		cpPart.Parent = cpFolder
	end

	-- +Z of startCFrame points along the track forward direction (aligned with Start Arch and GameLoopManager's -90° yaw offset)
	local startGrid = Instance.new("Part")
	startGrid.Name = "TrackStartGridPart"
	startGrid.Anchored = true
	startGrid.CanCollide = false
	startGrid.Transparency = 1
	startGrid.Size = Vector3.new(TRACK_WIDTH, 2, 10)
	startGrid.CFrame = startCFrame * CFrame.new(0, 1.5, -3)
	startGrid.Parent = mapModel

	MapBuilder.addStartingPointToMap(mapModel, startCFrame, TRACK_WIDTH)

	optimizeMapCollisionFlags(mapModel)
	return mapModel
end

return MapBuilder
