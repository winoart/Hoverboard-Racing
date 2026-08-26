--!strict
-- HoverboardConfig.luau
-- Configuration for self-balancing Hoverboard and Nitro Booster System

local HoverboardConfig = {
	-- Speed & Movement Settings
	RIDE_WALKSPEED = 100,            -- Normal cruise speed on hoverboard (100)
	BOOSTER_WALKSPEED = 150,         -- Nitro Booster speed boost! (150)
	RIDE_JUMPPOWER = 65,             -- Jump power
	
	-- Booster System Settings
	BOOSTER_MAX_GAUGE = 100,         -- Max booster gauge percentage (100%)
	BOOSTER_CHARGE_RATE = 25,        -- Gauge charge speed per sec while driving
	BOOSTER_DRAIN_RATE = 35,         -- Gauge drain speed per sec while boosting
	BOOSTER_MIN_TO_USE = 10,         -- Minimum gauge required to ignite boost
	BOOSTER_FOV = 95,                -- Camera FOV warp during boost
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
}

return HoverboardConfig
