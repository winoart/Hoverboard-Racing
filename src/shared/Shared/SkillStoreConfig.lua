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
		goldPrice = 2000,
		cooldownType = "Cooldown",
		cooldownTime = 10
	},
	{
		id = "Skill_Paintball",
		name = "Paintball",
		description = "Splats ink on the screen of the player directly in front of you, blocking their vision.",
		imageId = "rbxassetid://100042133733129",
		goldPrice = 2500,
		cooldownType = "Cooldown",
		cooldownTime = 12
	},
	{
		id = "Skill_Shield",
		name = "Shield",
		description = "Blocks one incoming attack (Ice Bomb, Blind Fog, etc.) from other players.",
		imageId = "rbxassetid://90453361413919",
		goldPrice = 3000,
		cooldownType = "Cooldown",
		cooldownTime = 15
	},
	{
		id = "Skill_OrbitalLaser",
		name = "Orbital Laser",
		description = "Fires a satellite laser at all opponents on the map, temporarily stopping their engines.",
		imageId = "rbxassetid://93503559614483",
		goldPrice = 4000,
		cooldownType = "Charges",
		maxUses = 1,
		cooldownTime = 5 -- 연속 사용 방지용 짧은 쿨타임
	},
	{
		id = "Skill_Reflect",
		name = "Reflect",
		description = "Creates a red shield that lasts until hit. Reflects targeted skills (like Ice Bomb, Paintball) back to the attacker! (Max 2 uses per game)",
		imageId = "rbxassetid://13583568770", -- 방패 아이콘이 없으면 일단 임시 배정
		goldPrice = 3000,
		cooldownType = "Cooldown",
		cooldownTime = 1
	},
	{
		id = "Skill_BlindFog",
		name = "Blind Fog",
		description = "Obscures opponents' screens with dense fog, blocking their vision.",
		imageId = "rbxassetid://72092197321443",
		goldPrice = 6000,
		cooldownType = "Charges",
		maxUses = 3,
		cooldownTime = 5
	},
	{
		id = "Skill_Ghost",
		name = "Ghost",
		description = "Become invisible for a duration, ignoring targeted attacks like Ice Bomb and Orbital Laser.",
		imageId = "rbxassetid://114460588000783",
		goldPrice = 8000,
		cooldownType = "Charges",
		maxUses = 2,
		cooldownTime = 5
	},
	{
		id = "Skill_EMP",
		name = "EMP Hack",
		description = "Hacks the hoverboards of nearby opponents, reversing their controls.",
		imageId = "rbxassetid://99214302538101",
		goldPrice = 10000,
		cooldownType = "Charges",
		maxUses = 2,
		cooldownTime = 5
	},
	{
		id = "Skill_Premium",
		name = "스타터 전용 스킬",
		description = "로벅스 패키지를 구매한 플레이어만 사용할 수 있는 강력한 전용 스킬입니다.",
		imageId = "rbxassetid://13583568770", -- Placeholder
		goldPrice = 0,
		cooldownType = "Cooldown",
		cooldownTime = 15,
		isExclusive = true -- 스킬 상점(골드 상점)에 노출되지 않음
	}
}

return SkillStoreConfig
