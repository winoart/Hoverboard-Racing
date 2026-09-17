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
-- container 변수에 의존하지 않도록 주석 처리 또는 무시
-- local container = gui:WaitForChild("SlotsContainer")

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

local hoverboardDisplay = gui:FindFirstChild("HoverboardDisplay")
if not hoverboardDisplay then
	hoverboardDisplay = Instance.new("Frame")
	hoverboardDisplay.Name = "HoverboardDisplay"
	hoverboardDisplay.Size = UDim2.new(0, 175, 0, 150)
	hoverboardDisplay.Position = UDim2.new(1, -190, 0.5, -230) -- SlotsContainer 보다 좀 더 위로
	hoverboardDisplay.BackgroundTransparency = 1 -- 배경 투명화
	hoverboardDisplay.Parent = gui

	local hbIcon = Instance.new("ImageLabel")
	hbIcon.Name = "Icon"
	hbIcon.Size = UDim2.new(0, 100, 0, 100) -- 40에서 100으로 2.5배 확대
	hbIcon.Position = UDim2.new(0.5, 0, 0, 0)
	hbIcon.AnchorPoint = Vector2.new(0.5, 0) -- 가로 중앙 정렬
	hbIcon.BackgroundTransparency = 1
	hbIcon.Image = ""
	hbIcon.Parent = hoverboardDisplay
	
	local hbName = Instance.new("TextLabel")
	hbName.Name = "NameLabel"
	hbName.Size = UDim2.new(1, 0, 0, 30)
	hbName.Position = UDim2.new(0.5, 0, 0, 80) -- 아이콘과 텍스트 사이 간격 줄임 (105 -> 80)
	hbName.AnchorPoint = Vector2.new(0.5, 0)
	hbName.BackgroundTransparency = 1
	hbName.Font = Enum.Font.FredokaOne
	hbName.Text = "호버보드"
	hbName.TextColor3 = Color3.fromRGB(255, 255, 255)
	hbName.TextSize = 22 -- 폰트 사이즈 22
	hbName.TextXAlignment = Enum.TextXAlignment.Center
	hbName.Parent = hoverboardDisplay
	
	local textStroke = Instance.new("UIStroke")
	textStroke.Color = Color3.fromRGB(30, 30, 30)
	textStroke.Thickness = 3 -- 외곽선 3
	textStroke.Parent = hbName
end

local hbIcon = hoverboardDisplay:WaitForChild("Icon") :: ImageLabel
local hbName = hoverboardDisplay:WaitForChild("NameLabel") :: TextLabel
local equippedBoardId = LocalPlayer:WaitForChild("EquippedHoverboardId") :: StringValue

local StoreConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("StoreConfig"))

local function updateHoverboardDisplay()
	local boardId = equippedBoardId.Value
	if boardId == "" then boardId = "DefaultHoverboard" end
	
	local foundInfo = nil
	for _, info in ipairs(StoreConfig.Items) do
		if info.id == boardId then
			foundInfo = info
			break
		end
	end
	
	if foundInfo then
		hbName.Text = foundInfo.name
		hbIcon.Image = foundInfo.imageId
	else
		hbName.Text = "호버보드"
		hbIcon.Image = ""
	end
end

updateHoverboardDisplay()
equippedBoardId.Changed:Connect(updateHoverboardDisplay)

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

local function bindSlot(index)
	local slotFrame = gui:FindFirstChild("Slot" .. index, true) :: ImageButton?
	if not slotFrame then
		warn("❌ [SkillActionController] Could not find 'Slot" .. index .. "' inside SkillActionGui. Skipping.")
		return
	end
	
	-- Dynamically create Icon if missing
	local icon = slotFrame:FindFirstChild("Icon") :: ImageLabel?
	if not icon then
		icon = Instance.new("ImageLabel")
		icon.Name = "Icon"
		icon.Size = UDim2.new(1, -20, 1, -20)
		icon.Position = UDim2.new(0, 10, 0, 5)
		icon.AnchorPoint = Vector2.new(0, 0)
		icon.BackgroundTransparency = 1
		icon.ZIndex = 2
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = icon
		icon.Parent = slotFrame
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
		
		local priceText = Instance.new("TextLabel")
		priceText.Name = "PriceLabel"
		priceText.Size = UDim2.new(1, 0, 0.3, 0)
		priceText.Position = UDim2.new(0, 0, 0.7, 0)
		priceText.BackgroundTransparency = 1
		priceText.Font = Enum.Font.FredokaOne
		priceText.TextColor3 = Color3.fromRGB(255, 215, 0) -- Gold/Robux color
		priceText.TextStrokeTransparency = 0
		priceText.TextSize = 14
		priceText.ZIndex = 7
		priceText.Parent = lock
		
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
	oc.CornerRadius = UDim.new(0, 16) -- 디자인 가이드 (CornerRadius 16)
	oc.Parent = overlay
	
	local slotCorner = slotFrame:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	slotCorner.CornerRadius = UDim.new(0, 16)
	slotCorner.Parent = slotFrame
	
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


	slotFrame.MouseButton1Click:Connect(function()
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
		
		if slots[index] and slots[index].skillId and (isRaceStarted and LocalPlayer:GetAttribute("IsRacing")) then
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
			
			local sInfo = getSkillInfo(skillId)
			local sName = sInfo and sInfo.name or skillId
			print("🔥 스킬 사용: " .. sName)
			showSkillToast(sName)
			
			if skillId == "Skill_IceBomb" then
				spawnLocalProjectileVisual(skillId)
			end
			
			useSkillRemote:FireServer(skillId)
			
			-- Cooldown UI logic
			slotFrame.overlay.Visible = true
			slots[index].cdLabel.Visible = true
			local conn
			conn = game:GetService("RunService").RenderStepped:Connect(function()
				local elapsed = os.clock() - clientCooldowns[skillId]
				if elapsed >= cooldown then
					slotFrame.overlay.Visible = false
					slots[index].cdLabel.Visible = false
					conn:Disconnect()
				else
					slots[index].cdLabel.Text = tostring(math.ceil(cooldown - elapsed))
				end
			end)
		end
	end)
end

for i = 1, 4 do
	bindSlot(i)
end

-- Function to get skill info from Config
local function getSkillInfo(skillId: string)
	for _, skill in ipairs(SkillStoreConfig.Skills) do
		if skill.id == skillId then
			return skill
		end
	end
	return nil
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
			
			local priceText = slot.lock:FindFirstChild("PriceLabel")
			if priceText then
				if i == 3 then
					priceText.Text = "R$ " .. MonetizationConfig.SlotUnlockProducts.Slot3.price
					priceText.TextColor3 = Color3.fromRGB(255, 215, 0)
					slot.overlay.BackgroundTransparency = 0.5
				elseif i == 4 then
					if currentMax < 3 then
						priceText.Text = "Unlock Slot 3 First"
						priceText.TextColor3 = Color3.fromRGB(255, 100, 100)
						slot.overlay.BackgroundTransparency = 0.8
					else
						priceText.Text = "R$ " .. MonetizationConfig.SlotUnlockProducts.Slot4.price
						priceText.TextColor3 = Color3.fromRGB(255, 215, 0)
						slot.overlay.BackgroundTransparency = 0.5
					end
				end
			end
		else
			slot.lock.Visible = false
			
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
	
	if not isMe and not isSpectatingThem then 
		print("[DEBUG-SkillWarning] Ignored. Not me and not spectating the target.")
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

-- 📡 Global Skill Cast Listener (For Spectators)
globalSkillCastRemote.OnClientEvent:Connect(function(casterUserId: number, skillId: string)
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
paintballEffectRemote.OnClientEvent:Connect(function()
	-- 1. Splat 에셋 찾기 (어디에 넣으셨든 다 찾도록 범위 확대)
	local splatSource = workspace:FindFirstChild("Splat", true) 
		or game.ReplicatedStorage:FindFirstChild("Splat", true)
		or game:GetService("StarterGui"):FindFirstChild("Splat", true)
		or game.Players.LocalPlayer:FindFirstChild("PlayerGui"):FindFirstChild("Splat", true)
	
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
