--!strict
-- RebirthConfig.luau
-- 환생 시스템 설정

local RebirthConfig = {}

-- 환생 최대 횟수
RebirthConfig.MAX_REBIRTHS = 50

-- 요구 거리 5km ~ 500km 스케일링을 위한 수학적 계산 함수
function RebirthConfig.GetRebirthData(rebirthLevel: number)
	if rebirthLevel <= 0 then
		return { RequiredDistance = 5000, BoostSpeedBonus = 0 }
	end
	
	local clampedLevel = math.clamp(rebirthLevel, 1, RebirthConfig.MAX_REBIRTHS)
	
	-- 수학적 스케일링: 레벨 1 = 5,000m / 레벨 50 = 약 497,750m
	-- 공식: 5000 + (레벨 - 1)^1.8 * 450
	local requiredDist = 5000 + math.floor(math.pow(clampedLevel - 1, 1.8) * 450)
	
	-- 부스터 속도 보너스: 1레벨당 기본 속도(150)의 1% (+1.5) 추가
	-- 레벨 1: +1.5 / 레벨 50: +75.0 (최대 225)
	local boostBonus = clampedLevel * 1.5
	
	return { 
		RequiredDistance = requiredDist, 
		BoostSpeedBonus = boostBonus 
	}
end

function RebirthConfig.GetNextRebirthData(currentRebirthLevel: number)
	if currentRebirthLevel >= RebirthConfig.MAX_REBIRTHS then
		return nil -- 이미 최대 레벨
	end
	return RebirthConfig.GetRebirthData(currentRebirthLevel + 1)
end

return RebirthConfig
