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

local function createFallbackPine(parent: Instance, pos: Vector3, groundY: number, scale: number, snowy: boolean): Model
	local model = Instance.new("Model")
	model.Name = snowy and "SnowyPine" or "HighwayPine"

	local trunkHeight = 16 * scale
	local trunkWidth = 3.6 * scale

	local trunk = Instance.new("Part")
	trunk.Name = "Trunk"
	trunk.Anchored = true
	trunk.CanCollide = false
	trunk.CanTouch = false
	trunk.CanQuery = false
	trunk.CastShadow = false
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
		leaves.CanTouch = false
		leaves.CanQuery = false
		leaves.CastShadow = false
		leaves.Material = Enum.Material.Grass
		leaves.Color = snowy and Color3.fromRGB(30, 75, 50) or Color3.fromRGB(36, 92, 48)
		leaves.Size = Vector3.new(tier.w, tier.h, tier.w)
		leaves.CFrame = CFrame.new(pos.X, groundY + tier.yOff + tier.h / 2, pos.Z)
		leaves.TopSurface = Enum.SurfaceType.Smooth
		leaves.BottomSurface = Enum.SurfaceType.Smooth
		leaves.Parent = model

		if snowy then
			local snowCap = Instance.new("Part")
			snowCap.Name = "SnowCap"
			snowCap.Anchored = true
			snowCap.CanCollide = false
			snowCap.CanTouch = false
			snowCap.CanQuery = false
			snowCap.CastShadow = false
			snowCap.Material = Enum.Material.Snow
			snowCap.Color = Color3.fromRGB(248, 252, 255)
			snowCap.Size = Vector3.new(tier.w * 0.92, tier.snowH, tier.w * 0.92)
			snowCap.CFrame = CFrame.new(pos.X, groundY + tier.yOff + tier.h + tier.snowH / 2 - 0.2, pos.Z)
			snowCap.TopSurface = Enum.SurfaceType.Smooth
			snowCap.BottomSurface = Enum.SurfaceType.Smooth
			snowCap.Parent = model
		end
	end

	model.Parent = parent
	return model
end

local function placeScaledAssetModel(template: Model, parent: Instance, name: string, pos: Vector3, groundY: number, relativeScale: number, yawRad: number): Model
	local clone = template:Clone()
	clone.Name = name
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			d.CastShadow = false
		end
	end

	-- Normalize pivot to upright world orientation before scaling/rotating so tilted PrimaryParts never knock trees sideways
	clone.PrimaryPart = nil
	clone.WorldPivot = CFrame.new(clone:GetPivot().Position)

	local baseScale = clone:GetScale()
	clone:ScaleTo(baseScale * relativeScale)

	local currentPivot = clone:GetPivot()
	clone:PivotTo(CFrame.new(pos.X, currentPivot.Position.Y, pos.Z) * CFrame.Angles(0, yawRad, 0))

	local bbCf, bbSize = clone:GetBoundingBox()
	local bottomY = bbCf.Position.Y - (bbSize.Y / 2)
	local shift = Vector3.new(pos.X - bbCf.Position.X, groundY - bottomY, pos.Z - bbCf.Position.Z)
	local alignedPivot = clone:GetPivot()
	clone:PivotTo(CFrame.new(alignedPivot.Position + shift) * alignedPivot.Rotation)

	clone.Parent = parent
	return clone
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
	baseSnow.Size = Vector3.new(760, 8, 920)
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

	-- Helpers for placing Studio tree asset templates and procedural fallback pines
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local treeTemplates = ReplicatedStorage:FindFirstChild("TreeTemplates")

	local forestTemplateSpecs = {
		{ name = "Tree_8999194306", minScale = 1.50, maxScale = 1.95 },
		{ name = "Tree_24715381", minScale = 2.60, maxScale = 3.30 },
		{ name = "Tree_15692092527", minScale = 2.50, maxScale = 3.20 },
	}

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

	-- Central Giant Landmark Christmas Tree (visible from all around the figure-8 track)
	local centerTreePos = Vector3.new(-120, 6.6, 0)
	local treePedestal = Instance.new("Part")
	treePedestal.Name = "ChristmasTreePedestal"
	treePedestal.Shape = Enum.PartType.Cylinder
	treePedestal.Anchored = true
	treePedestal.CanCollide = true
	treePedestal.Material = Enum.Material.Glacier
	treePedestal.Color = Color3.fromRGB(180, 240, 255)
	treePedestal.Size = Vector3.new(2.0, 56, 56)
	treePedestal.CFrame = CFrame.new(centerTreePos.X, 7.0, centerTreePos.Z) * CFrame.Angles(0, 0, math.rad(90))
	treePedestal.Parent = sceneryFolder

	local treeGlow = Instance.new("PointLight")
	treeGlow.Color = Color3.fromRGB(255, 220, 140)
	treeGlow.Brightness = 2.5
	treeGlow.Range = 60
	treeGlow.Parent = treePedestal

	local xmasTemplate = treeTemplates and treeTemplates:FindFirstChild("ChristmasTree_80754396112093")
	if xmasTemplate and xmasTemplate:IsA("Model") then
		placeScaledAssetModel(xmasTemplate, sceneryFolder, "GiantChristmasTree", centerTreePos, 7.5, 5.0, 0)
	end

	-- Place mixed asset forest with strict clearance (distToTrack >= 56, clear of central landmark)
	local placedTrees: { Vector2 } = {}
	local treeCount = 0
	local centerTreeXZ = Vector2.new(centerTreePos.X, centerTreePos.Z)
	local maxForestTrees = 95

	local function tryPlaceTree(x: number, z: number)
		if treeCount >= maxForestTrees then return false end
		if distToTrack(x, z) < 56 then return false end
		local candidateXZ = Vector2.new(x, z)
		if (candidateXZ - centerTreeXZ).Magnitude < 68 then
			return false
		end
		for _, prev in ipairs(placedTrees) do
			if (candidateXZ - prev).Magnitude < 36 then
				return false
			end
		end

		table.insert(placedTrees, candidateXZ)
		treeCount += 1

		local specIdx = ((treeCount - 1) % #forestTemplateSpecs) + 1
		local spec = forestTemplateSpecs[specIdx]
		local frac = ((treeCount * 37) % 100) / 100
		local relScale = spec.minScale + (spec.maxScale - spec.minScale) * frac
		local yawRad = math.rad((treeCount * 53) % 360)

		local template = treeTemplates and treeTemplates:FindFirstChild(spec.name)
		if template and template:IsA("Model") then
			placeScaledAssetModel(template, sceneryFolder, spec.name, Vector3.new(x, 6.6, z), 6.6, relScale, yawRad)
		else
			createFallbackPine(sceneryFolder, Vector3.new(x, 6.6, z), 6.6, relScale, true)
		end
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
				tryPlaceTree(px, pz)
			end
		end
	end

	-- Flanking groves along the figure-8 perimeter
	for step = 1, 60 do
		local t = (step / 60) * math.pi * 2
		local p, tan = getPoint(t)
		local normal = Vector3.new(-tan.Z, 0, tan.X).Unit
		for _, offset in ipairs({ 64, 96, 128 }) do
			for _, side in ipairs({ -1, 1 }) do
				local px = p.X + side * normal.X * offset
				local pz = p.Z + side * normal.Z * offset
				if math.abs(px) <= 340 and math.abs(pz) <= 430 then
					tryPlaceTree(px, pz)
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

	-- Snow Weather Canopy (from SnowEmitter_15528629762 template, covering track & valley)
	local snowWeatherFolder = Instance.new("Folder")
	snowWeatherFolder.Name = "SnowWeather"
	snowWeatherFolder.Parent = sceneryFolder

	local snowTemplatePart = treeTemplates and treeTemplates:FindFirstChild("SnowEmitter_15528629762")
	local snowTemplateEmitter = snowTemplatePart and snowTemplatePart:FindFirstChildWhichIsA("ParticleEmitter", true)

	local function spawnSnowCanopy(parent: Instance, name: string, centerPos: Vector3, boxSize: Vector3, emitterCount: number, ratePerEmitter: number)
		local canopy = Instance.new("Part")
		canopy.Name = name
		canopy.Anchored = true
		canopy.CanCollide = false
		canopy.CanTouch = false
		canopy.CanQuery = false
		canopy.CastShadow = false
		canopy.Transparency = 1
		canopy.Size = boxSize
		-- Match asset 15528629762's 180-deg Z flip so Enum.NormalId.Top emits downward along world -Y
		canopy.CFrame = CFrame.new(centerPos) * CFrame.Angles(0, 0, math.pi)
		canopy.Parent = parent

		for idx = 1, emitterCount do
			local emitter: ParticleEmitter
			if snowTemplateEmitter and snowTemplateEmitter:IsA("ParticleEmitter") then
				emitter = snowTemplateEmitter:Clone()
			else
				emitter = Instance.new("ParticleEmitter")
			end
			emitter.Name = "SnowFlakeEmitter_" .. idx
			emitter.Texture = "rbxassetid://118641183"
			emitter.Color = ColorSequence.new(Color3.new(1, 1, 1))
			emitter.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.05),
				NumberSequenceKeypoint.new(0.85, 0.05),
				NumberSequenceKeypoint.new(1, 1),
			})
			emitter.Size = NumberSequence.new((idx % 2 == 0) and 0.22 or 0.42)
			emitter.Lifetime = NumberRange.new(6, 12)
			emitter.Rate = ratePerEmitter
			emitter.Speed = NumberRange.new(6, 10)
			emitter.SpreadAngle = Vector2.new(10, 10)
			emitter.Acceleration = Vector3.new(0, 0, 0)
			emitter.EmissionDirection = Enum.NormalId.Top
			emitter.LockedToPart = false
			emitter.Enabled = true
			emitter.Parent = canopy
		end
	end

	for i = 1, 14 do
		local t = ((i - 1) / 14) * math.pi * 2
		local p = getPoint(t)
		spawnSnowCanopy(
			snowWeatherFolder,
			"SnowEmitterPart_Track_" .. i,
			p + Vector3.new(0, 26, 0),
			Vector3.new(105, 24, 105),
			6,
			24
		)
	end

	local valleyCanopies = {
		{ name = "SnowEmitterPart_Valley_1", pos = Vector3.new(-120, 95, 0), size = Vector3.new(160, 28, 160), rate = 25 },
		{ name = "SnowEmitterPart_Valley_2", pos = Vector3.new(0, 60, 200), size = Vector3.new(180, 24, 180), rate = 24 },
		{ name = "SnowEmitterPart_Valley_3", pos = Vector3.new(0, 60, -200), size = Vector3.new(180, 24, 180), rate = 24 },
		{ name = "SnowEmitterPart_Valley_4", pos = Vector3.new(0, 68, 0), size = Vector3.new(160, 24, 160), rate = 24 },
	}
	for _, vc in ipairs(valleyCanopies) do
		spawnSnowCanopy(snowWeatherFolder, vc.name, vc.pos, vc.size, 6, vc.rate)
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

function MapBuilder.buildAutobahnHighwayModel(): Model
	local mapModel = Instance.new("Model")
	mapModel.Name = "Autobahn Highway"

	local TRACK_WIDTH = 84
	local halfW = TRACK_WIDTH / 2
	local TRACK_THICKNESS = 3.0
	local SEG_LEN = 50
	local START_STEP = -2  -- Z = +100 (pre-start apron)
	local END_STEP = 125   -- Z = -6300 (post-finish braking runoff)

	local function getHighwayY(z: number): number
		if z >= -1200 then
			return 8.0
		elseif z >= -2400 then
			return 8.0 + 14.0 * (1 - math.cos(((z + 1200) / -1200) * math.pi * 2))
		elseif z >= -3600 then
			return 8.0
		elseif z >= -4800 then
			return 8.0 + 6.0 * (1 - math.cos(((z + 3600) / -1200) * math.pi * 2))
		else
			return 8.0
		end
	end

	-- 1. Straight 6-Lane Autobahn Track (0 curves, along -Z)
	local trackFolder = Instance.new("Folder")
	trackFolder.Name = "HoverboardTrack"
	trackFolder.Parent = mapModel

	local roadColor = Color3.fromRGB(36, 39, 46)
	local yellowCenterColor = Color3.fromRGB(255, 195, 30)
	local whiteLineColor = Color3.fromRGB(240, 244, 250)
	local railMetalColor = Color3.fromRGB(165, 175, 190)
	local railNeonColor = Color3.fromRGB(0, 210, 255)

	for step = START_STEP, END_STEP do
		local z1 = -(step * SEG_LEN)
		local z2 = -((step + 1) * SEG_LEN)
		local p1 = Vector3.new(0, getHighwayY(z1), z1)
		local p2 = Vector3.new(0, getHighwayY(z2), z2)
		local midPos = (p1 + p2) * 0.5
		local segLen = (p2 - p1).Magnitude + 0.6
		local cf = CFrame.lookAt(midPos, p2)

		local road = Instance.new("Part")
		road.Name = "HighwaySegment_" .. (step - START_STEP + 1)
		road.Anchored = true
		road.CanCollide = true
		road.Material = Enum.Material.Asphalt
		road.Color = roadColor
		road.Size = Vector3.new(TRACK_WIDTH, TRACK_THICKNESS, segLen)
		road.CFrame = cf
		road.TopSurface = Enum.SurfaceType.Smooth
		road.BottomSurface = Enum.SurfaceType.Smooth
		road.Parent = trackFolder

		local lineY = (TRACK_THICKNESS / 2) + 0.06

		-- Double amber center divider lines
		for _, cx in ipairs({ -0.8, 0.8 }) do
			local centerLine = Instance.new("Part")
			centerLine.Name = "CenterDividerLine"
			centerLine.Anchored = true
			centerLine.CanCollide = false
			centerLine.Material = Enum.Material.SmoothPlastic
			centerLine.Color = yellowCenterColor
			centerLine.Size = Vector3.new(0.7, 0.12, segLen)
			centerLine.CFrame = cf * CFrame.new(cx, lineY, 0)
			centerLine.TopSurface = Enum.SurfaceType.Smooth
			centerLine.Parent = trackFolder
		end

		-- Solid white outer shoulder lines
		for _, sx in ipairs({ -39, 39 }) do
			local shoulderLine = Instance.new("Part")
			shoulderLine.Name = "ShoulderLine"
			shoulderLine.Anchored = true
			shoulderLine.CanCollide = false
			shoulderLine.Material = Enum.Material.SmoothPlastic
			shoulderLine.Color = whiteLineColor
			shoulderLine.Size = Vector3.new(0.8, 0.12, segLen)
			shoulderLine.CFrame = cf * CFrame.new(sx, lineY, 0)
			shoulderLine.TopSurface = Enum.SurfaceType.Smooth
			shoulderLine.Parent = trackFolder
		end

		-- Dashed white 6-lane dividers
		if step % 2 == 0 then
			for _, lx in ipairs({ -26, -13, 13, 26 }) do
				local laneDash = Instance.new("Part")
				laneDash.Name = "LaneDash"
				laneDash.Anchored = true
				laneDash.CanCollide = false
				laneDash.Material = Enum.Material.SmoothPlastic
				laneDash.Color = whiteLineColor
				laneDash.Size = Vector3.new(0.55, 0.12, segLen * 0.55)
				laneDash.CFrame = cf * CFrame.new(lx, lineY, 0)
				laneDash.TopSurface = Enum.SurfaceType.Smooth
				laneDash.Parent = trackFolder
			end
		end

		-- Guardrails + glowing edge neon + invisible containment wall
		for _, side in ipairs({ -1, 1 }) do
			local rail = Instance.new("Part")
			rail.Name = "GuardRail"
			rail.Anchored = true
			rail.CanCollide = true
			rail.Material = Enum.Material.Metal
			rail.Color = railMetalColor
			rail.Size = Vector3.new(2.0, 4.0, segLen)
			rail.CFrame = cf * CFrame.new(side * (halfW - 1), 2.0, 0)
			rail.Parent = trackFolder

			local railNeon = Instance.new("Part")
			railNeon.Name = "GuardRailNeon"
			railNeon.Anchored = true
			railNeon.CanCollide = false
			railNeon.Material = Enum.Material.Neon
			railNeon.Color = railNeonColor
			railNeon.Size = Vector3.new(0.5, 0.45, segLen)
			railNeon.CFrame = cf * CFrame.new(side * (halfW - 1), 4.15, 0)
			railNeon.Parent = trackFolder

			local guardWall = Instance.new("Part")
			guardWall.Name = "TrackGuardWall"
			guardWall.Anchored = true
			guardWall.CanCollide = true
			guardWall.Transparency = 1
			guardWall.Size = Vector3.new(2.0, 28, segLen)
			guardWall.CFrame = cf * CFrame.new(side * (halfW - 1), 14, 0)
			guardWall.Parent = trackFolder
		end
	end

	-- 2. Ground & Water Channel (Contiguous Zones: +200..-3600 Grass, -3600..-4800 Water, -4800..-6500 City)
	local groundFolder = Instance.new("Folder")
	groundFolder.Name = "GroundFloor"
	groundFolder.Parent = mapModel

	local grassPlain1 = Instance.new("Part")
	grassPlain1.Name = "AutobahnGrassPlain_1"
	grassPlain1.Anchored = true
	grassPlain1.CanCollide = true
	grassPlain1.Material = Enum.Material.Grass
	grassPlain1.Color = Color3.fromRGB(48, 95, 52)
	grassPlain1.Size = Vector3.new(900, 8, 1950)
	grassPlain1.Position = Vector3.new(0, 2, -725) -- Covers Z = +250 to -1700 (stay within 2048 axis cap)
	grassPlain1.TopSurface = Enum.SurfaceType.Smooth
	grassPlain1.Parent = groundFolder

	local grassPlain2 = Instance.new("Part")
	grassPlain2.Name = "AutobahnGrassPlain_2"
	grassPlain2.Anchored = true
	grassPlain2.CanCollide = true
	grassPlain2.Material = Enum.Material.Grass
	grassPlain2.Color = Color3.fromRGB(48, 95, 52)
	grassPlain2.Size = Vector3.new(900, 8, 1900)
	grassPlain2.Position = Vector3.new(0, 2, -2650) -- Covers Z = -1700 to -3600
	grassPlain2.TopSurface = Enum.SurfaceType.Smooth
	grassPlain2.Parent = groundFolder

	local waterChannel = Instance.new("Part")
	waterChannel.Name = "SuspensionBridgeChannel"
	waterChannel.Anchored = true
	waterChannel.CanCollide = true
	waterChannel.Material = Enum.Material.Glass
	waterChannel.Color = Color3.fromRGB(25, 105, 175)
	waterChannel.Reflectance = 0.25
	waterChannel.Size = Vector3.new(900, 6, 1200)
	waterChannel.Position = Vector3.new(0, 1, -4200)
	waterChannel.TopSurface = Enum.SurfaceType.Smooth
	waterChannel.Parent = groundFolder

	local cityPlain = Instance.new("Part")
	cityPlain.Name = "AutobahnCityPlain_End"
	cityPlain.Anchored = true
	cityPlain.CanCollide = true
	cityPlain.Material = Enum.Material.Concrete
	cityPlain.Color = Color3.fromRGB(45, 50, 58)
	cityPlain.Size = Vector3.new(900, 8, 1700)
	cityPlain.Position = Vector3.new(0, 2, -5650)
	cityPlain.TopSurface = Enum.SurfaceType.Smooth
	cityPlain.Parent = groundFolder

	-- 3. Scenery & Zone Landmarks
	local sceneryFolder = Instance.new("Folder")
	sceneryFolder.Name = "Scenery"
	sceneryFolder.Parent = mapModel

	-- Helper: Autobahn Overhead Sign Gantry (top/bottom support trusses keep signboard completely unobstructed)
	local function createHighwayGantry(zPos: number, text: string, signColor: Color3)
		local roadY = getHighwayY(zPos)
		local isTunnel = (zPos <= -2450 and zPos >= -3550)
		local boardW = isTunnel and 72 or 76
		local boardH = isTunnel and 11 or 14
		local boardCenterY = isTunnel and (roadY + 21.5) or (roadY + 27.5)
		local topBeamY = boardCenterY + boardH / 2 + 1.0
		local botBeamY = boardCenterY - boardH / 2 - 1.0
		local pillarX = isTunnel and 41 or 46
		local pillarH = (topBeamY - roadY) + 3.0

		for _, sideX in ipairs({ -pillarX, pillarX }) do
			local pillar = Instance.new("Part")
			pillar.Name = "GantryPillar"
			pillar.Anchored = true
			pillar.CanCollide = false
			pillar.Material = Enum.Material.Metal
			pillar.Color = Color3.fromRGB(150, 160, 175)
			pillar.Size = Vector3.new(3.5, pillarH, 3.5)
			pillar.Position = Vector3.new(sideX, roadY + pillarH / 2 - 2, zPos)
			pillar.Parent = sceneryFolder
		end

		local beamW = (pillarX * 2) + 4
		for _, beamY in ipairs({ topBeamY, botBeamY }) do
			local truss = Instance.new("Part")
			truss.Name = "GantryBeam"
			truss.Anchored = true
			truss.CanCollide = false
			truss.Material = Enum.Material.Metal
			truss.Color = Color3.fromRGB(130, 140, 155)
			truss.Size = Vector3.new(beamW, 2.0, 2.5)
			truss.Position = Vector3.new(0, beamY, zPos)
			truss.Parent = sceneryFolder
		end

		local border = Instance.new("Part")
		border.Name = "GantrySignBorder"
		border.Anchored = true
		border.CanCollide = false
		border.Material = Enum.Material.Neon
		border.Color = Color3.fromRGB(235, 245, 255)
		border.Size = Vector3.new(boardW + 1.6, boardH + 1.6, 2.6)
		border.Position = Vector3.new(0, boardCenterY, zPos)
		border.Parent = sceneryFolder

		local board = Instance.new("Part")
		board.Name = "HighwaySignboard"
		board.Anchored = true
		board.CanCollide = false
		board.Material = Enum.Material.SmoothPlastic
		board.Color = signColor
		board.Size = Vector3.new(boardW, boardH, 3.2)
		board.Position = Vector3.new(0, boardCenterY, zPos)
		board.Parent = sceneryFolder

		for _, face in ipairs({ Enum.NormalId.Back, Enum.NormalId.Front }) do
			local gui = Instance.new("SurfaceGui")
			gui.Name = "SignGui_" .. face.Name
			gui.Face = face
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.PixelsPerStud = 20
			gui.Parent = board

			local pad = Instance.new("UIPadding")
			pad.PaddingLeft = UDim.new(0.04, 0)
			pad.PaddingRight = UDim.new(0.04, 0)
			pad.PaddingTop = UDim.new(0.08, 0)
			pad.PaddingBottom = UDim.new(0.08, 0)
			pad.Parent = gui

			local label = Instance.new("TextLabel")
			label.Size = UDim2.new(1, 0, 1, 0)
			label.BackgroundTransparency = 1
			label.Font = Enum.Font.GothamBlack
			label.Text = text
			label.TextColor3 = Color3.fromRGB(255, 255, 255)
			label.TextScaled = true
			label.Parent = gui

			local tStroke = Instance.new("UIStroke")
			tStroke.Color = Color3.fromRGB(0, 0, 0)
			tStroke.Thickness = 4
			tStroke.Parent = label
		end
	end

	createHighwayGantry(-90, "🛣️ AUTOBAHN A1\nNO SPEED LIMIT ∞", Color3.fromRGB(14, 78, 168))
	createHighwayGantry(-1000, "📍 CHECKPOINT 1\n5,000m TO FINISH", Color3.fromRGB(18, 110, 62))
	createHighwayGantry(-2000, "📍 CHECKPOINT 2\n4,000m TO FINISH", Color3.fromRGB(18, 110, 62))
	createHighwayGantry(-3000, "📍 CHECKPOINT 3\nHALFWAY 3,000m", Color3.fromRGB(20, 100, 145))
	createHighwayGantry(-4000, "📍 CHECKPOINT 4\n2,000m TO FINISH", Color3.fromRGB(165, 65, 25))
	createHighwayGantry(-5000, "📍 CHECKPOINT 5\nFINAL 1,000m SPRINT 🔥", Color3.fromRGB(165, 35, 70))

	-- Dual-Arm LED Streetlights every 200 studs outside tunnel (skipping gantry positions so poles never block signs)
	for z = 0, -5950, -200 do
		local isNearGantry = (z == -1000 or z == -2000 or z == -3000 or z == -4000 or z == -5000)
		if not isNearGantry and (z > -2450 or z < -3550) then
			local roadY = getHighwayY(z)
			for _, side in ipairs({ -1, 1 }) do
				local pole = Instance.new("Part")
				pole.Name = "HighwayLightPole"
				pole.Anchored = true
				pole.CanCollide = false
				pole.Material = Enum.Material.Metal
				pole.Color = Color3.fromRGB(120, 130, 145)
				pole.Size = Vector3.new(1.2, 22, 1.2)
				pole.Position = Vector3.new(side * 44, roadY + 11, z)
				pole.Parent = sceneryFolder

				local arm = Instance.new("Part")
				arm.Name = "HighwayLightArm"
				arm.Anchored = true
				arm.CanCollide = false
				arm.Material = Enum.Material.Metal
				arm.Color = Color3.fromRGB(120, 130, 145)
				arm.Size = Vector3.new(8, 0.8, 1.0)
				arm.Position = Vector3.new(side * 40, roadY + 22, z)
				arm.Parent = sceneryFolder

				local lamp = Instance.new("Part")
				lamp.Name = "HighwayLamp"
				lamp.Anchored = true
				lamp.CanCollide = false
				lamp.Material = Enum.Material.Neon
				lamp.Color = Color3.fromRGB(255, 240, 200)
				lamp.Size = Vector3.new(3.5, 0.6, 1.4)
				lamp.Position = Vector3.new(side * 37, roadY + 21.5, z)
				lamp.Parent = sceneryFolder
			end
		end
	end

	-- Zone 2 Overpass Support Piers (Z = -1350 to -2250)
	for z = -1350, -2250, -150 do
		local roadY = getHighwayY(z)
		local pierH = math.max(4, roadY - 4)
		for _, px in ipairs({ -28, 28 }) do
			local pier = Instance.new("Part")
			pier.Name = "OverpassPier"
			pier.Anchored = true
			pier.CanCollide = false
			pier.Material = Enum.Material.Concrete
			pier.Color = Color3.fromRGB(135, 142, 152)
			pier.Size = Vector3.new(7, pierH, 7)
			pier.Position = Vector3.new(px, 4 + pierH / 2, z)
			pier.Parent = sceneryFolder
		end
	end

	-- Zone 1 & Zone 2 Dense Lush Forest (Z = +80 to -2380 at X = ±72, ±110, ±152)
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local treeTemplates = ReplicatedStorage:FindFirstChild("TreeTemplates")
	local highwayTreeSpecs = {
		{ name = "Tree_4893246329", minScale = 1.90, maxScale = 2.60 },
		{ name = "Tree_12549617200", minScale = 1.25, maxScale = 1.70 },
		{ name = "Tree_10707210767", minScale = 1.25, maxScale = 1.70 },
		{ name = "Tree_16092857863", minScale = 2.90, maxScale = 3.90 },
	}
	local treeIdx = 0
	for z = 80, -2380, -95 do
		for _, xOff in ipairs({ 72, 110, 152 }) do
			for _, side in ipairs({ -1, 1 }) do
				treeIdx += 1
				local spec = highwayTreeSpecs[((treeIdx - 1) % #highwayTreeSpecs) + 1]
				local frac = ((treeIdx * 41) % 100) / 100
				local relScale = spec.minScale + (spec.maxScale - spec.minScale) * frac
				local yawRad = math.rad((treeIdx * 57) % 360)
				local jitterX = ((treeIdx * 19) % 17) - 8
				local jitterZ = ((treeIdx * 29) % 45) - 22
				local distFromCenter = math.max(64, xOff + jitterX)
				local px = side * distFromCenter
				local pz = z + jitterZ
				local template = treeTemplates and treeTemplates:FindFirstChild(spec.name)
				if template and template:IsA("Model") then
					placeScaledAssetModel(template, sceneryFolder, spec.name, Vector3.new(px, 6.0, pz), 6.0, relScale, yawRad)
				else
					createFallbackPine(sceneryFolder, Vector3.new(px, 6.0, pz), 6.0, relScale, false)
				end
			end
		end
	end

	-- Zone 3: High-Speed Mountain Neon Tunnel (Z = -2450 to -3550)
	local tunnelLength = 1100
	local tunnelCenterZ = -3000
	for _, side in ipairs({ -1, 1 }) do
		local tWall = Instance.new("Part")
		tWall.Name = "TunnelWall"
		tWall.Anchored = true
		tWall.CanCollide = true
		tWall.Material = Enum.Material.Concrete
		tWall.Color = Color3.fromRGB(45, 50, 60)
		tWall.Size = Vector3.new(8, 34, tunnelLength)
		tWall.Position = Vector3.new(side * 46, 23, tunnelCenterZ)
		tWall.Parent = sceneryFolder

		-- Outer mountain hillside casing flanking tunnel
		local hill = Instance.new("Part")
		hill.Name = "TunnelMountainRidge"
		hill.Anchored = true
		hill.CanCollide = false
		hill.Material = Enum.Material.Rock
		hill.Color = Color3.fromRGB(72, 78, 86)
		hill.Size = Vector3.new(80, 52, tunnelLength)
		hill.Position = Vector3.new(side * 90, 26, tunnelCenterZ)
		hill.Parent = sceneryFolder
	end

	local tCeiling = Instance.new("Part")
	tCeiling.Name = "TunnelCeiling"
	tCeiling.Anchored = true
	tCeiling.CanCollide = true
	tCeiling.Material = Enum.Material.Slate
	tCeiling.Color = Color3.fromRGB(40, 44, 54)
	tCeiling.Size = Vector3.new(100, 6, tunnelLength)
	tCeiling.Position = Vector3.new(0, 40, tunnelCenterZ)
	tCeiling.Parent = sceneryFolder

	-- 22 Glowing Neon Arch Ribs inside the tunnel (every 50 studs)
	local neonOrange = Color3.fromRGB(255, 150, 30)
	local neonCyan = Color3.fromRGB(0, 220, 255)
	for i = 1, 22 do
		local ribZ = -2450 - (i - 0.5) * 50
		local ribColor = (i % 2 == 0) and neonCyan or neonOrange

		local topRib = Instance.new("Part")
		topRib.Name = "TunnelNeonRibTop_" .. i
		topRib.Anchored = true
		topRib.CanCollide = false
		topRib.Material = Enum.Material.Neon
		topRib.Color = ribColor
		topRib.Size = Vector3.new(84, 1.2, 1.6)
		topRib.Position = Vector3.new(0, 36.4, ribZ)
		topRib.Parent = sceneryFolder

		for _, side in ipairs({ -1, 1 }) do
			local sideRib = Instance.new("Part")
			sideRib.Name = "TunnelNeonRibSide_" .. i
			sideRib.Anchored = true
			sideRib.CanCollide = false
			sideRib.Material = Enum.Material.Neon
			sideRib.Color = ribColor
			sideRib.Size = Vector3.new(1.0, 27, 1.6)
			sideRib.Position = Vector3.new(side * 41.6, 23, ribZ)
			sideRib.Parent = sceneryFolder
		end
	end

	-- Zone 4: Twin-Tower Suspension Bridge over Water (Z = -3650 to -4750)
	local crimsonRed = Color3.fromRGB(195, 42, 42)
	local cableSteel = Color3.fromRGB(205, 212, 222)
	local bridgeTowerZs = { -3900, -4500 }

	for _, tz in ipairs(bridgeTowerZs) do
		for _, sideX in ipairs({ -47, 47 }) do
			local towerPillar = Instance.new("Part")
			towerPillar.Name = "BridgeTowerPillar"
			towerPillar.Anchored = true
			towerPillar.CanCollide = false
			towerPillar.Material = Enum.Material.Metal
			towerPillar.Color = crimsonRed
			towerPillar.Size = Vector3.new(9, 140, 9)
			towerPillar.Position = Vector3.new(sideX, 72, tz)
			towerPillar.Parent = sceneryFolder

			local beacon = Instance.new("Part")
			beacon.Name = "TowerBeacon"
			beacon.Shape = Enum.PartType.Ball
			beacon.Anchored = true
			beacon.CanCollide = false
			beacon.Material = Enum.Material.Neon
			beacon.Color = Color3.fromRGB(255, 70, 50)
			beacon.Size = Vector3.new(5, 5, 5)
			beacon.Position = Vector3.new(sideX, 144, tz)
			beacon.Parent = sceneryFolder
		end

		for _, crossY in ipairs({ 75, 135 }) do
			local crossBeam = Instance.new("Part")
			crossBeam.Name = "BridgeTowerCrossBeam"
			crossBeam.Anchored = true
			crossBeam.CanCollide = false
			crossBeam.Material = Enum.Material.Metal
			crossBeam.Color = crimsonRed
			crossBeam.Size = Vector3.new(100, 8, 8)
			crossBeam.Position = Vector3.new(0, crossY, tz)
			crossBeam.Parent = sceneryFolder
		end
	end

	-- Bridge under-deck water piers
	for _, pz in ipairs({ -3900, -4200, -4500 }) do
		local py = getHighwayY(pz)
		for _, px in ipairs({ -32, 32 }) do
			local pier = Instance.new("Part")
			pier.Name = "BridgeWaterPier"
			pier.Anchored = true
			pier.CanCollide = false
			pier.Material = Enum.Material.Concrete
			pier.Color = Color3.fromRGB(125, 132, 142)
			pier.Size = Vector3.new(8, py, 10)
			pier.Position = Vector3.new(px, py / 2, pz)
			pier.Parent = sceneryFolder
		end
	end

	-- Suspension cables (main curved span & vertical suspender cables)
	local function getCableY(z: number): number
		if z >= -3900 then
			local u = (z - (-3650)) / (-3900 - (-3650)) -- 0 at -3650, 1 at -3900
			return 22 + 116 * (u ^ 1.35)
		elseif z >= -4500 then
			local u = (z - (-4200)) / 300 -- -1..1
			return 52 + 86 * (u * u)
		else
			local u = (z - (-4750)) / (-4500 - (-4750)) -- 0 at -4750, 1 at -4500
			return 22 + 116 * (u ^ 1.35)
		end
	end

	for z = -3650, -4700, -50 do
		local zNext = z - 50
		local cY1 = getCableY(z)
		local cY2 = getCableY(zNext)
		local segLen = math.sqrt((cY2 - cY1) ^ 2 + 50 ^ 2) + 0.5
		local deckY = getHighwayY(z) + 2

		for _, sideX in ipairs({ -47, 47 }) do
			local pA = Vector3.new(sideX, cY1, z)
			local pB = Vector3.new(sideX, cY2, zNext)
			local mainCable = Instance.new("Part")
			mainCable.Name = "MainSuspensionCable"
			mainCable.Anchored = true
			mainCable.CanCollide = false
			mainCable.Material = Enum.Material.Metal
			mainCable.Color = cableSteel
			mainCable.Size = Vector3.new(1.8, 1.8, segLen)
			mainCable.CFrame = CFrame.lookAt((pA + pB) * 0.5, pB)
			mainCable.Parent = sceneryFolder

			local dropH = cY1 - deckY
			if dropH > 2 then
				local susp = Instance.new("Part")
				susp.Name = "VerticalSuspender"
				susp.Anchored = true
				susp.CanCollide = false
				susp.Material = Enum.Material.Metal
				susp.Color = cableSteel
				susp.Size = Vector3.new(0.8, dropH, 0.8)
				susp.Position = Vector3.new(sideX, deckY + dropH / 2, z)
				susp.Parent = sceneryFolder
			end
		end
	end

	-- Zone 5: Illuminated City Skyline (Z = -4900 to -5850)
	local skylineColors = {
		Color3.fromRGB(0, 220, 255),
		Color3.fromRGB(255, 80, 190),
		Color3.fromRGB(255, 205, 50),
		Color3.fromRGB(70, 155, 255),
	}
	local bldgIdx = 0
	for z = -4900, -5850, -180 do
		for _, xOff in ipairs({ 85, 130 }) do
			for _, side in ipairs({ -1, 1 }) do
				bldgIdx += 1
				local w = 36 + ((bldgIdx * 7) % 17)
				local h = 90 + ((bldgIdx * 31) % 120)
				local bx = side * xOff
				local bz = z + ((bldgIdx * 13) % 30) - 15
				local accent = skylineColors[((bldgIdx - 1) % #skylineColors) + 1]

				local tower = Instance.new("Part")
				tower.Name = "SkylineTower_" .. bldgIdx
				tower.Anchored = true
				tower.CanCollide = false
				tower.Material = Enum.Material.SmoothPlastic
				tower.Color = Color3.fromRGB(26, 30, 42)
				tower.Size = Vector3.new(w, h, w)
				tower.Position = Vector3.new(bx, 6 + h / 2, bz)
				tower.Parent = sceneryFolder

				local roofNeon = Instance.new("Part")
				roofNeon.Name = "SkylineNeonTrim"
				roofNeon.Anchored = true
				roofNeon.CanCollide = false
				roofNeon.Material = Enum.Material.Neon
				roofNeon.Color = accent
				roofNeon.Size = Vector3.new(w + 0.6, 2.2, w + 0.6)
				roofNeon.Position = Vector3.new(bx, 6 + h - 3, bz)
				roofNeon.Parent = sceneryFolder
			end
		end
	end

	-- Grand Finish Festival Plaza (Separate from Start Line, at Z = -6000)
	local FINISH_Z = -6000
	local finishRoadTopY = getHighwayY(FINISH_Z) + (TRACK_THICKNESS / 2)

	local finishModel = Instance.new("Model")
	finishModel.Name = "FinishPoint"
	finishModel.Parent = mapModel

	-- Wide Checkered Finish Line Strip across 84-stud road
	local finishRows, finishCols = 2, 14
	local finishWidth = TRACK_WIDTH + 2
	local finishLength = 14
	local fTileW = finishWidth / finishCols
	local fTileL = finishLength / finishRows
	for r = 1, finishRows do
		for c = 1, finishCols do
			local isWhite = ((r + c) % 2 == 0)
			local fx = -(finishWidth / 2) + (c - 0.5) * fTileW
			local fz = FINISH_Z - (finishLength / 2) + (r - 0.5) * fTileL
			local fTile = Instance.new("Part")
			fTile.Name = "FinishCheckerTile"
			fTile.Anchored = true
			fTile.CanCollide = false
			fTile.Material = Enum.Material.SmoothPlastic
			fTile.Color = isWhite and Color3.fromRGB(245, 245, 250) or Color3.fromRGB(20, 20, 25)
			fTile.Size = Vector3.new(fTileW, 0.2, fTileL)
			fTile.Position = Vector3.new(fx, finishRoadTopY + 0.1, fz)
			fTile.TopSurface = Enum.SurfaceType.Smooth
			fTile.Parent = finishModel
		end
	end

	-- 3 Pre-Finish Glowing Victory Arches leading into Finish Line (Z = -5880, -5920, -5960)
	local victoryArchColors = {
		Color3.fromRGB(0, 225, 255),
		Color3.fromRGB(255, 215, 40),
		Color3.fromRGB(0, 225, 255),
	}
	for aIdx, archZ in ipairs({ -5880, -5920, -5960 }) do
		local aColor = victoryArchColors[aIdx]
		for _, sideX in ipairs({ -43, 43 }) do
			local vPillar = Instance.new("Part")
			vPillar.Name = "PreFinishArchPillar_" .. aIdx
			vPillar.Anchored = true
			vPillar.CanCollide = false
			vPillar.Material = Enum.Material.Neon
			vPillar.Color = aColor
			vPillar.Size = Vector3.new(2.2, 30, 2.2)
			vPillar.Position = Vector3.new(sideX, finishRoadTopY + 13, archZ)
			vPillar.Parent = finishModel
		end
		local vBeam = Instance.new("Part")
		vBeam.Name = "PreFinishArchTop_" .. aIdx
		vBeam.Anchored = true
		vBeam.CanCollide = false
		vBeam.Material = Enum.Material.Neon
		vBeam.Color = aColor
		vBeam.Size = Vector3.new(88, 2.2, 2.2)
		vBeam.Position = Vector3.new(0, finishRoadTopY + 28, archZ)
		vBeam.Parent = finishModel
	end

	-- Towering Twin Finish Pillars (Height 46) with Checkered Stripes & 180-stud Golden Skyward Beacons
	local finishPillarH = 46
	for _, sideX in ipairs({ -46, 46 }) do
		local fPillar = Instance.new("Part")
		fPillar.Name = "FinishArchPillar"
		fPillar.Anchored = true
		fPillar.CanCollide = true
		fPillar.Material = Enum.Material.Metal
		fPillar.Color = Color3.fromRGB(20, 24, 34)
		fPillar.Size = Vector3.new(7, finishPillarH, 8)
		fPillar.Position = Vector3.new(sideX, finishRoadTopY + finishPillarH / 2 - 2, FINISH_Z)
		fPillar.Parent = finishModel

		local goldTrim = Instance.new("Part")
		goldTrim.Name = "FinishGoldTrim"
		goldTrim.Anchored = true
		goldTrim.CanCollide = false
		goldTrim.Material = Enum.Material.Neon
		goldTrim.Color = Color3.fromRGB(255, 215, 40)
		goldTrim.Size = Vector3.new(1.4, finishPillarH, 8.6)
		goldTrim.Position = Vector3.new(sideX, finishRoadTopY + finishPillarH / 2 - 2, FINISH_Z)
		goldTrim.Parent = finishModel

		-- Checkered banner blocks stacked up the pillar faces
		for b = 0, 5 do
			local isGold = (b % 2 == 0)
			local cBlock = Instance.new("Part")
			cBlock.Name = "FinishPillarChecker"
			cBlock.Anchored = true
			cBlock.CanCollide = false
			cBlock.Material = Enum.Material.SmoothPlastic
			cBlock.Color = isGold and Color3.fromRGB(250, 250, 255) or Color3.fromRGB(24, 24, 30)
			cBlock.Size = Vector3.new(7.4, 3.6, 8.4)
			cBlock.Position = Vector3.new(sideX, finishRoadTopY + 4 + b * 4.2, FINISH_Z)
			cBlock.Parent = finishModel
		end

		-- 180-stud Skyward Golden Beacon Beam visible from far down the highway
		local skyBeacon = Instance.new("Part")
		skyBeacon.Name = "FinishSkyBeacon"
		skyBeacon.Anchored = true
		skyBeacon.CanCollide = false
		skyBeacon.Material = Enum.Material.Neon
		skyBeacon.Color = Color3.fromRGB(255, 220, 60)
		skyBeacon.Transparency = 0.35
		skyBeacon.Size = Vector3.new(3.5, 180, 3.5)
		skyBeacon.Position = Vector3.new(sideX, finishRoadTopY + finishPillarH + 88, FINISH_Z)
		skyBeacon.Parent = finishModel
	end

	-- Top & Bottom Structural Beams flanking Giant Signboard cleanly without blocking faces
	local finishTopBeam = Instance.new("Part")
	finishTopBeam.Name = "FinishArchTopBeam"
	finishTopBeam.Anchored = true
	finishTopBeam.CanCollide = true
	finishTopBeam.Material = Enum.Material.Metal
	finishTopBeam.Color = Color3.fromRGB(24, 28, 40)
	finishTopBeam.Size = Vector3.new(102, 2.5, 3.0)
	finishTopBeam.Position = Vector3.new(0, finishRoadTopY + 45, FINISH_Z)
	finishTopBeam.Parent = finishModel
	finishModel.PrimaryPart = finishTopBeam

	local finishBotBeam = Instance.new("Part")
	finishBotBeam.Name = "FinishArchBottomBeam"
	finishBotBeam.Anchored = true
	finishBotBeam.CanCollide = true
	finishBotBeam.Material = Enum.Material.Metal
	finishBotBeam.Color = Color3.fromRGB(24, 28, 40)
	finishBotBeam.Size = Vector3.new(96, 2.2, 3.0)
	finishBotBeam.Position = Vector3.new(0, finishRoadTopY + 23, FINISH_Z)
	finishBotBeam.Parent = finishModel

	-- Giant Finish Signboard (80x20, proud Z=3.6 in front of 3.0 beams & neon gold border)
	local finishNeonBorder = Instance.new("Part")
	finishNeonBorder.Name = "FinishNeonBorder"
	finishNeonBorder.Anchored = true
	finishNeonBorder.CanCollide = false
	finishNeonBorder.Material = Enum.Material.Neon
	finishNeonBorder.Color = Color3.fromRGB(255, 215, 40)
	finishNeonBorder.Size = Vector3.new(82, 22, 3.0)
	finishNeonBorder.Position = Vector3.new(0, finishRoadTopY + 34, FINISH_Z)
	finishNeonBorder.Parent = finishModel

	local finishBoard = Instance.new("Part")
	finishBoard.Name = "FinishSignboard"
	finishBoard.Anchored = true
	finishBoard.CanCollide = false
	finishBoard.Material = Enum.Material.SmoothPlastic
	finishBoard.Color = Color3.fromRGB(14, 18, 28)
	finishBoard.Size = Vector3.new(80, 20, 3.6)
	finishBoard.Position = Vector3.new(0, finishRoadTopY + 34, FINISH_Z)
	finishBoard.Parent = finishModel

	for _, face in ipairs({ Enum.NormalId.Back, Enum.NormalId.Front }) do
		local fGui = Instance.new("SurfaceGui")
		fGui.Name = "FinishSignGui_" .. face.Name
		fGui.Face = face
		fGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		fGui.PixelsPerStud = 20
		fGui.Parent = finishBoard

		local mainLabel = Instance.new("TextLabel")
		mainLabel.Size = UDim2.new(0.96, 0, 0.62, 0)
		mainLabel.Position = UDim2.new(0.02, 0, 0.04, 0)
		mainLabel.BackgroundTransparency = 1
		mainLabel.Font = Enum.Font.GothamBlack
		mainLabel.Text = "🏆 FINISH LINE 🏆"
		mainLabel.TextColor3 = Color3.fromRGB(255, 225, 40)
		mainLabel.TextScaled = true
		mainLabel.Parent = fGui

		local mainStroke = Instance.new("UIStroke")
		mainStroke.Color = Color3.fromRGB(0, 0, 0)
		mainStroke.Thickness = 6
		mainStroke.Parent = mainLabel

		local subLabel = Instance.new("TextLabel")
		subLabel.Size = UDim2.new(0.92, 0, 0.30, 0)
		subLabel.Position = UDim2.new(0.04, 0, 0.66, 0)
		subLabel.BackgroundTransparency = 1
		subLabel.Font = Enum.Font.GothamBlack
		subLabel.Text = "🏁 GOAL — 6,000m AUTOBAHN SPRINT 🏁"
		subLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		subLabel.TextScaled = true
		subLabel.Parent = fGui

		local subStroke = Instance.new("UIStroke")
		subStroke.Color = Color3.fromRGB(0, 0, 0)
		subStroke.Thickness = 4
		subStroke.Parent = subLabel
	end

	-- Finish Plaza Stadium Grandstands on both sides (Z = -5850 to -6090, X = ±58 to ±82, ground top Y = 6.0)
	local standLen = 240
	local standCenterZ = -5970
	local tierColors = {
		Color3.fromRGB(235, 65, 65),
		Color3.fromRGB(50, 155, 255),
		Color3.fromRGB(255, 200, 40),
		Color3.fromRGB(40, 220, 175),
	}
	for _, side in ipairs({ -1, 1 }) do
		for tier = 1, 4 do
			local riserH = 3.2 * tier
			local tierX = side * (55 + tier * 6)
			local tierBlock = Instance.new("Part")
			tierBlock.Name = "FinishGrandstandTier_" .. tier
			tierBlock.Anchored = true
			tierBlock.CanCollide = false
			tierBlock.Material = Enum.Material.Concrete
			tierBlock.Color = Color3.fromRGB(68, 74, 86)
			tierBlock.Size = Vector3.new(6, riserH, standLen)
			tierBlock.Position = Vector3.new(tierX, 6.0 + riserH / 2, standCenterZ)
			tierBlock.Parent = finishModel

			local seatBench = Instance.new("Part")
			seatBench.Name = "FinishGrandstandSeat_" .. tier
			seatBench.Anchored = true
			seatBench.CanCollide = false
			seatBench.Material = Enum.Material.SmoothPlastic
			seatBench.Color = tierColors[tier]
			seatBench.Size = Vector3.new(4.2, 1.0, standLen - 2)
			seatBench.Position = Vector3.new(tierX, 6.0 + riserH + 0.5, standCenterZ)
			seatBench.Parent = finishModel
		end

		for _, colZ in ipairs({ -5865, -5935, -6005, -6075 }) do
			local standCol = Instance.new("Part")
			standCol.Name = "GrandstandRoofColumn"
			standCol.Anchored = true
			standCol.CanCollide = false
			standCol.Material = Enum.Material.Metal
			standCol.Color = Color3.fromRGB(140, 150, 165)
			standCol.Size = Vector3.new(2.2, 23, 2.2)
			standCol.Position = Vector3.new(side * 81, 6.0 + 11.5, colZ)
			standCol.Parent = finishModel
		end

		local roofTilt = math.rad(side * -10)
		local canopyRoof = Instance.new("Part")
		canopyRoof.Name = "GrandstandCanopy"
		canopyRoof.Anchored = true
		canopyRoof.CanCollide = false
		canopyRoof.Material = Enum.Material.SmoothPlastic
		canopyRoof.Color = Color3.fromRGB(28, 34, 48)
		canopyRoof.Size = Vector3.new(28, 1.5, standLen + 6)
		canopyRoof.CFrame = CFrame.new(side * 68, 29, standCenterZ) * CFrame.Angles(0, 0, roofTilt)
		canopyRoof.Parent = finishModel

		local canopyNeon = Instance.new("Part")
		canopyNeon.Name = "GrandstandCanopyNeon"
		canopyNeon.Anchored = true
		canopyNeon.CanCollide = false
		canopyNeon.Material = Enum.Material.Neon
		canopyNeon.Color = Color3.fromRGB(255, 215, 40)
		canopyNeon.Size = Vector3.new(1.2, 1.2, standLen + 6)
		canopyNeon.CFrame = CFrame.new(side * 55, 26.6, standCenterZ)
		canopyNeon.Parent = finishModel

		for fIdx, flagZ in ipairs({ -5875, -5925, -5975, -6025, -6075 }) do
			local flagColor = tierColors[((fIdx - 1) % #tierColors) + 1]
			local pole = Instance.new("Part")
			pole.Name = "FestivalFlagPole"
			pole.Anchored = true
			pole.CanCollide = false
			pole.Material = Enum.Material.Metal
			pole.Color = Color3.fromRGB(210, 215, 225)
			pole.Size = Vector3.new(0.8, 12, 0.8)
			pole.Position = Vector3.new(side * 58, 34, flagZ)
			pole.Parent = finishModel

			local banner = Instance.new("Part")
			banner.Name = "FestivalFlagBanner"
			banner.Anchored = true
			banner.CanCollide = false
			banner.Material = Enum.Material.Neon
			banner.Color = flagColor
			banner.Size = Vector3.new(0.4, 4.5, 8)
			banner.Position = Vector3.new(side * 58, 37.5, flagZ - 4)
			banner.Parent = finishModel
		end
	end

	-- 4. Sequential Checkpoints (1..5 along highway, 6 exactly at Finish Line Z = -6000)
	local cpFolder = Instance.new("Folder")
	cpFolder.Name = "Checkpoints"
	cpFolder.Parent = mapModel

	for idx, cpZ in ipairs({ -1000, -2000, -3000, -4000, -5000, -6000 }) do
		local cpPart = Instance.new("Part")
		cpPart.Name = tostring(idx)
		cpPart.Anchored = true
		cpPart.CanCollide = false
		cpPart.Transparency = 1
		cpPart.Size = Vector3.new(TRACK_WIDTH + 16, 26, 24)
		cpPart.CFrame = CFrame.new(0, getHighwayY(cpZ) + 12, cpZ)
		cpPart.Parent = cpFolder
	end

	-- 5. Starting Line & Spawn Grid at Z = 0 (facing -Z down the Autobahn)
	local startPos = Vector3.new(0, 8.5, 0)
	local flatForward = Vector3.new(0, 0, -1)
	local startCFrame = CFrame.lookAt(startPos, startPos - flatForward)

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

function MapBuilder.buildCyberCityModel(): Model
	local mapModel = Instance.new("Model")
	mapModel.Name = "Cyber City"

	local SEGMENTS = 240
	local TRACK_WIDTH = 68
	local halfW = TRACK_WIDTH / 2
	local TRACK_THICKNESS = 2.6

	local function getCyberPoint(t: number): (Vector3, Vector3)
		local x = 250 * math.cos(t) + 32 * math.cos(3 * t)
		local z = 310 * math.sin(t) - 24 * math.sin(3 * t)
		local y = 26 + 18 * math.sin(t)

		local dx = -250 * math.sin(t) - 96 * math.sin(3 * t)
		local dz = 310 * math.cos(t) - 72 * math.cos(3 * t)
		local dy = 18 * math.cos(t)

		return Vector3.new(x, y, z), Vector3.new(dx, dy, dz).Unit
	end

	-- 1. Smooth Cyber Skyway Track Segments (Matte Asphalt & Non-Glare Trim)
	local trackFolder = Instance.new("Folder")
	trackFolder.Name = "HoverboardTrack"
	trackFolder.Parent = mapModel

	local roadColor = Color3.fromRGB(36, 40, 50)
	local centerCyan = Color3.fromRGB(75, 165, 220)
	local centerIndigo = Color3.fromRGB(130, 115, 200)
	local curbColor = Color3.fromRGB(58, 65, 82)
	local curbTrimColor = Color3.fromRGB(85, 175, 230)
	local whiteLaneColor = Color3.fromRGB(220, 235, 255)

	local trackCenterPoints: { Vector2 } = {}

	for i = 1, SEGMENTS do
		local t1 = ((i - 1) / SEGMENTS) * math.pi * 2
		local t2 = (i / SEGMENTS) * math.pi * 2
		local p1 = getCyberPoint(t1)
		local p2 = getCyberPoint(t2)
		table.insert(trackCenterPoints, Vector2.new(p1.X, p1.Z))

		local midPos = (p1 + p2) * 0.5
		local segLen = (p2 - p1).Magnitude + 1.4
		local cf = CFrame.lookAt(midPos, p2)

		local road = Instance.new("Part")
		road.Name = "CyberTrackSegment_" .. i
		road.Anchored = true
		road.CanCollide = true
		road.Material = Enum.Material.Asphalt
		road.Color = roadColor
		road.Size = Vector3.new(TRACK_WIDTH, TRACK_THICKNESS, segLen)
		road.CFrame = cf
		road.TopSurface = Enum.SurfaceType.Smooth
		road.BottomSurface = Enum.SurfaceType.Smooth
		road.Parent = trackFolder

		local lineY = (TRACK_THICKNESS / 2) + 0.06

		-- Soft Cyan & Indigo matte center guide lines
		for _, centerLine in ipairs({
			{ x = -1.4, color = centerCyan },
			{ x = 1.4, color = centerIndigo },
		}) do
			local cLine = Instance.new("Part")
			cLine.Name = "CyberCenterNeon"
			cLine.Anchored = true
			cLine.CanCollide = false
			cLine.Material = Enum.Material.SmoothPlastic
			cLine.Color = centerLine.color
			cLine.Size = Vector3.new(0.7, 0.14, segLen)
			cLine.CFrame = cf * CFrame.new(centerLine.x, lineY, 0)
			cLine.Parent = trackFolder
		end

		-- Dashed lane markers at X = ±16
		if i % 2 == 0 then
			for _, lx in ipairs({ -16, 16 }) do
				local lane = Instance.new("Part")
				lane.Name = "CyberLaneDash"
				lane.Anchored = true
				lane.CanCollide = false
				lane.Material = Enum.Material.SmoothPlastic
				lane.Color = whiteLaneColor
				lane.Size = Vector3.new(0.55, 0.12, segLen * 0.55)
				lane.CFrame = cf * CFrame.new(lx, lineY, 0)
				lane.Parent = trackFolder
			end
		end

		-- Non-glare curbs, consistent edge trim, and full containment walls
		for _, side in ipairs({ -1, 1 }) do
			local curb = Instance.new("Part")
			curb.Name = "HologramCurb"
			curb.Anchored = true
			curb.CanCollide = true
			curb.Material = Enum.Material.SmoothPlastic
			curb.Transparency = 0
			curb.Color = curbColor
			curb.Size = Vector3.new(2.0, 3.5, segLen)
			curb.CFrame = cf * CFrame.new(side * (halfW - 1), 1.8, 0)
			curb.Parent = trackFolder

			local topNeon = Instance.new("Part")
			topNeon.Name = "CyberEdgeNeon"
			topNeon.Anchored = true
			topNeon.CanCollide = false
			topNeon.Material = Enum.Material.SmoothPlastic
			topNeon.Color = curbTrimColor
			topNeon.Size = Vector3.new(0.6, 0.45, segLen)
			topNeon.CFrame = cf * CFrame.new(side * (halfW - 1), 3.7, 0)
			topNeon.Parent = trackFolder

			local guardWall = Instance.new("Part")
			guardWall.Name = "TrackGuardWall"
			guardWall.Anchored = true
			guardWall.CanCollide = true
			guardWall.Transparency = 1
			guardWall.Size = Vector3.new(2.0, 28, segLen)
			guardWall.CFrame = cf * CFrame.new(side * (halfW - 1), 14, 0)
			guardWall.Parent = trackFolder
		end
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

	-- 2. GroundFloor (Calm Matte Night City Base, well within 2048 stud cap)
	local groundFolder = Instance.new("Folder")
	groundFolder.Name = "GroundFloor"
	groundFolder.Parent = mapModel

	local cityBase = Instance.new("Part")
	cityBase.Name = "CyberNightCityBase"
	cityBase.Anchored = true
	cityBase.CanCollide = true
	cityBase.Material = Enum.Material.SmoothPlastic
	cityBase.Color = Color3.fromRGB(26, 30, 40)
	cityBase.Size = Vector3.new(960, 8, 1080)
	cityBase.Position = Vector3.new(0, 2, 0) -- Top at Y = 6.0
	cityBase.TopSurface = Enum.SurfaceType.Smooth
	cityBase.Parent = groundFolder

	local gridLineColor = Color3.fromRGB(42, 50, 68)
	for _, gx in ipairs({ -160, 0, 160 }) do
		local gridStripX = Instance.new("Part")
		gridStripX.Name = "CityNeonGrid_Z"
		gridStripX.Anchored = true
		gridStripX.CanCollide = false
		gridStripX.Material = Enum.Material.SmoothPlastic
		gridStripX.Color = gridLineColor
		gridStripX.Size = Vector3.new(2.0, 0.2, 1060)
		gridStripX.Position = Vector3.new(gx, 6.08, 0)
		gridStripX.Parent = groundFolder
	end

	for _, gz in ipairs({ -200, 0, 200 }) do
		local gridStripZ = Instance.new("Part")
		gridStripZ.Name = "CityNeonGrid_X"
		gridStripZ.Anchored = true
		gridStripZ.CanCollide = false
		gridStripZ.Material = Enum.Material.SmoothPlastic
		gridStripZ.Color = gridLineColor
		gridStripZ.Size = Vector3.new(940, 0.2, 2.0)
		gridStripZ.Position = Vector3.new(0, 6.08, gz)
		gridStripZ.Parent = groundFolder
	end

	-- 3. Scenery & 4 Clean Architectural Cyberpunk Sectors
	local sceneryFolder = Instance.new("Folder")
	sceneryFolder.Name = "Scenery"
	sceneryFolder.Parent = mapModel

	local towerSteelBlue = Color3.fromRGB(75, 155, 215)
	local towerSlateIndigo = Color3.fromRGB(115, 105, 185)

	-- Sector 1: Central Landmark — CyberCoreMegaTower at (0, 6, 0), height 240 studs (Y = 6..246)
	local megaTowerModel = Instance.new("Model")
	megaTowerModel.Name = "CyberCoreMegaTower"
	megaTowerModel.Parent = sceneryFolder

	local towerTiers = {
		{ name = "TowerBaseTier", w = 64, h = 80, yCenter = 6 + 40, color = Color3.fromRGB(28, 34, 48) },
		{ name = "TowerMidTier", w = 44, h = 90, yCenter = 6 + 80 + 45, color = Color3.fromRGB(32, 38, 54) },
		{ name = "TowerUpperTier", w = 26, h = 70, yCenter = 6 + 170 + 35, color = Color3.fromRGB(36, 44, 62) },
	}
	for _, tier in ipairs(towerTiers) do
		local block = Instance.new("Part")
		block.Name = tier.name
		block.Anchored = true
		block.CanCollide = true
		block.Material = Enum.Material.SmoothPlastic
		block.Color = tier.color
		block.Size = Vector3.new(tier.w, tier.h, tier.w)
		block.Position = Vector3.new(0, tier.yCenter, 0)
		block.Parent = megaTowerModel

		if tier.name == "TowerBaseTier" then
			megaTowerModel.PrimaryPart = block
		end

		-- Calm architectural accent strips on all 4 faces
		for faceIdx, offset in ipairs({
			{ x = 0, z = tier.w / 2 + 0.4, sx = 2.4, sz = 0.8 },
			{ x = 0, z = -(tier.w / 2 + 0.4), sx = 2.4, sz = 0.8 },
			{ x = tier.w / 2 + 0.4, z = 0, sx = 0.8, sz = 2.4 },
			{ x = -(tier.w / 2 + 0.4), z = 0, sx = 0.8, sz = 2.4 },
		}) do
			local strip = Instance.new("Part")
			strip.Name = "MegaTowerNeonStrip"
			strip.Anchored = true
			strip.CanCollide = false
			strip.Material = Enum.Material.SmoothPlastic
			strip.Color = (faceIdx % 2 == 0) and towerSlateIndigo or towerSteelBlue
			strip.Size = Vector3.new(offset.sx, tier.h - 4, offset.sz)
			strip.Position = Vector3.new(offset.x, tier.yCenter, offset.z)
			strip.Parent = megaTowerModel
		end
	end

	-- 3 Architectural Energy Rings around MegaTower (Y = 75, 140, 200)
	local plasmaRings = {
		{ y = 75, radius = 42, thick = 4, color = towerSteelBlue },
		{ y = 140, radius = 32, thick = 3.5, color = towerSlateIndigo },
		{ y = 200, radius = 22, thick = 3.0, color = towerSteelBlue },
	}
	for _, ring in ipairs(plasmaRings) do
		local barLen = ring.radius * 2 + ring.thick
		for _, bar in ipairs({
			{ pos = Vector3.new(0, ring.y, ring.radius), size = Vector3.new(barLen, ring.thick, ring.thick) },
			{ pos = Vector3.new(0, ring.y, -ring.radius), size = Vector3.new(barLen, ring.thick, ring.thick) },
			{ pos = Vector3.new(ring.radius, ring.y, 0), size = Vector3.new(ring.thick, ring.thick, barLen) },
			{ pos = Vector3.new(-ring.radius, ring.y, 0), size = Vector3.new(ring.thick, ring.thick, barLen) },
		}) do
			local rPart = Instance.new("Part")
			rPart.Name = "PlasmaEnergyRing"
			rPart.Anchored = true
			rPart.CanCollide = false
			rPart.Material = Enum.Material.SmoothPlastic
			rPart.Color = ring.color
			rPart.Size = bar.size
			rPart.Position = bar.pos
			rPart.Parent = megaTowerModel
		end
	end

	-- Sleek Metallic Spire Antenna atop MegaTower
	local spireAntenna = Instance.new("Part")
	spireAntenna.Name = "CyberCoreSkyBeam"
	spireAntenna.Anchored = true
	spireAntenna.CanCollide = false
	spireAntenna.Material = Enum.Material.Metal
	spireAntenna.Color = Color3.fromRGB(140, 155, 175)
	spireAntenna.Size = Vector3.new(3.5, 65, 3.5)
	spireAntenna.Position = Vector3.new(0, 246 + 32.5, 0)
	spireAntenna.Parent = megaTowerModel

	-- Sector 2: Architectural Skyscraper District (~44 towers + 10 Hologram Billboards)
	local placedTowers: { Vector2 } = {}
	local billboardTexts = {
		"⚡ CYBER CITY 2099 ⚡",
		"🚀 NITRO SKYWAY",
		"🛸 HOVER CORP",
		"🔥 MAX OVERDRIVE",
		"💎 NEON DISTRICT",
	}
	local accentPalette = {
		Color3.fromRGB(70, 130, 180),
		Color3.fromRGB(105, 95, 160),
		Color3.fromRGB(65, 145, 140),
	}
	local softHoloTextColor = Color3.fromRGB(160, 220, 255)
	local towerCount = 0
	local billboardCount = 0

	local function createSkyscraper(x: number, z: number, facingTarget: Vector3)
		if towerCount >= 44 then return end
		if math.sqrt(x * x + z * z) < 82 then return end
		if distToTrack(x, z) < 62 then return end
		local candidate = Vector2.new(x, z)
		for _, prev in ipairs(placedTowers) do
			if (candidate - prev).Magnitude < 52 then
				return
			end
		end

		table.insert(placedTowers, candidate)
		towerCount += 1

		local w = 28 + ((towerCount * 7) % 16)
		local h = 85 + ((towerCount * 29) % 110)
		local accent = accentPalette[((towerCount - 1) % #accentPalette) + 1]

		local bldg = Instance.new("Part")
		bldg.Name = "CyberSkyscraper_" .. towerCount
		bldg.Anchored = true
		bldg.CanCollide = false
		bldg.Material = Enum.Material.SmoothPlastic
		bldg.Color = Color3.fromRGB(34, 40, 54)
		bldg.Size = Vector3.new(w, h, w)
		bldg.Position = Vector3.new(x, 6 + h / 2, z)
		bldg.Parent = sceneryFolder

		local roofNeon = Instance.new("Part")
		roofNeon.Name = "SkyscraperRoofNeon"
		roofNeon.Anchored = true
		roofNeon.CanCollide = false
		roofNeon.Material = Enum.Material.SmoothPlastic
		roofNeon.Color = accent
		roofNeon.Size = Vector3.new(w + 1.0, 2.5, w + 1.0)
		roofNeon.Position = Vector3.new(x, 6 + h - 3, z)
		roofNeon.Parent = sceneryFolder

		-- Clean vertical architectural window band
		local vStrip = Instance.new("Part")
		vStrip.Name = "SkyscraperVerticalNeon"
		vStrip.Anchored = true
		vStrip.CanCollide = false
		vStrip.Material = Enum.Material.SmoothPlastic
		vStrip.Color = accent
		vStrip.Size = Vector3.new(w * 0.35, h * 0.72, w + 0.6)
		vStrip.Position = Vector3.new(x, 6 + h * 0.48, z)
		vStrip.Parent = sceneryFolder

		-- Mount Clean Architectural Billboard on 10 prominent towers
		if billboardCount < 10 and towerCount % 4 == 1 then
			billboardCount += 1
			local holoY = 6 + math.min(h - 14, 72)
			local flatDir = Vector3.new(facingTarget.X - x, 0, facingTarget.Z - z)
			local dirUnit = (flatDir.Magnitude > 1) and flatDir.Unit or Vector3.new(1, 0, 0)
			local signCenter = Vector3.new(x, holoY, z) + dirUnit * (w * 0.5 + 3.0)
			local signCF = CFrame.lookAt(signCenter, signCenter + dirUnit)

			local holoFrame = Instance.new("Part")
			holoFrame.Name = "HoloBillboardBorder_" .. billboardCount
			holoFrame.Anchored = true
			holoFrame.CanCollide = false
			holoFrame.Material = Enum.Material.SmoothPlastic
			holoFrame.Color = accent
			holoFrame.Size = Vector3.new(34, 15, 0.8)
			holoFrame.CFrame = signCF
			holoFrame.Parent = sceneryFolder

			local holoBoard = Instance.new("Part")
			holoBoard.Name = "HoloBillboard_" .. billboardCount
			holoBoard.Anchored = true
			holoBoard.CanCollide = false
			holoBoard.Material = Enum.Material.SmoothPlastic
			holoBoard.Color = Color3.fromRGB(18, 24, 38)
			holoBoard.Size = Vector3.new(32, 13, 1.2)
			holoBoard.CFrame = signCF
			holoBoard.Parent = sceneryFolder

			local textStr = billboardTexts[((billboardCount - 1) % #billboardTexts) + 1]
			for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
				local hGui = Instance.new("SurfaceGui")
				hGui.Name = "HoloGui_" .. face.Name
				hGui.Face = face
				hGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
				hGui.PixelsPerStud = 20
				hGui.Parent = holoBoard

				local hLabel = Instance.new("TextLabel")
				hLabel.Size = UDim2.new(0.92, 0, 0.84, 0)
				hLabel.Position = UDim2.new(0.04, 0, 0.08, 0)
				hLabel.BackgroundTransparency = 1
				hLabel.Font = Enum.Font.GothamBlack
				hLabel.Text = textStr
				hLabel.TextColor3 = softHoloTextColor
				hLabel.TextScaled = true
				hLabel.Parent = hGui

				local hStroke = Instance.new("UIStroke")
				hStroke.Color = Color3.fromRGB(0, 0, 0)
				hStroke.Thickness = 4
				hStroke.Parent = hLabel
			end
		end
	end

	-- Infield skyscrapers surrounding CyberCoreMegaTower
	for _, ringSpec in ipairs({
		{ radX = 105, radZ = 125, n = 8 },
		{ radX = 145, radZ = 185, n = 10 },
	}) do
		for k = 1, ringSpec.n do
			local ang = (k / ringSpec.n) * math.pi * 2 + 0.25
			local bx = math.cos(ang) * ringSpec.radX
			local bz = math.sin(ang) * ringSpec.radZ
			createSkyscraper(bx, bz, Vector3.new(bx * 2, 40, bz * 2))
		end
	end

	-- Perimeter skyscrapers around the Cyber City track
	for step = 1, 36 do
		local t = (step / 36) * math.pi * 2
		local p, tan = getCyberPoint(t)
		local normal = Vector3.new(-tan.Z, 0, tan.X).Unit
		for _, off in ipairs({ 82, 118 }) do
			for _, side in ipairs({ -1, 1 }) do
				local bx = p.X + side * normal.X * off
				local bz = p.Z + side * normal.Z * off
				if math.abs(bx) <= 440 and math.abs(bz) <= 500 then
					createSkyscraper(bx, bz, p)
				end
			end
		end
	end

	-- Sector 3: North Skybridge Arches (8 SmoothPlastic Architectural Arches + Support Pylons along t = 0.28*pi .. 0.72*pi)
	local archGateColor = Color3.fromRGB(65, 135, 190)
	for i = 1, 8 do
		local t = (0.28 + ((i - 1) / 7) * 0.44) * math.pi
		local p, tan = getCyberPoint(t)
		local cf = CFrame.lookAt(p, p + tan)

		-- Portal Pillars & Overhead Beam Arch
		for _, side in ipairs({ -1, 1 }) do
			local gatePost = Instance.new("Part")
			gatePost.Name = "PlasmaGatePost_" .. i
			gatePost.Anchored = true
			gatePost.CanCollide = false
			gatePost.Material = Enum.Material.SmoothPlastic
			gatePost.Color = archGateColor
			gatePost.Size = Vector3.new(2.6, 32, 2.6)
			gatePost.CFrame = cf * CFrame.new(side * (halfW + 4), 16, 0)
			gatePost.Parent = sceneryFolder
		end

		local gateTop = Instance.new("Part")
		gateTop.Name = "PlasmaGateTop_" .. i
		gateTop.Anchored = true
		gateTop.CanCollide = false
		gateTop.Material = Enum.Material.SmoothPlastic
		gateTop.Color = archGateColor
		gateTop.Size = Vector3.new(TRACK_WIDTH + 10, 2.6, 2.6)
		gateTop.CFrame = cf * CFrame.new(0, 32, 0)
		gateTop.Parent = sceneryFolder

		-- Support Pylon connecting elevated skybridge to city floor (Y = 6)
		local pylonH = math.max(4, p.Y - 6)
		local pylon = Instance.new("Part")
		pylon.Name = "SkybridgePylon_" .. i
		pylon.Anchored = true
		pylon.CanCollide = false
		pylon.Material = Enum.Material.Metal
		pylon.Color = Color3.fromRGB(36, 40, 56)
		pylon.Size = Vector3.new(10, pylonH, 10)
		pylon.Position = Vector3.new(p.X, 6 + pylonH / 2, p.Z)
		pylon.Parent = sceneryFolder
	end

	-- Sector 4: South Undercity Tunnel (t = 1.32*pi .. 1.68*pi, Uniform SmoothPlastic Ribs on even segments)
	local tunnelSegs = 16
	local tunnelRibColor = Color3.fromRGB(75, 145, 200)
	for i = 1, tunnelSegs do
		local t1 = (1.32 + ((i - 1) / tunnelSegs) * 0.36) * math.pi
		local t2 = (1.32 + (i / tunnelSegs) * 0.36) * math.pi
		local p1 = getCyberPoint(t1)
		local p2 = getCyberPoint(t2)
		local mid = (p1 + p2) * 0.5
		local segLen = (p2 - p1).Magnitude + 3.5
		local cf = CFrame.lookAt(mid, p2)

		for _, side in ipairs({ -1, 1 }) do
			local tWall = Instance.new("Part")
			tWall.Name = "LaserTunnelWall_" .. i
			tWall.Anchored = true
			tWall.CanCollide = true
			tWall.Material = Enum.Material.Metal
			tWall.Color = Color3.fromRGB(28, 32, 44)
			tWall.Size = Vector3.new(4, 28, segLen)
			tWall.CFrame = cf * CFrame.new(side * (halfW + 3), 13, 0)
			tWall.Parent = sceneryFolder
		end

		local tRoof = Instance.new("Part")
		tRoof.Name = "LaserTunnelRoof_" .. i
		tRoof.Anchored = true
		tRoof.CanCollide = true
		tRoof.Material = Enum.Material.Metal
		tRoof.Color = Color3.fromRGB(24, 28, 40)
		tRoof.Size = Vector3.new(TRACK_WIDTH + 10, 4, segLen)
		tRoof.CFrame = cf * CFrame.new(0, 27, 0)
		tRoof.Parent = sceneryFolder

		if i % 2 == 0 then
			local laserTop = Instance.new("Part")
			laserTop.Name = "TunnelLaserRibTop_" .. i
			laserTop.Anchored = true
			laserTop.CanCollide = false
			laserTop.Material = Enum.Material.SmoothPlastic
			laserTop.Color = tunnelRibColor
			laserTop.Size = Vector3.new(TRACK_WIDTH + 2, 1.0, 1.4)
			laserTop.CFrame = cf * CFrame.new(0, 24.5, 0)
			laserTop.Parent = sceneryFolder

			for _, side in ipairs({ -1, 1 }) do
				local laserSide = Instance.new("Part")
				laserSide.Name = "TunnelLaserRibSide_" .. i
				laserSide.Anchored = true
				laserSide.CanCollide = false
				laserSide.Material = Enum.Material.SmoothPlastic
				laserSide.Color = tunnelRibColor
				laserSide.Size = Vector3.new(1.0, 23, 1.4)
				laserSide.CFrame = cf * CFrame.new(side * (halfW + 0.5), 13, 0)
				laserSide.Parent = sceneryFolder
			end
		end
	end

	-- 4. Sequential Checkpoints (1..6)
	local cpFolder = Instance.new("Folder")
	cpFolder.Name = "Checkpoints"
	cpFolder.Parent = mapModel

	local cpAngles = {
		0.33 * math.pi,
		0.66 * math.pi,
		1.00 * math.pi,
		1.33 * math.pi,
		1.66 * math.pi,
		0.0,
	}
	for idx, cpT in ipairs(cpAngles) do
		local p, tan = getCyberPoint(cpT)
		local cf = CFrame.lookAt(p, p + tan)
		local cpPart = Instance.new("Part")
		cpPart.Name = tostring(idx)
		cpPart.Anchored = true
		cpPart.CanCollide = false
		cpPart.Transparency = 1
		cpPart.Size = Vector3.new(TRACK_WIDTH + 14, 24, 22)
		cpPart.CFrame = cf * CFrame.new(0, 10, 0)
		cpPart.Parent = cpFolder
	end

	-- 5. Start Line & Spawn Grid at t = 0.0
	local startP, startTan = getCyberPoint(0.0)
	local flatForward = Vector3.new(startTan.X, 0, startTan.Z).Unit
	local startPos = startP + Vector3.new(0, 0.35, 0)
	local startCFrame = CFrame.lookAt(startPos, startPos - flatForward)

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


function MapBuilder.buildPirateTreasureIslandModel(): Model
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local pirateAssets = ReplicatedStorage:FindFirstChild("PirateAssets")

	local mapModel = Instance.new("Model")
	mapModel.Name = "Pirate Treasure Island"

	local SEGMENTS = 240
	local TRACK_WIDTH = 58
	local halfW = TRACK_WIDTH / 2
	local TRACK_THICKNESS = 2.4

	local function getPiratePoint(t: number): (Vector3, Vector3)
		local x = 300 * math.sin(t) + 60 * math.sin(2 * t)
		local z = -340 * math.cos(t) + 40 * math.cos(3 * t)

		local dx = 300 * math.cos(t) + 120 * math.cos(2 * t)
		local dz = 340 * math.sin(t) - 120 * math.sin(3 * t)

		local frac = t / (2 * math.pi)
		local y = 14.0
		local dy = 0.0

		if frac < 0.25 then
			y = 14.0
			dy = 0.0
		elseif frac < 0.38 then
			local u = (frac - 0.25) / 0.13
			local s = u * u * (3 - 2 * u)
			local ds = (6 * u - 6 * u * u) / 0.13
			y = 14.0 + 18.0 * s
			dy = (18.0 * ds) / (2 * math.pi)
		elseif frac < 0.58 then
			y = 32.0
			dy = 0.0
		elseif frac < 0.66 then
			local u = (frac - 0.58) / 0.08
			local s = u * u * (3 - 2 * u)
			local ds = (6 * u - 6 * u * u) / 0.08
			y = 32.0 - 16.0 * s
			dy = (-16.0 * ds) / (2 * math.pi)
		elseif frac < 0.80 then
			local u = (frac - 0.66) / 0.14
			local s = u * u * (3 - 2 * u)
			local ds = (6 * u - 6 * u * u) / 0.14
			y = 16.0 + 20.0 * s
			dy = (20.0 * ds) / (2 * math.pi)
		elseif frac < 0.90 then
			y = 36.0
			dy = 0.0
		else
			local u = (frac - 0.90) / 0.10
			local s = u * u * (3 - 2 * u)
			local ds = (6 * u - 6 * u * u) / 0.10
			y = 36.0 - 22.0 * s
			dy = (-22.0 * ds) / (2 * math.pi)
		end

		local pos = Vector3.new(x, y, z)
		local tan = Vector3.new(dx, dy, dz).Unit
		return pos, tan
	end

	local function distToTrack(x: number, z: number): number
		local minDist = 99999
		for step = 1, 60 do
			local t = (step / 60) * math.pi * 2
			local p = getPiratePoint(t)
			local d = math.sqrt((x - p.X)^2 + (z - p.Z)^2)
			if d < minDist then minDist = d end
		end
		return minDist
	end

	-- 1. TRACK & GUARDWALLS
	local trackFolder = Instance.new("Folder")
	trackFolder.Name = "HoverboardTrack"
	trackFolder.Parent = mapModel

	local woodPlanks = Enum.Material.WoodPlanks
	local slateMat = Enum.Material.Slate

	for i = 1, SEGMENTS do
		local t1 = ((i - 1) / SEGMENTS) * math.pi * 2
		local t2 = (i / SEGMENTS) * math.pi * 2
		local p1 = getPiratePoint(t1)
		local p2 = getPiratePoint(t2)

		local midPos = (p1 + p2) * 0.5
		local segLen = (p2 - p1).Magnitude + 1.2
		local cf = CFrame.lookAt(midPos, p2)

		local frac = t1 / (2 * math.pi)
		local isBeachZone   = (frac < 0.25)
		local isRampUp      = (frac >= 0.25 and frac < 0.38)
		local isGalleonDeck = (frac >= 0.38 and frac < 0.58)
		local isSternDive   = (frac >= 0.58 and frac < 0.66)
		local isCavernZone  = (frac >= 0.66 and frac < 0.80)
		local isBridgeZone  = (frac >= 0.80 and frac < 0.90)
		local isDescentZone = (frac >= 0.90)

		local roadMat = woodPlanks
		local roadColor = Color3.fromRGB(135, 88, 50) -- Harbor & Beach wood
		local curbColor = Color3.fromRGB(80, 50, 30)

		if isRampUp or isGalleonDeck then
			roadColor = Color3.fromRGB(115, 75, 42) -- Ship deck dark oak
			curbColor = Color3.fromRGB(65, 40, 22)
		elseif isCavernZone then
			roadMat = slateMat
			roadColor = Color3.fromRGB(65, 62, 60) -- Mountain cavern slate
			curbColor = Color3.fromRGB(90, 85, 80)
		elseif isBridgeZone then
			roadColor = Color3.fromRGB(145, 105, 70) -- Suspension bridge weathered planks
			curbColor = Color3.fromRGB(95, 65, 40)
		end

		local road = Instance.new("Part")
		road.Name = "PirateTrack_" .. i
		road.Anchored = true
		road.CanCollide = true
		road.CastShadow = false
		road.Material = roadMat
		road.Color = roadColor
		road.Size = Vector3.new(TRACK_WIDTH, TRACK_THICKNESS, segLen)
		road.CFrame = cf
		road.TopSurface = Enum.SurfaceType.Smooth
		road.BottomSurface = Enum.SurfaceType.Smooth
		road.Parent = trackFolder

		-- Track center stripe: brass studs or gold inlays
		local stripeColor = isCavernZone and Color3.fromRGB(240, 195, 50) or Color3.fromRGB(165, 125, 75)
		local stripe = Instance.new("Part")
		stripe.Name = "TrackCenterStripe"
		stripe.Anchored = true
		stripe.CanCollide = false
		stripe.CastShadow = false
		stripe.Material = isCavernZone and Enum.Material.Metal or Enum.Material.Wood
		stripe.Color = stripeColor
		stripe.Size = Vector3.new(1.4, 0.2, segLen)
		stripe.CFrame = cf * CFrame.new(0, (TRACK_THICKNESS / 2) + 0.1, 0)
		stripe.Parent = trackFolder

		-- Curbs and Railings
		local barrierH = (isBridgeZone or isGalleonDeck or isRampUp) and 5.5 or 3.2
		for _, side in ipairs({ -1, 1 }) do
			local curb = Instance.new("Part")
			curb.Name = "TrackCurb"
			curb.Anchored = true
			curb.CanCollide = true
			curb.CastShadow = false
			curb.Material = roadMat
			curb.Color = curbColor
			curb.Size = Vector3.new(2.4, barrierH, segLen)
			curb.CFrame = cf * CFrame.new(side * (halfW - 1.2), (barrierH - TRACK_THICKNESS) / 2 + 0.4, 0)
			curb.Parent = trackFolder

			local ropeRail = Instance.new("Part")
			ropeRail.Name = "RopeRail"
			ropeRail.Anchored = true
			ropeRail.CanCollide = false
			ropeRail.CastShadow = false
			ropeRail.Material = Enum.Material.Wood
			ropeRail.Color = Color3.fromRGB(180, 140, 90)
			ropeRail.Size = Vector3.new(0.8, 0.8, segLen)
			ropeRail.CFrame = cf * CFrame.new(side * (halfW - 1.2), barrierH + 0.4, 0)
			ropeRail.Parent = trackFolder

			local guard = Instance.new("Part")
			guard.Name = "TrackGuardWall"
			guard.Anchored = true
			guard.CanCollide = true
			guard.CastShadow = false
			guard.Transparency = 1
			guard.Size = Vector3.new(1.5, 24, segLen)
			guard.CFrame = cf * CFrame.new(side * (halfW + 0.6), 12, 0)
			guard.Parent = trackFolder
		end

		-- Support stilts for elevated sections (Y >= 18)
		if p1.Y >= 18 and i % 3 == 0 then
			for _, side in ipairs({ -1, 1 }) do
				local stiltH = p1.Y - 2
				local stilt = Instance.new("Part")
				stilt.Name = "TrackStiltPillar"
				stilt.Anchored = true
				stilt.CanCollide = false
				stilt.CastShadow = false
				stilt.Material = Enum.Material.Wood
				stilt.Color = Color3.fromRGB(75, 45, 25)
				stilt.Size = Vector3.new(3.0, stiltH, 3.0)
				stilt.CFrame = cf * CFrame.new(side * (halfW - 2), -stiltH / 2, 0)
				stilt.Parent = trackFolder
			end
		end
	end

	-- 2. OCEAN & TERRAIN
	local groundFolder = Instance.new("Folder")
	groundFolder.Name = "GroundFloor"
	groundFolder.Parent = mapModel

	local oceanQuads = {
		{ x = -420, z = -420 },
		{ x =  420, z = -420 },
		{ x = -420, z =  420 },
		{ x =  420, z =  420 },
	}
	for idx, q in ipairs(oceanQuads) do
		local water = Instance.new("Part")
		water.Name = "CaribbeanOcean_" .. idx
		water.Anchored = true
		water.CanCollide = true
		water.CastShadow = false
		water.Material = Enum.Material.SmoothPlastic
		water.Color = Color3.fromRGB(0, 160, 215)
		water.Transparency = 0.35
		water.Reflectance = 0.2
		water.Size = Vector3.new(860, 4, 860)
		water.CFrame = CFrame.new(q.x, 2, q.z)
		water.TopSurface = Enum.SurfaceType.Smooth
		water.BottomSurface = Enum.SurfaceType.Smooth
		water.Parent = groundFolder

		local seaBed = Instance.new("Part")
		seaBed.Name = "SandySeaBed_" .. idx
		seaBed.Anchored = true
		seaBed.CanCollide = true
		seaBed.CastShadow = false
		seaBed.Material = Enum.Material.Sand
		seaBed.Color = Color3.fromRGB(225, 215, 185)
		seaBed.Size = Vector3.new(860, 6, 860)
		seaBed.CFrame = CFrame.new(q.x, -3, q.z)
		seaBed.TopSurface = Enum.SurfaceType.Smooth
		seaBed.BottomSurface = Enum.SurfaceType.Smooth
		seaBed.Parent = groundFolder
	end

	-- Tropical Beach along Sector 1
	local beachSand = Instance.new("Part")
	beachSand.Name = "TropicalBeachSand"
	beachSand.Anchored = true
	beachSand.CanCollide = true
	beachSand.CastShadow = false
	beachSand.Material = Enum.Material.Sand
	beachSand.Color = Color3.fromRGB(240, 225, 185)
	beachSand.Size = Vector3.new(420, 6, 440)
	beachSand.CFrame = CFrame.new(180, 5, -200)
	beachSand.TopSurface = Enum.SurfaceType.Smooth
	beachSand.Parent = groundFolder

	-- 3. PIRATE SHIP DECK RUN & AUTHENTIC ASSET INTEGRATION
	local galleonFolder = Instance.new("Folder")
	galleonFolder.Name = "GalleonShipSection"
	galleonFolder.Parent = mapModel

	-- Clone authentic PirateShip asset (134484871178553) into the bay
	local shipAsset = pirateAssets and pirateAssets:FindFirstChild("PirateShip")
	if shipAsset then
		local shipClone = shipAsset:Clone()
		shipClone.Name = "AnchoredGalleon"

		-- Position ship alongside the deck run at t = 0.48*2*pi
		local shipCenterP, shipCenterTan = getPiratePoint(0.48 * 2 * math.pi)
		local shipCF = CFrame.lookAt(shipCenterP + Vector3.new(-65, -8, -15), shipCenterP + Vector3.new(-65, -8, -15) + shipCenterTan)

		shipClone:PivotTo(shipCF)
		for _, d in ipairs(shipClone:GetDescendants()) do
			if d:IsA("BasePart") then
				if d.Size.Magnitude < 2.5 and not d:IsA("MeshPart") then
					d:Destroy()
				else
					d.CanCollide = false -- Keep completely safe so no collisions with track
					d.Anchored = true
					d.CastShadow = false
				end
			end
		end
		shipClone.Parent = galleonFolder
	end

	-- Pirate Captain (100944702942220) + Ship's Wheel (14924421591) + Rum Mugs (11487426084) on Quarterdeck
	local captainP, captainTan = getPiratePoint(0.50 * 2 * math.pi)
	local captainCF = CFrame.lookAt(captainP, captainP + captainTan)

	-- Elevated wooden captain's quarterdeck platform - positioned right along track railing for high visibility
	local quarterdeckPlatform = Instance.new("Part")
	quarterdeckPlatform.Name = "CaptainQuarterdeck"
	quarterdeckPlatform.Anchored = true
	quarterdeckPlatform.CanCollide = true
	quarterdeckPlatform.Material = Enum.Material.WoodPlanks
	quarterdeckPlatform.Color = Color3.fromRGB(75, 45, 25)
	quarterdeckPlatform.Size = Vector3.new(24, 6, 32)
	quarterdeckPlatform.CFrame = captainCF * CFrame.new(-(halfW + 6), 5.5, 0)
	quarterdeckPlatform.Parent = galleonFolder

	-- Carved decorative railings with gold trim on outer edges
	for _, rSide in ipairs({ -1, 1 }) do
		local rail = Instance.new("Part")
		rail.Name = "QuarterdeckRailing"
		rail.Anchored = true
		rail.CanCollide = false
		rail.Material = Enum.Material.Wood
		rail.Color = Color3.fromRGB(90, 55, 30)
		rail.Size = Vector3.new(1.8, 4.0, 32)
		rail.CFrame = quarterdeckPlatform.CFrame * CFrame.new(rSide * 11.5, 4.5, 0)
		rail.Parent = galleonFolder
	end

	-- Grand Brass Ship Lanterns on platform corners illuminating the Captain & Helm
	for _, cZ in ipairs({ -14, 14 }) do
		local lPost = Instance.new("Part")
		lPost.Name = "QuarterdeckLanternPost"
		lPost.Anchored = true
		lPost.CanCollide = false
		lPost.Material = Enum.Material.Wood
		lPost.Color = Color3.fromRGB(55, 35, 20)
		lPost.Size = Vector3.new(1.6, 12.0, 1.6)
		lPost.CFrame = quarterdeckPlatform.CFrame * CFrame.new(10.5, 8.5, cZ)
		lPost.Parent = galleonFolder

		local lamp = Instance.new("Part")
		lamp.Name = "QuarterdeckLamp"
		lamp.Anchored = true
		lamp.CanCollide = false
		lamp.Material = Enum.Material.Neon
		lamp.Color = Color3.fromRGB(255, 225, 130)
		lamp.Size = Vector3.new(2.8, 4.0, 2.8)
		lamp.CFrame = lPost.CFrame * CFrame.new(0, 7.0, 0)
		lamp.Parent = galleonFolder

		local lampLight = Instance.new("PointLight")
		lampLight.Color = Color3.fromRGB(255, 195, 85)
		lampLight.Brightness = 4.5
		lampLight.Range = 36
		lampLight.Parent = lamp
	end

	-- Overhead Theatrical Spotlight directly focused onto the Captain & Steering Helm
	local spotRig = Instance.new("Part")
	spotRig.Name = "CaptainSpotlightMount"
	spotRig.Anchored = true
	spotRig.CanCollide = false
	spotRig.Transparency = 1
	spotRig.Size = Vector3.new(2, 2, 2)
	spotRig.CFrame = quarterdeckPlatform.CFrame * CFrame.new(0, 26, 0)
	spotRig.Parent = galleonFolder

	local spotLight = Instance.new("SpotLight")
	spotLight.Face = Enum.NormalId.Bottom
	spotLight.Color = Color3.fromRGB(255, 220, 140)
	spotLight.Brightness = 6.0
	spotLight.Range = 40
	spotLight.Angle = 65
	spotLight.Parent = spotRig

	-- 1. COLOSSAL PIRATE CAPTAIN (100944702942220) - Scaled 2.8x (Height ~18 studs!)
	local captainAsset = pirateAssets and pirateAssets:FindFirstChild("PirateCaptain")
	if captainAsset then
		local capClone = captainAsset:Clone()
		capClone.Name = "CaptainJack"
		capClone:ScaleTo(2.8)
		capClone:PivotTo(quarterdeckPlatform.CFrame * CFrame.new(-3.5, 3.0 + 8.9, 0) * CFrame.Angles(0, math.rad(90), 0))
		for _, d in ipairs(capClone:GetDescendants()) do
			if d:IsA("BasePart") then
				d.CanCollide = false
				d.Anchored = true
			end
		end
		capClone.Parent = galleonFolder

		-- Prominent Cartoon Pirate Name Tag above Captain Jack's head
		local head = capClone:FindFirstChild("Head", true) or capClone.PrimaryPart
		if head then
			local bb = Instance.new("BillboardGui")
			bb.Name = "CaptainTitleHUD"
			bb.Size = UDim2.new(0, 260, 0, 56)
			bb.StudsOffset = Vector3.new(0, 6.5, 0)
			bb.AlwaysOnTop = true
			bb.MaxDistance = 350
			bb.Parent = head

			local title = Instance.new("TextLabel")
			title.Size = UDim2.new(1, 0, 1, 0)
			title.BackgroundTransparency = 1
			title.Text = "☠️ 캡틴 잭 (Captain Jack)"
			title.TextColor3 = Color3.fromRGB(255, 225, 90)
			title.TextStrokeColor3 = Color3.fromRGB(35, 18, 5)
			title.TextStrokeTransparency = 0
			title.Font = Enum.Font.FredokaOne
			title.TextSize = 26
			title.Parent = bb
		end
	end

	-- 2. MASSIVE SHIP'S WHEEL (14924421591) - Scaled 3.5x on Steering Pedestal
	local wheelPedestal = Instance.new("Part")
	wheelPedestal.Name = "SteeringPedestal"
	wheelPedestal.Anchored = true
	wheelPedestal.CanCollide = false
	wheelPedestal.Material = Enum.Material.WoodPlanks
	wheelPedestal.Color = Color3.fromRGB(65, 38, 20)
	wheelPedestal.Size = Vector3.new(4.5, 7.5, 4.5)
	wheelPedestal.CFrame = quarterdeckPlatform.CFrame * CFrame.new(3.5, 3.0 + 3.75, 0)
	wheelPedestal.Parent = galleonFolder

	local wheelAsset = pirateAssets and pirateAssets:FindFirstChild("ShipsWheel")
	if wheelAsset then
		local wheelClone = wheelAsset:Clone()
		wheelClone.Name = "QuarterdeckWheel"
		local handle = wheelClone:FindFirstChild("Handle")
		if handle and handle:IsA("BasePart") then
			handle.Anchored = true
			handle.CanCollide = false
			handle.Size = Vector3.new(3, 3, 3)
			handle.CFrame = quarterdeckPlatform.CFrame * CFrame.new(3.5, 3.0 + 7.8, 0) * CFrame.Angles(0, math.rad(90), 0)
			local sMesh = handle:FindFirstChildWhichIsA("SpecialMesh")
			if sMesh then
				sMesh.Scale = Vector3.new(3.5, 3.5, 3.5)
			end
		end
		wheelClone.Parent = galleonFolder
	end

	-- 3. GIANT RUM MUGS (11487426084) - Scaled 4.5x on Captain's Table with Treasure
	local rumTable = Instance.new("Part")
	rumTable.Name = "CaptainsRumTable"
	rumTable.Anchored = true
	rumTable.CanCollide = false
	rumTable.Material = Enum.Material.Wood
	rumTable.Color = Color3.fromRGB(70, 42, 24)
	rumTable.Size = Vector3.new(8.0, 4.0, 10.0)
	rumTable.CFrame = quarterdeckPlatform.CFrame * CFrame.new(1.0, 3.0 + 2.0, 8.5)
	rumTable.Parent = galleonFolder

	-- Wooden Rum Barrel alongside table
	local barrel = Instance.new("Part")
	barrel.Name = "RumBarrel"
	barrel.Shape = Enum.PartType.Cylinder
	barrel.Size = Vector3.new(6.0, 5.5, 5.5)
	barrel.Material = Enum.Material.Wood
	barrel.Color = Color3.fromRGB(85, 50, 28)
	barrel.CFrame = quarterdeckPlatform.CFrame * CFrame.new(-5.5, 3.0 + 2.75, 8.5) * CFrame.Angles(0, 0, math.rad(90))
	barrel.Anchored = true
	barrel.CanCollide = false
	barrel.Parent = galleonFolder

	-- Gold coin pile on table
	local tableGold = Instance.new("Part")
	tableGold.Name = "TableGoldPile"
	tableGold.Size = Vector3.new(5.0, 1.0, 6.0)
	tableGold.Material = Enum.Material.Foil
	tableGold.Color = Color3.fromRGB(255, 215, 0)
	tableGold.CFrame = rumTable.CFrame * CFrame.new(0, 2.3, 0)
	tableGold.Anchored = true
	tableGold.CanCollide = false
	tableGold.Parent = galleonFolder

	local rumAsset = pirateAssets and pirateAssets:FindFirstChild("RumMug")
	if rumAsset then
		for idx, rOff in ipairs({ Vector3.new(-1.8, 3.0 + 4.2, 8.5), Vector3.new(1.8, 3.0 + 4.2, 8.5) }) do
			local mugClone = rumAsset:Clone()
			mugClone.Name = "GiantRumMug_" .. idx
			mugClone:PivotTo(quarterdeckPlatform.CFrame * CFrame.new(rOff))
			for _, d in ipairs(mugClone:GetDescendants()) do
				if d:IsA("BasePart") then
					d.CanCollide = false
					d.Anchored = true
					local sMesh = d:FindFirstChildWhichIsA("SpecialMesh")
					if sMesh then
						sMesh.Scale = Vector3.new(4.5, 4.5, 4.5)
					end
				end
			end
			local handle = mugClone:FindFirstChild("Handle", true)
			if handle and handle:IsA("BasePart") then
				local mLight = Instance.new("PointLight")
				mLight.Color = Color3.fromRGB(255, 170, 30)
				mLight.Brightness = 3.5
				mLight.Range = 16
				mLight.Parent = handle
			end
			mugClone.Parent = galleonFolder
		end
	end

	-- Masts & Rigging spanning overhead across the ship deck
	for _, mFrac in ipairs({ 0.40, 0.48, 0.55 }) do
		local mp, mTan = getPiratePoint(mFrac * 2 * math.pi)
		local mcf = CFrame.lookAt(mp, mp + mTan)

		for _, side in ipairs({ -1, 1 }) do
			local mastCol = Instance.new("Part")
			mastCol.Name = "ShipDeckMastPillar"
			mastCol.Anchored = true
			mastCol.CanCollide = false
			mastCol.Material = Enum.Material.Wood
			mastCol.Color = Color3.fromRGB(85, 50, 28)
			mastCol.Size = Vector3.new(4, 95, 4)
			mastCol.CFrame = mcf * CFrame.new(side * (halfW + 4), 45, 0)
			mastCol.Parent = galleonFolder

			local rig = Instance.new("TrussPart")
			rig.Name = "MastRigging"
			rig.Anchored = true
			rig.CanCollide = false
			rig.Color = Color3.fromRGB(70, 50, 35)
			rig.Size = Vector3.new(2, 75, 2)
			rig.CFrame = mcf * CFrame.new(side * (halfW + 6), 37, 0)
			rig.Parent = galleonFolder
		end

		-- Overhead Yards & White Billowing Sails
		for tier = 1, 2 do
			local yH = 36 + tier * 24
			local sparW = TRACK_WIDTH + 26
			local yard = Instance.new("Part")
			yard.Name = "OverheadYard"
			yard.Anchored = true
			yard.CanCollide = false
			yard.Material = Enum.Material.Wood
			yard.Color = Color3.fromRGB(75, 45, 25)
			yard.Size = Vector3.new(sparW, 2.5, 2.5)
			yard.CFrame = mcf * CFrame.new(0, yH, 0)
			yard.Parent = galleonFolder

			local sail = Instance.new("Part")
			sail.Name = "BillowingSail"
			sail.Anchored = true
			sail.CanCollide = false
			sail.Material = Enum.Material.SmoothPlastic
			sail.Color = Color3.fromRGB(245, 240, 230)
			sail.Size = Vector3.new(sparW - 6, 16, 1.2)
			sail.CFrame = mcf * CFrame.new(0, yH - 8, 2.0) * CFrame.Angles(math.rad(8), 0, 0)
			sail.Parent = galleonFolder
		end
	end

	-- 4. AUTHENTIC SKULL ROCK (1609804106) & TREASURE CAVERN
	local skullFolder = Instance.new("Folder")
	skullFolder.Name = "SkullRockAndCavern"
	skullFolder.Parent = mapModel

	local darkSlate = Color3.fromRGB(58, 54, 50)
	local midSlate  = Color3.fromRGB(72, 67, 62)
	local warmSlate = Color3.fromRGB(86, 80, 74)

	-- 1. Grand Arch Entrance with Authentic Skull & Mountain Cliffs
	local entFrac = 0.68
	local entP, entTan = getPiratePoint(entFrac * 2 * math.pi)
	local entCF = CFrame.lookAt(entP, entP + entTan)

	-- Flanking Mountain Cliffs on both sides of the skull arch
	for _, side in ipairs({ -1, 1 }) do
		local cliff = Instance.new("Part")
		cliff.Name = "MountainCliffCrag"
		cliff.Anchored = true
		cliff.CanCollide = false
		cliff.Material = Enum.Material.Rock
		cliff.Color = darkSlate
		cliff.Size = Vector3.new(32, 60, 36)
		cliff.CFrame = entCF * CFrame.new(side * (halfW + 18), 28, -6) * CFrame.Angles(0, side * math.rad(15), side * math.rad(-5))
		cliff.Parent = skullFolder

		-- Authentic Fire Pillar (15219131218) on cliff pinnacle
		local firePillarAsset = pirateAssets and pirateAssets:FindFirstChild("FirePillar")
		if firePillarAsset then
			local pClone = firePillarAsset:Clone()
			pClone.Name = "AuthenticCliffFirePillar"
			pClone:PivotTo(cliff.CFrame * CFrame.new(0, 30, 0))
			for _, d in ipairs(pClone:GetDescendants()) do
				if d:IsA("BasePart") then
					d.Anchored = true
					d.CanCollide = false
				end
			end
			pClone.Parent = skullFolder
		end

		local boulder = Instance.new("Part")
		boulder.Name = "EntranceBoulder"
		boulder.Anchored = true
		boulder.CanCollide = false
		boulder.Material = Enum.Material.Slate
		boulder.Color = midSlate
		boulder.Size = Vector3.new(24, 28, 26)
		boulder.CFrame = entCF * CFrame.new(side * (halfW + 12), 14, 8) * CFrame.Angles(side * math.rad(10), 0, side * math.rad(10))
		boulder.Parent = skullFolder

		local pillar = Instance.new("Part")
		pillar.Name = "EntrancePillar"
		pillar.Anchored = true
		pillar.CanCollide = false
		pillar.Material = Enum.Material.Slate
		pillar.Color = warmSlate
		pillar.Size = Vector3.new(12, 36, 14)
		pillar.CFrame = entCF * CFrame.new(side * (halfW + 4), 18, 0)
		pillar.Parent = skullFolder

		local sconce = Instance.new("Part")
		sconce.Name = "EntranceLantern"
		sconce.Anchored = true
		sconce.CanCollide = false
		sconce.Material = Enum.Material.Metal
		sconce.Color = Color3.fromRGB(40, 35, 30)
		sconce.Size = Vector3.new(2, 4, 2)
		sconce.CFrame = entCF * CFrame.new(side * (halfW + 1), 22, -3)
		sconce.Parent = skullFolder

		local sconceLight = Instance.new("PointLight")
		sconceLight.Color = Color3.fromRGB(255, 175, 75)
		sconceLight.Brightness = 3.5
		sconceLight.Range = 30
		sconceLight.Parent = sconce
	end

	-- Arch Beam across top
	local archBeam = Instance.new("Part")
	archBeam.Name = "EntranceArchBeam"
	archBeam.Anchored = true
	archBeam.CanCollide = false
	archBeam.Material = Enum.Material.Slate
	archBeam.Color = darkSlate
	archBeam.Size = Vector3.new(TRACK_WIDTH + 14, 8, 16)
	archBeam.CFrame = entCF * CFrame.new(0, 32, 0)
	archBeam.Parent = skullFolder

	-- Hanging stone stalactites forming natural "teeth" below the arch
	for i = -3, 3 do
		local tooth = Instance.new("Part")
		tooth.Name = "ArchStalactiteTooth"
		tooth.Anchored = true
		tooth.CanCollide = false
		tooth.Material = Enum.Material.Rock
		tooth.Color = midSlate
		tooth.Size = Vector3.new(3.5, math.abs(i) % 2 == 0 and 6.0 or 4.0, 3.5)
		tooth.CFrame = entCF * CFrame.new(i * 7.5, 26, -1)
		tooth.Parent = skullFolder
	end

	-- The Colossal Authentic Skull resting majestically atop the arch
	local skullAsset = pirateAssets and pirateAssets:FindFirstChild("SkullRock")
	local skullMeshOrig = skullAsset and skullAsset:FindFirstChild("Skull", true)
	if skullMeshOrig then
		local skullClone = skullMeshOrig:Clone()
		skullClone.Name = "ColossalSkullRock"
		skullClone.Size = Vector3.new(70, 70, 70)
		skullClone.CFrame = (entCF * CFrame.new(0, 60, -4)) * CFrame.Angles(math.rad(-14), 0, 0)
		skullClone.Anchored = true
		skullClone.CanCollide = false
		skullClone.Material = Enum.Material.Rock
		skullClone.Color = Color3.fromRGB(205, 200, 186)
		skullClone.Parent = skullFolder

		local eyeCF = skullClone.CFrame
		for _, side in ipairs({ -1, 1 }) do
			local eyePart = Instance.new("Part")
			eyePart.Name = "SkullEyeFire"
			eyePart.Shape = Enum.PartType.Ball
			eyePart.Size = Vector3.new(5.0, 5.0, 5.0)
			eyePart.Material = Enum.Material.Neon
			eyePart.Color = Color3.fromRGB(255, 60, 15)
			eyePart.Anchored = true
			eyePart.CanCollide = false
			eyePart.CFrame = eyeCF * CFrame.new(side * 11.5, 7.5, 7.0)
			eyePart.Parent = skullFolder

			local eyeLight = Instance.new("PointLight")
			eyeLight.Name = "EyeGlow"
			eyeLight.Color = Color3.fromRGB(255, 55, 10)
			eyeLight.Brightness = 4.0
			eyeLight.Range = 24
			eyeLight.Parent = eyePart
		end
	end

	-- 2. Cavern Walls, Natural Arches, and Treasure Grotto (frac: 0.68 to 0.79)
	local cavernStart = math.floor(0.68 * SEGMENTS)
	local cavernEnd   = math.floor(0.79 * SEGMENTS)

	for cStep = cavernStart, cavernEnd, 2 do
		local t = (cStep / SEGMENTS) * 2 * math.pi
		local cp, cTan = getPiratePoint(t)
		local ccf = CFrame.lookAt(cp, cp + cTan)

		-- Natural jagged rock side walls
		for _, side in ipairs({ -1, 1 }) do
			local wall = Instance.new("Part")
			wall.Name = "CavernWall"
			wall.Anchored = true
			wall.CanCollide = false
			wall.Material = Enum.Material.Slate
			wall.Color = (cStep % 4 == 0) and darkSlate or midSlate
			wall.Size = Vector3.new(16, 32, 22)
			wall.CFrame = ccf * CFrame.new(side * (halfW + 8), 16, 0)
			wall.Parent = skullFolder

			if cStep % 4 == 1 then
				local stalagmite = Instance.new("Part")
				stalagmite.Name = "Stalagmite"
				stalagmite.Anchored = true
				stalagmite.CanCollide = false
				stalagmite.Material = Enum.Material.Rock
				stalagmite.Color = darkSlate
				stalagmite.Size = Vector3.new(5, 12, 5)
				stalagmite.CFrame = ccf * CFrame.new(side * (halfW + 3), 6, 0)
				stalagmite.Parent = skullFolder
			end
		end

		-- Natural stone arch every 4 steps
		if cStep % 4 == 0 then
			local roofArch = Instance.new("Part")
			roofArch.Name = "CavernNaturalArch"
			roofArch.Anchored = true
			roofArch.CanCollide = false
			roofArch.Material = Enum.Material.Rock
			roofArch.Color = darkSlate
			roofArch.Size = Vector3.new(TRACK_WIDTH + 18, 6, 18)
			roofArch.CFrame = ccf * CFrame.new(0, 27, 0)
			roofArch.Parent = skullFolder

			local stalactite = Instance.new("Part")
			stalactite.Name = "Stalactite"
			stalactite.Anchored = true
			stalactite.CanCollide = false
			stalactite.Material = Enum.Material.Rock
			stalactite.Color = midSlate
			stalactite.Size = Vector3.new(4, 8, 4)
			stalactite.CFrame = ccf * CFrame.new((cStep % 8 == 0 and -14 or 14), 22, 0)
			stalactite.Parent = skullFolder
		end

		-- Warm Pirate Wall Torches
		if cStep % 3 == 0 then
			for _, side in ipairs({ -1, 1 }) do
				local torchBracket = Instance.new("Part")
				torchBracket.Name = "CaveLanternBracket"
				torchBracket.Anchored = true
				torchBracket.CanCollide = false
				torchBracket.Material = Enum.Material.Metal
				torchBracket.Color = Color3.fromRGB(45, 40, 35)
			torchBracket.Size = Vector3.new(1.2, 3.5, 1.2)
				torchBracket.CFrame = ccf * CFrame.new(side * (halfW + 2), 11, 0)
				torchBracket.Parent = skullFolder

				local flame = Instance.new("Part")
				flame.Name = "LanternFlame"
				flame.Anchored = true
				flame.CanCollide = false
				flame.Material = Enum.Material.Neon
				flame.Color = Color3.fromRGB(255, 185, 80)
				flame.Size = Vector3.new(1.5, 1.5, 1.5)
				flame.CFrame = torchBracket.CFrame * CFrame.new(0, 2.2, 0)
				flame.Parent = skullFolder

				local light = Instance.new("PointLight")
				light.Name = "CaveLanternLight"
				light.Color = Color3.fromRGB(255, 180, 80)
				light.Brightness = 3.2
				light.Range = 36
				light.Parent = flame
			end
		end

		-- Sparkling Gold Piles & Glowing Crystals
		if cStep % 3 == 1 then
			for _, side in ipairs({ -1, 1 }) do
				local gold = Instance.new("Part")
				gold.Name = "PirateGoldPile"
				gold.Anchored = true
				gold.CanCollide = false
				gold.Material = Enum.Material.Foil
				gold.Color = Color3.fromRGB(255, 215, 0)
				gold.Size = Vector3.new(8, 2.5, 10)
				gold.CFrame = ccf * CFrame.new(side * (halfW - 3), 1.2, 0)
				gold.Parent = skullFolder

				local crystal = Instance.new("Part")
				crystal.Name = "CavernCrystal"
				crystal.Anchored = true
				crystal.CanCollide = false
				crystal.Material = Enum.Material.Neon
				local isRuby = (cStep % 2 == 0)
				crystal.Color = isRuby and Color3.fromRGB(255, 40, 80) or Color3.fromRGB(40, 255, 120)
				crystal.Size = Vector3.new(2.5, 6.0, 2.5)
				crystal.CFrame = ccf * CFrame.new(side * (halfW + 2), 4.0, 0) * CFrame.Angles(0, 0, side * math.rad(-20))
				crystal.Parent = skullFolder

				local cLight = Instance.new("PointLight")
				cLight.Color = crystal.Color
				cLight.Brightness = 2.2
				cLight.Range = 18
				cLight.Parent = crystal
			end
		end
	end

	-- 3. Grand Cavern Exit Portal
	local exitFrac = 0.795
	local exitP, exitTan = getPiratePoint(exitFrac * 2 * math.pi)
	local exitCF = CFrame.lookAt(exitP, exitP + exitTan)

	for _, side in ipairs({ -1, 1 }) do
		local exitPillar = Instance.new("Part")
		exitPillar.Name = "ExitPillar"
		exitPillar.Anchored = true
		exitPillar.CanCollide = false
		exitPillar.Material = Enum.Material.Slate
		exitPillar.Color = darkSlate
		exitPillar.Size = Vector3.new(16, 32, 16)
		exitPillar.CFrame = exitCF * CFrame.new(side * (halfW + 6), 16, 0)
		exitPillar.Parent = skullFolder
	end

	local exitBeam = Instance.new("Part")
	exitBeam.Name = "ExitArchBeam"
	exitBeam.Anchored = true
	exitBeam.CanCollide = false
	exitBeam.Material = Enum.Material.Slate
	exitBeam.Color = darkSlate
	exitBeam.Size = Vector3.new(TRACK_WIDTH + 14, 6, 14)
	exitBeam.CFrame = exitCF * CFrame.new(0, 28, 0)
	exitBeam.Parent = skullFolder

	-- 5. CLIFFSIDE ROPE SUSPENSION BRIDGE (frac: 0.80 to 0.90)
	local bridgeFolder = Instance.new("Folder")
	bridgeFolder.Name = "SuspensionBridge"
	bridgeFolder.Parent = mapModel

	local bridgeStartIdx = math.floor(0.80 * SEGMENTS)
	local bridgeEndIdx   = math.floor(0.90 * SEGMENTS)

	for _, bt in ipairs({ (bridgeStartIdx / SEGMENTS) * 2 * math.pi, (bridgeEndIdx / SEGMENTS) * 2 * math.pi }) do
		local bp, bTan = getPiratePoint(bt)
		local bcf = CFrame.lookAt(bp, bp + bTan)

		local towerModel = Instance.new("Model")
		towerModel.Name = "BridgeTimberTower"
		towerModel.Parent = bridgeFolder

		for _, side in ipairs({ -1, 1 }) do
			local col = Instance.new("Part")
			col.Name = "PylonColumn"
			col.Anchored = true
			col.CanCollide = false
			col.Material = Enum.Material.Wood
			col.Color = Color3.fromRGB(80, 48, 25)
			col.Size = Vector3.new(5, 42, 5)
			col.CFrame = bcf * CFrame.new(side * (halfW + 4), 21, 0)
			col.Parent = towerModel
		end

		local topBeam = Instance.new("Part")
		topBeam.Name = "PylonCrossBeam"
		topBeam.Anchored = true
		topBeam.CanCollide = false
		topBeam.Material = Enum.Material.Wood
		topBeam.Color = Color3.fromRGB(70, 40, 20)
		topBeam.Size = Vector3.new(TRACK_WIDTH + 16, 4.5, 5)
		topBeam.CFrame = bcf * CFrame.new(0, 42, 0)
		topBeam.Parent = towerModel

		local bLantern = Instance.new("Part")
		bLantern.Name = "BridgeLantern"
		bLantern.Anchored = true
		bLantern.CanCollide = false
		bLantern.Material = Enum.Material.Metal
		bLantern.Color = Color3.fromRGB(240, 190, 40)
		bLantern.Size = Vector3.new(2.5, 4, 2.5)
		bLantern.CFrame = bcf * CFrame.new(0, 38, 0)
		bLantern.Parent = towerModel

		local bLight = Instance.new("PointLight")
		bLight.Color = Color3.fromRGB(255, 175, 60)
		bLight.Brightness = 3.0
		bLight.Range = 30
		bLight.Parent = bLantern
	end

	for sStep = bridgeStartIdx, bridgeEndIdx, 2 do
		local t = (sStep / SEGMENTS) * 2 * math.pi
		local sp, sTan = getPiratePoint(t)
		local scf = CFrame.lookAt(sp, sp + sTan)

		local frac = (sStep - bridgeStartIdx) / (bridgeEndIdx - bridgeStartIdx)
		local sag = 4 * frac * (1 - frac)
		local cableY = 38 - sag * 22

		for _, side in ipairs({ -1, 1 }) do
			local cablePart = Instance.new("Part")
			cablePart.Name = "MainSuspensionCable"
			cablePart.Anchored = true
			cablePart.CanCollide = false
			cablePart.Material = Enum.Material.Wood
			cablePart.Color = Color3.fromRGB(150, 110, 65)
			cablePart.Size = Vector3.new(1.8, 1.8, 14)
			cablePart.CFrame = scf * CFrame.new(side * (halfW + 3), cableY, 0)
			cablePart.Parent = bridgeFolder

			local hanger = Instance.new("Part")
			hanger.Name = "VerticalRopeDropper"
			hanger.Anchored = true
			hanger.CanCollide = false
			hanger.Material = Enum.Material.Wood
			hanger.Color = Color3.fromRGB(135, 95, 55)
			hanger.Size = Vector3.new(0.6, math.max(2, cableY - 3), 0.6)
			hanger.CFrame = scf * CFrame.new(side * (halfW + 3), cableY / 2, 0)
			hanger.Parent = bridgeFolder
		end
	end

	-- 6. AUTHENTIC PIRATE CANNONS (140358914983423) ALONG HARBOR FORT & SHIP
	local cannonFolder = Instance.new("Folder")
	cannonFolder.Name = "PirateCannonsBattery"
	cannonFolder.Parent = mapModel

	local cannonAsset = pirateAssets and pirateAssets:FindFirstChild("PirateCannon")
	if cannonAsset then
		-- Harbor battery (Sector 1)
		for _, cFrac in ipairs({ 0.08, 0.14, 0.20 }) do
			local cp, cTan = getPiratePoint(cFrac * 2 * math.pi)
			local ccf = CFrame.lookAt(cp, cp + cTan)

			local canClone = cannonAsset:Clone()
			canClone:PivotTo(ccf * CFrame.new(halfW + 10, 2.0, 0) * CFrame.Angles(0, math.rad(90), 0))
			for _, d in ipairs(canClone:GetDescendants()) do
				if d:IsA("BasePart") then
					d.CanCollide = false
					d.Anchored = true
				end
			end
			canClone.Parent = cannonFolder
		end

		-- Ship battery (Sector 2)
		for _, cFrac in ipairs({ 0.42, 0.52 }) do
			local cp, cTan = getPiratePoint(cFrac * 2 * math.pi)
			local ccf = CFrame.lookAt(cp, cp + cTan)

			local canClone = cannonAsset:Clone()
			canClone:PivotTo(ccf * CFrame.new(-(halfW + 10), 2.0, 0) * CFrame.Angles(0, math.rad(-90), 0))
			for _, d in ipairs(canClone:GetDescendants()) do
				if d:IsA("BasePart") then
					d.CanCollide = false
					d.Anchored = true
				end
			end
			canClone.Parent = cannonFolder
		end
	end

	-- 7. PROCEDURAL TROPICAL PALM TREES & SCENERY
	local sceneryFolder = Instance.new("Folder")
	sceneryFolder.Name = "TropicalScenery"
	sceneryFolder.Parent = mapModel

	local function createPalmTree(parent: Instance, pos: Vector3, groundY: number, scale: number)
		local treeModel = Instance.new("Model")
		treeModel.Name = "TropicalPalmTree"

		local trunkH = 26 * scale
		local trunkW = 3.2 * scale

		local trunk = Instance.new("Part")
		trunk.Name = "PalmTrunk"
		trunk.Anchored = true
		trunk.CanCollide = false
		trunk.Material = Enum.Material.Wood
		trunk.Color = Color3.fromRGB(120, 80, 50)
		trunk.Size = Vector3.new(trunkW, trunkH, trunkW)
		trunk.CFrame = CFrame.new(pos.X, groundY + trunkH / 2, pos.Z) * CFrame.Angles(math.rad(math.random(-8, 8)), math.rad(math.random(0, 360)), math.rad(math.random(-8, 8)))
		trunk.Parent = treeModel
		treeModel.PrimaryPart = trunk

		local crownY = groundY + trunkH
		local frondCount = 6
		for f = 1, frondCount do
			local fAng = (f / frondCount) * math.pi * 2
			local frond = Instance.new("Part")
			frond.Name = "PalmFrond_" .. f
			frond.Anchored = true
			frond.CanCollide = false
			frond.Material = Enum.Material.SmoothPlastic
			frond.Color = Color3.fromRGB(45, 150, 55)
			frond.Size = Vector3.new(4.5 * scale, 0.8 * scale, 22 * scale)
			local leafCF = CFrame.new(pos.X, crownY, pos.Z) * CFrame.Angles(0, fAng, 0) * CFrame.Angles(math.rad(-22), 0, 0) * CFrame.new(0, 0, 9 * scale)
			frond.CFrame = leafCF
			frond.Parent = treeModel
		end

		for c = 1, 3 do
			local cAng = (c / 3) * math.pi * 2
			local coconut = Instance.new("Part")
			coconut.Name = "Coconut_" .. c
			coconut.Anchored = true
			coconut.CanCollide = false
			coconut.Material = Enum.Material.SmoothPlastic
			coconut.Color = Color3.fromRGB(75, 45, 25)
			coconut.Size = Vector3.new(2.2 * scale, 2.6 * scale, 2.2 * scale)
			coconut.CFrame = CFrame.new(pos.X, crownY - 1.5 * scale, pos.Z) * CFrame.new(math.cos(cAng) * 2, 0, math.sin(cAng) * 2)
			coconut.Parent = treeModel
		end

		treeModel.Parent = parent
		return treeModel
	end

	for pStep = 1, 40 do
		local t = (pStep / 40) * math.pi * 2
		local frac = t / (2 * math.pi)
		if not (frac >= 0.35 and frac <= 0.85) then
			local p, tan = getPiratePoint(t)
			local normal = Vector3.new(-tan.Z, 0, tan.X).Unit
			for _, side in ipairs({ -1, 1 }) do
				local offset = 48 + (pStep % 3) * 14
				local px = p.X + side * normal.X * offset
				local pz = p.Z + side * normal.Z * offset
				if distToTrack(px, pz) >= 42 and math.abs(px) < 380 and math.abs(pz) < 400 then
					local scale = 0.9 + (pStep % 4) * 0.15
					createPalmTree(sceneryFolder, Vector3.new(px, 0, pz), 6, scale)
				end
			end
		end
	end

	-- 8. CHECKPOINTS (1..6)
	local cpFolder = Instance.new("Folder")
	cpFolder.Name = "Checkpoints"
	cpFolder.Parent = mapModel

	local cpAngles = {
		{ name = "1", frac = 0.20 }, -- Beach slalom
		{ name = "2", frac = 0.38 }, -- Top of boarding ramp into Galleon
		{ name = "3", frac = 0.58 }, -- Stern dive jump
		{ name = "4", frac = 0.70 }, -- Mouth of Skull Rock
		{ name = "5", frac = 0.86 }, -- High suspension bridge
		{ name = "6", frac = 0.00 }, -- Start / Finish Line Arch!
	}

	for _, cpData in ipairs(cpAngles) do
		local p, tan = getPiratePoint(cpData.frac * 2 * math.pi)
		local cf = CFrame.lookAt(p, p + tan)

		local cpPart = Instance.new("Part")
		cpPart.Name = cpData.name
		cpPart.Anchored = true
		cpPart.CanCollide = false
		cpPart.Transparency = 1
		cpPart.Size = Vector3.new(TRACK_WIDTH + 14, 28, 22)
		cpPart.CFrame = cf * CFrame.new(0, 14, 0)
		cpPart.Parent = cpFolder
	end

	-- 9. START / FINISH LINE & TRACK START GRID
	local startP, startTan = getPiratePoint(0.0)
	local flatForward = Vector3.new(startTan.X, 0, startTan.Z).Unit
	local startPos = startP + Vector3.new(0, 0.4, 0)
	local startCFrame = CFrame.lookAt(startPos, startPos - flatForward)

	local startGrid = Instance.new("Part")
	startGrid.Name = "TrackStartGridPart"
	startGrid.Anchored = true
	startGrid.CanCollide = false
	startGrid.Transparency = 1
	startGrid.Size = Vector3.new(TRACK_WIDTH, 2, 10)
	startGrid.CFrame = startCFrame * CFrame.new(0, 1.5, -3)
	startGrid.Parent = mapModel

	local startModel = Instance.new("Model")
	startModel.Name = "StartingPoint"
	startModel.Parent = mapModel

	local lineLength = 12.0
	local lineWidth = TRACK_WIDTH + 4.0
	local lineYOffset = 1.08

	local startLineBase = Instance.new("Part")
	startLineBase.Name = "StartLineBase"
	startLineBase.Anchored = true
	startLineBase.CanCollide = false
	startLineBase.Material = Enum.Material.WoodPlanks
	startLineBase.Color = Color3.fromRGB(25, 20, 18)
	startLineBase.Size = Vector3.new(lineWidth, 0.15, lineLength)
	startLineBase.CFrame = startCFrame * CFrame.new(0, lineYOffset, 0)
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
			tile.Color = isWhite and Color3.fromRGB(245, 245, 240) or Color3.fromRGB(30, 25, 25)
			tile.Size = Vector3.new(tileW, 0.18, tileL)
			tile.CFrame = startCFrame * CFrame.new(offsetX, lineYOffset + 0.02, offsetZ)
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
		pillar.Material = Enum.Material.Wood
		pillar.Color = Color3.fromRGB(75, 45, 25)
		pillar.Size = Vector3.new(5.0, archHeight, 6.0)
		pillar.CFrame = archCenterCFrame * CFrame.new(sideX, archHeight / 2, 0)
		pillar.Parent = startModel
	end

	local topBeam = Instance.new("Part")
	topBeam.Name = "StartArchTopBeam"
	topBeam.Anchored = true
	topBeam.CanCollide = true
	topBeam.Material = Enum.Material.Wood
	topBeam.Color = Color3.fromRGB(65, 38, 20)
	topBeam.Size = Vector3.new((pillarOffset * 2) + 6.0, 4.5, 6.0)
	topBeam.CFrame = archCenterCFrame * CFrame.new(0, archHeight + 2, 0)
	topBeam.Parent = startModel

	-- Sleek Signboard mounted flush on top beam front (does not block sword above!)
	local signBoard = Instance.new("Part")
	signBoard.Name = "StartSignBoard"
	signBoard.Anchored = true
	signBoard.CanCollide = false
	signBoard.Material = Enum.Material.WoodPlanks
	signBoard.Color = Color3.fromRGB(45, 25, 15)
	signBoard.Size = Vector3.new(44, 4.2, 1.2)
	signBoard.CFrame = topBeam.CFrame * CFrame.new(0, 0, -3.2)
	signBoard.Parent = startModel

	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local signGui = Instance.new("SurfaceGui")
		signGui.Name = "StartSignGui_" .. tostring(face)
		signGui.Face = face
		signGui.CanvasSize = Vector2.new(900, 110)
		signGui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		signGui.LightInfluence = 0
		signGui.Parent = signBoard

		local signText = Instance.new("TextLabel")
		signText.Size = UDim2.new(1, 0, 1, 0)
		signText.BackgroundTransparency = 1
		signText.Font = Enum.Font.FredokaOne
		signText.Text = "☠️ PIRATE TREASURE ISLAND ☠️"
		signText.TextColor3 = Color3.fromRGB(255, 215, 60)
		signText.TextStrokeColor3 = Color3.fromRGB(35, 18, 5)
		signText.TextStrokeTransparency = 0
		signText.TextScaled = true
		signText.Parent = signGui
	end

	-- Countdown Signal Lights Pod (Traffic lights) hanging below the arch beam
	local lightPodCFrame = topBeam.CFrame * CFrame.new(0, -4.8, -1.0)
	local lightPod = Instance.new("Part")
	lightPod.Name = "SignalLightPod"
	lightPod.Anchored = true
	lightPod.CanCollide = false
	lightPod.Material = Enum.Material.WoodPlanks
	lightPod.Color = Color3.fromRGB(30, 20, 12)
	lightPod.Size = Vector3.new(24.0, 5.0, 2.5)
	lightPod.CFrame = lightPodCFrame
	lightPod.Parent = startModel

	local signalColors = {
		{ name = "RedLight", color = Color3.fromRGB(255, 40, 40), offsetX = 7.0 },
		{ name = "YellowLight", color = Color3.fromRGB(255, 200, 30), offsetX = 0 },
		{ name = "GreenLight", color = Color3.fromRGB(40, 255, 80), offsetX = -7.0 },
	}

	for _, sig in ipairs(signalColors) do
		local lightPart = Instance.new("Part")
		lightPart.Name = sig.name
		lightPart.Anchored = true
		lightPart.CanCollide = false
		lightPart.Shape = Enum.PartType.Ball
		lightPart.Material = Enum.Material.Neon
		lightPart.Color = sig.color
		lightPart.Size = Vector3.new(4.0, 4.0, 4.0)
		lightPart.CFrame = lightPodCFrame * CFrame.new(sig.offsetX, 0, -1.2)
		lightPart.Parent = startModel

		local pLight = Instance.new("PointLight")
		pLight.Color = sig.color
		pLight.Brightness = 4.0
		pLight.Range = 16
		pLight.Parent = lightPart
	end

	-- Mount Crossed Pirate Cutlasses (13265924820) proudly ABOVE the arch (100% visible, zero obstruction!)
	local swordAsset = pirateAssets and pirateAssets:FindFirstChild("PirateSword")
	if swordAsset then
		for idx, angle in ipairs({ 22, -22 }) do
			local sClone = swordAsset:Clone()
			sClone.Name = "CrossedSword_" .. idx
			sClone:PivotTo(topBeam.CFrame * CFrame.new(0, 30.0, idx == 1 and -0.8 or 0.8) * CFrame.Angles(0, 0, math.rad(angle)))
			for _, d in ipairs(sClone:GetDescendants()) do
				d.Name = "SwordMesh_" .. d.Name
				if d:IsA("BasePart") then
					d.CanCollide = false
					d.Anchored = true
				end
			end
			sClone.Parent = startModel
		end
	end

	-- Flying Pirate Flags (11961818089) on pillars
	local flagAsset = pirateAssets and pirateAssets:FindFirstChild("PirateFlag")
	if flagAsset then
		for _, sideX in ipairs({ -pillarOffset, pillarOffset }) do
			local fClone = flagAsset:Clone()
			fClone.Name = "ArchPirateFlag"
			fClone:PivotTo(archCenterCFrame * CFrame.new(sideX, archHeight + 6, 0))
			-- Remove legacy flipbook script to prevent FlagMesh_Animate error
			for _, s in ipairs(fClone:GetDescendants()) do
				if s:IsA("LuaSourceContainer") then
					s:Destroy()
				end
			end
			for _, d in ipairs(fClone:GetDescendants()) do
				d.Name = "FlagMesh_" .. d.Name
				if d:IsA("BasePart") then
					d.CanCollide = false
					d.Anchored = true
					if d.Name == "FlagMesh_1" then
						d.Transparency = 0
					else
						d.Transparency = 1
					end
				end
			end
			fClone.Parent = startModel
		end
	end

	-- 8. DYNAMIC PIRATE MAP EFFECTS SCRIPT (Cannons firing cannonballs & Skull breathing fire!)
	local fxScript = Instance.new("Script")
	fxScript.Name = "PirateMapEffects"
	fxScript.Source = [=[
local map = script.Parent
if not map then return end

local Debris = game:GetService("Debris")

-- Wait until loaded into Workspace
if not map:IsDescendantOf(workspace) then
	map.AncestryChanged:Wait()
	if not map:IsDescendantOf(workspace) then return end
end

local battery = map:FindFirstChild("PirateCannonsBattery")
local skullFolder = map:FindFirstChild("SkullRockAndCavern")
local skull = skullFolder and skullFolder:FindFirstChild("ColossalSkullRock")

local fxFolder = Instance.new("Folder")
fxFolder.Name = "LiveEffectsFolder"
fxFolder.Parent = map

local flameEmitter, smokeEmitter, fireLight, fireSound
local cliffFlames = {}

if skull then
	local mouthPart = Instance.new("Part")
	mouthPart.Name = "SkullMouthFireJet"
	mouthPart.Anchored = true
	mouthPart.CanCollide = false
	mouthPart.Transparency = 1
	mouthPart.Size = Vector3.new(4, 4, 4)
	mouthPart.CFrame = skull.CFrame * CFrame.new(0, -18, 14) * CFrame.Angles(0, math.rad(180), 0)
	mouthPart.Parent = fxFolder

	flameEmitter = Instance.new("ParticleEmitter")
	flameEmitter.Name = "FlameBlast"
	flameEmitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 245, 120)),
		ColorSequenceKeypoint.new(0.3, Color3.fromRGB(255, 130, 20)),
		ColorSequenceKeypoint.new(0.7, Color3.fromRGB(220, 50, 10)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 20, 10))
	})
	flameEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 3.5),
		NumberSequenceKeypoint.new(0.4, 12.0),
		NumberSequenceKeypoint.new(1, 20.0)
	})
	flameEmitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(0.7, 0.3),
		NumberSequenceKeypoint.new(1, 1.0)
	})
	flameEmitter.LightEmission = 0.85
	flameEmitter.LightInfluence = 0
	flameEmitter.Speed = NumberRange.new(45, 65)
	flameEmitter.SpreadAngle = Vector2.new(16, 16)
	flameEmitter.Lifetime = NumberRange.new(0.9, 1.4)
	flameEmitter.Rate = 0
	flameEmitter.Enabled = false
	flameEmitter.Parent = mouthPart

	smokeEmitter = Instance.new("ParticleEmitter")
	smokeEmitter.Name = "VolcanicSmoke"
	smokeEmitter.Color = ColorSequence.new(Color3.fromRGB(45, 42, 40))
	smokeEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 5),
		NumberSequenceKeypoint.new(1, 22)
	})
	smokeEmitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(1, 1)
	})
	smokeEmitter.Speed = NumberRange.new(20, 35)
	smokeEmitter.SpreadAngle = Vector2.new(25, 25)
	smokeEmitter.Lifetime = NumberRange.new(1.5, 2.5)
	smokeEmitter.Rate = 0
	smokeEmitter.Enabled = false
	smokeEmitter.Parent = mouthPart

	fireLight = Instance.new("PointLight")
	fireLight.Name = "MouthFireLight"
	fireLight.Color = Color3.fromRGB(255, 130, 25)
	fireLight.Brightness = 0
	fireLight.Range = 60
	fireLight.Parent = mouthPart

	fireSound = Instance.new("Sound")
	fireSound.Name = "FireRoarSound"
	fireSound.SoundId = "rbxassetid://131070686"
	fireSound.Volume = 2.0
	fireSound.RollOffMaxDistance = 400
	fireSound.RollOffMinDistance = 40
	fireSound.Parent = mouthPart

	for _, child in ipairs(skullFolder:GetChildren()) do
		if child.Name == "AuthenticCliffFirePillar" then
			for _, emitter in ipairs(child:GetDescendants()) do
				if emitter:IsA("ParticleEmitter") then
					table.insert(cliffFlames, emitter)
				end
			end
		end
	end
end

local function fireSingleCannon(cannonModel)
	if not cannonModel or not cannonModel.Parent then return end
	local mesh = cannonModel:FindFirstChildWhichIsA("MeshPart", true)
	if not mesh then return end

	local muzzleCF = mesh.CFrame * CFrame.new(0, 3.5, -9.5)
	local shootDir = (mesh.CFrame.LookVector + Vector3.new(0, 0.35, 0)).Unit

	local flash = Instance.new("Part")
	flash.Name = "MuzzleFlash"
	flash.Anchored = true
	flash.CanCollide = false
	flash.Shape = Enum.PartType.Ball
	flash.Material = Enum.Material.Neon
	flash.Color = Color3.fromRGB(255, 210, 60)
	flash.Size = Vector3.new(6, 6, 6)
	flash.CFrame = muzzleCF
	flash.Parent = fxFolder

	local fLight = Instance.new("PointLight")
	fLight.Color = Color3.fromRGB(255, 180, 50)
	fLight.Brightness = 8.0
	fLight.Range = 40
	fLight.Parent = flash

	local puff = Instance.new("ParticleEmitter")
	puff.Color = ColorSequence.new(Color3.fromRGB(200, 200, 200))
	puff.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 4), NumberSequenceKeypoint.new(1, 14) })
	puff.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	puff.Speed = NumberRange.new(25, 40)
	puff.Lifetime = NumberRange.new(0.8, 1.4)
	puff.Parent = flash
	puff:Emit(8)

	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://287390954"
	sound.Volume = 1.4
	sound.RollOffMaxDistance = 350
	sound.RollOffMinDistance = 30
	sound.Parent = flash
	sound:Play()

	Debris:AddItem(flash, 1.5)
	task.delay(0.12, function()
		if flash and flash.Parent then
			flash.Transparency = 1
			fLight.Enabled = false
		end
	end)

	local ball = Instance.new("Part")
	ball.Name = "FlyingCannonball"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(3.0, 3.0, 3.0)
	ball.Material = Enum.Material.Metal
	ball.Color = Color3.fromRGB(30, 30, 30)
	ball.CanCollide = false
	ball.Anchored = false
	ball.CFrame = muzzleCF + shootDir * 3
	ball.Velocity = shootDir * 130 + Vector3.new(0, 35, 0)
	ball.Parent = fxFolder

	local tail = Instance.new("ParticleEmitter")
	tail.Name = "SmokeTail"
	tail.Color = ColorSequence.new(Color3.fromRGB(150, 150, 150))
	tail.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.8), NumberSequenceKeypoint.new(1, 5.0) })
	tail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1.0) })
	tail.Speed = NumberRange.new(2, 6)
	tail.Lifetime = NumberRange.new(0.5, 0.9)
	tail.Rate = 12
	tail.Parent = ball

	local splashTriggered = false
	local function triggerSplash(pos)
		if splashTriggered then return end
		splashTriggered = true
		ball:Destroy()

		local splashAnchor = Instance.new("Part")
		splashAnchor.Name = "WaterSplash"
		splashAnchor.Anchored = true
		splashAnchor.CanCollide = false
		splashAnchor.Transparency = 1
		splashAnchor.Position = pos
		splashAnchor.Parent = fxFolder

		local spray = Instance.new("ParticleEmitter")
		spray.Color = ColorSequence.new(Color3.fromRGB(230, 248, 255))
		spray.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 12) })
		spray.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
		spray.Speed = NumberRange.new(35, 55)
		spray.SpreadAngle = Vector2.new(30, 30)
		spray.Lifetime = NumberRange.new(0.8, 1.3)
		spray.EmissionDirection = Enum.NormalId.Top
		spray.Parent = splashAnchor
		spray:Emit(15)

		local sSound = Instance.new("Sound")
		sSound.SoundId = "rbxassetid://12222225"
		sSound.Volume = 1.3
		sSound.RollOffMaxDistance = 250
		sSound.Parent = splashAnchor
		sSound:Play()

		Debris:AddItem(splashAnchor, 2.0)
	end

	task.delay(1.15, function()
		if ball and ball.Parent then
			local p = ball.Position
			triggerSplash(Vector3.new(p.X, 6.0, p.Z))
		end
	end)
end

-- Cannon battery volley loop
task.spawn(function()
	task.wait(2.0)
	while map and map.Parent do
		local cannons = battery and battery:GetChildren() or {}
		for _, cannon in ipairs(cannons) do
			if not map or not map.Parent then break end
			fireSingleCannon(cannon)
			task.wait(0.7)
		end
		task.wait(4.5)
	end
end)

-- Skull fire breath loop
if flameEmitter and fireSound then
	task.spawn(function()
		task.wait(4.5)
		while map and map.Parent do
			fireSound:Play()
			flameEmitter.Enabled = true
			flameEmitter.Rate = 45
			smokeEmitter.Enabled = true
			smokeEmitter.Rate = 20
			fireLight.Brightness = 8.0

			for _, cf in ipairs(cliffFlames) do
				cf.Enabled = true
				cf.Rate = 25
			end

			task.wait(2.4)

			flameEmitter.Enabled = false
			smokeEmitter.Enabled = false
			fireLight.Brightness = 0
			for _, cf in ipairs(cliffFlames) do
				cf.Enabled = false
			end

			task.wait(5.5)
		end
	end)
end

-- Ship's Wheel realistic steering oscillation
local galleon = map:FindFirstChild("GalleonShipSection")
local wheelObj = galleon and galleon:FindFirstChild("QuarterdeckWheel", true)
local wheelPart = wheelObj and (wheelObj:IsA("BasePart") and wheelObj or wheelObj:FindFirstChild("Handle"))
if wheelPart then
	local origWheelCF = wheelPart.CFrame
	task.spawn(function()
		local t = 0
		while map and map.Parent do
			t = t + 0.1
			wheelPart.CFrame = origWheelCF * CFrame.Angles(0, 0, math.sin(t * 1.6) * 0.42)
			task.wait(0.1)
		end
	end)
end
]=]
	fxScript.Parent = mapModel

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

			-- Disable dynamic shadows on decorative / track parts to eliminate shadow cascades lag
			local name = d.Name
			if name:find("Track") or name:find("Rope") or name:find("Rail") or name:find("Stripe")
				or name:find("Curb") or name:find("Ocean") or name:find("SeaBed") or name:find("Beach")
				or name:find("Frond") or name:find("Coconut") or name:find("Palm") or name:find("Cable")
				or name:find("Hanger") or name:find("Dropper") or name:find("Stalactite") or name:find("Stalagmite")
				or name:find("Crystal") or name:find("Gold") or name:find("Lantern") or name:find("Torch")
				or name:find("Checker") or name:find("StartLine") or name:find("Sign") or name:find("Sword")
				or name:find("Flag") or name:find("Mug") or name:find("Barrel") or name:find("Table")
				or name:find("Wall") or name:find("Boulder") or name:find("Pillar") or name:find("ArchBeam")
				or name:find("Mast") or name:find("Sail") or name:find("Rigging") or name:find("Yard") then
				d.CastShadow = false
			end
		end
	end

	mapModel.PrimaryPart = startGrid
	optimizeMapCollisionFlags(mapModel)
	return mapModel
end

return MapBuilder
