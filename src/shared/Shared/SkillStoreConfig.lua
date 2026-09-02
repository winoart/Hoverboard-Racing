--!strict
-- SkillStoreConfig.lua
-- Contains the list of skills available in the Skill Store

local SkillStoreConfig = {}

SkillStoreConfig.Skills = {
	{
		id = "Skill_IceBomb",
		name = "얼음 폭탄",
		description = "내 주변 유저를 잠시 얼려서 속도를 늦춥니다.",
		imageId = "rbxassetid://81959011754721",
		goldPrice = 2000
	},
	{
		id = "Skill_Shield",
		name = "방어막",
		description = "다른 유저의 공격(얼음폭탄, 안개 등)을 1회 방어해줍니다.",
		imageId = "rbxassetid://90453361413919",
		goldPrice = 3000
	},
	{
		id = "Skill_OrbitalLaser",
		name = "위성 타격",
		description = "맵 상의 모든 상대방에게 위성 레이저를 발사하여 엔진을 일시 정지시킵니다.",
		imageId = "rbxassetid://93503559614483",
		goldPrice = 4000
	},
	{
		id = "Skill_BlindFog",
		name = "안개",
		description = "상대방의 화면을 짙은 안개로 가려 시야를 방해합니다.",
		imageId = "rbxassetid://72092197321443",
		goldPrice = 6000
	},
	{
		id = "Skill_Ghost",
		name = "유령화",
		description = "일정 시간 투명해지며, 얼음폭탄, 위성 타격 등 타겟팅 공격의 대상에서 제외됩니다. (안개 제외)",
		imageId = "rbxassetid://114460588000783",
		goldPrice = 8000
	},
	{
		id = "Skill_EMP",
		name = "EMP",
		description = "주변 상대방의 호버보드를 해킹하여 조작키를 반대로 만듭니다.",
		imageId = "rbxassetid://10000000006", -- Placeholder
		goldPrice = 10000
	}
}

return SkillStoreConfig
