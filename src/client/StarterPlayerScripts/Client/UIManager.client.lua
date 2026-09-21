--!strict
-- UIManager.client.luau
-- 중앙 집중식 UI 표시/숨김 제어 시스템

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local remotesFolder = ReplicatedStorage:WaitForChild("HoverboardRemotes")
local phaseRemote = remotesFolder:WaitForChild("GamePhaseChanged") :: RemoteEvent

-- 대기실/AFK 상태일 때 보여져야 할 '버튼' ScreenGui 목록 (켜고 끄기 양방향)
local LOUNGE_BUTTON_GUIS = {
	"dailyreward",
	"Quest",
	"Rebirth",
	"RobuxShop",
	"SkillShop",
	"setting",
	"Hover",
	"HoverShop",
	"UtilityBarGui"
}

-- 상점, 인벤토리 등 팝업창 목록 (레이싱 진입 시 강제로 '끄기'만 하고 자동으로 '켜지'는 않음)
local LOUNGE_POPUP_GUIS = {
	"RebirthWindowGui",
	"AttendanceGui",
	"InventoryGui",
	"HoverboardRouletteGui",
	"SkillStoreGui",
	"HoverboardShopHUD",
}

-- 다른 ScreenGui 안에 둥둥 떠있는 대기실용 개별 버튼들의 이름 목록 (더 이상 필요 없지만 백업용)
local LOUNGE_BUTTON_NAMES = {
	"Rebirth", "RebirthBtn", "DoRebirthBtn",
	"Quest", "QuestBtn",
	"Skill", "SkillBtn", "SkillStoreBtn",
	"Hover", "HoverBtn", "HoverShopBtn",
	"Robux", "RobuxShop", "RobuxShopBtn",
	"Settings", "SettingsBtn"
}

-- UI 갱신 함수 (상태에 따라 가시성 일괄 제어)
local function updateUIVisibility()
	local isRacing = LocalPlayer:GetAttribute("IsRacing") == true
	local isSpectating = LocalPlayer:GetAttribute("IsSpectating") == true
	
	-- 레이싱 중이거나 관전 중일 때는 대기실 메뉴 버튼들을 모두 가림
	local shouldShowLoungeUI = not (isRacing or isSpectating)
	
	-- 1. 대기실 기본 버튼들 (돌아오면 켜져야 함)
	for _, guiName in ipairs(LOUNGE_BUTTON_GUIS) do
		local gui = PlayerGui:FindFirstChild(guiName)
		if gui and gui:IsA("ScreenGui") then
			gui.Enabled = shouldShowLoungeUI
		end
	end
	
	-- 2. 팝업창 강제 닫기 (관전/레이싱 진입 시에만 닫고, 대기실 돌아올 땐 자동으로 안 켬!)
	if not shouldShowLoungeUI then
		for _, guiName in ipairs(LOUNGE_POPUP_GUIS) do
			local gui = PlayerGui:FindFirstChild(guiName)
			if gui and gui:IsA("ScreenGui") then
				gui.Enabled = false
			end
		end
	end
	
	-- 2. 태그(LoungeUI)가 부여된 개별 버튼/UI들 일괄 제어 (가장 깔끔한 방법)
	for _, obj in ipairs(game:GetService("CollectionService"):GetTagged("LoungeUI")) do
		-- 로컬 플레이어의 PlayerGui 안에 있는 인스턴스인지 확인
		if obj:IsDescendantOf(PlayerGui) and obj:IsA("GuiObject") then
			obj.Visible = shouldShowLoungeUI
		end
	end
end

-- 속성 변경 시 실시간 UI 갱신
LocalPlayer:GetAttributeChangedSignal("IsRacing"):Connect(updateUIVisibility)
LocalPlayer:GetAttributeChangedSignal("IsSpectating"):Connect(updateUIVisibility)
LocalPlayer:GetAttributeChangedSignal("IsAFK"):Connect(updateUIVisibility)

-- 초기 갱신
updateUIVisibility()

print("🛡️ [UIManager] UI 중앙 제어 시스템 가동 완료!")
