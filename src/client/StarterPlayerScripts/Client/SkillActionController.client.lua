--!strict
-- SkillActionController.client.luau
-- Manages the Skill UI HUD on the right side and input triggers

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local playerGui = LocalPlayer:WaitForChild("PlayerGui")
local equippedSkillsFolder = LocalPlayer:WaitForChild("EquippedSkills")
local maxSkillSlots = LocalPlayer:WaitForChild("MaxSkillSlots")

local remotesFolder = ReplicatedStorage:WaitForChild("HoverboardRemotes")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SkillStoreConfig = require(Shared:WaitForChild("SkillStoreConfig") :: ModuleScript)
local MonetizationConfig = require(Shared:WaitForChild("MonetizationConfig") :: ModuleScript)
local SkillMessages = require(Shared:WaitForChild("SkillMessages") :: ModuleScript)

local hoverRemotes = ReplicatedStorage:WaitForChild("HoverboardRemotes")
local phaseRemote = hoverRemotes:WaitForChild("GamePhaseChanged") :: RemoteEvent
local countdownRemote = hoverRemotes:WaitForChild("StartCountdownSignal") :: RemoteEvent
local useSkillRemote = hoverRemotes:WaitForChild("UseSkill") :: RemoteEvent
local skillWarningRemote = hoverRemotes:WaitForChild("SkillWarning") :: RemoteEvent
local blindEffectRemote = hoverRemotes:WaitForChild("BlindEffect") :: RemoteEvent
local empEffectRemote = hoverRemotes:WaitForChild("EMPEffect") :: RemoteEvent
local frostEffectRemote = hoverRemotes:WaitForChild("FrostEffect") :: RemoteEvent
local empHackRemote = hoverRemotes:WaitForChild("EMPHackEffect") :: RemoteEvent
local globalSkillCastRemote = hoverRemotes:WaitForChild("GlobalSkillCast") :: RemoteEvent
local paintballEffectRemote = hoverRemotes:WaitForChild("PaintballEffect") :: RemoteEvent
local updateUsesRemote = hoverRemotes:WaitForChild("SkillUsesUpdated") :: RemoteEvent

-- Temporary Product IDs for unlocking slots
local MonetizationConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MonetizationConfig"))

-- Store config to get image/name
local SkillStoreConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SkillStoreConfig"))

local isRaceStarted = false
local clientCooldowns = {}
local clientSkillUses = {}

-- Bind UI
local gui = playerGui:WaitForChild("SkillActionGui")
gui.DisplayOrder = 30 -- 모바일 TouchGui 및 카메라 터치 영역보다 위에 위치하여 터치 입력 보장
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local slotsContainer = gui:WaitForChild("SlotsContainer")
slotsContainer.Visible = false -- 로딩 중 깜빡임 방지를 위해 일단 숨김 처리

-- 보스님이 스튜디오에서 설정하신 UI 위치와 크기(고정값)를 100% 그대로 사용합니다.
-- 더 이상 스크립트가 크기나 위치, 부모를 강제로 수정하지 않습니다.

local slots = {}
local hotkeys = { Enum.KeyCode.Q, Enum.KeyCode.E, Enum.KeyCode.R, Enum.KeyCode.T }
local hotkeyStrs = { "Q", "E", "R", "T" }

local fullScreenGui = playerGui:FindFirstChild("FullScreenEffectsGui")
if not fullScreenGui then
	fullScreenGui = Instance.new("ScreenGui")
	fullScreenGui.Name = "FullScreenEffectsGui"
	fullScreenGui.IgnoreGuiInset = true
	fullScreenGui.ResetOnSpawn = false
	fullScreenGui.DisplayOrder = 100
	fullScreenGui.Parent = playerGui
end

local glitchOverlay = fullScreenGui:FindFirstChild("EMPGlitchOverlay")
if not glitchOverlay then
	glitchOverlay = Instance.new("Frame")
	glitchOverlay.Name = "EMPGlitchOverlay"
	glitchOverlay.Size = UDim2.new(1, 0, 1, 0)
	glitchOverlay.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
	glitchOverlay.BackgroundTransparency = 1
	glitchOverlay.ZIndex = 99
	glitchOverlay.Visible = false
	glitchOverlay.Parent = fullScreenGui
end



-- [클라이언트 사이드 시각화 (KartRider 방식 표준)]
-- 투사체 스킬을 쓸 때 핑 지연 없이 내 화면에 즉시 발사되는 연출을 만듭니다.
local function spawnLocalProjectileVisual(skillId: string, overrideChar: Model?)
	local casterChar = overrideChar or LocalPlayer.Character
	local rootPart = casterChar and (casterChar.PrimaryPart or casterChar:FindFirstChild("HumanoidRootPart"))
	if not rootPart then 
		warn("❌ [Client] No RootPart found! Cannot spawn Ice Bomb visual.")
		return 
	end
	
	print("❄️ [Client] Spawning local Ice Bomb visual!")
	
	local projectile = Instance.new("Part")
	projectile.Name = "LocalProjectile_" .. skillId
	projectile.Shape = Enum.PartType.Ball
	projectile.Size = Vector3.new(8, 8, 8)
	projectile.Color = Color3.fromRGB(0, 255, 255) -- Cyan
	projectile.Material = Enum.Material.Neon -- Make it glow so it's super visible
	projectile.CanCollide = false
	projectile.Anchored = true
	
	local rootPos = rootPart.Position
	
	local flatVel = rootPart.AssemblyLinearVelocity
	flatVel = Vector3.new(flatVel.X, 0, flatVel.Z)
	
	-- 카메라가 고정이므로 카메라 방향을 쓸 수 없습니다.
	-- 코너링 시 원심력(Velocity)도 벽을 향하므로 쓸 수 없습니다.
	-- 따라서 '호버보드 기체'가 현재 바라보고 있는 시각적인 기수(앞코) 방향을 찾아 씁니다.
	-- 유저분이 첨부해주신 사진(3인칭 백뷰)을 보면 카메라가 캐릭터 뒤에 고정되어 트랙 앞을 바라보고 있습니다.
	-- 모델의 축(LookVector)이 왼쪽/오른쪽으로 틀어져 있는 문제를 피하기 위해, 
	-- 무조건 가장 정확한 '카메라가 바라보는 정면 방향(빨간 화살표)'을 사용합니다.
	local camLook = workspace.CurrentCamera.CFrame.LookVector
	local flatLook = Vector3.new(camLook.X, 0, camLook.Z)
	
	if flatLook.Magnitude < 0.001 then
		flatLook = Vector3.new(0, 0, -1)
	else
		flatLook = flatLook.Unit
	end
	
	-- 클라이언트에서 직접 생성하므로 서버 지연(Latency)을 예측할 필요가 전혀 없습니다!
	-- 오프셋을 0으로 설정하여 완벽하게 내 몸 정중앙에서부터 출발하도록 합니다.
	local startPos = rootPos + Vector3.new(0, 3, 0)
	projectile.Position = startPos
	projectile.Parent = workspace
	
	-- 발사 시 파티클 폭발 연출을 위한 임시 투명 파트 생성
	local explosionPart = Instance.new("Part")
	explosionPart.Size = Vector3.new(1, 1, 1)
	explosionPart.Position = startPos
	explosionPart.Transparency = 1
	explosionPart.Anchored = true
	explosionPart.CanCollide = false
	explosionPart.Parent = workspace
	
	local launchSound = Instance.new("Sound")
	launchSound.SoundId = "rbxassetid://138081509" -- 발사/폭발음
	launchSound.Volume = 0.8
	launchSound.Parent = explosionPart
	launchSound:Play()
	
	local launchEmit = Instance.new("ParticleEmitter")
	-- 텍스처를 생략하여 로블록스 기본 파티클을 강제 사용 (무조건 렌더링되게 보장)
	launchEmit.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 6)})
	launchEmit.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.5, 0.5),
		NumberSequenceKeypoint.new(1, 1)
	})
	launchEmit.Color = ColorSequence.new(Color3.fromRGB(150, 255, 255))
	launchEmit.LightEmission = 0.5 -- 눈부심 완화
	launchEmit.ZOffset = 1
	launchEmit.Speed = NumberRange.new(30, 60)
	launchEmit.Drag = 5
	launchEmit.Lifetime = NumberRange.new(0.5, 1.0)
	launchEmit.Rate = 0
	launchEmit.SpreadAngle = Vector2.new(180, 180) 
	launchEmit.Parent = explosionPart
	launchEmit:Emit(50) -- 개수를 50개로 대폭 줄임
	
	game:GetService("Debris"):AddItem(explosionPart, 2)
	
	
	local trail = Instance.new("Trail")
	local a0 = Instance.new("Attachment", projectile)
	a0.Position = Vector3.new(0, 2, 0)
	local a1 = Instance.new("Attachment", projectile)
	a1.Position = Vector3.new(0, -2, 0)
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.5
	trail.Color = ColorSequence.new(Color3.fromRGB(0, 255, 255))
	trail.Parent = projectile
	
	-- 서버 통신 없이 2초간 350 속도로 내 눈앞으로 쏘아보냅니다.
	local flySpeed = 350
	local duration = 2.0
	local elapsed = 0
	local maxHeight = 150 -- 곡사포처럼 위로 솟구칠 최대 높이
	
	local RunService = game:GetService("RunService")
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		elapsed += dt
		if elapsed > duration or not projectile.Parent then
			if conn then conn:Disconnect() end
			if projectile then
				-- Small pop animation
				local ts = TweenService:Create(projectile, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Size = Vector3.new(15, 15, 15),
					Transparency = 1
				})
				ts:Play()
				ts.Completed:Connect(function() projectile:Destroy() end)
			end
			return
		end
		
		-- 무조건 하늘로 치솟게 만듭니다. (앞으로는 조금만 전진하고 위로)
		local forwardOffset = flatLook * (100 * elapsed)
		local arcHeight = 100 * elapsed -- 속도를 100으로 줄임
		
		-- 최종 위치 계산
		local newPos = startPos + forwardOffset + Vector3.new(0, arcHeight, 0)
		projectile.Position = newPos
		
		-- 화면(모니터) 위쪽으로 완전히 벗어나면 즉시 삭제
		local _, onScreen = workspace.CurrentCamera:WorldToViewportPoint(newPos)
		if elapsed > 0.1 and not onScreen then
			if conn then conn:Disconnect() end
			if projectile then projectile:Destroy() end
		end
	end)
end

local function createSpritePart()
	local p = Instance.new("Part")
	p.Size = Vector3.new(0.1, 0.1, 0.1)
	p.Transparency = 1
	p.CanCollide = false
	p.Anchored = true
	
	local att = Instance.new("Attachment", p)
	local pe = Instance.new("ParticleEmitter", att)
	pe.Texture = "rbxassetid://741215414" -- 선명한 별 텍스처 복구 (안개처럼 보이지 않게 함)
	pe.Size = NumberSequence.new(0.4) -- 너무 뭉치지 않게 크기 축소
	pe.Color = ColorSequence.new(Color3.fromRGB(255, 215, 0))
	pe.Lifetime = NumberRange.new(10)
	pe.Rate = 0
	pe.Speed = NumberRange.new(0)
	pe.LockedToPart = true
	pe.LightEmission = 1
	pe.ZOffset = 1
	
	return p, pe
end

local function spawnGoldenFreezeUpVisual(casterRoot)
	print("🛠️ [DEBUG] spawnGoldenFreezeUpVisual 2-Step (Pop & Fly) started for:", casterRoot and casterRoot.Parent and casterRoot.Parent.Name)
	task.spawn(function()
		for i = 1, 150 do -- 150개로 풍성하게 유지
			if not casterRoot or not casterRoot.Parent then break end
			local p, pe = createSpritePart()
			p.Anchored = false 
			p.Parent = casterRoot
			
			local weld = Instance.new("Weld")
			weld.Part0 = casterRoot
			weld.Part1 = p
			weld.C0 = CFrame.new(0, 0, 0)
			weld.Parent = p
			pe:Emit(1)
			
			-- [1단계] 몸에서 사방으로 살짝 튀어나오는 Pop 연출 (Quad Out - 느려짐)
			local popX = math.random(-10, 10)
			local popY = math.random(0, 10)
			local popZ = math.random(-10, 10)
			local popOffset = CFrame.new(popX, popY, popZ)
			
			local popTweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			local popTween = TweenService:Create(weld, popTweenInfo, {C0 = popOffset})
			
			popTween.Completed:Connect(function()
				if not p or not p.Parent or not weld.Parent then return end
				
				-- [2단계] 캐릭터 앞쪽 허공으로 가속하며 쏘아지는 Fly 연출 (Exponential In - 가속도)
				-- 계속 Weld되어 있으므로 캐릭터가 아무리 빨리 달려도 속도를 완벽히 물려받음
				local forwardDist = math.random(80, 150)
				local upDist = math.random(60, 100)
				-- C0 기준 Z 음수가 캐릭터 앞방향
				local targetOffset = popOffset * CFrame.new(0, upDist, -forwardDist)
				
				local flyDuration = 0.5 + (math.random() * 0.3)
				local flyTweenInfo = TweenInfo.new(flyDuration, Enum.EasingStyle.Exponential, Enum.EasingDirection.In)
				local flyTween = TweenService:Create(weld, flyTweenInfo, {C0 = targetOffset})
				
				flyTween:Play()
				flyTween.Completed:Connect(function() p:Destroy() end)
			end)
			
			-- 10개 단위로 아주 미세한 시차를 두고 팝(Pop) 시킴
			task.delay((i % 10) * 0.01, function()
				if p and p.Parent then
					popTween:Play()
				end
			end)
		end
	end)
end

local function spawnGoldenFreezeDownVisual(targetRoot)
	task.spawn(function()
		local orbitParts = {}
		-- 0.7초 지연 후 하늘에서 생성 (총 1.0초 뒤 타격과 동기화)
		task.wait(0.7)
		
		for i = 1, 200 do -- 안개 파티클을 제거하고 200개의 개별 파티클로 확실하게 감싸기
			if not targetRoot or not targetRoot.Parent then break end
			local p, pe = createSpritePart()
			p.Anchored = false
			p.Parent = targetRoot
			table.insert(orbitParts, p)
			pe:Emit(1)
			
			local weld = Instance.new("Weld")
			weld.Part0 = targetRoot
			weld.Part1 = p
			
			-- 시작점: 반경 5~12 주변, 60스터드 위 하늘
			local startAngle = math.rad(math.random(0, 360))
			local startRadius = math.random(5, 12)
			weld.C0 = CFrame.new(math.cos(startAngle) * startRadius, 60, math.sin(startAngle) * startRadius)
			weld.Parent = p
			
			-- [1단계] 떨어지는 연출 (0.3초) -> 상대가 도망가도 C0 웰드 덕분에 정수리로 정확히 떨어짐
			local dropTween = TweenService:Create(weld, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				C0 = CFrame.new(math.cos(startAngle) * startRadius, math.random(-2, 4), math.sin(startAngle) * startRadius)
			})
			dropTween:Play()
			
			dropTween.Completed:Connect(function()
				if not weld or not weld.Parent then return end
				-- [2단계] 떨어지자마자 몸에서 약간 거리를 둔 반경(4~6)으로 조여드는 연출
				local bindRadius = math.random(4, 6)
				local targetY = math.random(-3, 3)
				local bindTween = TweenService:Create(weld, TweenInfo.new(0.5, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), {
					C0 = CFrame.new(math.cos(startAngle) * bindRadius, targetY, math.sin(startAngle) * bindRadius)
				})
				bindTween:Play()
				
				-- [3단계] 5초 동안 주위를 천천히 도는(Orbit) 연출
				local rotationSpeed = math.random(60, 120) -- 초당 60~120도 회전
				local dir = (math.random(1, 2) == 1) and 1 or -1
				
				task.spawn(function()
					local startTime = tick()
					local currentAngle = startAngle
					while weld and weld.Parent and tick() - startTime < 5.0 do
						local dt = task.wait()
						currentAngle = currentAngle + math.rad(rotationSpeed * dt * dir)
						weld.C0 = CFrame.new(math.cos(currentAngle) * bindRadius, targetY, math.sin(currentAngle) * bindRadius)
					end
				end)
			end)
		end
		
		-- 5초 후 꽁꽁 묶어놨던 입자들 소멸
		task.delay(5.0, function()
			for _, p in ipairs(orbitParts) do
				if p and p.Parent then
					local att = p:FindFirstChildWhichIsA("Attachment")
					if att then
						local pe = att:FindFirstChildWhichIsA("ParticleEmitter")
						if pe then pe.Enabled = false end
					end
					p:Destroy()
				end
			end
		end)
	end)
end

local activeToasts = {}
local MAX_TOASTS = 4
local TOAST_SPACING = 0.08 -- Y-scale offset per toast

local function addToastToStack(toast: TextLabel, config, offsetX: number)
	-- 기존 토스트 위로 밀어내기
	for i = #activeToasts, 1, -1 do
		local tInfo = activeToasts[i]
		if not tInfo.toast or not tInfo.toast.Parent then
			table.remove(activeToasts, i)
			continue
		end
		
		tInfo.index = tInfo.index + 1
		
		if tInfo.index >= MAX_TOASTS then
			-- 최대치 도달 시 강제 페이드아웃 및 삭제
			if tInfo.flashTween then tInfo.flashTween:Cancel() end
			TweenService:Create(tInfo.toast, TweenInfo.new(0.1), { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
			task.delay(0.1, function()
				if tInfo.toast then tInfo.toast:Destroy() end
			end)
			table.remove(activeToasts, i)
		else
			-- 위로 애니메이션
			local newY = tInfo.baseY - (tInfo.index * TOAST_SPACING)
			TweenService:Create(tInfo.toast, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Position = UDim2.new(0.5, tInfo.offsetX, newY, 0)
			}):Play()
		end
	end
	
	table.insert(activeToasts, {
		toast = toast,
		baseY = config.PosY,
		offsetX = offsetX,
		index = 0
	})
end

local function showSkillToast(skillName: string)
	local config = SkillMessages.Design.MySkillToast
	local toast = Instance.new("TextLabel")
	toast.Size = UDim2.new(0, 800, 0, 100)
	toast.Position = UDim2.new(0.5, -400, config.PosY + 0.05, 0)
	toast.BackgroundTransparency = 1
	toast.TextTransparency = 1
	toast.Font = config.Font
	toast.Text = SkillMessages:Format("MySkillActivated", {skillName = skillName})
	toast.TextColor3 = config.TextColor
	toast.TextSize = config.TextSize
	toast.Parent = fullScreenGui
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 15)
	corner.Parent = toast
	
	local stroke = Instance.new("UIStroke")
	stroke.Color = config.StrokeColor
	stroke.Thickness = config.StrokeThickness
	stroke.Transparency = 1
	stroke.Parent = toast
	
	addToastToStack(toast, config, -400)
	
	-- Animate up and fade in
	TweenService:Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { 
		Position = UDim2.new(0.5, -400, config.PosY, 0),
		TextTransparency = 0
	}):Play()
	TweenService:Create(stroke, TweenInfo.new(0.3), { Transparency = 0 }):Play()
	
	task.delay(1.5, function()
		if not toast.Parent then return end
		local t = TweenService:Create(toast, TweenInfo.new(0.5), { TextTransparency = 1, BackgroundTransparency = 1 })
		TweenService:Create(stroke, TweenInfo.new(0.5), { Transparency = 1 }):Play()
		t:Play()
		t.Completed:Connect(function()
			toast:Destroy()
		end)
	end)
end

local function showWarningToast(message: string)
	local config = SkillMessages.Design.WarningToast
	local toast = Instance.new("TextLabel")
	toast.Size = UDim2.new(0, 1000, 0, 120)
	toast.Position = UDim2.new(0.5, -500, config.PosY + 0.05, 0)
	toast.BackgroundTransparency = 1
	toast.TextTransparency = 1
	toast.Font = config.Font
	toast.Text = message
	toast.TextColor3 = config.TextColor
	toast.TextSize = config.TextSize
	toast.Parent = fullScreenGui
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 15)
	corner.Parent = toast
	
	local stroke = Instance.new("UIStroke")
	stroke.Color = config.StrokeColor
	stroke.Thickness = config.StrokeThickness
	stroke.Transparency = 1
	stroke.Parent = toast
	
	addToastToStack(toast, config, -500)
	
	-- Flashing effect on text instead of background
	local flashTween = TweenService:Create(toast, TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { TextColor3 = Color3.fromRGB(255, 255, 255) })
	flashTween:Play()
	
	-- Store flashTween in the activeToasts table so addToastToStack can cancel it
	for _, tInfo in ipairs(activeToasts) do
		if tInfo.toast == toast then
			tInfo.flashTween = flashTween
			break
		end
	end
	
	-- Animate up and fade in
	TweenService:Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { 
		Position = UDim2.new(0.5, -500, config.PosY, 0),
		TextTransparency = 0 
	}):Play()
	TweenService:Create(stroke, TweenInfo.new(0.3), { Transparency = 0 }):Play()
	
	task.delay(2.5, function()
		if not toast.Parent then return end
		flashTween:Cancel()
		local t = TweenService:Create(toast, TweenInfo.new(0.5), { TextTransparency = 1, BackgroundTransparency = 1 })
		TweenService:Create(stroke, TweenInfo.new(0.5), { Transparency = 1 }):Play()
		t:Play()
		t.Completed:Connect(function()
			toast:Destroy()
		end)
	end)
end

local fogOverlay = gui:FindFirstChild("BlindFogOverlay")
if not fogOverlay then
	fogOverlay = Instance.new("ImageLabel")
	fogOverlay.Name = "BlindFogOverlay"
	fogOverlay.Size = UDim2.new(1, 0, 1, 0)
	fogOverlay.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
	fogOverlay.BackgroundTransparency = 1
	fogOverlay.ImageTransparency = 1
	fogOverlay.ZIndex = 98
	fogOverlay.Visible = false
	fogOverlay.Parent = gui
end

local function setBlindEffect(active: boolean)
	-- 물리적인 3D 안개(Smoke)가 시야를 가려주므로, 기존의 인위적인 2D 회색 오버레이 UI는 비활성화합니다.
	-- (추후 필요시 복구를 위해 함수 구조는 유지)
end

-- For static noise, a UIGradient or ImageLabel can be used. We'll use a fast flickering frame.
local function playGlitchEffect()
	glitchOverlay.Visible = true
	
	-- Play a short loud zap sound
	local zapSound = Instance.new("Sound")
	zapSound.SoundId = "rbxassetid://138084050" -- Glitch/zap
	zapSound.Volume = 1
	zapSound.Parent = workspace
	zapSound:Play()
	game.Debris:AddItem(zapSound, 3)
	
	task.spawn(function()
		for i = 1, 15 do
			glitchOverlay.BackgroundTransparency = math.random(5, 9) / 10
			glitchOverlay.BackgroundColor3 = math.random() > 0.5 and Color3.fromRGB(0, 255, 255) or Color3.fromRGB(255, 0, 255)
			task.wait(math.random(3, 10)/100)
		end
		glitchOverlay.BackgroundTransparency = 1
		glitchOverlay.Visible = false
	end)
end

-- Function to get skill info from Config (bindSlot보다 먼저 선언되어야 함)
local function getSkillInfo(skillId: string)
	for _, skill in ipairs(SkillStoreConfig.Skills) do
		if skill.id == skillId then
			return skill
		end
	end
	return nil
end

local function bindSlot(index)
	local slotsContainer = gui:FindFirstChild("SlotsContainer")
	local slotFrame = slotsContainer and slotsContainer:FindFirstChild("Slot" .. index) :: ImageButton?
	if not slotFrame then
		warn("❌ [SkillActionController] Could not find 'Slot" .. index .. "' inside SkillActionGui. Skipping.")
		return
	end
	
	slotFrame.ZIndex = 1

	-- Dynamically create Icon if missing
	local icon = slotFrame:FindFirstChild("Icon") :: ImageLabel?
	if not icon then
		icon = Instance.new("ImageLabel")
		icon.Name = "Icon"
		icon.Size = UDim2.new(1, -12, 1, -12) -- 원형 안에 잘 들어가도록 크기를 살짝 줄임
		icon.Position = UDim2.new(0.5, 0, 0.5, 0)
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.BackgroundTransparency = 1
		icon.ZIndex = 2
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 16)
		corner.Parent = icon
		icon.Parent = slotFrame
	else
		-- 유저가 스튜디오에서 맞춘 설정을 존중 (강제 덮어쓰기 안 함)
		icon.Size = UDim2.new(1, -12, 1, -12)
		icon.Position = UDim2.new(0.5, 0, 0.5, 0)
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.ZIndex = 2
	end

	-- Find and clear any default labels left by the UI designer
	for _, child in ipairs(slotFrame:GetChildren()) do
		if child:IsA("TextLabel") and (child.Text == "Label" or child.Name == "Label" or child.Name == "TextLabel") then
			child:Destroy()
		end
	end

	-- Studio의 NameLabel 세팅을 그대로 사용, 없으면 동적 생성
	local nameLabel = slotFrame:FindFirstChild("NameLabel") :: TextLabel?
	if not nameLabel then
		nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "NameLabel"
		nameLabel.Parent = slotFrame
	end
	
	-- 기존 Label이든 새 Label이든 가이드에 맞게 무조건 덮어쓰기
	nameLabel.Size = UDim2.new(1.3, 0, 0, 30) -- 줄여서 옆 슬롯 침범 방지
	nameLabel.Position = UDim2.new(0.5, 0, 1, 0) -- 버튼 정중앙 하단
	nameLabel.AnchorPoint = Vector2.new(0.5, 0.5) -- 정확히 경계선에 걸치게 앵커 포인트 조정
	nameLabel.BackgroundTransparency = 1
	nameLabel.Visible = false -- 스킬명을 숨기고 아이콘만 보이게 함
	nameLabel.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextStrokeTransparency = 1
	nameLabel.TextWrapped = true -- 두 줄 바꿈 허용
	nameLabel.TextScaled = true -- 긴 글씨는 작아지게
	
	local sizeConstraint = nameLabel:FindFirstChildOfClass("UITextSizeConstraint") or Instance.new("UITextSizeConstraint")
	sizeConstraint.MaxTextSize = 22
	sizeConstraint.MinTextSize = 10
	sizeConstraint.Parent = nameLabel
	nameLabel.TextXAlignment = Enum.TextXAlignment.Center
	nameLabel.TextYAlignment = Enum.TextYAlignment.Center
	nameLabel.ZIndex = 4
	-- 항상 외곽선 두께 3 적용 (없으면 생성, 있으면 덮어쓰기)
	local nameLabelStroke = nameLabel:FindFirstChildOfClass("UIStroke")
	if not nameLabelStroke then
		nameLabelStroke = Instance.new("UIStroke")
		nameLabelStroke.Color = Color3.fromRGB(0, 0, 0)
		nameLabelStroke.Parent = nameLabel
	end
	nameLabelStroke.Thickness = 3
	nameLabelStroke.Color = Color3.fromRGB(0, 0, 0)
	
	local lock = slotFrame:FindFirstChild("LockIcon") :: Frame?
	if not lock then
		lock = Instance.new("Frame")
		lock.Name = "LockIcon"
		lock.Size = UDim2.new(1, 0, 1, 0)
		lock.BackgroundTransparency = 1
		lock.Visible = false
		lock.ZIndex = 6
		
		local lockImg = Instance.new("ImageLabel")
		lockImg.Name = "LockImage"
		lockImg.Size = UDim2.new(0.5, 0, 0.5, 0)
		lockImg.Position = UDim2.new(0.5, 0, 0.4, 0)
		lockImg.AnchorPoint = Vector2.new(0.5, 0.5)
		lockImg.BackgroundTransparency = 1
		lockImg.Image = "rbxassetid://17368080973"
		lockImg.ZIndex = 7
		lockImg.Parent = lock
		
		lock.Parent = slotFrame
	end
	
	local overlay = slotFrame:FindFirstChild("Overlay") :: Frame?
	if not overlay then
		overlay = Instance.new("Frame")
		overlay.Name = "Overlay"
		overlay.Parent = slotFrame
	end
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	overlay.BackgroundTransparency = 0.5
	overlay.Visible = false
	
	local oc = overlay:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	-- 스튜디오 설정 존중을 위해 기본값일 경우에만 설정
	if oc.Parent ~= overlay then
		oc.CornerRadius = UDim.new(0, 16)
		oc.Parent = overlay
	end
	
	local slotCorner = slotFrame:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	if slotCorner.Parent ~= slotFrame then
		slotCorner.CornerRadius = UDim.new(0, 16)
		slotCorner.Parent = slotFrame
	end
	
	local aspect = slotFrame:FindFirstChildOfClass("UIAspectRatioConstraint") or Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1
	aspect.Parent = slotFrame
	
	local stroke = slotFrame:FindFirstChild("UIStroke") :: UIStroke?
	if not stroke then
		stroke = Instance.new("UIStroke")
		stroke.Name = "UIStroke"
		stroke.Color = Color3.fromRGB(0, 0, 0)
		stroke.Thickness = 3
		stroke.Parent = slotFrame
	else
		stroke.Color = Color3.fromRGB(0, 0, 0)
		stroke.Thickness = 3
	end
	
	local cdLabel = slotFrame:FindFirstChild("CdLabel") :: TextLabel?
	if not cdLabel then
		cdLabel = Instance.new("TextLabel")
		cdLabel.Name = "CdLabel"
		cdLabel.Size = UDim2.new(1, 0, 1, 0)
		cdLabel.BackgroundTransparency = 1
		cdLabel.Font = Enum.Font.FredokaOne
		cdLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		cdLabel.TextSize = 42
		cdLabel.Visible = false
		cdLabel.ZIndex = 5
		
		local cdStroke = Instance.new("UIStroke")
		cdStroke.Color = Color3.fromRGB(0, 0, 0)
		cdStroke.Thickness = 4
		cdStroke.Parent = cdLabel
		
		cdLabel.Parent = slotFrame
	end
	
	local hotkeyLabel = slotFrame:FindFirstChild("HotkeyLabel") :: TextLabel?
	if hotkeyLabel then
		hotkeyLabel.Size = UDim2.new(0, 26, 0, 26)
		hotkeyLabel.Position = UDim2.new(1, -10, 0, -10)
		hotkeyLabel.ZIndex = 10
		hotkeyLabel.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Bold)
		hotkeyLabel.TextSize = 19
		hotkeyLabel.TextColor3 = Color3.fromRGB(0, 0, 0)
		local hkStroke = hotkeyLabel:FindFirstChildOfClass("UIStroke")
		if hkStroke then
			hkStroke:Destroy()
		end
		local hkCorner = hotkeyLabel:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
		hkCorner.CornerRadius = UDim.new(1, 0) -- 원형
		hkCorner.Parent = hotkeyLabel
	end
	
	
	local usesLabel = slotFrame:FindFirstChild("UsesLabel") :: TextLabel?
	if not usesLabel then
		usesLabel = Instance.new("TextLabel")
		usesLabel.Name = "UsesLabel"
		usesLabel.Size = UDim2.new(0, 30, 0, 30)
		usesLabel.Position = UDim2.new(1, -5, 0, 5)
		usesLabel.AnchorPoint = Vector2.new(1, 0)
		usesLabel.BackgroundTransparency = 1
		usesLabel.Font = Enum.Font.FredokaOne
		usesLabel.TextSize = 22
		usesLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
		usesLabel.TextStrokeTransparency = 0
		usesLabel.ZIndex = 8
		usesLabel.Visible = false
		
		local hkStroke = Instance.new("UIStroke")
		hkStroke.Color = Color3.fromRGB(0, 0, 0)
		hkStroke.Thickness = 3
		hkStroke.Parent = usesLabel
		
		usesLabel.Parent = slotFrame
	end

	slots[index] = {
		usesLabel = usesLabel,
		frame = slotFrame,
		icon = icon,
		nameLabel = nameLabel,
		lock = lock,
		overlay = overlay,
		stroke = stroke,
		cdLabel = cdLabel,
		skillId = nil
	}

	-- 터치 가로채기 방지: 버튼의 자식 요소들은 입력을 소비하지 않도록 Active = false 처리
	icon.Active = false
	nameLabel.Active = false
	if lock then lock.Active = false end
	if overlay then overlay.Active = false end
	if cdLabel then cdLabel.Active = false end
	local usesLabel = slotFrame:FindFirstChild("UsesLabel") :: TextLabel?
	if usesLabel then usesLabel.Active = false end
	local hotkeyLabel = slotFrame:FindFirstChild("HotkeyLabel") :: TextLabel?
	if hotkeyLabel then hotkeyLabel.Active = false end

	slotFrame.Active = true
	slotFrame.Selectable = true

	local function handleSlotActivation()
		if index == 3 and maxSkillSlots.Value < 3 then
			MarketplaceService:PromptProductPurchase(LocalPlayer, MonetizationConfig.SlotUnlockProducts.Slot3.id)
			return
		elseif index == 4 and maxSkillSlots.Value < 4 then
			if maxSkillSlots.Value < 3 then
				showSkillToast(SkillMessages.Messages.NeedSlot3First)
			else
				MarketplaceService:PromptProductPurchase(LocalPlayer, MonetizationConfig.SlotUnlockProducts.Slot4.id)
			end
			return
		end
		
		if not slots[index] or not slots[index].skillId then
			print(string.format("[SkillAction] Slot %d is empty or no skillId", index))
			return
		end

		local isRacing = LocalPlayer:GetAttribute("IsRacing")
		if not isRaceStarted or not isRacing then
			print(string.format("[SkillAction] Slot %d ignored - isRaceStarted=%s, IsRacing=%s", index, tostring(isRaceStarted), tostring(isRacing)))
			return
		end

		local skillId = slots[index].skillId
		local sInfo = getSkillInfo(skillId)
		if not sInfo then return end
		
		if sInfo.cooldownType == "Charges" then
			local left = clientSkillUses[skillId] or sInfo.maxUses
			if left <= 0 then return end
		end
		
		local lastUsed = clientCooldowns[skillId]
		local cooldown = sInfo.cooldownTime or 10

		if lastUsed and (os.clock() - lastUsed) < cooldown then
			print(SkillMessages.Messages.CooldownActive)
			return
		end
		
		clientCooldowns[skillId] = os.clock()
		
		local sName = sInfo and sInfo.name or skillId
		print("🔥 스킬 사용: " .. sName)
		showSkillToast(sName)
		
		if skillId == "Skill_IceBomb" then
			spawnLocalProjectileVisual(skillId)
		end
		
		useSkillRemote:FireServer(skillId)
		
		-- Cooldown UI logic (버그 수정: slotFrame.overlay 대신 slots[index].overlay 사용)
		local currentOverlay = slots[index].overlay
		local currentCdLabel = slots[index].cdLabel
		if currentOverlay then currentOverlay.Visible = true end
		if currentCdLabel then currentCdLabel.Visible = true end

		local conn
		conn = game:GetService("RunService").RenderStepped:Connect(function()
			local elapsed = os.clock() - clientCooldowns[skillId]
			if elapsed >= cooldown then
				if currentOverlay then currentOverlay.Visible = false end
				if currentCdLabel then currentCdLabel.Visible = false end
				conn:Disconnect()
			else
				if currentCdLabel then
					currentCdLabel.Text = tostring(math.ceil(cooldown - elapsed))
				end
			end
		end)
	end

	-- 모바일 터치 및 마우스 클릭 완벽 대응 (Activated 사용)
	slotFrame.Activated:Connect(handleSlotActivation)
	slotFrame.MouseButton1Click:Connect(handleSlotActivation)
end

for i = 1, 4 do
	bindSlot(i)
end

local function refreshSlots()
	local equipped = equippedSkillsFolder:GetChildren()
	local currentMax = maxSkillSlots.Value
	print("🛠️ [SkillActionController] refreshSlots called. Equipped count:", #equipped, "CurrentMax:", currentMax)
	
	for i = 1, 4 do
		local slot = slots[i]
		if not slot then 
			print("🛠️ [SkillActionController] Slot", i, "not found in slots table")
			continue 
		end
		
		-- Manage Lock status for Slot 3 and 4
		if i > currentMax then
			slot.lock.Visible = true
			slot.icon.Image = ""
			slot.nameLabel.Text = ""
			slot.skillId = nil
			slot.stroke.Color = Color3.fromRGB(0, 0, 0)
			slot.overlay.Visible = true
			
			if i == 3 then
				slot.overlay.BackgroundTransparency = 0.5
			elseif i == 4 then
				if currentMax < 3 then
					slot.overlay.BackgroundTransparency = 0.8
				else
					slot.overlay.BackgroundTransparency = 0.5
				end
			end
			
			-- 이모지 대신 유저가 요청한 실제 이미지 에셋(17368080973)으로 교체
			for _, desc in ipairs(slot.frame:GetDescendants()) do
				if desc:IsA("TextLabel") and (string.find(desc.Text, "R%$") or string.find(desc.Text, "50") or string.find(desc.Text, "100") or string.find(desc.Text, "🔒")) then
					desc.Text = ""
					
					if not desc.Parent:FindFirstChild("ScriptCreatedLockIcon") then
						local img = Instance.new("ImageLabel")
						img.Name = "ScriptCreatedLockIcon"
						img.Size = UDim2.new(0.8, 0, 0.8, 0)
						img.Position = UDim2.new(0.5, 0, 0.5, 0)
						img.AnchorPoint = Vector2.new(0.5, 0.5)
						img.BackgroundTransparency = 1
						img.Image = "rbxassetid://17368080973"
						img.ZIndex = 10
						img.Parent = desc.Parent
					end
				end
			end
		else
			slot.lock.Visible = false
			
			for _, desc in ipairs(slot.frame:GetDescendants()) do
				if desc.Name == "ScriptCreatedLockIcon" then
					desc:Destroy()
				end
			end
			
			local skillVal = equipped[i]
			if skillVal then
				print("🛠️ [SkillActionController] Slot", i, "Equipped:", skillVal.Name)
				slot.skillId = skillVal.Name
				
				local info = getSkillInfo(skillVal.Name)
				if info then
					print("🛠️ [SkillActionController] Slot", i, "Found Info:", info.name)
					slot.icon.Image = info.imageId
					slot.nameLabel.Text = info.name
					slot.stroke.Color = Color3.fromRGB(0, 0, 0)
					if info.cooldownType == "Charges" then
						slot.usesLabel.Visible = true
						local left = clientSkillUses[info.id] or info.maxUses
						slot.usesLabel.Text = tostring(left)
						if left <= 0 then
							slot.overlay.Visible = true
						else
							slot.overlay.Visible = false
						end
					else
						slot.usesLabel.Visible = false
						slot.overlay.Visible = false
					end
				else
					print("⚠️ [SkillActionController] Slot", i, "Missing Info for:", skillVal.Name)
					slot.skillId = nil
					slot.icon.Image = ""
					slot.nameLabel.Text = ""
					slot.stroke.Color = Color3.fromRGB(0, 0, 0)
					slot.usesLabel.Visible = false
					slot.overlay.Visible = false
				end
			else
				print("🛠️ [SkillActionController] Slot", i, "is Empty in EquippedSkillsFolder")
				slot.skillId = nil
				slot.icon.Image = ""
				slot.nameLabel.Text = ""
				slot.stroke.Color = Color3.fromRGB(0, 0, 0)
				slot.usesLabel.Visible = false
				slot.overlay.Visible = false
			end
		end
	end
end

-- Listen for equipped skills changes
equippedSkillsFolder.ChildAdded:Connect(refreshSlots)
equippedSkillsFolder.ChildRemoved:Connect(refreshSlots)
maxSkillSlots.Changed:Connect(refreshSlots)

-- Initial UI Setup
refreshSlots()

-- Listen for Game Phase
phaseRemote.OnClientEvent:Connect(function(phase, timeLeft)
	if phase ~= "RACE_MATCH" then
		isRaceStarted = false
		clientSkillUses = {}
		refreshSlots()
		
		-- Force clear EMP effects
		_G.isEMPHacked = false
		if glitchOverlay then
			glitchOverlay.Visible = false
		end
		if fullScreenGui then
			for _, child in ipairs(fullScreenGui:GetChildren()) do
				if child.Name == "EMPHackText" then
					child:Destroy()
				end
			end
		end
	end
end)

countdownRemote.OnClientEvent:Connect(function(count)
	if count == 0 then
		isRaceStarted = true
		clientSkillUses = {}
		refreshSlots()
	end
end)

skillWarningRemote.OnClientEvent:Connect(function(targetName: string, casterName: string, skillId: string)
	print("[DEBUG-SkillWarning] Received for target:", targetName, "from:", casterName, "skillId:", skillId)
	local isMe = (targetName == LocalPlayer.Name)
	local isSpectatingThem = false
	if LocalPlayer:GetAttribute("IsSpectating") then
		local Camera = workspace.CurrentCamera
		local subject = Camera.CameraSubject
		if subject and subject.Parent and subject.Parent.Name == targetName then
			isSpectatingThem = true
		end
		print("[DEBUG-SkillWarning] I am spectating target:", subject and subject.Parent and subject.Parent.Name, "Result:", isSpectatingThem)
	end
	
	-- 🌐 글로벌 시각적 효과: 모든 유저가 타겟이 맞는 것을 봐야 합니다!
	if skillId == "Skill_Premium" then
		local targetPlayer = Players:FindFirstChild(targetName)
		if targetPlayer and targetPlayer.Character and targetPlayer.Character.PrimaryPart then
			-- spawnGoldenFreezeDownVisual 내부에서 0.7초 대기하므로 즉시 호출합니다.
			spawnGoldenFreezeDownVisual(targetPlayer.Character.PrimaryPart)
		end
	end

	if not isMe and not isSpectatingThem then 
		print("[DEBUG-SkillWarning] Ignored UI for non-target.")
		return 
	end

	print("[DEBUG-SkillWarning] SkillActionController - Passed checks, processing skillId:", skillId)
	if skillId == "Skill_Shield_Break" then
		if casterName == "SYSTEM" then
			showWarningToast(SkillMessages.Messages.ShieldBroken)
			
			-- 화면 피격 피드백 (빨간 번쩍임)
			local cc = Instance.new("ColorCorrectionEffect")
			cc.TintColor = Color3.fromRGB(255, 150, 150)
			cc.Parent = game:GetService("Lighting")
			local tween = TweenService:Create(cc, TweenInfo.new(0.4), {TintColor = Color3.fromRGB(255, 255, 255)})
			tween:Play()
			tween.Completed:Connect(function() cc:Destroy() end)
		else
			showWarningToast(SkillMessages:Format("ShieldDisabledEnemy", {casterName = casterName}))
		end
		return
	end
	
	if skillId == "Skill_Reflected" then
		showWarningToast(SkillMessages:Format("SkillReflected", {casterName = casterName}))
		
		-- 화면 피격 피드백 (빨간 번쩍임)
		local cc = Instance.new("ColorCorrectionEffect")
		cc.TintColor = Color3.fromRGB(255, 150, 150)
		cc.Parent = game:GetService("Lighting")
		local tween = TweenService:Create(cc, TweenInfo.new(0.4), {TintColor = Color3.fromRGB(255, 255, 255)})
		tween:Play()
		tween.Completed:Connect(function() cc:Destroy() end)
		return
	end
	
	local sInfo = getSkillInfo(skillId)
	local sName = sInfo and sInfo.name or skillId
	showWarningToast(SkillMessages:Format("EnemyUsedSkillOnYou", {casterName = casterName, skillName = sName}))
end)

blindEffectRemote.OnClientEvent:Connect(function(active: boolean)
	setBlindEffect(active)
end)

empEffectRemote.OnClientEvent:Connect(function(casterName: string)
	print("[DEBUG-EMP] empEffectRemote received! casterName:", casterName)
	local isMe = (LocalPlayer.Name == casterName)
	local isSpectatingThem = false
	if LocalPlayer:GetAttribute("IsSpectating") then
		local Camera = workspace.CurrentCamera
		local subject = Camera.CameraSubject
		if subject and subject.Parent and subject.Parent.Name == casterName then
			isSpectatingThem = true
		end
		print("[DEBUG-EMP] I am spectating subject:", subject and subject.Parent and subject.Parent.Name, "Result:", isSpectatingThem)
	end

	if isMe or isSpectatingThem then
		print("[DEBUG-EMP] Condition met! Showing EMPReady toast to screen.")
		showWarningToast(SkillMessages.Messages.EMPReady)
		local zapSound = Instance.new("Sound")
		zapSound.SoundId = "rbxassetid://138084050" -- Glitch/zap
		zapSound.Volume = 0.5
		zapSound.Parent = workspace
		zapSound:Play()
		game.Debris:AddItem(zapSound, 3)
	else
		-- Note: Hacked players now receive a separate EMPHackEffect remote.
		-- We can optionally show a toast to everyone else, or just do nothing.
		-- showWarningToast(SkillMessages:Format("EnemyUsedEMP", {casterName = casterName}))
	end
end)

-- Key inputs
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if not isRaceStarted or not LocalPlayer:GetAttribute("IsRacing") then
		-- print("🚫 대기실/AFK 상태에서는 스킬을 사용할 수 없습니다!")
		return
	end
	for i, key in ipairs(hotkeys) do
		if input.KeyCode == key then
			if slots[i] and slots[i].skillId and maxSkillSlots.Value >= i then
				local skillId = slots[i].skillId
				
			local sInfo = getSkillInfo(skillId)
			if not sInfo then continue end
			
			if sInfo.cooldownType == "Charges" then
				local left = clientSkillUses[skillId] or sInfo.maxUses
				if left <= 0 then continue end
			end
			
			local lastUsed = clientCooldowns[skillId]
			local cooldown = sInfo.cooldownTime or 10

				if lastUsed and (os.clock() - lastUsed) < cooldown then
					print(SkillMessages.Messages.CooldownActive)
					continue
				end
				
				clientCooldowns[skillId] = os.clock()
				
				local sInfo = getSkillInfo(skillId)
				local sName = sInfo and sInfo.name or skillId
				print("🔥 단축키로 스킬 사용: " .. sName)
				showSkillToast(sName)
				
				if skillId == "Skill_IceBomb" then
					spawnLocalProjectileVisual(skillId)
				end
				
				useSkillRemote:FireServer(skillId)
				
				-- Cooldown UI logic
				slots[i].overlay.Visible = true
				slots[i].cdLabel.Visible = true
				local conn
				conn = game:GetService("RunService").RenderStepped:Connect(function()
					if not clientCooldowns[skillId] then conn:Disconnect(); return end
					local elapsed = os.clock() - clientCooldowns[skillId]
					if elapsed >= cooldown then
						slots[i].overlay.Visible = false
						slots[i].cdLabel.Visible = false
						conn:Disconnect()
					else
						slots[i].cdLabel.Text = tostring(math.ceil(cooldown - elapsed))
					end
				end)
			end
		end
		task.wait(0.2)
	end
end)

-- Initial refresh
refreshSlots()

LocalPlayer:GetAttributeChangedSignal("IsSpectating"):Connect(function()
	if LocalPlayer:GetAttribute("IsSpectating") == true then
		gui.Enabled = false
	else
		gui.Enabled = true
		-- 관전 종료 시 효과 초기화
		_G.isEMPHacked = false
		if glitchOverlay then glitchOverlay.Visible = false end
		if fullScreenGui then
			for _, child in ipairs(fullScreenGui:GetChildren()) do
				if child.Name == "EMPHackText" then child:Destroy() end
			end
		end
	end
end)

-- EMP 해킹 효과 수신
_G.isEMPHacked = false
local currentEMPHackId = 0
empHackRemote.OnClientEvent:Connect(function()
	_G.isEMPHacked = true
	currentEMPHackId = currentEMPHackId + 1
	local thisHackId = currentEMPHackId
	
	-- 해킹 알림 UI 및 파티클 이펙트
	local config = SkillMessages.Design.EMPHackToast
	local hackText = Instance.new("TextLabel")
	hackText.Name = "EMPHackText"
	hackText.Text = SkillMessages.Messages.EMPHackText
	hackText.Size = UDim2.new(1, 0, 0.2, 0)
	hackText.Position = UDim2.new(0, 0, config.PosY, 0)
	hackText.BackgroundTransparency = 1
	hackText.TextColor3 = config.TextColor
	hackText.TextStrokeTransparency = 0
	hackText.TextScaled = true
	hackText.Font = config.Font
	
	-- 기존 hackText 삭제 방지 (gui 안에 여러 개 쌓이는 것 방지)
	for _, child in ipairs(fullScreenGui:GetChildren()) do
		if child.Name == "EMPHackText" then
			child:Destroy()
		end
	end
	
	hackText.Parent = fullScreenGui
	
	-- 카메라 스파크 이펙트 (간단 구현)
	if glitchOverlay then
		glitchOverlay.Visible = true
		task.spawn(function()
			for i = 1, 20 do
				if currentEMPHackId ~= thisHackId then break end -- 새로운 EMP가 오면 중단
				glitchOverlay.BackgroundTransparency = math.random() * 0.5 + 0.5
				task.wait(0.2)
			end
			if currentEMPHackId == thisHackId then
				glitchOverlay.Visible = false
			end
		end)
	end
	
	task.delay(4, function()
		if currentEMPHackId == thisHackId then
			_G.isEMPHacked = false
			if hackText and hackText.Parent then
				hackText:Destroy()
			end
		end
	end)
end)

-- 📡 Global Skill Cast Listener (For Spectators & Global Visuals)
globalSkillCastRemote.OnClientEvent:Connect(function(casterUserId: number, skillId: string)
	-- 시전자 시각적 효과 (전체 클라이언트 재생)
	if skillId == "Skill_Premium" then
		local casterPlayer = nil
		for _, p in ipairs(Players:GetPlayers()) do
			if p.UserId == casterUserId then casterPlayer = p break end
		end
		
		if casterPlayer and casterPlayer.Character and casterPlayer.Character.PrimaryPart then
			spawnGoldenFreezeUpVisual(casterPlayer.Character.PrimaryPart)
		end
	end

	if LocalPlayer:GetAttribute("IsSpectating") == true then
		local Camera = workspace.CurrentCamera
		local subject = Camera.CameraSubject
		local targetChar = nil
		if subject and subject:IsA("Humanoid") and subject.Parent then
			targetChar = subject.Parent
		end
		
		if targetChar then
			local targetPlayer = Players:GetPlayerFromCharacter(targetChar)
			if targetPlayer and targetPlayer.UserId == casterUserId then
				local sInfo = getSkillInfo(skillId)
				local sName = sInfo and sInfo.name or skillId
				showSkillToast(sName)
				if skillId == "Skill_IceBomb" then
					spawnLocalProjectileVisual(skillId, targetChar)
				end
			end
		end
	end
end)

-- 📡 Spectator Status Effect Sync Loop
game:GetService("RunService").Heartbeat:Connect(function()
	if LocalPlayer:GetAttribute("IsSpectating") ~= true then
		return
	end
	
	local Camera = workspace.CurrentCamera
	local subject = Camera.CameraSubject
	local targetChar = nil
	if subject and subject:IsA("Humanoid") and subject.Parent then
		targetChar = subject.Parent
	end
	
	if not targetChar then return end
	
	-- EMP SYNC
	local isEmped = targetChar:GetAttribute("StatusEffect_EMP")
	if isEmped and not _G.isEMPHacked then
		-- Trigger EMP visual for spectator
		_G.isEMPHacked = true
		
		local config = SkillMessages.Design.EMPHackToast
		local hackText = Instance.new("TextLabel")
		hackText.Name = "EMPHackText"
		hackText.Text = SkillMessages.Messages.EMPHackText
		hackText.Size = UDim2.new(1, 0, 0.2, 0)
		hackText.Position = UDim2.new(0, 0, config.PosY, 0)
		hackText.BackgroundTransparency = 1
		hackText.TextColor3 = config.TextColor
		hackText.TextStrokeTransparency = 0
		hackText.TextScaled = true
		hackText.Font = config.Font
		
		for _, child in ipairs(fullScreenGui:GetChildren()) do
			if child.Name == "EMPHackText" then child:Destroy() end
		end
		hackText.Parent = fullScreenGui
		
		if glitchOverlay then
			glitchOverlay.Visible = true
			task.spawn(function()
				while _G.isEMPHacked do
					glitchOverlay.BackgroundTransparency = math.random() * 0.5 + 0.5
					task.wait(0.2)
				end
				glitchOverlay.Visible = false
			end)
		end
	elseif not isEmped and _G.isEMPHacked then
		-- Turn off EMP visual
		_G.isEMPHacked = false
		for _, child in ipairs(fullScreenGui:GetChildren()) do
			if child.Name == "EMPHackText" then child:Destroy() end
		end
		if glitchOverlay then glitchOverlay.Visible = false end
	end
end)



updateUsesRemote.OnClientEvent:Connect(function(skillId, left)
	clientSkillUses[skillId] = left
	refreshSlots()
end)

local paintOverlay
local cachedSplatSource = nil

paintballEffectRemote.OnClientEvent:Connect(function()
	-- 1. Splat 에셋 찾기 (경로 하드코딩 - 가장 빠르고 권장되는 방식)
	-- 주의: Splat 원본 에셋은 반드시 ReplicatedStorage 바로 아래에 위치해야 합니다.
	if not cachedSplatSource or not cachedSplatSource.Parent then
		cachedSplatSource = game.ReplicatedStorage:FindFirstChild("Splat")
	end
	
	local splatSource = cachedSplatSource
	
	if splatSource then
		-- 2. Splat 복제 후 화면에 띄우기
		local splatClone = splatSource:Clone()
		
		if splatClone:IsA("ScreenGui") then
			-- ScreenGui 전체라면 PlayerGui에 직접 넣기
			local playerGui = game.Players.LocalPlayer:FindFirstChild("PlayerGui")
			if playerGui then
				splatClone.Parent = playerGui
			end
		elseif splatClone:IsA("GuiObject") then
			-- ImageLabel, Frame 등 GUI 컴포넌트라면 기존 fullScreenGui 안에 넣기
			splatClone.Parent = fullScreenGui
		else
			-- 파트나 모델(3D 이펙트)라면 카메라 바로 앞에 매 프레임마다 고정시키기
			splatClone.Parent = workspace.CurrentCamera
			
			local originalSize
			if splatClone:IsA("BasePart") then
				splatClone.Anchored = true
				splatClone.CanCollide = false
				splatClone.Transparency = 0 -- 초기 투명도 설정
				originalSize = splatClone.Size
				splatClone.Size = originalSize * 0.01 -- 아주 작게 시작
			elseif splatClone:IsA("Model") then
				splatClone:ScaleTo(splatClone:GetScale() * 0.01) 
			end

			local runService = game:GetService("RunService")
			local tweenService = game:GetService("TweenService")
			
			-- 1. 화면에 붙은 채로 크기가 확 커지는 스케일 애니메이션
			local scaleValue = Instance.new("NumberValue")
			scaleValue.Value = 0.01 -- 1% 크기에서 시작
			
			-- 바운스 효과 제거, 빠르고 부드럽게 커지게 (Linear 또는 Quad 적용)
			local popTween = tweenService:Create(scaleValue, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Value = 0.6})
			popTween:Play()

			-- 고속 이동 시 카메라 프레임 지연(Lag)으로 파트가 뒤에 남는 현상 방지:
			-- 모든 게임의 카메라 연산이 끝난 맨 마지막(Last.Value + 1)에 무조건 강제 고정!
			local renderId = "SplatEffect_" .. tostring(math.random(100000, 999999))
			print("[DEBUG-Splat] 시작! Splat 생성 및 렌더 우선순위(Last+1) 바인딩 완료. ID: ", renderId)
			local lastPrintTick = 0
			
			runService:BindToRenderStep(renderId, Enum.RenderPriority.Last.Value + 1, function()
				if splatClone and splatClone.Parent then
					local camCFrame = workspace.CurrentCamera.CFrame
					
					-- 거리는 항상 -3 스터드로 화면 바로 앞에 고정
					local targetCFrame = camCFrame * CFrame.new(0, 0, -3) * CFrame.Angles(math.rad(90), 0, 0)
					
					if splatClone:IsA("Model") then
						splatClone:PivotTo(targetCFrame)
					elseif splatClone:IsA("BasePart") then
						splatClone.CFrame = targetCFrame
						-- FOV 변경에 따라 시각적인 크기 보정 (FOV가 넓어지면 작아보이는 것을 방지)
						local currentFOV = workspace.CurrentCamera.FieldOfView
						local fovScale = math.tan(math.rad(currentFOV / 2)) / math.tan(math.rad(70 / 2))
						
						-- 실시간으로 바뀌는 scaleValue 값과 fovScale 값을 결합하여 Size에 적용
						splatClone.Size = originalSize * (scaleValue.Value * fovScale)
					end
					
					-- 0.2초마다 상태 추적 로그 출력
					if tick() - lastPrintTick > 0.2 then
						lastPrintTick = tick()
						local dist = (camCFrame.Position - splatClone:GetPivot().Position).Magnitude
						print(string.format("[DEBUG-Splat] 유지중! 속도 체크: 카메라와거리=%.2f, 크기배율=%.2f, 투명도=%.2f, 현재부모=%s", 
							dist, scaleValue.Value, splatClone:IsA("BasePart") and splatClone.Transparency or 0, tostring(splatClone.Parent)))
					end
				else
					print("[DEBUG-Splat] 객체가 삭제되어 RenderStep 바인딩 해제함. ID: ", renderId)
					runService:UnbindFromRenderStep(renderId)
				end
			end)
			
			-- 파티클이 있다면 촥! 뿜어주기
			for _, child in ipairs(splatClone:GetDescendants()) do
				if child:IsA("ParticleEmitter") then
					-- [중요] 플레이어가 초고속으로 이동할 때 파티클이 공중에 남겨져서 뒤로 밀리는 현상(안 보이는 현상) 방지
					child.LockedToPart = true 
					child:Emit(30)
				end
			end
			
			-- 2. 서서히 투명해지며 사라지는 애니메이션 (2초 유지 후 1초간 페이드아웃)
			task.delay(2, function()
				if splatClone and splatClone:IsA("BasePart") then
					local fadeTween = tweenService:Create(splatClone, TweenInfo.new(1, Enum.EasingStyle.Linear), {Transparency = 1})
					fadeTween:Play()
				end
			end)
		end
		
		-- 3. 3초 뒤에 깔끔하게 객체들 완전히 삭제
		task.delay(3.1, function()
			if splatClone then splatClone:Destroy() end
		end)
	else
		-- 만약 Splat을 못 찾았을 때를 대비한 기본 잉크 자국 (예비용)
		if not paintOverlay then
			paintOverlay = Instance.new("ImageLabel")
			paintOverlay.Size = UDim2.new(0.5, 0, 0.5, 0)
			paintOverlay.Position = UDim2.new(0.5, 0, 0.5, 0)
			paintOverlay.AnchorPoint = Vector2.new(0.5, 0.5)
			paintOverlay.BackgroundTransparency = 1
			paintOverlay.Image = "rbxthumb://type=Asset&id=82078297468898&w=420&h=420"
			paintOverlay.ZIndex = 100
			paintOverlay.Parent = fullScreenGui
		end
		paintOverlay.Visible = true
		local ts = TweenService:Create(paintOverlay, TweenInfo.new(3), {ImageTransparency = 1})
		paintOverlay.ImageTransparency = 0
		ts:Play()
		ts.Completed:Connect(function() paintOverlay.Visible = false end)
	end
end)

-- ----------------------------------------------------
-- 📱 RESPONSIVE UI TOGGLE (No Dynamic Positioning)
-- ----------------------------------------------------
-- 유저분께서 스튜디오에서 직접(하드코딩) 배치하신 UI를 그대로 사용합니다.
-- 이 스크립트는 PC/모바일 환경에 맞춰 단축키 라벨과 부스터 버튼의 가시성(Visible)만 제어합니다.

local updateUIVisibility -- 사전 선언

local mobileBoosterEvent = remotesFolder:FindFirstChild("MobileBoosterEvent")
if not mobileBoosterEvent then
	mobileBoosterEvent = Instance.new("BindableEvent")
	mobileBoosterEvent.Name = "MobileBoosterEvent"
	mobileBoosterEvent.Parent = remotesFolder
end

local isMobileView = UserInputService.TouchEnabled

local isMobileView = UserInputService.TouchEnabled

-- 호버보드 탑승 상태를 공유받기 위해 StateChanged 리모트 이벤트 연결
local stateRemote = remotesFolder:WaitForChild("StateChanged")
local isMounted = false

stateRemote.OnClientEvent:Connect(function(mounted)
	isMounted = mounted
	if updateUIVisibility then
		updateUIVisibility()
	end
end)

-- 커스텀 부스터 버튼은 이제 완전히 삭제했습니다! 로블록스 기본 점프 버튼만 사용합니다.
local boosterBtn = gui:FindFirstChild("MobileBoosterBtn") or (gui:FindFirstChild("SlotsContainer") and gui.SlotsContainer:FindFirstChild("MobileBoosterBtn"))
if boosterBtn then
	boosterBtn:Destroy() -- 기존에 남아있던 흔적조차 삭제
end

-- 이전에 정의된 updateUIVisibility를 위에서 호출하기 위해 forward declaration이 없었으므로 전역 또는 로컬 할당 방식을 사용
local function applyMobileLayout()
	local slotsContainer = gui:FindFirstChild("SlotsContainer")
	if slotsContainer then slotsContainer.Visible = false end
	
	-- 실제 위치 이동은 아래의 폴링 루프(점프 버튼 좌표 추적)에서 담당합니다.
	for i = 1, 4 do
		if slots[i] and slots[i].frame then
			local frame = slots[i].frame
			
			-- 백업
			if not frame:GetAttribute("OrigSizeScaleX") then
				frame:SetAttribute("OrigSizeScaleX", frame.Size.X.Scale)
				frame:SetAttribute("OrigSizeOffsetX", frame.Size.X.Offset)
				frame:SetAttribute("OrigSizeScaleY", frame.Size.Y.Scale)
				frame:SetAttribute("OrigSizeOffsetY", frame.Size.Y.Offset)
			end
			
			for _, desc in ipairs(frame:GetDescendants()) do
				if desc:IsA("UICorner") then
					if not desc:GetAttribute("OriginalCorner") then
						desc:SetAttribute("OriginalCorner", desc.CornerRadius)
					end
					desc.CornerRadius = UDim.new(0.5, 0)
				end
			end
			
			local hotkeyLabel = frame:FindFirstChild("HotkeyLabel")
			if hotkeyLabel then hotkeyLabel.Visible = false end
			
			-- 안전하게 메인 gui에 둡니다 (점프버튼 내부에 넣으면 캐릭터 리셋 시 같이 파괴됨)
			frame.Parent = gui
			frame.AnchorPoint = Vector2.new(0.5, 0.5)
			frame.Size = UDim2.new(0, 40, 0, 40)
			frame.ZIndex = 1
			frame.Active = true
			
			-- 점프 버튼을 찾기 전까지 화면 좌측 상단(0,0)에서 깜빡이는 현상 방지를 위해 화면 밖으로 치워둠
			frame.Position = UDim2.new(2, 0, 2, 0)
		end
	end
	return true
end

local function applyPCLayout()
	local slotsContainer = gui:FindFirstChild("SlotsContainer")
	if slotsContainer then slotsContainer.Visible = true end
	
	for i = 1, 4 do
		if slots[i] and slots[i].frame then
			local frame = slots[i].frame
			
			for _, desc in ipairs(frame:GetDescendants()) do
				if desc:IsA("UICorner") and desc:GetAttribute("OriginalCorner") then
					desc.CornerRadius = desc:GetAttribute("OriginalCorner")
				end
			end
			
			if frame:GetAttribute("OrigSizeScaleX") then
				frame.Size = UDim2.new(
					frame:GetAttribute("OrigSizeScaleX"),
					frame:GetAttribute("OrigSizeOffsetX"),
					frame:GetAttribute("OrigSizeScaleY"),
					frame:GetAttribute("OrigSizeOffsetY")
				)
			end
			
			local hotkeyLabel = frame:FindFirstChild("HotkeyLabel")
			if hotkeyLabel then hotkeyLabel.Visible = true end
			
			if slotsContainer then
				frame.Parent = slotsContainer
				frame.AnchorPoint = Vector2.new(0, 0) 
			end
		end
	end
end

updateUIVisibility = function()
	if isMobileView then
		applyMobileLayout()
	else
		applyPCLayout()
	end
end

local function getMobileJumpButton(shouldDebug)
	local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
	if not playerGui then if shouldDebug then warn("[MobileDebug] No PlayerGui") end return nil end
	local touchGui = playerGui:FindFirstChild("TouchGui")
	if not touchGui then if shouldDebug then warn("[MobileDebug] No TouchGui") end return nil end
	local controlFrame = touchGui:FindFirstChild("TouchControlFrame")
	if not controlFrame then if shouldDebug then warn("[MobileDebug] No TouchControlFrame") end return nil end
	local jumpBtn = controlFrame:FindFirstChild("JumpButton")
	if not jumpBtn then if shouldDebug then warn("[MobileDebug] No JumpButton") end return nil end
	return jumpBtn
end

-- 점프버튼 좌표 동적 추적 시스템 (기종별 해상도/비율 완벽 대응)
task.spawn(function()
	local angles = {160, 205, 250, 295}
	local debugTimer = 0
	while true do
		debugTimer = debugTimer + 0.2
		local shouldDebug = false
		if debugTimer >= 2.0 then
			shouldDebug = true
			debugTimer = 0
		end
		
		if isMobileView then
			local jumpBtn = getMobileJumpButton(shouldDebug)
			if jumpBtn then
				local absPos = jumpBtn.AbsolutePosition
				local absSize = jumpBtn.AbsoluteSize
				
				if shouldDebug then
					warn("[MobileDebug] JumpBtn Found! AbsPos:", absPos, "AbsSize:", absSize)
				end
				
				-- 로딩 중이거나 가려져서 절대좌표가 0,0인 쓰레기값 상태는 무시
				if absPos.X > 10 and absPos.Y > 10 then
					-- 1. 화면 최좌측 상단(0,0)을 기준으로 한 점프버튼의 물리적 정중앙
					local centerX = absPos.X + (absSize.X / 2)
					local centerY = absPos.Y + (absSize.Y / 2)
					
					local screenX = gui.AbsoluteSize.X
					local screenY = gui.AbsoluteSize.Y
					
					if shouldDebug then
						warn("[MobileDebug] ScreenSize:", screenX, screenY, "Center:", centerX, centerY)
					end
					
					if screenX > 0 and screenY > 0 then
						-- 2. 절대 픽셀 좌표를 상대적인 Scale 비율로 변환! (아이패드 UIScale 버그 원천 차단)
						local scaleX = centerX / screenX
						local scaleY = centerY / screenY
						
						-- 3. 현재 화면에 적용된 UIScale을 찾아서, 오프셋(반지름)이 왜곡되지 않도록 보정
						local uiScale = 1
						local scaleObj = gui:FindFirstChildOfClass("UIScale")
						if scaleObj then uiScale = scaleObj.Scale end
						
						if shouldDebug then
							warn("[MobileDebug] ScaleX:", scaleX, "ScaleY:", scaleY, "UIScale:", uiScale)
						end
						
						-- 핵심: 디바이스마다 달라지는 점프버튼의 '실제 크기(absSize.X)'를 기준으로 비율 계산
						local jumpBtnSize = absSize.X
						-- 반경은 점프버튼 크기의 95%
						local dynamicRadius = jumpBtnSize * 0.95
						-- 스킬 버튼 크기는 점프버튼 크기의 55%
						local dynamicSkillSize = jumpBtnSize * 0.55
						
						for i = 1, 4 do
							if slots[i] and slots[i].frame then
								local frame = slots[i].frame
								local angleRad = math.rad(angles[i])
								
								-- UIScale 역산 및 동적 반경 적용
								local dx = (math.cos(angleRad) * dynamicRadius) / uiScale
								local dy = (math.sin(angleRad) * dynamicRadius) / uiScale
								
								-- 부모가 바뀌었거나 크기가 안 맞으면 실시간 복구
								if frame.Parent ~= gui then
									frame.Parent = gui
									frame.AnchorPoint = Vector2.new(0.5, 0.5)
								end
								frame.ZIndex = 1
								frame.Active = true
								
								-- 점프버튼 크기에 비례하여 동적으로 버튼 크기 변경
								frame.Size = UDim2.new(0, dynamicSkillSize / uiScale, 0, dynamicSkillSize / uiScale)
								
								-- 완벽한 호환성을 자랑하는 Scale + 보정 Offset 방식
								frame.Position = UDim2.new(
									scaleX, dx,
									scaleY, dy
								)
								
								if shouldDebug and i == 1 then
									warn("[MobileDebug] Slot 1 Final Pos:", frame.Position, "Size:", frame.Size, "Visible:", frame.Visible)
								end
							end
						end
					end
				end
			end
		end
		task.wait(0.2)
	end
end)

UserInputService.LastInputTypeChanged:Connect(function(lastInputType)
	local wasMobile = isMobileView
	if lastInputType == Enum.UserInputType.Touch then
		isMobileView = true
	elseif lastInputType == Enum.UserInputType.Keyboard or lastInputType == Enum.UserInputType.MouseMovement then
		-- 캡처 스크린샷 튕김 방지: 스튜디오 안에서는 키보드를 눌러도 모바일 모드를 유지함!
		if not UserInputService.TouchEnabled and not game:GetService("RunService"):IsStudio() then
			isMobileView = false
		end
	end
	
	if wasMobile ~= isMobileView then
		updateUIVisibility()
	end
end)

-- 초기 1회 실행
task.delay(0.5, updateUIVisibility)

