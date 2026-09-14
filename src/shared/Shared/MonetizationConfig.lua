--!strict
-- MonetizationConfig.lua
-- ROBUX 상점 및 기간 한정/수량 한정 프로모션 상품 설정

local MonetizationConfig = {}

-- 한국 표준시(KST)를 Unix Timestamp로 변환하는 함수
local function KST(year: number, month: number, day: number, hour: number, min: number, sec: number)
	-- KST는 UTC+9 이므로, 주어진 시간에서 9시간을 빼서 UTC 기준으로 DateTime 객체를 생성합니다.
	return DateTime.fromUniversalTime(year, month, day, hour - 9, min, sec).UnixTimestamp
end

-- 프로모션 설정 가이드:
-- id: Developer Product ID
-- promotionName: 관리자 및 유저에게 보일 프로모션 이름
-- adminDesc: 관리자 메모용 설명
-- startDate / endDate: KST(한국 표준시) 기준 배너 노출 기간
-- bannerImage: 3:1 비율의 배너 이미지 (rbxassetid://...)
-- rewardType/Value 대신 여러 개의 보상을 지급할 수 있도록 rewards 배열을 사용합니다.
-- rewards = { {type="Gold", value=1000}, {type="Hoverboard", value="Hoverboard_001"} }
-- price: UI 표기용 로벅스 가격
-- maxQuantity: 한정 수량 (nil 이면 무제한)

MonetizationConfig.RobuxPromotions = {
	-- 1. 상시 판매 상품 (먼 미래 종료)
	{
		id = 100001,
		promotionName = "소량의 골드 (상시)",
		adminDesc = "상시 판매용 기본 골드",
		startDate = 0,
		endDate = 4102412400, -- 2099년
		bannerImage = "rbxassetid://13110903322", -- 임시 배너 이미지
		rewards = {
			{ type = "Gold", value = 1000 }
		},
		price = 20,
		maxQuantity = nil, -- 무제한
	},
	{
		id = 100002,
		promotionName = "금화 상자 (상시)",
		adminDesc = "상시 판매용 대량 골드",
		startDate = 0,
		endDate = 4102412400, -- 2099년
		bannerImage = "rbxassetid://13110903322",
		rewards = {
			{ type = "Gold", value = 20000 }
		},
		price = 250,
		maxQuantity = nil,
	},
	-- 2. 복합 보상 상품 (스타터팩 등)
	{
		id = 100005,
		promotionName = "초보자 스타터 팩",
		adminDesc = "골드와 전용 보드를 함께 지급하는 패키지",
		startDate = 0,
		endDate = KST(2030, 12, 31, 23, 59, 59),
		bannerImage = "rbxassetid://13110903322",
		rewards = {
			{ type = "Gold", value = 5000 },
			{ type = "Hoverboard", value = "Hoverboard_Starter" },
			{ type = "Skill", value = "Skill_Premium" }
		},
		price = 500,
		maxQuantity = 100, -- 100개 한정
	}
}

MonetizationConfig.SlotUnlockProducts = {
	Slot3 = {
		id = 123456789,
		price = 300,
		name = "R 슬롯 잠금 해제"
	},
	Slot4 = {
		id = 987654321,
		price = 500,
		name = "T 슬롯 잠금 해제"
	}
}

return MonetizationConfig
