--!strict
-- StoreConfig.lua
-- Contains the catalog of Hoverboards for the store and roulette mechanics.

local StoreConfig = {}

-- 1회 뽑기 비용
StoreConfig.RouletteCost = 300
-- 중복 시 환급해주는 골드
StoreConfig.RefundAmount = 100

export type Rarity = "Normal" | "Rare" | "Super Rare" | "Epic" | "Legendary"

export type StoreItem = {
	id: string,
	name: string,
	imageId: string,
	rarity: Rarity,
	weight: number, -- 뽑기 확률 가중치 (0이면 안나옴)
}

StoreConfig.Items = {
	{
		id = "DefaultHoverboard",
		name = "블루토닉 (기본)",
		imageId = "rbxassetid://10078028148", 
		rarity = "Normal",
		weight = 0, -- 기본 보드는 뽑기에서 등장하지 않음
	},
	{
		id = "NormalBoard1",
		name = "스탠다드 호버",
		imageId = "rbxassetid://10078028148",
		rarity = "Normal",
		weight = 500, -- 50%
	},
	{
		id = "RareBoard1",
		name = "루비 슬라이더",
		imageId = "rbxassetid://10078028148",
		rarity = "Rare",
		weight = 150, -- 15%
	},
	{
		id = "CloudBoard",
		name = "근두운",
		imageId = "rbxassetid://10078028148",
		rarity = "Rare",
		weight = 150, -- 15%
	},
	{
		id = "SuperRareBoard1",
		name = "네온 스트라이크",
		imageId = "rbxassetid://10078028148",
		rarity = "Super Rare",
		weight = 150, -- 15%
	},
	{
		id = "MagicBroom",
		name = "님부스2000",
		imageId = "rbxassetid://10078028148",
		rarity = "Epic",
		weight = 40, -- 4%
	},
	{
		id = "LegendaryBoard1",
		name = "드래곤 윙",
		imageId = "rbxassetid://10078028148",
		rarity = "Legendary",
		weight = 10, -- 1%
	},
}

-- Rarity Colors (For UI)
StoreConfig.RarityColors = {
	["Normal"] = Color3.fromRGB(200, 200, 200),
	["Rare"] = Color3.fromRGB(30, 144, 255),
	["Super Rare"] = Color3.fromRGB(138, 43, 226),
	["Epic"] = Color3.fromRGB(255, 0, 128),
	["Legendary"] = Color3.fromRGB(255, 215, 0),
}

return StoreConfig
