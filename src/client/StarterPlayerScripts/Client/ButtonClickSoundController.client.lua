--!strict
-- ButtonClickSoundController.client.luau
-- 🎵 중앙 집중식 UI 버튼 클릭 사운드 시스템 (초고속 제로 레이턴시 최적화)
-- 사운드 ID: rbxassetid://87437544236708 (설정, 출석리워드, Items, Quest, Level, Robux, AFK, 닫기 X 버튼 등)

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local BUTTON_CLICK_SOUND_ID = "rbxassetid://87437544236708"
-- 🎯 0.088초: 선행 소프트 틱(0~0.08초)을 건너뛰고 강력한 메인 스냅 피크로 직행하여 체감 딜레이 완전 소멸
local SOUND_ATTACK_OFFSET = 0.088 
local SOUND_PLAYBACK_SPEED = 1.25 -- 25% 가속으로 쫀득하고 즉각적인 아케이드 타격감 구현

-- 🚀 1. 사운드 오브젝트 풀링 (Sound Pool) - 동적 생성/삭제 딜레이 0초화
local SOUND_POOL_SIZE = 6
local soundPool = {}
local poolIndex = 1

for i = 1, SOUND_POOL_SIZE do
	local snd = Instance.new("Sound")
	snd.Name = "UIButtonClickSound_" .. i
	snd.SoundId = BUTTON_CLICK_SOUND_ID
	snd.Volume = 1.0
	snd.PlaybackSpeed = SOUND_PLAYBACK_SPEED
	snd.RollOffMode = Enum.RollOffMode.Linear
	snd.Parent = SoundService
	table.insert(soundPool, snd)
end

-- 사운드 에셋 사전 로딩 (Preload)
task.spawn(function()
	pcall(function()
		ContentProvider:PreloadAsync(soundPool)
	end)
end)

-- ⚡ 2. 초고속 제로 레이턴시 사운드 재생 함수 (디바운스 0.03초)
local lastPlayTime = 0
local function playButtonClickSound()
	local now = os.clock()
	if now - lastPlayTime < 0.03 then return end
	lastPlayTime = now

	local snd = soundPool[poolIndex]
	poolIndex = (poolIndex % SOUND_POOL_SIZE) + 1

	pcall(function()
		snd:Play()
		-- Play 직후 오프셋을 강제 지정하여 FMOD 버퍼링 지연 없이 메인 타격 피크 즉각 출력
		snd.TimePosition = SOUND_ATTACK_OFFSET
	end)
end

-- 외부 스크립트에서도 직접 호출할 수 있도록 글로벌 등록
_G.PlayButtonClickSound = playButtonClickSound

-- 인게임 스킬 발사 버튼 등 예외 처리할 GUI 목록
local EXCLUDED_GUIS = {
	["SkillActionGui"] = true,     -- 인게임 스킬 슬롯 (Slot1, Slot2, Slot3, Slot4 - 고유 스킬 사운드 보유)
	["TouchGui"] = true,           -- 모바일 터치 가상 패드
}

-- 닫기 버튼인지 판별
local function isCloseButton(btn: GuiButton): boolean
	local lowerName = string.lower(btn.Name)
	if string.find(lowerName, "close") or string.find(lowerName, "exit") or string.find(lowerName, "cancel") then
		return true
	end

	if btn:IsA("TextButton") then
		local txt = string.gsub(btn.Text, "%s+", "")
		local lowerTxt = string.lower(txt)
		if lowerTxt == "x" or txt == "✕" or txt == "✖" or txt == "닫기" or txt == "종료" then
			return true
		end
	end

	return false
end

-- 해당 버튼이 클릭음을 재생해야 하는지 검사
local function shouldPlayClickSound(btn: GuiButton): boolean
	if not btn:IsA("GuiButton") then return false end
	if btn:GetAttribute("IgnoreClickSound") == true then return false end

	-- 예외 GUI 내부인지 확인
	for excludedName, _ in pairs(EXCLUDED_GUIS) do
		if btn:FindFirstAncestor(excludedName) then
			return false
		end
	end

	-- 1. 닫기 (X) 버튼 판정
	if isCloseButton(btn) then
		return true
	end

	-- 2. 유저 요청 필수 HUD 버튼들
	-- 설정, 출석리워드, items, quest, level, robux, afk off
	local lowerName = string.lower(btn.Name)
	if lowerName == "settingbutton" or lowerName == "settingsbutton" or lowerName == "setting"
		or lowerName == "dailybutton" or lowerName == "daily" or lowerName == "attendance"
		or lowerName == "inventorytoggle" or lowerName == "inventorybtn"
		or lowerName == "quest" or lowerName == "questbtn" or lowerName == "fallbackquestbtn"
		or lowerName == "rebirth" or lowerName == "rebirthbtn" or lowerName == "dorebirthbtn" or lowerName == "level" or lowerName == "levelbtn"
		or lowerName == "robuxshop" or lowerName == "robuxshopbtn" or lowerName == "robux"
		or lowerName == "afkbutton" or lowerName == "exitbtn" or lowerName == "startspectatebutton" then
		return true
	end

	-- 3. 주요 UI 팝업창 및 HUD 컨테이너 내부의 버튼인지 확인
	local parentScreen = btn:FindFirstAncestorOfClass("ScreenGui")
	if parentScreen then
		local sName = parentScreen.Name
		local UI_SCREEN_WHITELIST = {
			["UtilityBarGui"] = true,
			["InventoryHUD"] = true,
			["Quest"] = true,
			["QuestUI"] = true,
			["Rebirth"] = true,
			["RebirthWindowGui"] = true,
			["RobuxShop"] = true,
			["RobuxShopUI"] = true,
			["setting"] = true,
			["SettingsGui"] = true,
			["dailyreward"] = true,
			["AttendanceGui"] = true,
			["InventoryGui"] = true,
			["AFKGui"] = true,
			["HoverboardShopHUD"] = true,
			["SkillStoreGui"] = true,
			["HoverboardRouletteGui"] = true,
			["AdminToggleGui"] = true,
			["AdminPanelGui"] = true,
			["LevelBarHUD"] = true,
		}
		if UI_SCREEN_WHITELIST[sName] then
			return true
		end
	end

	return false
end

-- 닫기 버튼 전용 즉시 닫기 처리 (마우스를 뗄 때까지 기다리지 않고 누르는 즉시 닫힘)
local function executeInstantClose(btn: GuiButton)
	pcall(function()
		local screen = btn:FindFirstAncestorOfClass("ScreenGui")
		if screen then
			local sName = screen.Name
			if sName == "SettingsGui" or sName == "AttendanceGui" or sName == "InventoryGui"
				or sName == "SkillStoreGui" or sName == "HoverboardShopHUD" or sName == "HoverboardRouletteGui" then
				screen.Enabled = false
			end
		end

		-- 프레임 단위 숨김 UI (QuestUI, RebirthWindowGui, RobuxShopUI 등)
		local current: Instance? = btn.Parent
		while current and not current:IsA("ScreenGui") do
			if current:IsA("GuiObject") then
				local cName = current.Name
				if cName == "MainPanel" or cName == "MainFrame" or cName == "Background" or cName == "Panel" then
					(current :: GuiObject).Visible = false
				end
			end
			current = current.Parent
		end
	end)
end

-- 🎯 버튼 이벤트 연결 (마우스를 누르는 '다운' 즉시 0ms 반응)
local function hookButton(btn: GuiButton)
	if not btn:IsA("GuiButton") then return end
	if btn:GetAttribute("ClickSoundHooked") then return end
	if not shouldPlayClickSound(btn) then return end

	btn:SetAttribute("ClickSoundHooked", true)
	local isClose = isCloseButton(btn)

	local function onTrigger()
		playButtonClickSound()
		if isClose then
			executeInstantClose(btn)
		end
	end

	-- ⚡ 1. PC 마우스 클릭 다운 즉시 발동 (손을 뗄 때까지 기다리는 150ms 딜레이 제거)
	btn.MouseButton1Down:Connect(onTrigger)

	-- ⚡ 2. 모바일 터치 / 게임패드 입력 다운 즉시 발동
	btn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			onTrigger()
		end
	end)

	-- 🛡️ 3. 백업 안전망 (Activated: 디바운스로 중복 방지)
	btn.Activated:Connect(onTrigger)
end

-- 기존 생성되어 있는 모든 버튼 검색 및 연결
local function scanAndHookAll()
	for _, desc in ipairs(PlayerGui:GetDescendants()) do
		if desc:IsA("GuiButton") then
			hookButton(desc)
		end
	end
end

-- 새로 생성되는 버튼 동적 감지 (팝업창 생성, 리스폰 등)
PlayerGui.DescendantAdded:Connect(function(desc)
	if desc:IsA("GuiButton") then
		hookButton(desc)
	end
end)

-- 초기 스캔 실행
scanAndHookAll()

print("🔊 [ButtonClickSoundController] 초고속 제로 레이턴시 UI 버튼 사운드 가동 완료! (ID: " .. BUTTON_CLICK_SOUND_ID .. ")")
