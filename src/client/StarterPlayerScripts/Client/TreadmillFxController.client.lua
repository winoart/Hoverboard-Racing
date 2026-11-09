--!strict
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local localPlayer = Players.LocalPlayer

-- 애니메이션 파라미터
local X_MIN = -21.0 -- 전면 (터빈 앞)
local X_MAX = -5.5  -- 후면 (진입 램프 입구)
local X_LEN = X_MAX - X_MIN

local SPEED_IDLE = 10.0  -- 대기 중 화살표 속도 (studs/sec)
local SPEED_RIDING = 42.0 -- 탑승 주행 중 화살표 속도 (초고속 질주!)

local currentSpeed = SPEED_IDLE
local chevronDataList = {}
local windEmitters = {}
local hudElements = nil
local beltTexture = nil

local function setupTreadmillFx(model: Model)
	chevronDataList = {}
	windEmitters = {}
	hudElements = nil
	beltTexture = nil

	-- 1. 셰브론 모델 수집
	local chevronsFolder = model:FindFirstChild("Chevrons")
	if chevronsFolder then
		for _, chModel in ipairs(chevronsFolder:GetChildren()) do
			if chModel:IsA("Model") then
				local currentX = chModel:GetAttribute("CurrentX")
				if not currentX and chModel.PrimaryPart then
					currentX = chModel.PrimaryPart.Position.X
				end
				currentX = currentX or X_MIN
				
				local parts = {}
				for _, p in ipairs(chModel:GetDescendants()) do
					if p:IsA("BasePart") then
						table.insert(parts, {
							part = p,
							baseColor = p.Color,
							relCFrame = chModel.PrimaryPart and (chModel.PrimaryPart.CFrame:Inverse() * p.CFrame) or CFrame.identity
						})
					end
				end
				
				table.insert(chevronDataList, {
					model = chModel,
					currentX = currentX,
					primaryPart = chModel.PrimaryPart,
					parts = parts
				})
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

	-- 3. 벨트 텍스처 수집
	local belt = model:FindFirstChild("Belt")
	if belt then
		beltTexture = belt:FindFirstChild("BeltTexture") :: Texture?
	end

	-- 4. HUD 디스플레이 요소 수집
	local screen = model:FindFirstChild("Screen")
	if screen then
		local sg = screen:FindFirstChild("HoverSimulatorHUD")
		if sg then
			local bg = sg:FindFirstChildOfClass("Frame")
			if bg then
				local subHeader = bg:FindFirstChild("TextLabel") and bg:GetChildren()[3] :: TextLabel? -- subHeader
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
end

-- 주기적으로 모델 감지 및 연결
task.spawn(function()
	while true do
		local lounge = Workspace:FindFirstChild("WaitingRoomLounge") or Workspace:FindFirstChild("WaitingRoom")
		local treadmill = lounge and lounge:FindFirstChild("Treadmill") :: Model?
		if treadmill and #chevronDataList == 0 then
			setupTreadmillFx(treadmill)
		end
		task.wait(2)
	end
end)

-- 렌더 루프 (60/120fps 부드러운 애니메이션)
local elapsedRidingTime = 0

RunService.RenderStepped:Connect(function(dt)
	if #chevronDataList == 0 then return end

	local isOnTreadmill = localPlayer:GetAttribute("OnTreadmill") == true
	local targetSpeed = isOnTreadmill and SPEED_RIDING or SPEED_IDLE
	
	-- 부드러운 가속/감속
	currentSpeed = currentSpeed + (targetSpeed - currentSpeed) * math.clamp(dt * 6, 0, 1)

	-- A. 셰브론 화살표 위치 이동 및 무한 루프
	local step = currentSpeed * dt
	for _, data in ipairs(chevronDataList) do
		data.currentX = data.currentX + step
		if data.currentX > X_MAX then
			data.currentX = data.currentX - X_LEN
		end

		-- 양 끝단 페이드아웃 (터빈 앞 스폰 시 부드럽게 나타나고, 램프 끝에서 부드럽게 사라짐)
		local fadeDist = 1.8
		local alpha = 0
		if data.currentX < (X_MIN + fadeDist) then
			alpha = 1 - math.clamp((data.currentX - X_MIN) / fadeDist, 0, 1)
		elseif data.currentX > (X_MAX - fadeDist) then
			alpha = math.clamp((data.currentX - (X_MAX - fadeDist)) / fadeDist, 0, 1)
		end

		if data.primaryPart then
			local curPos = data.primaryPart.Position
			local deltaX = data.currentX - curPos.X
			
			for _, pInfo in ipairs(data.parts) do
				local p = pInfo.part
				p.CFrame = p.CFrame + Vector3.new(deltaX, 0, 0)
				p.Transparency = alpha
			end
		end
	end

	-- B. 벨트 텍스처 스크롤 동기화
	if beltTexture and beltTexture.StudsPerTileV > 0 then
		beltTexture.OffsetStudsV = (beltTexture.OffsetStudsV - dt * currentSpeed * 0.4) % beltTexture.StudsPerTileV
	end

	-- C. 터빈 윈드 이미터 속도 및 방출량 동적 조절
	if #windEmitters > 0 then
		local targetRate = isOnTreadmill and 50 or 12
		local targetWindSpeed = isOnTreadmill and 36 or 16
		for _, pe in ipairs(windEmitters) do
			pe.Rate = pe.Rate + (targetRate - pe.Rate) * math.clamp(dt * 5, 0, 1)
			pe.Speed = NumberRange.new(targetWindSpeed * 0.85, targetWindSpeed * 1.15)
		end
	end

	-- D. HUD 대시보드 실시간 반응
	if hudElements and hudElements.speedVal and hudElements.pBarFill then
		if isOnTreadmill then
			elapsedRidingTime = elapsedRidingTime + dt
			-- 역동적인 속도 변화 (148~154 KM/H 진동)
			local jitter = math.sin(elapsedRidingTime * 8) * 3 + math.cos(elapsedRidingTime * 14) * 2
			local displaySpeed = math.floor(150 + jitter)
			hudElements.speedVal.Text = string.format("%d <font size=\"32\" color=\"#FFB91E\">KM/H</font>", displaySpeed)
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
	end
end)
