--!strict
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")

local localPlayer = Players.LocalPlayer

-- 초경량 UI 기반 무한 스크롤 스피드 파라미터
local SPEED_IDLE = 350.0  -- 대기 시 부드러운 스크롤 (px/sec)
local SPEED_RIDING = 1400.0 -- 탑승 시 초고속 질주 모드 (px/sec)

-- 🎵 트레드밀 주행 사운드 (호버 엔진음)
local TREADMILL_SOUND_ID = "rbxassetid://75876120873511"
local TARGET_VOLUME = 0.55

local treadmillSound = Instance.new("Sound")
treadmillSound.Name = "TreadmillRunningSound"
treadmillSound.SoundId = TREADMILL_SOUND_ID
treadmillSound.Looped = true
treadmillSound.Volume = 0
treadmillSound.PlaybackSpeed = 1.0
treadmillSound.Parent = SoundService

pcall(function()
	ContentProvider:PreloadAsync({ treadmillSound })
end)

local currentSpeed = SPEED_IDLE
local scrollOffset = 0
local chevronFrames = {}
local windEmitters = {}
local hudElements = nil

local function setupTreadmillFx(model: Model)
	chevronFrames = {}
	windEmitters = {}
	hudElements = nil

	-- 1. 벨트의 HoverBeltHUD 셰브론 프레임 수집
	local belt = model:FindFirstChild("Belt")
	if belt then
		local sg = belt:FindFirstChild("HoverBeltHUD")
		local bg = sg and sg:FindFirstChild("MainTrack")
		local container = bg and bg:FindFirstChild("ChevronContainer")
		if container then
			local list = container:GetChildren()
			for i, child in ipairs(list) do
				if child:IsA("Frame") and child.Name == "Chevron" then
					local initY = (i - 1) * 400 + 80
					table.insert(chevronFrames, {
						frame = child,
						initY = initY
					})
				end
			end
		end
	end

	-- 2. 터빈 윈드 이미터 수집
	for _, child in ipairs(model:GetChildren()) do
		if child.Name == "TurbineCore" then
			local pe = child:FindFirstChild("WindStream")
			if pe and pe:IsA("ParticleEmitter") then
				table.insert(windEmitters, pe)
			end
		end
	end

	-- 3. 전면 스크린 HUD 수집
	local screen = model:FindFirstChild("Screen")
	if screen then
		local sg = screen:FindFirstChild("HoverSimulatorHUD")
		local bg = sg and sg:FindFirstChildOfClass("Frame")
		if bg then
			local subHeader = bg:FindFirstChild("TextLabel") and bg:GetChildren()[3] :: TextLabel?
			local gaugeBox = bg:FindFirstChild("Frame") :: Frame?
			if gaugeBox then
				local speedVal = gaugeBox:FindFirstChild("TextLabel") and gaugeBox:GetChildren()[3] :: TextLabel?
				local pBarBg = gaugeBox:FindFirstChildOfClass("Frame") :: Frame?
				local pBarFill = pBarBg and pBarBg:FindFirstChildOfClass("Frame") :: Frame?
				
				hudElements = {
					subHeader = subHeader,
					speedVal = speedVal,
					pBarFill = pBarFill
				}
			end
		end
	end
end

-- 주기적으로 모델 감지
task.spawn(function()
	while true do
		local lounge = Workspace:FindFirstChild("WaitingRoomLounge") or Workspace:FindFirstChild("WaitingRoom")
		local treadmill = lounge and lounge:FindFirstChild("Treadmill") :: Model?
		if treadmill and #chevronFrames == 0 then
			setupTreadmillFx(treadmill)
		end
		task.wait(2)
	end
end)

-- 60fps/120fps 초경량 GPU 가속 렌더 루프
local elapsedRidingTime = 0
local TRACK_HEIGHT = 1600

RunService.RenderStepped:Connect(function(dt)
	if #chevronFrames == 0 then return end

	local isOnTreadmill = localPlayer:GetAttribute("OnTreadmill") == true
	local targetSpeed = isOnTreadmill and SPEED_RIDING or SPEED_IDLE
	
	-- 부드러운 가속 / 감속
	currentSpeed = currentSpeed + (targetSpeed - currentSpeed) * math.clamp(dt * 7, 0, 1)

	-- A. 셰브론 화살표 무한 스크롤 (앞에서 뒤로)
	scrollOffset = (scrollOffset + currentSpeed * dt) % TRACK_HEIGHT
	for _, item in ipairs(chevronFrames) do
		local curY = (item.initY + scrollOffset) % TRACK_HEIGHT - 60
		item.frame.Position = UDim2.new(0.5, -180, 0, curY)
	end

	-- B. 터빈 바람 파티클 분사량 제어
	if #windEmitters > 0 then
		local targetRate = isOnTreadmill and 50 or 12
		local targetWindSpeed = isOnTreadmill and 35 or 15
		for _, pe in ipairs(windEmitters) do
			pe.Rate = pe.Rate + (targetRate - pe.Rate) * math.clamp(dt * 6, 0, 1)
			pe.Speed = NumberRange.new(targetWindSpeed * 0.85, targetWindSpeed * 1.15)
		end
	end

	-- C. 전면 대시보드 HUD 실시간 반영
	if hudElements and hudElements.speedVal and hudElements.pBarFill then
		pcall(function()
			if isOnTreadmill then
				elapsedRidingTime = elapsedRidingTime + dt
				local jitter = math.sin(elapsedRidingTime * 8) * 3
				local spd = math.floor(150 + jitter)
				hudElements.speedVal.Text = string.format("%d <font size=\"32\" color=\"#FFB91E\">KM/H</font>", spd)
				hudElements.pBarFill.Size = UDim2.new(0.88, 0, 1, 0)
				hudElements.pBarFill.BackgroundColor3 = Color3.fromRGB(0, 255, 180)
				if hudElements.subHeader then
					hudElements.subHeader.Text = "SYSTEM STATUS: 🔥 HIGH VELOCITY TEST 🔥"
					hudElements.subHeader.TextColor3 = Color3.fromRGB(255, 190, 40)
				end
			else
				elapsedRidingTime = 0
				hudElements.speedVal.Text = "0 <font size=\"32\" color=\"#7890AA\">KM/H</font>"
				hudElements.pBarFill.Size = UDim2.new(0.08, 0, 1, 0)
				hudElements.pBarFill.BackgroundColor3 = Color3.fromRGB(0, 240, 255)
				if hudElements.subHeader then
					hudElements.subHeader.Text = "SYSTEM STATUS: READY  |  WIND TUNNEL: IDLE"
					hudElements.subHeader.TextColor3 = Color3.fromRGB(120, 255, 150)
				end
			end
		end)
	end

	-- D. 엔진음 미세 공명 효과 (살아있는 모터 회전감 연출)
	if isOnTreadmill and treadmillSound.IsPlaying then
		treadmillSound.PlaybackSpeed = 1.0 + math.sin(elapsedRidingTime * 6) * 0.03
	end
end)

-- =========================================================================
-- 🔊 트레드밀 탑승 사운드 제어 (Fade In / Fade Out)
-- =========================================================================
local soundTween: Tween? = nil

local function updateTreadmillSound()
	local isOnTreadmill = localPlayer:GetAttribute("OnTreadmill") == true
	local isRacing = localPlayer:GetAttribute("IsRacing") == true

	if isOnTreadmill and not isRacing then
		if not treadmillSound.IsPlaying then
			treadmillSound.Volume = 0
			treadmillSound.PlaybackSpeed = 1.0
			treadmillSound:Play()
		end

		if soundTween then soundTween:Cancel() end
		soundTween = TweenService:Create(treadmillSound, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Volume = TARGET_VOLUME,
			PlaybackSpeed = 1.0,
		})
		soundTween:Play()
	else
		if treadmillSound.IsPlaying then
			if soundTween then soundTween:Cancel() end
			soundTween = TweenService:Create(treadmillSound, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Volume = 0,
			})
			soundTween.Completed:Connect(function()
				if localPlayer:GetAttribute("OnTreadmill") ~= true or localPlayer:GetAttribute("IsRacing") == true then
					treadmillSound:Stop()
				end
			end)
			soundTween:Play()
		end
	end
end

localPlayer:GetAttributeChangedSignal("OnTreadmill"):Connect(updateTreadmillSound)
localPlayer:GetAttributeChangedSignal("IsRacing"):Connect(updateTreadmillSound)

-- 초기 상태 동기화
task.defer(updateTreadmillSound)
