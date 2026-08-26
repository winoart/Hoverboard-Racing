--!strict
-- HoverboardBuilder.luau
-- Procedural 3D model generator for self-balancing hoverboard with Wind Breaking Particle Effects

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HoverboardConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("HoverboardConfig") :: ModuleScript)

local HoverboardBuilder = {}

-- Helper to create and weld a part to the main deck
local function createSubPart(
	name: string,
	size: Vector3,
	color: Color3,
	material: Enum.Material,
	c0Offset: CFrame,
	parentModel: Model,
	deck: Part
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.Massless = true
	part.Anchored = false
	part.Parent = parentModel

	local weld = Instance.new("Weld")
	weld.Name = name .. "_Weld"
	weld.Part0 = deck
	weld.Part1 = part
	weld.C0 = c0Offset
	weld.Parent = part

	return part
end

function HoverboardBuilder.createModel(): Model
	local model = Instance.new("Model")
	model.Name = "Hoverboard"

	-- Main Root Deck Part (Wide X: 4.4 studs, Short Z: 1.8 studs - moves along Z axis short side)
	local deck = Instance.new("Part")
	deck.Name = "RootPart"
	deck.Size = Vector3.new(HoverboardConfig.BOARD_WIDTH, HoverboardConfig.BOARD_THICKNESS, HoverboardConfig.BOARD_LENGTH)
	deck.Color = HoverboardConfig.DECK_PRIMARY_COLOR
	deck.Material = Enum.Material.Metal
	deck.TopSurface = Enum.SurfaceType.Smooth
	deck.BottomSurface = Enum.SurfaceType.Smooth
	deck.CanCollide = false
	deck.Anchored = false
	deck.Massless = true
	deck.Parent = model

	model.PrimaryPart = deck

	-- 1. Left & Right Foot Grip Pads
	local padLength = HoverboardConfig.BOARD_LENGTH * 0.85
	local padWidth = 1.4
	local padThickness = 0.08
	local padSize = Vector3.new(padWidth, padThickness, padLength)
	local padY = (HoverboardConfig.BOARD_THICKNESS / 2) + (padThickness / 2)

	local leftPadOffset = CFrame.new(-1.2, padY, 0)
	local rightPadOffset = CFrame.new(1.2, padY, 0)

	createSubPart("LeftGripPad", padSize, HoverboardConfig.GRIP_PAD_COLOR, Enum.Material.DiamondPlate, leftPadOffset, model, deck)
	createSubPart("RightGripPad", padSize, HoverboardConfig.GRIP_PAD_COLOR, Enum.Material.DiamondPlate, rightPadOffset, model, deck)

	-- 2. Side Outer Caps
	local capWidth = 0.18
	local capSize = Vector3.new(capWidth, HoverboardConfig.BOARD_THICKNESS + 0.06, HoverboardConfig.BOARD_LENGTH + 0.04)
	local leftCapOffset = CFrame.new(-(HoverboardConfig.BOARD_WIDTH / 2 + capWidth / 2), 0, 0)
	local rightCapOffset = CFrame.new(HoverboardConfig.BOARD_WIDTH / 2 + capWidth / 2, 0, 0)

	createSubPart("LeftSideCap", capSize, HoverboardConfig.DECK_SECONDARY_COLOR, Enum.Material.Neon, leftCapOffset, model, deck)
	createSubPart("RightSideCap", capSize, HoverboardConfig.DECK_SECONDARY_COLOR, Enum.Material.Neon, rightCapOffset, model, deck)

	-- 3. Front & Rear Headlights / LED Strips
	local ledSize = Vector3.new(HoverboardConfig.BOARD_WIDTH * 0.85, HoverboardConfig.BOARD_THICKNESS * 0.5, 0.1)
	local frontLedOffset = CFrame.new(0, 0, -(HoverboardConfig.BOARD_LENGTH / 2 + 0.05))
	local rearLedOffset = CFrame.new(0, 0, (HoverboardConfig.BOARD_LENGTH / 2 + 0.05))

	createSubPart("FrontLED", ledSize, HoverboardConfig.HEADLIGHT_COLOR, Enum.Material.Neon, frontLedOffset, model, deck)
	createSubPart("RearLED", ledSize, HoverboardConfig.DECK_SECONDARY_COLOR, Enum.Material.Neon, rearLedOffset, model, deck)

	-- 4. Underbody Left & Right Hover Thruster Discs
	local thrusterXOffsets = { -1.2, 1.2 }
	for i, xOffset in ipairs(thrusterXOffsets) do
		local housingSize = Vector3.new(0.28, HoverboardConfig.THRUSTER_RADIUS * 2, HoverboardConfig.THRUSTER_RADIUS * 2)
		local housingC0 = CFrame.new(xOffset, -(HoverboardConfig.BOARD_THICKNESS / 2 + 0.14), 0) * CFrame.Angles(0, 0, math.rad(90))

		local housing = createSubPart("ThrusterHousing_" .. i, housingSize, HoverboardConfig.DECK_PRIMARY_COLOR, Enum.Material.Metal, housingC0, model, deck)
		housing.Shape = Enum.PartType.Cylinder

		local coreSize = Vector3.new(0.3, HoverboardConfig.THRUSTER_RADIUS * 1.5, HoverboardConfig.THRUSTER_RADIUS * 1.5)
		local core = createSubPart("ThrusterCore_" .. i, coreSize, HoverboardConfig.THRUSTER_COLOR, Enum.Material.Neon, housingC0, model, deck)
		core.Shape = Enum.PartType.Cylinder

		-- Attachment & Particle Emitter under each foot thruster
		local attachment = Instance.new("Attachment")
		attachment.Name = "ThrusterAttachment_" .. i
		attachment.Position = Vector3.new(xOffset, -(HoverboardConfig.BOARD_THICKNESS / 2 + 0.18), 0)
		attachment.Parent = deck

		local particles = Instance.new("ParticleEmitter")
		particles.Name = "HoverParticles"
		particles.Color = ColorSequence.new(HoverboardConfig.THRUSTER_COLOR)
		particles.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.8),
			NumberSequenceKeypoint.new(0.5, 0.4),
			NumberSequenceKeypoint.new(1, 0),
		})
		particles.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.3),
			NumberSequenceKeypoint.new(1, 1),
		})
		particles.Lifetime = NumberRange.new(0.15, 0.4)
		particles.Rate = 35
		particles.Speed = NumberRange.new(3, 7)
		particles.SpreadAngle = Vector2.new(360, 360)
		particles.EmissionDirection = Enum.NormalId.Bottom
		particles.Enabled = true
		particles.Parent = attachment

		-- Steady non-flashing PointLight
		local pointLight = Instance.new("PointLight")
		pointLight.Name = "ThrusterLight"
		pointLight.Color = HoverboardConfig.THRUSTER_COLOR
		pointLight.Range = 8
		pointLight.Brightness = 2.5
		pointLight.Shadows = false
		pointLight.Parent = attachment
	end

	-- 5. Aerodynamic Wind Breaking Particles Attachment (Front Center Deck)
	local windAttachment = Instance.new("Attachment")
	windAttachment.Name = "WindAttachment"
	windAttachment.Position = Vector3.new(0, 1.2, -1.0)
	windAttachment.Parent = deck

	local windParticles = Instance.new("ParticleEmitter")
	windParticles.Name = "WindParticles"
	windParticles.Color = ColorSequence.new(Color3.fromRGB(240, 252, 255))
	windParticles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(0.4, 0.8),
		NumberSequenceKeypoint.new(1, 0),
	})
	windParticles.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.25),
		NumberSequenceKeypoint.new(0.8, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	windParticles.Lifetime = NumberRange.new(0.2, 0.45)
	windParticles.Rate = 0 -- Enabled when boosting!
	windParticles.Speed = NumberRange.new(30, 50)
	windParticles.SpreadAngle = Vector2.new(30, 30)
	windParticles.EmissionDirection = Enum.NormalId.Back
	windParticles.Orientation = Enum.ParticleOrientation.FacingCamera
	windParticles.Enabled = true
	windParticles.Parent = windAttachment

	return model
end

return HoverboardBuilder
