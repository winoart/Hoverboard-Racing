--!strict
-- DistanceController.client.luau
-- 거리를 측정하고 서버에 동기화하며 화면에 표시

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local remotesFolder = ReplicatedStorage:WaitForChild("HoverboardRemotes")
local addDistanceRemote = remotesFolder:WaitForChild("AddDistance") :: RemoteEvent

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RebirthConfig = require(Shared:WaitForChild("RebirthConfig"))
local HoverboardConfig = require(Shared:WaitForChild("HoverboardConfig"))

local accumulatedDistance = 0
local lastSyncTime = os.clock()
local SYNC_INTERVAL = 1.0 -- 1초마다 서버에 전송

local lastLightningDistance = -1
local LIGHTNING_SPAWN_INTERVAL = 100 -- 100미터마다 번개 생성

-- 포맷팅 함수
local function formatDistance(meters: number): string
	if meters >= 1000 then
		local km = meters / 1000
		return string.format("%.1fkm", km)
	else
		return string.format("%dm", math.floor(meters))
	end
end

-- 미터기 UI 찾기 (재시도 로직)
local function getMeterLabel(): TextLabel?
	local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
	if playerGui then
		local targetLabel = nil
		
		-- 1. 먼저 MeterTextLabel 이나 MeterDisplayHUD 라는 이름으로 찾아봅니다.
		for _, gui in ipairs(playerGui:GetChildren()) do
			if gui:IsA("ScreenGui") then
				local label = gui:FindFirstChild("MeterTextLabel", true) or gui:FindFirstChild("MeterDisplayHUD", true)
				if label and (label:IsA("TextLabel") or label:IsA("TextButton")) then
					targetLabel = label
					break
				end
			end
		end
		
		-- 2. 만약 이름을 다르게 지으셨다면, 텍스트가 "12345"인 텍스트 관련 UI를 무조건 찾습니다!
		if not targetLabel then
			for _, gui in ipairs(playerGui:GetChildren()) do
				if gui:IsA("ScreenGui") then
					for _, desc in ipairs(gui:GetDescendants()) do
						if (desc:IsA("TextLabel") or desc:IsA("TextButton")) and desc.Text == "12345" then
							targetLabel = desc
							break
						end
					end
				end
				if targetLabel then break end
			end
		end
		
		if targetLabel then
			-- 외곽선 자동 추가 (없을 경우)
			local stroke = targetLabel:FindFirstChildOfClass("UIStroke")
			if not stroke then
				stroke = Instance.new("UIStroke")
				stroke.Color = Color3.new(0, 0, 0)
				stroke.Thickness = 3
				stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
				stroke.Parent = targetLabel
			else
				stroke.Color = Color3.new(0, 0, 0)
				stroke.Thickness = 3
				stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
			end
			return targetLabel
		end
	end
	return nil
end

local function spawnLightningEffect(meterLabel: TextLabel?, hrp: BasePart)
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	
	-- 월드 좌표를 스크린 좌표로 변환
	local screenPos, onScreen = Workspace.CurrentCamera:WorldToScreenPoint(hrp.Position)
	if not onScreen then return end
	
	local fxScreen = playerGui:FindFirstChild("LightningFXGui")
	if not fxScreen then
		fxScreen = Instance.new("ScreenGui")
		fxScreen.Name = "LightningFXGui"
		fxScreen.Parent = playerGui
	end
	
	-- 타겟 위치 (미터 텍스트 라벨의 중앙)
	local targetPos
	if meterLabel then
		targetPos = UDim2.new(0, meterLabel.AbsolutePosition.X + (meterLabel.AbsoluteSize.X / 2), 0, meterLabel.AbsolutePosition.Y + (meterLabel.AbsoluteSize.Y / 2))
	else
		targetPos = UDim2.new(0, screenPos.X, 0, screenPos.Y - 250)
	end
	
	for i = 1, 3 do
		local icon = Instance.new("TextLabel")
		icon.Size = UDim2.new(0, 78, 0, 78) -- 기존 60에서 30% 증가
		icon.Position = UDim2.new(0, screenPos.X, 0, screenPos.Y)
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.BackgroundTransparency = 1
		icon.Font = Enum.Font.GothamBlack
		icon.Text = "⚡"
		icon.TextSize = 78
		icon.TextColor3 = Color3.fromRGB(255, 255, 0) -- 노란색 시도
		icon.ZIndex = 100
		
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.new(0, 0, 0)
		stroke.Thickness = 2
		stroke.Parent = icon
		
		icon.Parent = fxScreen
		
		-- 1단계: 플레이어 몸에서 아래쪽으로 스무스하게 튀어나오기
		local randomX = screenPos.X + math.random(-80, 80)
		local randomY = screenPos.Y + math.random(50, 120)
		local popPos = UDim2.new(0, randomX, 0, randomY)
		
		local popTweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local popTween = TweenService:Create(icon, popTweenInfo, {Position = popPos})
		
		-- 2단계: 거리 표시 UI 쪽으로 가속하며 빨려 들어가기 (가속도 = EasingDirection.In)
		local flyTweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Cubic, Enum.EasingDirection.In)
		local flyTween = TweenService:Create(icon, flyTweenInfo, {
			Position = targetPos,
			TextSize = meterLabel and 40 or 10,
			TextTransparency = meterLabel and 0 or 1
		})
		
		popTween.Completed:Connect(function()
			flyTween:Play()
		end)
		
		flyTween.Completed:Connect(function()
			icon:Destroy()
		end)
		
		-- 3개의 번개가 약간의 시차를 두고 순차적으로 튀어나오도록 딜레이 적용
		task.delay((i - 1) * 0.15, function()
			if icon.Parent then
				popTween:Play()
			end
		end)
	end
end

RunService.RenderStepped:Connect(function(dt)
	local isSpectating = LocalPlayer:GetAttribute("IsSpectating") == true
	
	local meterLabel = getMeterLabel()
	if meterLabel then
		local mGui = meterLabel:FindFirstAncestor("MeterDisplayHUD")
		if mGui and mGui:IsA("ScreenGui") then
			mGui.Enabled = not isSpectating
		else
			meterLabel.Visible = not isSpectating
		end
	end

	if isSpectating then return end
	
	local character = LocalPlayer.Character
	if not character then return end
	
	-- 1. UI는 호버보드 탑승 여부와 상관없이 항상 업데이트 합니다. (외곽선 추가 및 현재 거리 표시)
	local currentDistance = 0
	local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
	if leaderstats then
		local distanceVal = leaderstats:FindFirstChild("Distance") :: IntValue
		currentDistance = (distanceVal and distanceVal.Value or 0) + accumulatedDistance
		if meterLabel then
			meterLabel.Text = formatDistance(currentDistance)
		end
		
		-- 초기 접속 시 가지고 있던 거리로 기준점 초기화 (불필요한 번개 생성 방지)
		if lastLightningDistance == -1 or currentDistance < lastLightningDistance then
			print("[DistanceController] lastLightningDistance 초기화:", lastLightningDistance, "->", currentDistance)
			lastLightningDistance = currentDistance
		end
		
		-- 번개 이펙트 생성 (100미터 마다)
		if currentDistance - lastLightningDistance >= LIGHTNING_SPAWN_INTERVAL then
			
			-- 갑작스러운 데이터 로딩으로 인한 거리 점프 방지용 처리
			if currentDistance - lastLightningDistance > LIGHTNING_SPAWN_INTERVAL * 5 then
				print("[DistanceController] 경고: 거리가 비정상적으로 크게 뛰었습니다. (데이터 로딩 추정) 번개 이펙트 스킵.")
				lastLightningDistance = currentDistance
			else
				print("[DistanceController] 번개 생성 조건 충족! currentDistance:", currentDistance, "lastLightningDistance:", lastLightningDistance)
				lastLightningDistance = currentDistance
				
				-- 캐릭터 HRP가 있을 때만 이펙트 발생
				local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart
				if hrp then
					spawnLightningEffect(meterLabel, hrp)
				end
			end
		end
	end
	
	-- 2. 호버보드 미탑승 시 이동 거리는 측정하지 않음
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart
	local equippedBoard = character:FindFirstChild("EquippedHoverboard")
	
	if not hrp then return end
	if not equippedBoard and not LocalPlayer:GetAttribute("OnTreadmill") then return end
	
	-- 속도를 기반으로 이동 거리 계산 (m/s 기준으로 환산, 예를들어 1스터드 = 0.28m)
	-- 게임적 허용으로 1스터드 = 1m 로 취급하거나, 속도에 비례해 거리를 올립니다.
	local speed = 0
	if LocalPlayer:GetAttribute("OnTreadmill") then
		local rbData = RebirthConfig.GetRebirthData(LocalPlayer:GetAttribute("Rebirths") or 0)
		speed = HoverboardConfig.RIDE_WALKSPEED + rbData.BoostSpeedBonus
	else
		speed = Vector3.new(hrp.AssemblyLinearVelocity.X, 0, hrp.AssemblyLinearVelocity.Z).Magnitude
	end
	
	local distanceMoved = speed * dt
	
	if distanceMoved > 0 then
		accumulatedDistance += distanceMoved
	end
	
	-- 1초마다 서버 동기화
	if os.clock() - lastSyncTime >= SYNC_INTERVAL then
		if accumulatedDistance >= 1 then
			addDistanceRemote:FireServer(accumulatedDistance)
			accumulatedDistance = 0
		end
		lastSyncTime = os.clock()
	end
end)
