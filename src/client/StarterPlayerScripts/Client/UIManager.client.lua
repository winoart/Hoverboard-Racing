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
	"UtilityBarGui",
	"InventoryHUD"
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
	
end

-- 속성 변경 시 실시간 UI 갱신
LocalPlayer:GetAttributeChangedSignal("IsRacing"):Connect(updateUIVisibility)
LocalPlayer:GetAttributeChangedSignal("IsSpectating"):Connect(updateUIVisibility)
LocalPlayer:GetAttributeChangedSignal("IsAFK"):Connect(updateUIVisibility)

-- 초기 갱신
updateUIVisibility()

-- 모바일/작은 화면일 때 텍스트 라벨 숨기기 (반응형)
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local function applyVisibilityToGui(gui, isSmallScreen)
	for _, desc in ipairs(gui:GetDescendants()) do
		if desc:IsA("TextLabel") then
			print("🔎 [Debug] Found TextLabel:", desc.Name, "in", gui.Name, "| Setting Visible to:", not isSmallScreen)
			desc.Visible = not isSmallScreen
		end
	end
end

local function updateMobileTextVisibility()
	-- 창 크기(ViewportSize)로 판단하면 스튜디오 패널 때문에 창이 좁아졌을 때 모바일로 오작동함.
	-- PC 창을 작게 줄였을 때(Output창 등) 버튼 글씨가 사라지는 문제 수정
	-- 터치가 되면서 키보드가 없는 순수 모바일 환경일 때만 글씨를 숨기도록 변경합니다.
	local isSmallScreen = (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled)
	
	local mobileHideGuis = {"InventoryHUD", "Quest", "Rebirth", "RobuxShop"}
	
	for _, guiName in ipairs(mobileHideGuis) do
		task.spawn(function()
			local gui = PlayerGui:WaitForChild(guiName, 10)
			if gui then
				applyVisibilityToGui(gui, isSmallScreen)
			end
		end)
	end
end

-- 아랫줄 버튼(Rebirth, RobuxShop) 위치 고정 및 모바일 간격 조절
local function lockBottomButtonsPosition()
	local inventory = PlayerGui:WaitForChild("InventoryHUD", 10)
	local quest = PlayerGui:WaitForChild("Quest", 10)
	local rebirth = PlayerGui:WaitForChild("Rebirth", 10)
	local robux = PlayerGui:WaitForChild("RobuxShop", 10)
	
	if not (inventory and quest and rebirth and robux) then return end
	
	local function getButton(gui)
		for _, desc in ipairs(gui:GetDescendants()) do
			if desc:IsA("GuiButton") then return desc end
		end
		return nil
	end
	
	local invBtn = getButton(inventory)
	local questBtn = getButton(quest)
	local rebBtn = getButton(rebirth)
	local robuxBtn = getButton(robux)
	
	local function updateLayout()
		local isSmallScreen = (workspace.CurrentCamera.ViewportSize.Y < 600) or (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled)
		
		-- 모바일일 때는 간격을 10픽셀로 살짝 띄우고, PC일 때는 18픽셀로 넉넉하게
		local gap = isSmallScreen and 10 or 18
		
		-- 윗줄 버튼 모바일 위치 상승 (원본 Position은 Studio에 세팅된 값 유지, Offset만 조절)
		if invBtn and invBtn:FindFirstChild("OriginalY") == nil then
			local ogY = Instance.new("NumberValue")
			ogY.Name = "OriginalY"
			ogY.Value = invBtn.Position.Y.Offset
			ogY.Parent = invBtn
		end
		if questBtn and questBtn:FindFirstChild("OriginalY") == nil then
			local ogY = Instance.new("NumberValue")
			ogY.Name = "OriginalY"
			ogY.Value = questBtn.Position.Y.Offset
			ogY.Parent = questBtn
		end
		
		if invBtn then
			local ogY = invBtn:FindFirstChild("OriginalY").Value
			invBtn.Position = UDim2.new(invBtn.Position.X.Scale, invBtn.Position.X.Offset, invBtn.Position.Y.Scale, isSmallScreen and (ogY - 50) or ogY)
		end
		if questBtn then
			local ogY = questBtn:FindFirstChild("OriginalY").Value
			questBtn.Position = UDim2.new(questBtn.Position.X.Scale, questBtn.Position.X.Offset, questBtn.Position.Y.Scale, isSmallScreen and (ogY - 50) or ogY)
		end
		
		-- 아랫줄 버튼 윗줄 바로 아래로 고정
		if invBtn and rebBtn then
			rebBtn.AnchorPoint = Vector2.new(rebBtn.AnchorPoint.X, invBtn.AnchorPoint.Y)
			rebBtn.Position = UDim2.new(rebBtn.Position.X.Scale, rebBtn.Position.X.Offset, invBtn.Position.Y.Scale, invBtn.Position.Y.Offset + invBtn.AbsoluteSize.Y + gap)
		end
		if questBtn and robuxBtn then
			robuxBtn.AnchorPoint = Vector2.new(robuxBtn.AnchorPoint.X, questBtn.AnchorPoint.Y)
			robuxBtn.Position = UDim2.new(robuxBtn.Position.X.Scale, robuxBtn.Position.X.Offset, questBtn.Position.Y.Scale, questBtn.Position.Y.Offset + questBtn.AbsoluteSize.Y + gap)
		end
	end

	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		task.wait(0.05) -- AbsoluteSize 갱신 대기 최소화
		updateLayout()
	end)
	
	if invBtn then invBtn:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateLayout) end
	if questBtn then questBtn:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateLayout) end
	
	updateLayout() -- 딜레이 없이 즉시 실행하여 버튼 튀는 현상 제거
end

-- 해상도 변경 시 실시간 대응
Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateMobileTextVisibility)
-- 초기 로딩 대응
task.spawn(updateMobileTextVisibility)
task.spawn(lockBottomButtonsPosition)

print("🛡️ [UIManager] UI 중앙 제어 시스템 가동 완료!")
