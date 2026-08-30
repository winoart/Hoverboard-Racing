--!strict
-- MonetizationConfig.lua
-- 골드 구매 상점의 상품(Developer Products) 정보 정의

local MonetizationConfig = {}

-- 임시 로블록스 Developer Product ID
-- 나중에 실제 대시보드에서 생성한 ID로 교체해야 합니다.
MonetizationConfig.GoldProducts = {
	{
		id = 100001,
		name = "소량의 골드",
		amount = 1000,
		price = 20,
		isBestValue = false,
		icon = "rbxassetid://13110903322" -- 작은 코인 아이콘
	},
	{
		id = 100002,
		name = "골드 주머니",
		amount = 5000,
		price = 80,
		isBestValue = false,
		icon = "rbxassetid://13110903322" -- 중간 코인 아이콘
	},
	{
		id = 100003,
		name = "금화 상자",
		amount = 20000,
		price = 250,
		isBestValue = false,
		icon = "rbxassetid://13110903322" -- 상자 아이콘
	},
	{
		id = 100004,
		name = "골드 마운틴",
		amount = 100000,
		price = 999,
		isBestValue = true,
		icon = "rbxassetid://13110903322" -- 왕관 코인 아이콘
	}
}

return MonetizationConfig
