--!strict
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer

-- 초경량 UI 기반 무한 스크롤 스피드 파라미터
local SPEED_IDLE = 350.0  -- 대기 시 부드러운 스크롤 (px/sec)
local SPEED_RIDING = 1400.0 -- 탑승 시 초고속 질주 모드 (px/sec)

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
		if isOnTreadmill then
			elapsedRidingTime = elapsedRidingTime + dt
			local jitter = math.sin(elapsedRidingTime * 8) * 3
			local spd = math.floor(150 + jitter)
			hudSpeedVal.Text = string.format("%d <font size=\"32\" color=\"#FFB91E\">KM/H</font>", spd)
			hudBarFill.Size = UDim2.new(0.88, 0, 1, 0)
			hudBarFill.BackgroundColor3 = Color3.fromRGB(0, 255, 180)
			if hudSubHeader then
				hudSubHeader.Text = "SYSTEM STATUS: 🔥 HIGH VELOCITY TEST 🔥"
				hudSubHeader.TextColor3 = Color3.fromRGB(255, 190, 40)
			end
		else
			elapsedRidingTime = 0
			hudSpeedVal.Text = "0 <font size=\"32\" color=\"#7890AA\">KM/H</font>"
			hudBarFill.Size = UDim2.new(0.08, 0, 1, 0)
			hudBarFill.BackgroundColor3 = Color3.fromRGB(0, 240, 255)
			if hudSubHeader then
				hudSubHeader.Text = "SYSTEM STATUS: READY  |  WIND TUNNEL: IDLE"
				hudSubHeader.TextColor3 = Color3.fromRGB(120, 255, 150)
			end
		end
	end
end)
