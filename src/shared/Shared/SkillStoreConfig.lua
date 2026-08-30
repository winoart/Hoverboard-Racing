--!strict
-- SkillStoreConfig.lua
-- Contains the list of skills available in the Skill Store

local SkillStoreConfig = {}

SkillStoreConfig.Skills = {
	{
		id = "Skill_IceBomb",
		name = "얼음 폭탄 (Ice Bomb)",
		description = "내 주변 유저를 잠시 얼려서 속도를 늦춥니다.",
		imageId = "rbxassetid://10000000002", -- Placeholder
		goldPrice = 2000
	},
	{
		id = "Skill_Shield",
		name = "방어막 (Shield)",
		description = "다른 유저의 공격(얼음폭탄, 안개 등)을 1회 방어해줍니다.",
		imageId = "rbxassetid://10000000001", -- Placeholder
		goldPrice = 3000
	},
	{
		id = "Skill_IceTrap",
		name = "빙판 (Ice Trap)",
		description = "내 뒤에 빙판 함정을 설치하여, 밟은 상대방을 미끄러지게 합니다.",
		imageId = "rbxassetid://10000000004", -- Placeholder
		goldPrice = 4000
	},
	{
		id = "Skill_BlindFog",
		name = "안개 (Blind Fog)",
		description = "상대방의 화면을 짙은 안개로 가려 시야를 방해합니다.",
		imageId = "rbxassetid://10000000003", -- Placeholder
		goldPrice = 6000
	},
	{
		id = "Skill_Ghost",
		name = "유령화 (Ghost)",
		description = "일정 시간 투명해지며, 안개/얼음폭탄 등 공격 대상에서 제외됩니다.",
		imageId = "rbxassetid://10000000005", -- Placeholder
		goldPrice = 8000
	},
	{
		id = "Skill_EMP",
		name = "EMP (조작 방해)",
		description = "주변 상대방의 호버보드를 해킹하여 조작키를 반대로 만듭니다.",
		imageId = "rbxassetid://10000000006", -- Placeholder
		goldPrice = 10000
	}
}

return SkillStoreConfig
