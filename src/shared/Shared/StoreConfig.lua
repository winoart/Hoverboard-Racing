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
		name = "Blue Tonic",
		imageId = "rbxassetid://98211009044526",
		rarity = "Common",
		weight = 500, -- 기본 보드도 뽑기에서 등장하게 수정
		price = 0, -- 기본 보드 무료
		desc = "The most basic hoverboard for beginners. Features a stable and smooth ride.",
	},
	{
		id = "ClassicRookie",
		name = "Classic Rookie",
		imageId = "rbxassetid://10078028148", -- 아이콘은 임시
		rarity = "Common",
		weight = 500, -- 50%
		price = 500,
		desc = "A sleek, sporty aerodynamic hoverboard designed to minimize air resistance.",
	},
	{
		id = "NeonPulse",
		name = "Neon Pulse",
		imageId = "rbxassetid://10078028148", -- 아이콘은 임시
		rarity = "Uncommon",
		weight = 500, -- 50%
		price = 1000,
		desc = "A futuristic, cyberpunk-style metallic hoverboard.",
	},
	{
		id = "CloudBoard",
		name = "Cloud Nimbus",
		imageId = "rbxassetid://116012241551714",
		rarity = "Rare",
		weight = 150, -- 15%
		price = 3000,
		desc = "A mysterious hoverboard shaped like a fluffy cloud. Glides softly through the air.",
	},
	{
		id = "MagicBroom",
		name = "Nimbus 2025",
		imageId = "rbxassetid://91414670760591",
		rarity = "Super Rare",
		weight = 40, -- 4%
		price = 5000,
		desc = "A legendary broomstick-style hoverboard once favored by wizards.",
	},
	{
		id = "IndustrialHoverboard",
		name = "Mecha Titan",
		imageId = "rbxassetid://10078028148", -- 아이콘은 임시
		rarity = "Uncommon",
		weight = 500, -- 50%
		price = 1500,
		desc = "A heavy-duty hoverboard equipped with thick armor plating and giant jet engines.",
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
