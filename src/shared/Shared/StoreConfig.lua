--!strict
-- StoreConfig.lua
-- Contains the catalog of Hoverboards for the store and roulette mechanics.

local StoreConfig = {}

-- 1회 뽑기 비용
StoreConfig.RouletteCost = 300
-- 중복 시 환급해주는 골드
StoreConfig.RefundAmount = 100

export type Rarity = "Common" | "Uncommon" | "Rare" | "Super Rare"

-- Kiosk 상점의 슬롯별 등급 등장 확률 (백분율)
StoreConfig.ShopRarityRates = {
	["Common"] = 50,
	["Uncommon"] = 30,
	["Rare"] = 15,
	["Super Rare"] = 5,
}

export type StoreItem = {
	id: string,
	name: string,
	imageId: string,
	rarity: Rarity,
	weight: number, -- 뽑기 확률 가중치 (0이면 안나옴)
	desc: string?, -- 아이템 설명 (선택 사항)
}

StoreConfig.Items = {
	{
		id = "DefaultHoverboard",
		name = "블루토닉 (기본)",
		imageId = "rbxassetid://98211009044526",
		rarity = "Common",
		weight = 500, -- 기본 보드도 뽑기에서 등장하게 수정
		price = 0, -- 기본 보드 무료
		desc = "초보자를 위한 가장 기본적인 호버보드입니다. 안정적인 주행감을 자랑합니다.",
	},
	{
		id = "ClassicRookie",
		name = "클래식 루키",
		imageId = "rbxassetid://10078028148", -- 아이콘은 임시
		rarity = "Common",
		weight = 500, -- 50%
		price = 500,
		desc = "공기 저항을 최소화한 날렵하고 스포티한 유선형 호버보드입니다.",
	},
	{
		id = "NeonPulse",
		name = "네온 펄스",
		imageId = "rbxassetid://10078028148", -- 아이콘은 임시
		rarity = "Uncommon",
		weight = 500, -- 50%
		price = 1000,
		desc = "미래지향적인 사이버펑크 스타일의 메탈릭 호버보드입니다.",
	},
	{
		id = "CloudBoard",
		name = "근두운",
		imageId = "rbxassetid://116012241551714",
		rarity = "Rare",
		weight = 150, -- 15%
		price = 3000,
		desc = "푹신한 구름 모양을 한 신비로운 보드입니다. 부드럽게 날아갑니다.",
	},
	{
		id = "MagicBroom",
		name = "님부스2025",
		imageId = "rbxassetid://91414670760591",
		rarity = "Super Rare",
		weight = 40, -- 4%
		price = 5000,
		desc = "마법사들이 애용하던 전설적인 빗자루 형태의 호버보드입니다.",
	},
	{
		id = "IndustrialHoverboard",
		name = "메카 타이탄",
		imageId = "rbxassetid://10078028148", -- 아이콘은 임시
		rarity = "Uncommon",
		weight = 500, -- 50%
		price = 1500,
		desc = "묵직한 장갑판과 거대한 제트 엔진이 달린 중장비 스타일의 호버보드입니다.",
	},
}

-- Rarity Colors (For UI)
StoreConfig.RarityColors = {
	["Common"] = Color3.fromRGB(255, 255, 0), -- 노랑색
	["Uncommon"] = Color3.fromRGB(0, 0, 255), -- 파랑색
	["Rare"] = Color3.fromRGB(128, 0, 128), -- 보라색
	["Super Rare"] = Color3.fromRGB(0, 0, 0), -- 검정색
}

return StoreConfig
