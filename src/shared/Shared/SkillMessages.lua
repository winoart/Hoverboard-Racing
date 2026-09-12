--!strict
-- SkillMessages.lua
-- 게임 내 스킬 사용 시 나타나는 모든 문구와 디자인(UI) 세팅을 관리하는 설정 파일입니다.
-- 자유롭게 텍스트(Text)와 디자인 속성을 수정하세요!

return {
	-- =======================================================
	-- 1. [디자인 세팅] 알림창(Toast) UI 디자인
	-- =======================================================
	Design = {
		-- [내 스킬 알림] 내가 스킬을 사용했을 때 화면 중앙 아래에 뜨는 알림
		MySkillToast = {
			PosY = 0.3, -- 화면 위에서부터의 위치 (0 ~ 1, 0.7 = 위에서 70% 지점)
			TextSize = 60, -- 글자 크기
			Font = Enum.Font.FredokaOne, -- 글로벌 영어 폰트
			StrokeColor = Color3.fromRGB(0, 0, 0), -- 검정 외곽선
			StrokeThickness = 6, -- 아주 두꺼운 외곽선
			TextColor = Color3.fromRGB(255, 200, 50), -- 글자 내부 색상
		},

		-- [경고 알림] 남이 나를 공격하거나 내 방어막이 깨졌을 때 화면 중앙 위에 뜨는 알림
		WarningToast = {
			PosY = 0.3, -- 화면 위에서부터의 위치 (0.3 = 위에서 30% 지점)
			TextSize = 60, -- 글자 크기
			Font = Enum.Font.FredokaOne, -- 글로벌 영어 폰트
			StrokeColor = Color3.fromRGB(0, 0, 0), -- 검정 외곽선
			StrokeThickness = 6, -- 아주 두꺼운 외곽선
			TextColor = Color3.fromRGB(255, 50, 50), -- 빨간색 글자
		},
		
		-- [EMP 해킹 알림] 내가 EMP 공격을 받아 화면이 해킹당했을 때 뜨는 큰 알림
		EMPHackToast = {
			PosY = 0.3, -- 화면 위에서 20% 지점
			Font = Enum.Font.FredokaOne,
			TextColor = Color3.fromRGB(255, 0, 0),
			-- 참고: EMP 해킹 알림은 화면을 꽉 채우기 위해 폰트 사이즈가 자동으로 변합니다 (TextScaled = true)
		}
	},

	-- =======================================================
	-- 2. [텍스트 문구] 상황별 출력 메시지
	-- =======================================================
	Messages = {
		-- 🛡️ [방어막 관련]
		-- 상대방의 공격(얼음폭탄 등)을 내 방어막이 막아서 파괴되었을 때 나에게 뜨는 경고
		ShieldBroken = "🛡️ Shield Broken!",
		
		-- 내가 공격한 상대방이 방어막을 켜고 있어서, 상대의 방어막만 부수고 끝났을 때 나에게 뜨는 알림
		-- {casterName} 자리에 상대방 이름이 자동으로 들어갑니다.
		ShieldDisabledEnemy = "💥 Broke {casterName}'s Shield!",

		-- ⚠️ [피격 경고]
		-- 누군가 나에게 타겟팅 스킬(얼음폭탄 등)을 쏘았을 때 나에게 뜨는 위험 경고
		EnemyUsedSkillOnYou = "⚠️ {casterName} used {skillName}!",

		-- 🔥 [내 스킬 사용]
		-- 내가 키보드 단축키를 눌러 스킬을 발동했을 때 화면 아래에 뜨는 문구
		MySkillActivated = "🔥 [{skillName}] Activated!",

		-- 🚀 [부스터 사용]
		-- 부스터(Space바)를 켰을 때 뜨는 문구
		BoosterActivated = "🔥 Booster ON!",

		-- ⚡ [EMP 관련]
		-- 내가 EMP 스킬을 성공적으로 사용하여 적들을 마비시켰을 때 나에게 뜨는 문구
		EMPReady = "⚡ EMP Hack Ready!",
		
		-- 다른 유저가 나에게 EMP를 쏘았을 때 나에게 뜨는 알림 (현재는 별도 해킹UI가 뜨므로 안 쓰임)
		EnemyUsedEMP = "⚡ {casterName} used EMP!",
		
		-- 내가 EMP에 맞아 조작이 마비되었을 때 화면을 덮는 경고 문구
		EMPHackText = "🚨 CONTROLS HACKED 🚨",

		-- ⏳ [시스템 안내]
		-- 스킬 쿨타임이 덜 끝났는데 또 스킬 키를 눌렀을 때 (Output 창 등에 출력됨)
		CooldownActive = "⏳ On Cooldown!",
		
		-- 슬롯 구매 경고 (4번째 슬롯을 열려는데 3번째를 안 열었을 때)
		NeedSlot3First = "You must purchase the 3rd slot first!"
	},

	-- =======================================================
	-- (내부용) 변수를 텍스트에 쏙쏙 집어넣어주는 유틸리티 함수
	-- =======================================================
	Format = function(self, messageKey: string, vars: {[string]: any}?): string
		local msg = self.Messages[messageKey]
		if not msg then return messageKey end
		
		if vars then
			for k, v in pairs(vars) do
				msg = string.gsub(msg, "{" .. k .. "}", tostring(v))
			end
		end
		return msg
	end
}
