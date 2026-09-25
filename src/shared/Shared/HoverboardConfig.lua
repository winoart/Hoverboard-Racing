--!strict
-- HoverboardConfig.luau
-- Configuration for self-balancing Hoverboard and Nitro Booster System

local HoverboardConfig = {}

HoverboardConfig.Boards = {
	Hoverboard_Default = {
		-- Speed & Movement Settings
		RIDE_WALKSPEED = 110,            -- Normal cruise speed on hoverboard (110)
		BOOSTER_WALKSPEED = 150,         -- Nitro Booster speed boost! (150)
		RIDE_JUMPPOWER = 65,             -- Jump power
		
		-- Booster System Settings
		BOOSTER_MAX_GAUGE = 100,         -- Max booster gauge percentage (100%)
		BOOSTER_CHARGE_RATE = 12.5,      -- Gauge charge speed per sec while driving
		BOOSTER_DRAIN_RATE = 35,         -- Gauge drain speed per sec while boosting
		BOOSTER_MIN_TO_USE = 10,         -- Minimum gauge required to ignite boost
		BOOSTER_FOV = 110,               -- Camera FOV warp during boost
		BOOSTER_KEY = Enum.KeyCode.Space,
		
		-- Hovering & Floating Physics
		HOVER_HEIGHT = 4.2,              -- Elevated hover height above ground
		BOB_AMPLITUDE = 0.35,            -- Up and down hovering wave distance
		BOB_FREQUENCY = 4.0,             -- Hover oscillation speed (Hz)
		
		-- Character Orientation & Camera Locking
		STANCE_YAW_ANGLE = 0,            -- 0 degrees: Short side (Z axis) points forward, Wide side (X axis) is left-to-right
		MAX_BANK_ANGLE = 32,             -- Max tilt angle (degrees) when turning left/right (32° sharp bank)
		BANK_SMOOTHNESS = 18,            -- Speed of interpolation for tilting
		PITCH_ANGLE = 8,                 -- Forward pitch angle when moving forward
		
		-- Aesthetics & Colors (Metallic Slate & Electric Cyan/Blue)
		DECK_PRIMARY_COLOR = Color3.fromRGB(28, 32, 42),     -- Dark Metallic Slate
		DECK_SECONDARY_COLOR = Color3.fromRGB(0, 180, 240),  -- Electric Cyan Accent
		GRIP_PAD_COLOR = Color3.fromRGB(45, 50, 60),        -- Non-slip Dark Graphite Footpads
		THRUSTER_COLOR = Color3.fromRGB(0, 220, 255),       -- Bright Cyan Thruster Glow
		HEADLIGHT_COLOR = Color3.fromRGB(100, 230, 255),    -- Front LED
		
		-- Dimensions (Studs: Wide left-to-right X, Short front-to-back Z)
		BOARD_WIDTH = 4.6,               -- Left-to-Right width (WIDE X axis)
		BOARD_LENGTH = 1.8,              -- Front-to-Back length (SHORT Z axis)
		BOARD_THICKNESS = 0.4,
		THRUSTER_RADIUS = 0.75,
		
		-- Keybind & Distance
		MOUNT_PROMPT_DISTANCE = 10,
		DISMOUNT_KEY = Enum.KeyCode.E,
	},
	StarterPac_Board = {
		-- Speed & Movement Settings (Same as Default)
		RIDE_WALKSPEED = 110,
		BOOSTER_WALKSPEED = 150,
		RIDE_JUMPPOWER = 65,
		
		-- Booster System Settings
		BOOSTER_MAX_GAUGE = 100,
		BOOSTER_CHARGE_RATE = 12.5,
		BOOSTER_DRAIN_RATE = 35,
		BOOSTER_MIN_TO_USE = 10,
		BOOSTER_FOV = 110,
		BOOSTER_KEY = Enum.KeyCode.Space,
		
		-- Hovering & Floating Physics
		HOVER_HEIGHT = 4.2,
		BOB_AMPLITUDE = 0.35,
		BOB_FREQUENCY = 4.0,
		
		-- Character Orientation & Camera Locking
		STANCE_YAW_ANGLE = 0,
		MAX_BANK_ANGLE = 32,
		BANK_SMOOTHNESS = 18,
		PITCH_ANGLE = 8,
		
		-- Aesthetics & Colors (Golden Star Casual Design)
		DECK_PRIMARY_COLOR = Color3.fromRGB(255, 215, 0),     -- Bright Golden Yellow
		DECK_SECONDARY_COLOR = Color3.fromRGB(255, 255, 255), -- Crisp White Accents
		GRIP_PAD_COLOR = Color3.fromRGB(90, 100, 120),        -- Soft Slate Blue-Grey
		THRUSTER_COLOR = Color3.fromRGB(255, 230, 80),        -- Glowing Sun Yellow
		HEADLIGHT_COLOR = Color3.fromRGB(255, 255, 255),      -- Bright White Glow
		BOARD_WIDTH = 4.6,
		BOARD_LENGTH = 1.8,
		BOARD_THICKNESS = 0.4,
		THRUSTER_RADIUS = 0.75,
		
		-- Keybind & Distance
		MOUNT_PROMPT_DISTANCE = 10,
		DISMOUNT_KEY = Enum.KeyCode.E,
	}
}

-- Backward compatibility for existing scripts
for k, v in pairs(HoverboardConfig.Boards.Hoverboard_Default) do
	HoverboardConfig[k] = v
end

function HoverboardConfig.GetBoard(boardId: string?)
	if boardId and HoverboardConfig.Boards[boardId] then
		return HoverboardConfig.Boards[boardId]
	end
	return HoverboardConfig.Boards.Hoverboard_Default
end

return HoverboardConfig
