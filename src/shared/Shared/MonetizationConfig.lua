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

MonetizationConfig.ShopData = {
	Events = {
		{
			id = 100005,
			promotionName = "초보자 스타터 팩",
			hookText = "단 한 번의 기회! 압도적인 성장을 시작하세요",
			adminDesc = "골드와 전용 보드를 함께 지급하는 패키지",
			isStarter = true, -- 최초 접속 후 24시간 동안만 노출
			startDate = 0,
			endDate = 4102412400, -- 2099년
			bannerImage = "rbxassetid://13110903322", -- 5:3 비율
			giftImage = "rbxassetid://13110903322", -- 하단 선물 이미지
			rewards = {
				{ type = "Gold", value = 5000 },
				{ type = "Hoverboard", value = "Hoverboard_Starter" },
				{ type = "Skill", value = "Skill_Premium" }
			},
			price = 500,
			maxQuantity = nil, -- 무제한
		}
		-- 향후 시즌 이벤트 배너는 여기에 추가
	},
	Passes = {
		{
			id = 11111111, -- TODO: 실제 게임 패스 ID로 교체하세요
			name = "x2 Distance",
			icon = "rbxassetid://13110903322",
			price = 399,
			isGamePass = true
		},
		{
			id = 22222222, -- TODO: 실제 게임 패스 ID로 교체하세요
			name = "x2 Acceleration",
			icon = "rbxassetid://13110903322",
			price = 299,
			isGamePass = true
		},
		{
			id = 33333333, -- TODO: 실제 게임 패스 ID로 교체하세요
			name = "x2 Race Prize",
			icon = "rbxassetid://13110903322",
			price = 499,
			isGamePass = true
		}
	},
	Golds = {
		{
			id = 100001,
			name = "소량의 골드",
			icon = "rbxassetid://13110903322",
			price = 20,
			rewards = { { type = "Gold", value = 1000 } }
		},
		{
			id = 100002,
			name = "금화 상자",
			icon = "rbxassetid://13110903322",
			price = 250,
			rewards = { { type = "Gold", value = 20000 } }
		}
	}
}

return MonetizationConfig
