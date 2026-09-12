--!strict
-- SkillStoreConfig.lua
-- Contains the list of skills available in the Skill Store

local SkillStoreConfig = {}

SkillStoreConfig.Skills = {
	{
		id = "Skill_IceBomb",
		name = "Ice Bomb",
		description = "Temporarily freezes the player directly in front of you, slowing them down.",
		imageId = "rbxassetid://81959011754721",
		goldPrice = 2000
	},
	{
		id = "Skill_Shield",
		name = "Shield",
		description = "Blocks one incoming attack (Ice Bomb, Blind Fog, etc.) from other players.",
		imageId = "rbxassetid://90453361413919",
		goldPrice = 3000
	},
	{
		id = "Skill_OrbitalLaser",
		name = "Orbital Laser",
		description = "Fires a satellite laser at all opponents on the map, temporarily stopping their engines.",
		imageId = "rbxassetid://93503559614483",
		goldPrice = 4000
	},
	{
		id = "Skill_BlindFog",
		name = "Blind Fog",
		description = "Obscures opponents' screens with dense fog, blocking their vision.",
		imageId = "rbxassetid://72092197321443",
		goldPrice = 6000
	},
	{
		id = "Skill_Ghost",
		name = "Ghost",
		description = "Become invisible for a duration, ignoring targeted attacks like Ice Bomb and Orbital Laser.",
		imageId = "rbxassetid://114460588000783",
		goldPrice = 8000
	},
	{
		id = "Skill_EMP",
		name = "EMP Hack",
		description = "Hacks the hoverboards of nearby opponents, reversing their controls.",
		imageId = "rbxassetid://99214302538101",
		goldPrice = 10000
	}
}

return SkillStoreConfig
