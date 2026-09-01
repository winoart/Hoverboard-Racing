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

local hoverRemotes = ReplicatedStorage:WaitForChild("HoverboardRemotes")
local phaseRemote = hoverRemotes:WaitForChild("GamePhaseChanged") :: RemoteEvent
local countdownRemote = hoverRemotes:WaitForChild("StartCountdownSignal") :: RemoteEvent
local useSkillRemote = hoverRemotes:WaitForChild("UseSkill") :: RemoteEvent
local skillWarningRemote = hoverRemotes:WaitForChild("SkillWarning") :: RemoteEvent
local blindEffectRemote = hoverRemotes:WaitForChild("BlindEffect") :: RemoteEvent
local empEffectRemote = hoverRemotes:WaitForChild("EMPEffect") :: RemoteEvent
local frostEffectRemote = hoverRemotes:WaitForChild("FrostEffect") :: RemoteEvent

-- Temporary Product ID for unlocking the 3rd slot
local UNLOCK_SLOT3_PRODUCT_ID = 123456789 

-- Store config to get image/name
local SkillStoreConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SkillStoreConfig"))

local isRaceStarted = false
local clientCooldowns = {}
local SKILL_COOLDOWNS = {
	Skill_IceBomb = 10,
	Skill_Shield = 15,
	Skill_IceTrap = 15,
	Skill_BlindFog = 15,
	Skill_Ghost = 20,
	Skill_EMP = 30,
}

-- Create UI
local gui = Instance.new("ScreenGui")
gui.Name = "SkillActionGui"
gui.ResetOnSpawn = false
gui.Parent = playerGui

local container = Instance.new("Frame")
container.Name = "SlotsContainer"
container.Size = UDim2.new(0, 80, 0, 260)
container.Position = UDim2.new(1, -100, 0.5, -130)
container.BackgroundTransparency = 1
container.Parent = gui

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 15)
listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = container

local slots = {}
local hotkeys = { Enum.KeyCode.Q, Enum.KeyCode.E, Enum.KeyCode.R }
local hotkeyStrs = { "Q", "E", "R" }

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
	local toast = Instance.new("TextLabel")
	toast.Size = UDim2.new(0, 400, 0, 60)
	toast.Position = UDim2.new(0.5, -200, 0.7, 0)
	toast.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
	toast.BackgroundTransparency = 0.2
	toast.Font = Enum.Font.GothamBlack
	toast.Text = "🔥 [" .. skillName .. "] 발동!"
	toast.TextColor3 = Color3.fromRGB(255, 200, 50)
	toast.TextSize = 24
	toast.Parent = gui
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 15)
	corner.Parent = toast
	
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 150, 0)
	stroke.Thickness = 2
	stroke.Parent = toast
	
	-- Animate up and fade out
	TweenService:Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, -200, 0.65, 0) }):Play()
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
	local toast = Instance.new("TextLabel")
	toast.Size = UDim2.new(0, 500, 0, 70)
	toast.Position = UDim2.new(0.5, -250, 0.3, 0)
	toast.BackgroundColor3 = Color3.fromRGB(50, 20, 20)
	toast.BackgroundTransparency = 0.2
	toast.Font = Enum.Font.GothamBlack
	toast.Text = "⚠️ " .. message
	toast.TextColor3 = Color3.fromRGB(255, 100, 100)
	toast.TextSize = 24
	toast.Parent = gui
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 15)
	corner.Parent = toast
	
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 50, 50)
	stroke.Thickness = 3
	stroke.Parent = toast
	
	-- Flashing effect
	local flashTween = TweenService:Create(toast, TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { BackgroundColor3 = Color3.fromRGB(100, 20, 20) })
	flashTween:Play()
	
	-- Animate up and fade out
	TweenService:Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, -250, 0.25, 0) }):Play()
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

local fogOverlay = Instance.new("ImageLabel")
fogOverlay.Name = "BlindFogOverlay"
fogOverlay.Size = UDim2.new(1, 0, 1, 0)
fogOverlay.Position = UDim2.new(0, 0, 0, 0)
fogOverlay.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
fogOverlay.BackgroundTransparency = 1
fogOverlay.Image = "rbxassetid://733568916" -- Foggy texture
fogOverlay.ImageTransparency = 1
fogOverlay.ImageColor3 = Color3.fromRGB(150, 150, 150)
fogOverlay.ZIndex = 100
fogOverlay.Visible = false
fogOverlay.Parent = gui

local function setBlindEffect(active: boolean)
	if active then
		fogOverlay.Visible = true
		TweenService:Create(fogOverlay, TweenInfo.new(0.5), {
			BackgroundTransparency = 0.2,
			ImageTransparency = 0.5
		}):Play()
	else
		local t = TweenService:Create(fogOverlay, TweenInfo.new(1), {
			BackgroundTransparency = 1,
			ImageTransparency = 1
		})
		t:Play()
		t.Completed:Connect(function()
			if fogOverlay.BackgroundTransparency >= 0.99 then
				fogOverlay.Visible = false
			end
		end)
	end
end

-- Glitch UI for EMP
local glitchOverlay = Instance.new("Frame")
glitchOverlay.Name = "EMPGlitchOverlay"
glitchOverlay.Size = UDim2.new(1, 0, 1, 0)
glitchOverlay.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
glitchOverlay.BackgroundTransparency = 1
glitchOverlay.ZIndex = 99
glitchOverlay.Visible = false
glitchOverlay.Parent = gui

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

local function createSlot(index: number)
	local slotFrame = Instance.new("ImageButton")
	slotFrame.Name = "Slot" .. index
	slotFrame.Size = UDim2.new(0, 70, 0, 70)
	slotFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	slotFrame.BackgroundTransparency = 0.2
	slotFrame.LayoutOrder = index
	slotFrame.Parent = container
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0) -- Circle
	corner.Parent = slotFrame
	
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(150, 150, 150)
	stroke.Thickness = 2
	stroke.Parent = slotFrame
	
	local icon = Instance.new("ImageLabel")
	icon.Size = UDim2.new(1, -10, 1, -10)
	icon.Position = UDim2.new(0.5, 0, 0.5, 0)
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.BackgroundTransparency = 1
	icon.Image = ""
	icon.Parent = slotFrame
	
	local cornerIcon = Instance.new("UICorner")
	cornerIcon.CornerRadius = UDim.new(0.5, 0)
	cornerIcon.Parent = icon
	
	local hotkeyLabel = Instance.new("TextLabel")
	hotkeyLabel.Size = UDim2.new(0, 24, 0, 24)
	hotkeyLabel.Position = UDim2.new(1, -10, 0, -5)
	hotkeyLabel.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
	hotkeyLabel.Font = Enum.Font.GothamBlack
	hotkeyLabel.Text = hotkeyStrs[index]
	hotkeyLabel.TextColor3 = Color3.fromRGB(0, 0, 0)
	hotkeyLabel.TextSize = 14
	hotkeyLabel.Parent = slotFrame
	
	local hkCorner = Instance.new("UICorner")
	hkCorner.CornerRadius = UDim.new(1, 0)
	hkCorner.Parent = hotkeyLabel
	
	local overlay = Instance.new("Frame")
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	overlay.BackgroundTransparency = 0.5
	overlay.Visible = true -- Default locked in lobby
	overlay.Parent = slotFrame
	
	local overlayCorner = Instance.new("UICorner")
	overlayCorner.CornerRadius = UDim.new(0.5, 0)
	overlayCorner.Parent = overlay
	
	-- For slot 3 lock
	local lockIcon = Instance.new("TextLabel")
	lockIcon.Size = UDim2.new(1, 0, 1, 0)
	lockIcon.BackgroundTransparency = 1
	lockIcon.Font = Enum.Font.GothamBold
	lockIcon.Text = "🔒\n50 R$"
	lockIcon.TextColor3 = Color3.fromRGB(255, 100, 100)
	lockIcon.TextSize = 16
	lockIcon.Visible = false
	lockIcon.Parent = slotFrame
	
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 0, 20)
	nameLabel.Position = UDim2.new(0, 0, 1, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Text = ""
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextSize = 12
	nameLabel.Parent = slotFrame
	
	slots[index] = {
		frame = slotFrame,
		icon = icon,
		stroke = stroke,
		overlay = overlay,
		lock = lockIcon,
		nameLabel = nameLabel,
		skillId = nil
	}
	


	slotFrame.MouseButton1Click:Connect(function()
		if index == 3 and maxSkillSlots.Value < 3 then
			-- Prompt Purchase
			MarketplaceService:PromptProductPurchase(LocalPlayer, UNLOCK_SLOT3_PRODUCT_ID)
			return
		end
		
		if slots[index].skillId and isRaceStarted then
			local skillId = slots[index].skillId
			
			local lastUsed = clientCooldowns[skillId]
			local cooldown = SKILL_COOLDOWNS[skillId] or 10
			if lastUsed and (os.clock() - lastUsed) < cooldown then
				print("⏳ 아직 쿨타임 중입니다!")
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
			local fillRatio = 1
			local conn
			conn = game:GetService("RunService").RenderStepped:Connect(function()
				local elapsed = os.clock() - clientCooldowns[skillId]
				if elapsed >= cooldown then
					slotFrame.overlay.Visible = false
					conn:Disconnect()
				else
					-- We could animate overlay size or transparency here
				end
			end)
		end
	end)
end

for i = 1, 3 do
	createSlot(i)
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
	
	for i = 1, 3 do
		local slot = slots[i]
		
		-- Manage Lock status for Slot 3
		if i > currentMax then
			slot.lock.Visible = true
			slot.icon.Image = ""
			slot.nameLabel.Text = ""
			slot.skillId = nil
			slot.stroke.Color = Color3.fromRGB(80, 80, 80)
			slot.overlay.Visible = true
		else
			slot.lock.Visible = false
			
			local skillVal = equipped[i]
			if skillVal then
				slot.skillId = skillVal.Name
				local info = getSkillInfo(skillVal.Name)
				if info then
					slot.icon.Image = info.imageId
					slot.nameLabel.Text = info.name
					slot.stroke.Color = Color3.fromRGB(255, 215, 0)
				end
			else
				slot.skillId = nil
				slot.icon.Image = ""
				slot.nameLabel.Text = ""
				slot.stroke.Color = Color3.fromRGB(150, 150, 150)
			end
			
			-- Overlay logic (darken if not racing or if empty)
			if not isRaceStarted or not slot.skillId then
				slot.overlay.Visible = true
			else
				slot.overlay.Visible = false
			end
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
			showWarningToast("🛡️ 방어막이 파괴되었습니다!")
			
			-- 화면 피격 피드백 (빨간 번쩍임)
			local cc = Instance.new("ColorCorrectionEffect")
			cc.TintColor = Color3.fromRGB(255, 150, 150)
			cc.Parent = game:GetService("Lighting")
			local tween = TweenService:Create(cc, TweenInfo.new(0.4), {TintColor = Color3.fromRGB(255, 255, 255)})
			tween:Play()
			tween.Completed:Connect(function() cc:Destroy() end)
		else
			showWarningToast("💥 " .. casterName .. "님의 방어막을 무력화했습니다!")
		end
		return
	end
	
	local sInfo = getSkillInfo(skillId)
	local sName = sInfo and sInfo.name or skillId
	showWarningToast("⚠️ " .. casterName .. "님이 당신에게 " .. sName .. "을(를) 사용했습니다!")
end)

blindEffectRemote.OnClientEvent:Connect(function(active: boolean)
	setBlindEffect(active)
end)

empEffectRemote.OnClientEvent:Connect(function(casterName: string)
	print("⚡ EMP detected from " .. casterName)
	-- Global Aurora Effect
	local lighting = game:GetService("Lighting")
	local origColor = lighting.ColorShift_Top
	local origAmbient = lighting.Ambient
	
	local auroraColor = Color3.fromRGB(0, 255, 255) -- Cyan Aurora
	TweenService:Create(lighting, TweenInfo.new(0.5, Enum.EasingStyle.Sine), {
		ColorShift_Top = auroraColor,
		Ambient = auroraColor
	}):Play()
	
	-- Glitch effect for everyone (except the caster)
	if Players.LocalPlayer.Name ~= casterName then
		playGlitchEffect()
		showWarningToast("⚡ " .. casterName .. "님이 EMP를 터뜨렸습니다!")
	else
		showWarningToast("⚡ EMP 가동 완료!")
	end
	
	-- Revert sky after 2.5s
	task.delay(2.5, function()
		TweenService:Create(lighting, TweenInfo.new(2), {
			ColorShift_Top = origColor,
			Ambient = origAmbient
		}):Play()
	end)
end)

-- Key inputs
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if not isRaceStarted then return end
	
	for i, key in ipairs(hotkeys) do
		if input.KeyCode == key then
			if slots[i] and slots[i].skillId and maxSkillSlots.Value >= i then
				local skillId = slots[i].skillId
				local lastUsed = clientCooldowns[skillId]
				local cooldown = SKILL_COOLDOWNS[skillId] or 10
				if lastUsed and (os.clock() - lastUsed) < cooldown then
					print("⏳ 쿨타임 중입니다!")
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
				local conn
				conn = game:GetService("RunService").RenderStepped:Connect(function()
					if not clientCooldowns[skillId] then conn:Disconnect(); return end
					local elapsed = os.clock() - clientCooldowns[skillId]
					if elapsed >= cooldown then
						slots[i].overlay.Visible = false
						conn:Disconnect()
					end
				end)
			end
		end
	end
end)

-- Initial refresh
refreshSlots()
