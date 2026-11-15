--!strict
-- SkillSoundConfig.lua
-- 모든 스킬 사운드 ID 및 볼륨을 한 곳에서 손쉽게 관리하는 설정 파일
-- 보스께서 원하는 사운드 ID 숫자만 바꾸시면 서버/클라이언트 전체에 자동 적용됩니다!

local SkillSoundConfig = {
	-- 1. Ice Bomb (얼음 폭탄)
	IceBomb = {
		Launch = "rbxassetid://125601475634857", -- 발사음
		Shatter = "rbxassetid://131148590",      -- 얼음 깨지는 소리
		VolumeLaunch = 0.8,
		VolumeShatter = 1.0,
	},

	-- 2. Paintball (페인트볼)
	Paintball = {
		Launch = "rbxassetid://125601475634857", -- 발사음 (기본 세팅)
		Hit = "rbxassetid://0",                  -- 화면에 페인트 튈 때 소리
		VolumeLaunch = 0.8,
		VolumeHit = 1.0,
	},

	-- 3. Shield (에너지 쉴드)
	Shield = {
		Activate = "rbxassetid://86925927032494",  -- 쉴드 전개음
		Break = "rbxassetid://131018142172471",    -- 쉴드 방어/깨짐음
		VolumeActivate = 1.0,
		VolumeBreak = 1.0,
	},

	-- 4. Orbital Laser (궤도 위성 레이저)
	OrbitalLaser = {
		Warning = "rbxassetid://258057783", -- 락온/경고음
		Explosion = "rbxassetid://12222200",-- 폭발음
		VolumeWarning = 1.0,
		VolumeExplosion = 2.0,
	},

	-- 5. Reflect (반사 쉴드)
	Reflect = {
		Activate = "rbxassetid://86925927032494", -- 전개음
		Break = "rbxassetid://131018142172471",   -- 반사/파괴음
		VolumeActivate = 1.0,
		VolumeBreak = 1.0,
	},

	-- 6. Blind Fog (시야 차단 안개)
	BlindFog = {
		Activate = "rbxassetid://0", -- 안개 확산음
		Volume = 1.0,
	},

	-- 7. Ghost (유령/투명화)
	Ghost = {
		Activate = "rbxassetid://0", -- 유령 변신음
		Volume = 1.0,
	},

	-- 8. EMP Hack (주변 조작 반전 & 화면 글리치)
	EMP = {
		Zap = "rbxassetid://138084050",         -- 글리치/Zap 사운드
		ShieldBlock = "rbxassetid://131018142172471", -- 쉴드로 EMP 방어 시 소리
		VolumeZap = 0.8,
		VolumeShieldBlock = 1.0,
	},

	-- 9. Golden Freeze (스타터팩 전용 황금 결빙)
	GoldenFreeze = {
		Launch = "rbxassetid://125601475634857", -- 발사음
		Shatter = "rbxassetid://131148590",      -- 황금 얼음 깨짐음
		VolumeLaunch = 0.8,
		VolumeShatter = 0.8,
	},
}

return SkillSoundConfig

