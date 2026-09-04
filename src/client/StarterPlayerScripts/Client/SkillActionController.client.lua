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

-- Temporary Product IDs for unlocking slots
local MonetizationConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MonetizationConfig"))

-- Store config to get image/name
local SkillStoreConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SkillStoreConfig"))

local isRaceStarted = false
local clientCooldowns = {}
local SKILL_COOLDOWNS = {
	Skill_IceBomb = 10,
	Skill_Shield = 15,
	Skill_OrbitalLaser = 20,
	Skill_BlindFog = 15,
	Skill_Ghost = 20,
	Skill_EMP = 30,
}

-- Bind UI
local gui = playerGui:WaitForChild("SkillActionGui")
-- container 변수에 의존하지 않도록 주석 처리 또는 무시
-- local container = gui:WaitForChild("SlotsContainer")

local slots = {}
local hotkeys = { Enum.KeyCode.Q, Enum.KeyCode.E, Enum.KeyCode.R, Enum.KeyCode.T }
local hotkeyStrs = { "Q", "E", "R", "T" }

local glitchOverlay = gui:FindFirstChild("EMPGlitchOverlay")
if not glitchOverlay then
	glitchOverlay = Instance.new("Frame")
	glitchOverlay.Name = "EMPGlitchOverlay"
	glitchOverlay.Size = UDim2.new(1, 0, 1, 0)
	glitchOverlay.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
	glitchOverlay.BackgroundTransparency = 1
	glitchOverlay.ZIndex = 99
	glitchOverlay.Visible = false
	glitchOverlay.Parent = gui
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
local function spawnLocalProjectileVisual(skillId: string)
	local casterChar = LocalPlayer.Character
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

local function showSkillToast(skillName: string)
	local config = SkillMessages.Design.MySkillToast
	local toast = Instance.new("TextLabel")
	toast.Size = UDim2.new(0, 800, 0, 100)
	toast.Position = UDim2.new(0.5, -400, config.PosY, 0)
	toast.BackgroundTransparency = 1
	toast.Font = config.Font
	toast.Text = SkillMessages:Format("MySkillActivated", {skillName = skillName})
	toast.TextColor3 = config.TextColor
	toast.TextSize = config.TextSize
	toast.Parent = gui
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 15)
	corner.Parent = toast
	
	local stroke = Instance.new("UIStroke")
	stroke.Color = config.StrokeColor
	stroke.Thickness = config.StrokeThickness
	stroke.Parent = toast
	
	-- Animate up and fade out
	TweenService:Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, -400, config.PosY - 0.05, 0) }):Play()
	task.delay(1.5, function()
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
	toast.Position = UDim2.new(0.5, -500, config.PosY, 0)
	toast.BackgroundTransparency = 1
	toast.Font = config.Font
	toast.Text = message
	toast.TextColor3 = config.TextColor
	toast.TextSize = config.TextSize
	toast.Parent = gui
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 15)
	corner.Parent = toast
	
	local stroke = Instance.new("UIStroke")
	stroke.Color = config.StrokeColor
	stroke.Thickness = config.StrokeThickness
	stroke.Parent = toast
	
	-- Flashing effect on text instead of background
	local flashTween = TweenService:Create(toast, TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { TextColor3 = Color3.fromRGB(255, 255, 255) })
	flashTween:Play()
	
	-- Animate up and fade out
	TweenService:Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, -500, config.PosY - 0.05, 0) }):Play()
	task.delay(2.5, function()
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

	-- Studio의 NameLabel 세팅을 그대로 사용, 없으면 동적 생성
	local nameLabel = slotFrame:FindFirstChild("NameLabel") :: TextLabel?
	if not nameLabel then
		nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "NameLabel"
		nameLabel.Size = UDim2.new(1.4, 0, 0, 30)
		nameLabel.Position = UDim2.new(-0.2, 0, 1, -15)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Font = Enum.Font.GothamBlack
		nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLabel.TextStrokeTransparency = 1
		nameLabel.TextScaled = false
		nameLabel.TextSize = 22
		nameLabel.ZIndex = 4
		nameLabel.Parent = slotFrame
	end
	-- 항상 외곽선 두께 3 적용 (없으면 생성, 있으면 덮어쓰기)
	local nameLabelStroke = nameLabel:FindFirstChildOfClass("UIStroke")
	if not nameLabelStroke then
		nameLabelStroke = Instance.new("UIStroke")
		nameLabelStroke.Color = Color3.fromRGB(0, 0, 0)
		nameLabelStroke.Parent = nameLabel
	end
	nameLabelStroke.Thickness = 3
	
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
		priceText.Font = Enum.Font.GothamBlack
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
		overlay.Size = UDim2.new(1, 0, 1, 0)
		overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		overlay.BackgroundTransparency = 0.5
		overlay.Visible = false
		local oc = Instance.new("UICorner")
		oc.CornerRadius = UDim.new(0, 12)
		oc.Parent = overlay
		overlay.Parent = slotFrame
	end
	
	local stroke = slotFrame:FindFirstChild("UIStroke") :: UIStroke?
	if not stroke then
		stroke = Instance.new("UIStroke")
		stroke.Name = "UIStroke"
		stroke.Color = Color3.fromRGB(30, 30, 30)
		stroke.Thickness = 4
		stroke.Parent = slotFrame
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
		hotkeyLabel.ZIndex = 10
	end
	
	slots[index] = {
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
		
		if slots[index] and slots[index].skillId then -- Removed isRaceStarted check for testing
			local skillId = slots[index].skillId
			
			local lastUsed = clientCooldowns[skillId]
			local cooldown = SKILL_COOLDOWNS[skillId] or 10
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

-- Refresh UI based on equipped skills and max slots
local function refreshSlots()
	local equipped = equippedSkillsFolder:GetChildren()
	local currentMax = maxSkillSlots.Value
	
	for i = 1, 4 do
		local slot = slots[i]
		if not slot then continue end
		
		-- Manage Lock status for Slot 3 and 4
		if i > currentMax then
			slot.lock.Visible = true
			slot.icon.Image = ""
			slot.nameLabel.Text = ""
			slot.skillId = nil
			slot.stroke.Color = Color3.fromRGB(80, 80, 80)
			slot.overlay.Visible = true
			
			local priceText = slot.lock:FindFirstChild("PriceLabel")
			if priceText then
				if i == 3 then
					priceText.Text = "R$ " .. MonetizationConfig.SlotUnlockProducts.Slot3.price
					priceText.TextColor3 = Color3.fromRGB(255, 215, 0)
					slot.overlay.BackgroundTransparency = 0.5
				elseif i == 4 then
					if currentMax < 3 then
						priceText.Text = "R 슬롯 해제 필요"
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
				slot.skillId = skillVal.Name
				local info = getSkillInfo(skillVal.Name)
				if info then
					slot.icon.Image = info.imageId
					local cleanedName = string.gsub(info.name, "%s*%([a-zA-Z%s]+%)", "")
					slot.nameLabel.Text = cleanedName
					slot.stroke.Color = Color3.fromRGB(255, 215, 0)
				end
			else
				slot.skillId = nil
				slot.icon.Image = ""
				slot.nameLabel.Text = ""
				slot.stroke.Color = Color3.fromRGB(150, 150, 150)
			end
			-- Unlocked slots should never be dimmed by default in casual style
			slot.overlay.Visible = false
		end
	end
end

-- Listen for equipped skills changes
equippedSkillsFolder.ChildAdded:Connect(refreshSlots)
equippedSkillsFolder.ChildRemoved:Connect(refreshSlots)
maxSkillSlots.Changed:Connect(refreshSlots)

-- Listen for Game Phase
phaseRemote.OnClientEvent:Connect(function(phase, timeLeft)
	if phase ~= "RACE_MATCH" then
		isRaceStarted = false
		refreshSlots()
	end
end)

countdownRemote.OnClientEvent:Connect(function(count)
	if count == 0 then
		isRaceStarted = true
		refreshSlots()
	end
end)

skillWarningRemote.OnClientEvent:Connect(function(casterName: string, skillId: string)
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
	if Players.LocalPlayer.Name == casterName then
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
	if not isRaceStarted then
		-- print("🚫 대기실에서는 스킬을 사용할 수 없습니다!")
		return
	end
	for i, key in ipairs(hotkeys) do
		if input.KeyCode == key then
			if slots[i] and slots[i].skillId and maxSkillSlots.Value >= i then
				local skillId = slots[i].skillId
				local lastUsed = clientCooldowns[skillId]
				local cooldown = SKILL_COOLDOWNS[skillId] or 10
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
	for _, child in ipairs(gui:GetChildren()) do
		if child.Name == "EMPHackText" then
			child:Destroy()
		end
	end
	
	hackText.Parent = gui
	
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
