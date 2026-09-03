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
	desc: string?, -- 아이템 설명 (선택 사항)
}

StoreConfig.Items = {
	{
		id = "DefaultHoverboard",
		name = "블루토닉 (기본)",
		imageId = "rbxassetid://98211009044526",
		rarity = "Normal",
		weight = 0, -- 기본 보드는 뽑기에서 등장하지 않음
		desc = "초보자를 위한 가장 기본적인 호버보드입니다. 안정적인 주행감을 자랑합니다.",
	},
	{
		id = "NormalBoard1",
		name = "스탠다드 호버",
		imageId = "rbxassetid://10078028148",
		rarity = "Normal",
		weight = 500, -- 50%
		desc = "표준적인 성능을 갖춘 호버보드입니다. 가성비가 뛰어납니다.",
	},
	{
		id = "RareBoard1",
		name = "루비 슬라이더",
		imageId = "rbxassetid://10078028148",
		rarity = "Rare",
		weight = 150, -- 15%
		desc = "붉은 보석처럼 빛나는 세련된 디자인의 호버보드입니다.",
	},
	{
		id = "CloudBoard",
		name = "근두운",
		imageId = "rbxassetid://116012241551714",
		rarity = "Rare",
		weight = 150, -- 15%
		desc = "푹신한 구름 모양을 한 신비로운 보드입니다. 부드럽게 날아갑니다.",
	},
	{
		id = "SuperRareBoard1",
		name = "네온 스트라이크",
		imageId = "rbxassetid://10078028148",
		rarity = "Super Rare",
		weight = 150, -- 15%
		desc = "어둠 속에서도 빛을 내며 빠르게 질주하는 고성능 보드입니다.",
	},
	{
		id = "MagicBroom",
		name = "님부스2000",
		imageId = "rbxassetid://91414670760591",
		rarity = "Epic",
		weight = 40, -- 4%
		desc = "마법사들이 애용하던 전설적인 빗자루 형태의 호버보드입니다.",
	},
	{
		id = "LegendaryBoard1",
		name = "드래곤 윙",
		imageId = "rbxassetid://10078028148",
		rarity = "Legendary",
		weight = 10, -- 1%
		desc = "용의 날개를 뜯어 만든 듯한 압도적인 포스를 뿜어내는 최강의 보드입니다.",
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
