--!strict
-- SkillActionServer.server.lua
-- Handles skill usages during the race

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local LapManager = require(script.Parent:WaitForChild("LapManager") :: ModuleScript)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SkillStoreConfig = require(Shared:WaitForChild("SkillStoreConfig") :: ModuleScript)

-- Initialize Remotes
local remotesFolder = ReplicatedStorage:FindFirstChild("HoverboardRemotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "HoverboardRemotes"
	remotesFolder.Parent = ReplicatedStorage
end

local useSkillRemote = remotesFolder:FindFirstChild("UseSkill") :: RemoteEvent?
if not useSkillRemote then
	useSkillRemote = Instance.new("RemoteEvent")
	useSkillRemote.Name = "UseSkill"
	useSkillRemote.Parent = remotesFolder
end

local skillWarningRemote = remotesFolder:FindFirstChild("SkillWarning") :: RemoteEvent?
if not skillWarningRemote then
	skillWarningRemote = Instance.new("RemoteEvent")
	skillWarningRemote.Name = "SkillWarning"
	skillWarningRemote.Parent = remotesFolder
end

local blindEffectRemote = remotesFolder:FindFirstChild("BlindEffect") :: RemoteEvent?
if not blindEffectRemote then
	blindEffectRemote = Instance.new("RemoteEvent")
	blindEffectRemote.Name = "BlindEffect"
	blindEffectRemote.Parent = remotesFolder
end

local frostEffectRemote = remotesFolder:FindFirstChild("FrostEffect") :: RemoteEvent?
if not frostEffectRemote then
	frostEffectRemote = Instance.new("RemoteEvent")
	frostEffectRemote.Name = "FrostEffect"
	frostEffectRemote.Parent = remotesFolder
end

local empEffectRemote = remotesFolder:FindFirstChild("EMPEffect") :: RemoteEvent?
if not empEffectRemote then
	empEffectRemote = Instance.new("RemoteEvent")
	empEffectRemote.Name = "EMPEffect"
	empEffectRemote.Parent = remotesFolder
end

local empHackRemote = remotesFolder:FindFirstChild("EMPHackEffect") :: RemoteEvent?
if not empHackRemote then
	empHackRemote = Instance.new("RemoteEvent")
	empHackRemote.Name = "EMPHackEffect"
	empHackRemote.Parent = remotesFolder
end

local globalSkillCastRemote = remotesFolder:FindFirstChild("GlobalSkillCast") :: RemoteEvent?
if not globalSkillCastRemote then
	globalSkillCastRemote = Instance.new("RemoteEvent")
	globalSkillCastRemote.Name = "GlobalSkillCast"
	globalSkillCastRemote.Parent = remotesFolder
end

local paintballEffectRemote = remotesFolder:FindFirstChild("PaintballEffect") :: RemoteEvent?
if not paintballEffectRemote then
	paintballEffectRemote = Instance.new("RemoteEvent")
	paintballEffectRemote.Name = "PaintballEffect"
	paintballEffectRemote.Parent = remotesFolder
end

local updateUsesRemote = remotesFolder:FindFirstChild("SkillUsesUpdated") :: RemoteEvent?
if not updateUsesRemote then
	updateUsesRemote = Instance.new("RemoteEvent")
	updateUsesRemote.Name = "SkillUsesUpdated"
	updateUsesRemote.Parent = remotesFolder
end

-- Skill Tracking (Server side)
local playerCooldowns: { [number]: { [string]: number } } = {}
local playerSkillUses: { [number]: { [string]: number } } = {}

Players.PlayerAdded:Connect(function(player)
	player:GetAttributeChangedSignal("IsRacing"):Connect(function()
		if player:GetAttribute("IsRacing") then
			playerSkillUses[player.UserId] = {}
		end
	end)
end)

local activeShields: { [number]: boolean } = {}
local activeGhosts: { [number]: boolean } = {}
local activeReflects: { [number]: boolean } = {}
local reflectUses: { [number]: number } = {}

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		reflectUses[player.UserId] = 0
		activeReflects[player.UserId] = false
	end)
end)

local function getSkillConfig(skillId: string)
	for _, skill in ipairs(SkillStoreConfig.Skills) do
		if skill.id == skillId then return skill end
	end
	return nil
end

local function canUseSkill(player: Player, skillId: string): boolean
	local config = getSkillConfig(skillId)
	if not config then return true end
	
	if config.cooldownType == "Charges" then
		local uses = (playerSkillUses[player.UserId] and playerSkillUses[player.UserId][skillId]) or 0
		local maxUses = config.maxUses or 1
		if uses >= maxUses then return false end
	end
	
	local pCooldowns = playerCooldowns[player.UserId]
	if not pCooldowns then return true end
	
	local lastUsed = pCooldowns[skillId]
	if not lastUsed then return true end
	
	local cooldownDuration = config.cooldownTime or 10
	if os.clock() - lastUsed >= cooldownDuration then
		return true
	end
	return false
end

local function setCooldown(player: Player, skillId: string)
	if not playerCooldowns[player.UserId] then
		playerCooldowns[player.UserId] = {}
	end
	playerCooldowns[player.UserId][skillId] = os.clock()
	
	local config = getSkillConfig(skillId)
	if config and config.cooldownType == "Charges" then
		if not playerSkillUses[player.UserId] then
			playerSkillUses[player.UserId] = {}
		end
		playerSkillUses[player.UserId][skillId] = (playerSkillUses[player.UserId][skillId] or 0) + 1
		
		-- Notify client about use count update
		if updateUsesRemote then
			updateUsesRemote:FireClient(player, skillId, config.maxUses - playerSkillUses[player.UserId][skillId])
		end
	end
end

-- [KartRider-Style Projectile Standard]
-- 투사체(얼음폭탄 등)의 물리적 이동(Visuals)은 발사하는 클라이언트가 전담합니다.
-- 서버는 물리 파트를 생성하지 않고, 논리적 타격 판정(무조건 2초 후 적중)만 담당합니다.
local function fireIceBomb(caster: Player, target: Player?)
	local casterChar = caster.Character
	if not casterChar or not casterChar.PrimaryPart then return end
	
	setCooldown(caster, "Skill_IceBomb")
	
	if not target or not target.Character or not target.Character.PrimaryPart then
		print("❄️ [SkillServer] Ice Bomb fizzled (No Target) for " .. caster.Name)
		return
	end
	
	print("❄️ [SkillServer] Ice Bomb fired by " .. caster.Name .. " at " .. target.Name .. " (Will hit in 2 seconds)")
	
	if skillWarningRemote then
		skillWarningRemote:FireAllClients(target.Name, caster.Name, "Skill_IceBomb")
	end
	
	-- 서버는 타겟을 찾아 2초 뒤에 꽂히는 판정만 수행합니다.
	task.delay(2, function()
		if not target or not target.Character or not target.Character.PrimaryPart then return end
		local targetChar = target.Character
		local targetRoot = targetChar.PrimaryPart
		
		if activeGhosts[target.UserId] then
			print("👻 [SkillServer] " .. target.Name .. " DODGED Ice Bomb as a Ghost!")
			return
		end
		

		
		-- 떨어지는 액션 연출 (Weld를 사용하여 타겟의 빠른 이동에도 완벽하게 추적)
		local fallingBomb = Instance.new("Part")
		fallingBomb.Name = "FallingIceBomb"
		fallingBomb.Shape = Enum.PartType.Ball
		fallingBomb.Size = Vector3.new(5.5, 5.5, 5.5)
		fallingBomb.Color = Color3.fromRGB(0, 255, 255)
		fallingBomb.Material = Enum.Material.Neon
		fallingBomb.CanCollide = false
		fallingBomb.Anchored = false
		fallingBomb.CFrame = targetRoot.CFrame * CFrame.new(0, 40, 0)
		fallingBomb.Parent = workspace
		
		local weld = Instance.new("Weld")
		weld.Part0 = targetRoot
		weld.Part1 = fallingBomb
		weld.C0 = CFrame.new(0, 40, 0) -- 40스터드 위에서 시작
		weld.Parent = fallingBomb
		
		local trail = Instance.new("Trail")
		local a0 = Instance.new("Attachment", fallingBomb)
		a0.Position = Vector3.new(0, 0, 1.5)
		local a1 = Instance.new("Attachment", fallingBomb)
		a1.Position = Vector3.new(0, 0, -1.5)
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Lifetime = 0.2
		trail.Color = ColorSequence.new(Color3.fromRGB(0, 255, 255))
		trail.Parent = fallingBomb
		
		local fallDuration = 0.4
		-- 부드러운 가속도(Quad, In)로 타겟 머리 위로 꽂힘
		local fallTween = TweenService:Create(weld, TweenInfo.new(fallDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			C0 = CFrame.new(0, 0, 0)
		})
		fallTween:Play()
		
		task.delay(fallDuration, function()
			if fallingBomb and fallingBomb.Parent then
				fallingBomb:Destroy()
			end
			
			if not target or not target.Character or not target.Character.PrimaryPart then return end
			local targetChar = target.Character
			local targetRoot = targetChar.PrimaryPart
			
			-- 타격 직전(떨어진 후) 반사 체크
			if activeReflects[target.UserId] then
				print("🪞 [SkillServer] " .. target.Name .. " REFLECTED Ice Bomb back to " .. caster.Name .. "!")
				activeReflects[target.UserId] = false
				
				if skillWarningRemote then
					skillWarningRemote:FireAllClients(caster.Name, target.Name, "Skill_Reflected")
				end
				
				-- 타겟을 시전자로 교체하여 역으로 맞게 함
				target = caster
				targetChar = target.Character
				targetRoot = targetChar.PrimaryPart
			elseif activeShields[target.UserId] then
				print("🛡️ [SkillServer] " .. target.Name .. " BLOCKED Ice Bomb with a Shield!")
				activeShields[target.UserId] = false
				
				if skillWarningRemote then
					skillWarningRemote:FireAllClients(caster.Name, target.Name, "Skill_Shield_Break")
				end
				return
			end
			
			-- 타격 파티클 이펙트
			local hitAtt = Instance.new("Attachment", targetRoot)
			local hitEmit = Instance.new("ParticleEmitter")
			hitEmit.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 4), NumberSequenceKeypoint.new(1, 12)})
			hitEmit.Transparency = NumberSequence.new(0, 1)
			hitEmit.Color = ColorSequence.new(Color3.fromRGB(200, 255, 255))
			hitEmit.Speed = NumberRange.new(40, 80)
			hitEmit.Drag = 5
			hitEmit.Lifetime = NumberRange.new(0.5, 1)
			hitEmit.Rate = 0
			hitEmit.SpreadAngle = Vector2.new(180, 180)
			hitEmit.Parent = hitAtt
			hitEmit:Emit(100)
			game:GetService("Debris"):AddItem(hitAtt, 2)
			
			-- FREEZE TARGET
			print("❄️ [SkillServer] " .. target.Name .. " is FROZEN by " .. caster.Name .. "!")
				
				targetChar:SetAttribute("StatusEffect_Frozen", true)
				
				local hoverboard = targetChar:FindFirstChild("Hoverboard")
				if hoverboard and hoverboard:IsA("Model") and hoverboard.PrimaryPart then
					hoverboard.PrimaryPart.Anchored = true
				else
					targetRoot.Anchored = true
				end
				
				-- 얼음 큐브 생성 (서버/클라이언트 지연 시간 차이를 막기 위해 Weld로 부착)
				local iceCube = Instance.new("Part")
				iceCube.Name = "IceCubeEffect"
				iceCube.Size = Vector3.new(6, 7, 6)
				iceCube.Color = Color3.fromRGB(150, 220, 255)
				iceCube.Material = Enum.Material.Ice
				iceCube.Transparency = 0.4
				iceCube.Anchored = false
				iceCube.Massless = true
				iceCube.CanCollide = false
				iceCube.CFrame = targetRoot.CFrame
				iceCube.Parent = targetChar
				
				local iceWeld = Instance.new("WeldConstraint")
				iceWeld.Part0 = targetRoot
				iceWeld.Part1 = iceCube
				iceWeld.Parent = iceCube
				
				local humanoid = targetChar:FindFirstChild("Humanoid")
				local animator = humanoid and humanoid:FindFirstChild("Animator")
				local pausedTracks = {}
				if animator then
					for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
						track:AdjustSpeed(0)
						table.insert(pausedTracks, track)
					end
				end
				
				task.delay(2, function()
					if targetChar and targetChar.Parent then
						targetChar:SetAttribute("StatusEffect_Frozen", false)
					end
					if hoverboard and hoverboard:IsA("Model") and hoverboard.PrimaryPart then
						hoverboard.PrimaryPart.Anchored = false
					elseif targetRoot and targetRoot.Parent then
						targetRoot.Anchored = false
					end
					
					for _, track in ipairs(pausedTracks) do
						if track.IsPlaying then
							track:AdjustSpeed(1)
						end
					end
					
					if iceCube and iceCube.Parent then
						local shatterSound = Instance.new("Sound")
						shatterSound.SoundId = "rbxassetid://131148590" -- 유효한 유리 깨지는 소리
						shatterSound.Volume = 1
						shatterSound.Parent = targetRoot
						shatterSound:Play()
						game:GetService("Debris"):AddItem(shatterSound, 2)
						
						-- 물리적 파편 연출
						for i = 1, 8 do
							local debris = Instance.new("Part")
							debris.Name = "IceDebris"
							debris.Size = Vector3.new(math.random(1,3), math.random(1,3), math.random(1,3))
							debris.Color = Color3.fromRGB(150, 220, 255)
							debris.Material = Enum.Material.Ice
							debris.Position = iceCube.Position + Vector3.new(math.random(-3,3), math.random(0,5), math.random(-3,3))
							debris.Anchored = false
							debris.CanCollide = true
							debris.Parent = workspace
							
							debris.Velocity = Vector3.new(math.random(-20, 20), math.random(20, 50), math.random(-20, 20))
							debris.RotVelocity = Vector3.new(math.random(-10, 10), math.random(-10, 10), math.random(-10, 10))
							
							game:GetService("Debris"):AddItem(debris, 1)
						end
						
						local shatterTween = game:GetService("TweenService"):Create(iceCube, TweenInfo.new(0.3), {
							Size = Vector3.new(8, 9, 8),
							Transparency = 1
						})
						shatterTween:Play()
						shatterTween.Completed:Connect(function()
							iceCube:Destroy()
						end)
					end
				end)
			end)
	end)
end

-- Create Shield
local function fireShield(player: Player)
	local char = player.Character
	if not char or not char.PrimaryPart then return end
	
	setCooldown(player, "Skill_Shield")
	activeShields[player.UserId] = true
	
	print("🛡️ [SkillServer] " .. player.Name .. " activated Shield!")
	
	char:SetAttribute("HasShield", true)
	
	local root = char.PrimaryPart
	
	local shieldPart = Instance.new("Part")
	shieldPart.Name = "SkillShield"
	shieldPart.Shape = Enum.PartType.Ball
	shieldPart.Size = Vector3.new(12, 12, 12)
	shieldPart.Color = Color3.fromRGB(0, 255, 255) -- 형광 하늘색 (SF 느낌)
	shieldPart.Material = Enum.Material.ForceField
	shieldPart.Transparency = 0.5
	shieldPart.Anchored = false
	shieldPart.CanCollide = false
	shieldPart.Massless = true
	
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = shieldPart
	weld.Parent = shieldPart
	
	shieldPart.CFrame = root.CFrame
	shieldPart.Parent = char
	
	-- 발동 사운드
	local startSound = Instance.new("Sound")
	startSound.SoundId = "rbxassetid://12222076" -- SF 에너지 쉴드 발동음
	startSound.Parent = root
	startSound:Play()
	game:GetService("Debris"):AddItem(startSound, 2)
	
	-- 맥박 뛰는(Pulse) 애니메이션
	local pulseInfo = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	local pulseTween = TweenService:Create(shieldPart, pulseInfo, {
		Size = Vector3.new(13, 13, 13),
		Transparency = 0.3
	})
	pulseTween:Play()
	
	-- Keep track of state
	task.delay(5, function()
		if activeShields[player.UserId] then
			activeShields[player.UserId] = false
			print("🛡️ [SkillServer] " .. player.Name .. "'s Shield expired naturally.")
			if char and char.Parent then
				char:SetAttribute("HasShield", false)
			end
			
			if shieldPart.Parent then
				pulseTween:Cancel()
				local ts = TweenService:Create(shieldPart, TweenInfo.new(0.5), {Transparency = 1, Size = Vector3.new(15, 15, 15)})
				ts:Play()
				ts.Completed:Connect(function()
					shieldPart:Destroy()
				end)
			end
		end
	end)
	
	-- If it breaks early, we want to destroy the visual
	task.spawn(function()
		while shieldPart.Parent do
			if not activeShields[player.UserId] then
				-- Broken!
				if char and char.Parent then
					char:SetAttribute("HasShield", false)
				end
				pulseTween:Cancel()
				
				if skillWarningRemote then
					skillWarningRemote:FireAllClients(player.Name, "SYSTEM", "Skill_Shield_Break")
				end
				-- 방어 성공(무력화) 사운드
				local breakSound = Instance.new("Sound")
				breakSound.SoundId = "rbxassetid://258057783" -- 에너지 충돌/튕겨내는 소리
				breakSound.Volume = 1
				breakSound.Parent = root
				breakSound:Play()
				game:GetService("Debris"):AddItem(breakSound, 2)
				
				-- 방어막 깜빡거림 연출 (3~4번 깜빡인 후 소멸)
				if shieldPart and shieldPart.Parent then
					for i = 1, 4 do
						if not shieldPart or not shieldPart.Parent then break end
						shieldPart.Transparency = 1
						task.wait(0.08)
						if not shieldPart or not shieldPart.Parent then break end
						shieldPart.Transparency = 0.2
						task.wait(0.08)
					end
					
					if shieldPart and shieldPart.Parent then
						shieldPart:Destroy()
					end
				end
				break
			end
			task.wait(0.1)
		end
	end)
end

-- Create Orbital Laser
local function fireOrbitalLaser(player: Player)
	setCooldown(player, "Skill_OrbitalLaser")
	print("🛰️ [SkillServer] " .. player.Name .. " called Orbital Laser on all opponents!")
	
	for _, targetPlayer in ipairs(Players:GetPlayers()) do
		if targetPlayer.UserId == player.UserId then continue end
		if activeGhosts[targetPlayer.UserId] then continue end -- Ghosts are immune
		
		local char = targetPlayer.Character
		if not char then continue end
		
		-- 1. 2초 경고 연출
		if skillWarningRemote then
			skillWarningRemote:FireAllClients(targetPlayer.Name, player.Name, "Skill_OrbitalLaser")
		end
		
		-- 서버 측 경고 이펙트 (빨간 기둥)
		local root = char.PrimaryPart
		if not root then continue end
		
		local warningPillar = Instance.new("Part")
		warningPillar.Name = "OrbitalWarning"
		warningPillar.Shape = Enum.PartType.Cylinder
		warningPillar.Size = Vector3.new(500, 1, 1) -- Tall cylinder
		warningPillar.Color = Color3.fromRGB(255, 50, 50)
		warningPillar.Material = Enum.Material.Neon
		warningPillar.Transparency = 0.5
		warningPillar.Anchored = false
		warningPillar.CanCollide = false
		warningPillar.Massless = true
		
		-- [Bug Fix] Weld 하기 전에 파트의 실제 위치를 먼저 캐릭터 위로 옮겨두어야 물리 엔진이 캐릭터를 (0,0,0)으로 강제 이동시키지 않습니다.
		warningPillar.CFrame = root.CFrame * CFrame.new(0, 250, 0) * CFrame.Angles(0, 0, math.pi/2)
		
		local weld = Instance.new("Weld")
		weld.Part0 = root
		weld.Part1 = warningPillar
		weld.C0 = CFrame.new(0, 250, 0) * CFrame.Angles(0, 0, math.pi/2) -- Stick it straight up
		weld.Parent = warningPillar
		warningPillar.Parent = char
		
		local warningSound = Instance.new("Sound")
		warningSound.SoundId = "rbxassetid://258057783" -- lock on / warning sound
		warningSound.Volume = 1
		warningSound.Parent = root
		warningSound:Play()
		game:GetService("Debris"):AddItem(warningSound, 3)
		
		-- 2. 2초 뒤 실제 타격
		task.delay(2, function()
			if warningPillar.Parent then warningPillar:Destroy() end
			if not targetPlayer.Parent or not char.Parent then
				return
			end
			
			-- 쉴드 방어 체크
			if activeShields[targetPlayer.UserId] then
				print("🛡️ [SkillServer] " .. targetPlayer.Name .. " BLOCKED Orbital Laser with a Shield!")
				activeShields[targetPlayer.UserId] = false
				if skillWarningRemote then
					skillWarningRemote:FireAllClients(player.Name, targetPlayer.Name, "Skill_Shield_Break")
				end
				return
			end

			print("💥 [SkillServer] " .. targetPlayer.Name .. " got hit by Orbital Laser!")
			
			-- 실제 레이저 이펙트
			local laserPillar = Instance.new("Part")
			laserPillar.Name = "OrbitalStrike"
			laserPillar.Shape = Enum.PartType.Cylinder
			laserPillar.Size = Vector3.new(500, 15, 15) 
			laserPillar.Color = Color3.fromRGB(100, 255, 255)
			laserPillar.Material = Enum.Material.Neon
			laserPillar.Anchored = false -- Weld를 위해 고정 해제
			laserPillar.CanCollide = false
			laserPillar.Massless = true
			laserPillar.CFrame = root.CFrame * CFrame.new(0, 250, 0) * CFrame.Angles(0, 0, math.pi/2)
			
			local hitWeld = Instance.new("Weld")
			hitWeld.Part0 = root
			hitWeld.Part1 = laserPillar
			hitWeld.C0 = CFrame.new(0, 250, 0) * CFrame.Angles(0, 0, math.pi/2)
			hitWeld.Parent = laserPillar
			
			laserPillar.Parent = char
			game.Debris:AddItem(laserPillar, 1.5) -- 1.5초 후 이펙트 삭제 (기존에 삭제가 누락되어 무한정 남아있던 버그 수정)
			
			local boomSound = Instance.new("Sound")
			boomSound.SoundId = "rbxassetid://12222200" -- explosion
			boomSound.Volume = 2
			boomSound.Parent = root
			boomSound:Play()
			game.Debris:AddItem(boomSound, 3)
			
			-- 기절 효과 명령을 클라이언트로 전송
			if skillWarningRemote then
				skillWarningRemote:FireAllClients(targetPlayer.Name, "SYSTEM", "OrbitalStun")
			end
			
			char:SetAttribute("StatusEffect_Stun", true)
			
			-- 호버보드 엔진 강제 정지 (물리적 고정)
			local hoverboard = char:FindFirstChild("Hoverboard")
			if hoverboard and hoverboard:IsA("Model") and hoverboard.PrimaryPart then
				hoverboard.PrimaryPart.Anchored = true
			else
				root.Anchored = true
			end
			
			task.delay(1.5, function()
				if char and char.Parent then
					char:SetAttribute("StatusEffect_Stun", false)
					
					-- 엔진 정지 해제
					local hoverboard = char:FindFirstChild("Hoverboard")
					if hoverboard and hoverboard:IsA("Model") and hoverboard.PrimaryPart then
						hoverboard.PrimaryPart.Anchored = false
					else
						root.Anchored = false
					end
				end
			end)
			
			-- 레이저 서서히 사라짐
			local ts = TweenService:Create(laserPillar, TweenInfo.new(1.0), {Transparency = 1, Size = Vector3.new(500, 0, 0)})
			ts:Play()
			ts.Completed:Connect(function() laserPillar:Destroy() end)
		end)
	end
end

-- Create Blind Fog
local function fireBlindFog(player: Player)
	local char = player.Character
	if not char or not char.PrimaryPart then return end
	
	setCooldown(player, "Skill_BlindFog")
	
	print("🌫️ [SkillServer] " .. player.Name .. " casted Blind Fog!")
	
	local root = char.PrimaryPart
	-- Find position behind player
	local backwardCFrame = root.CFrame * CFrame.new(0, 0, 50) -- 50 studs behind to start the long fog
	
	-- Raycast down to find ground
	local rayOrigin = backwardCFrame.Position + Vector3.new(0, 20, 0)
	local rayDirection = Vector3.new(0, -100, 0)
	
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {char}
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	
	local rayResult = Workspace:Raycast(rayOrigin, rayDirection, raycastParams)
	local fogPosition = rayResult and rayResult.Position or (backwardCFrame.Position - Vector3.new(0, 3, 0))
	
	-- Create Fog Zone Hitbox
	local fogZone = Instance.new("Part")
	fogZone.Name = "SkillFogZone"
	fogZone.Size = Vector3.new(120, 40, 400) -- 거대한 크기로 확장 (길이 400)
	local centerPos = fogPosition + Vector3.new(0, 10, 0)
	fogZone.CFrame = CFrame.new(centerPos, centerPos + root.CFrame.LookVector)
	fogZone.Transparency = 1
	fogZone.Anchored = true
	fogZone.CanCollide = false
	fogZone.Parent = Workspace
	
	-- 🌫️ 볼류메트릭 안개 구현 (물리적으로 시야를 가리는 거대한 구름 형태)
	for i = 1, 50 do
		local attach = Instance.new("Attachment")
		-- 120x40x400 크기의 박스 내부에 랜덤하게 흩뿌림
		attach.Position = Vector3.new(
			(math.random() - 0.5) * 120,
			(math.random() - 0.5) * 40,
			(math.random() - 0.5) * 400
		)
		attach.Parent = fogZone
		
		local smoke = Instance.new("Smoke")
		smoke.Color = Color3.fromRGB(150, 150, 150) -- 원래의 밝은 회색(안개색)으로 복구
		smoke.Size = 50 -- 연기 덩어리 크기 확대
		smoke.Opacity = 1.0 -- 투명도 없이 완전 빽빽하게
		smoke.RiseVelocity = 0 -- 위로 솟구치지 않고 제자리에 머물게 함
		smoke.Parent = attach
		
		-- 10초 뒤 연기 생성 중지
		task.delay(10, function()
			smoke.Enabled = false
		end)
	end
	
	local activePlayersInFog = {}
	
	fogZone.Touched:Connect(function(hit)
		if not fogZone.Parent then return end
		local targetChar = hit.Parent
		if not targetChar then return end
		
		if targetChar.Name == "Hoverboard" then
			targetChar = targetChar.Parent
		end
		
		local targetPlayer = Players:GetPlayerFromCharacter(targetChar)
		if not targetPlayer then return end
		
		if targetPlayer.UserId == player.UserId then return end -- Caster is immune
		-- 유령화 상태라도 물리적인 안개 지대(지형)에 들어가면 시야가 가려지도록 면역 제외
		
		-- Blind them! (Shield does NOT block this)
		if not activePlayersInFog[targetPlayer.UserId] then
			activePlayersInFog[targetPlayer.UserId] = targetPlayer
			targetChar:SetAttribute("StatusEffect_Blind", true)
			if blindEffectRemote then
				blindEffectRemote:FireClient(targetPlayer, true)
			end
		end
	end)
	
	fogZone.TouchEnded:Connect(function(hit)
		local targetChar = hit.Parent
		if not targetChar then return end
		if targetChar.Name == "Hoverboard" then targetChar = targetChar.Parent end
		
		local targetPlayer = Players:GetPlayerFromCharacter(targetChar)
		if not targetPlayer then return end
		
		-- Simple touch ended check. (For complex shapes, magnitude checks can be safer, but this works for basic rectangular zones)
		if activePlayersInFog[targetPlayer.UserId] then
			activePlayersInFog[targetPlayer.UserId] = nil
			targetChar:SetAttribute("StatusEffect_Blind", false)
			if blindEffectRemote then
				blindEffectRemote:FireClient(targetPlayer, false)
			end
		end
	end)
	
	-- Destroy after 4 seconds
	task.delay(4, function()
		fogParticle.Enabled = false
		
		-- Clear everyone currently in fog
		for userId, p in pairs(activePlayersInFog) do
			if p.Character then
				p.Character:SetAttribute("StatusEffect_Blind", false)
			end
			if blindEffectRemote then
				blindEffectRemote:FireClient(p, false)
			end
		end
		table.clear(activePlayersInFog)
		
		task.delay(3, function()
			if fogZone.Parent then fogZone:Destroy() end
		end)
	end)
end

-- Create Ghost
local function fireGhost(player: Player)
	local char = player.Character
	if not char then return end
	
	setCooldown(player, "Skill_Ghost")
	activeGhosts[player.UserId] = true
	char:SetAttribute("IsGhost", true)
	
	print("👻 [SkillServer] " .. player.Name .. " activated Ghost mode!")
	
	-- Store original transparencies
	local origTransparencies = {}
	
	local function setTransparency(model, trans)
		for _, desc in ipairs(model:GetDescendants()) do
			if desc:IsA("BasePart") and desc.Name ~= "HumanoidRootPart" and desc.Transparency < 1 then
				if trans > 0 then
					if not origTransparencies[desc] then
						origTransparencies[desc] = desc.Transparency
					end
					desc.Transparency = math.max(trans, origTransparencies[desc])
				else
					desc.Transparency = origTransparencies[desc] or 0
				end
			end
		end
	end
	
	setTransparency(char, 0.6)
	
	task.delay(7, function()
		activeGhosts[player.UserId] = false
		print("👻 [SkillServer] " .. player.Name .. "'s Ghost mode expired.")
		if char and char.Parent then
			char:SetAttribute("IsGhost", false)
			setTransparency(char, 0)
		end
	end)
end

-- Create EMP
local function fireEMP(player: Player)
	setCooldown(player, "Skill_EMP")
	print("⚡ [SkillServer] " .. player.Name .. " unleashed EMP!")
	
	-- Global Aurora & Sound Effect via Remote
	if empEffectRemote then
		empEffectRemote:FireAllClients(player.Name)
	end
	
	-- Process all other players within 150 studs
	local char = player.Character
	local root = char and char.PrimaryPart
	if not root then return end
	
	for _, target in ipairs(Players:GetPlayers()) do
		if target.UserId ~= player.UserId then
			local tChar = target.Character
			local tRoot = tChar and tChar.PrimaryPart
			if tChar and tRoot then
				local distance = (root.Position - tRoot.Position).Magnitude
				if distance <= 10000 then -- 범위를 10000으로 늘려 거리 문제인지 확인
					if activeGhosts[target.UserId] then
						print("👻 [SkillServer] " .. target.Name .. " DODGED EMP as a Ghost!")
						continue
					end
					
					if activeShields[target.UserId] then
						print("🛡️ [SkillServer] " .. target.Name .. " BLOCKED EMP with Shield!")
						activeShields[target.UserId] = false
						
						local shieldBreakSound = Instance.new("Sound")
						shieldBreakSound.SoundId = "rbxassetid://600832910" 
						shieldBreakSound.Volume = 1
						shieldBreakSound.Parent = tRoot
						shieldBreakSound:Play()
						game.Debris:AddItem(shieldBreakSound, 2)
						
						if skillWarningRemote then
							skillWarningRemote:FireAllClients(player.Name, target.Name, "Skill_Shield_Break")
						end
						continue
					end
					
					-- Hack target!
					
					-- Show Lightning Icon above head
					local head = tChar:FindFirstChild("Head") or tRoot
					local bg = Instance.new("BillboardGui")
					bg.Name = "EMP_Icon"
					bg.Size = UDim2.new(0, 100, 0, 100)
					bg.StudsOffset = Vector3.new(0, 3, 0)
					bg.AlwaysOnTop = true
					
					local label = Instance.new("TextLabel")
					label.Size = UDim2.new(1, 0, 1, 0)
					label.BackgroundTransparency = 1
					label.Text = "⚡"
					label.TextScaled = true
					label.Parent = bg
					
					bg.Parent = head
					game.Debris:AddItem(bg, 4)
					
					tChar:SetAttribute("StatusEffect_EMP", true)
					task.delay(4, function()
						if tChar and tChar.Parent then
							tChar:SetAttribute("StatusEffect_EMP", false)
						end
					end)
					
					if empHackRemote then
						empHackRemote:FireClient(target)
					end
				end
			end
		end
	end
end

local function firePaintball(caster: Player, target: Player?)
	local casterChar = caster.Character
	if not casterChar or not casterChar.PrimaryPart then return end
	
	setCooldown(caster, "Skill_Paintball")
	
	if not target or not target.Character or not target.Character.PrimaryPart then
		print("🦑 [SkillServer] Paintball fizzled (No Target) for " .. caster.Name)
		return
	end
	
	print("🦑 [SkillServer] Paintball fired by " .. caster.Name .. " at " .. target.Name)
	
	if skillWarningRemote then
		skillWarningRemote:FireAllClients(target.Name, caster.Name, "Skill_Paintball")
	end
	
	task.delay(1.5, function()
		if not target or not target.Character or not target.Character.PrimaryPart then return end
		if activeGhosts[target.UserId] then
			print("👻 [SkillServer] " .. target.Name .. " DODGED Paintball as a Ghost!")
			return
		end
		
		if activeReflects[target.UserId] then
			print("🪞 [SkillServer] " .. target.Name .. " REFLECTED Paintball back to " .. caster.Name .. "!")
			activeReflects[target.UserId] = false
			if skillWarningRemote then
				skillWarningRemote:FireAllClients(caster.Name, target.Name, "Skill_Reflected")
			end
			target = caster
		elseif activeShields[target.UserId] then
			print("🛡️ [SkillServer] " .. target.Name .. " BLOCKED Paintball with a Shield!")
			activeShields[target.UserId] = nil
			return
		end
		
		if paintballEffectRemote then
			paintballEffectRemote:FireClient(target)
		end
	end)
end

-- Create Reflect
local function activateReflect(player: Player)
	local char = player.Character
	if not char or not char.PrimaryPart then return end
	
	-- Max 2 uses per game logic
	local uses = reflectUses[player.UserId] or 0
	if uses >= 2 then
		print("❌ [SkillServer] " .. player.Name .. " reached max reflect uses for this game!")
		return
	end
	
	reflectUses[player.UserId] = uses + 1
	setCooldown(player, "Skill_Reflect")
	activeReflects[player.UserId] = true
	
	print("🪞 [SkillServer] " .. player.Name .. " activated Reflect! (Uses: " .. reflectUses[player.UserId] .. "/2)")
	
	char:SetAttribute("HasReflect", true)
	
	local root = char.PrimaryPart
	
	local reflectPart = Instance.new("Part")
	reflectPart.Name = "SkillReflect"
	reflectPart.Shape = Enum.PartType.Ball
	reflectPart.Size = Vector3.new(12, 12, 12)
	reflectPart.Color = Color3.fromRGB(255, 0, 0) -- 빨간색 (Red)
	reflectPart.Material = Enum.Material.ForceField
	reflectPart.Transparency = 0.5
	reflectPart.Anchored = false
	reflectPart.CanCollide = false
	reflectPart.Massless = true
	
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = reflectPart
	weld.Parent = reflectPart
	
	reflectPart.CFrame = root.CFrame
	reflectPart.Parent = char
	
	-- 발동 사운드
	local startSound = Instance.new("Sound")
	startSound.SoundId = "rbxassetid://12222076" -- SF 에너지 쉴드 발동음
	startSound.Parent = root
	startSound:Play()
	game:GetService("Debris"):AddItem(startSound, 2)
	
	-- 맥박 뛰는(Pulse) 애니메이션
	local pulseInfo = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	local pulseTween = TweenService:Create(reflectPart, pulseInfo, {
		Size = Vector3.new(13, 13, 13),
		Transparency = 0.3
	})
	pulseTween:Play()
	
	-- No time limit, stays active until used.
	task.spawn(function()
		while reflectPart.Parent do
			if not activeReflects[player.UserId] then
				-- Broken/Used!
				if char and char.Parent then
					char:SetAttribute("HasReflect", false)
				end
				pulseTween:Cancel()
				
				-- 방어 성공 사운드
				local breakSound = Instance.new("Sound")
				breakSound.SoundId = "rbxassetid://258057783"
				breakSound.Volume = 1
				breakSound.Parent = root
				breakSound:Play()
				game:GetService("Debris"):AddItem(breakSound, 2)
				
				-- 방어막 깜빡거림 연출
				if reflectPart and reflectPart.Parent then
					for i = 1, 4 do
						if not reflectPart or not reflectPart.Parent then break end
						reflectPart.Transparency = 1
						task.wait(0.08)
						if not reflectPart or not reflectPart.Parent then break end
						reflectPart.Transparency = 0.2
						task.wait(0.08)
					end
					
					if reflectPart and reflectPart.Parent then
						reflectPart:Destroy()
					end
				end
				break
			end
			task.wait(0.1)
		end
	end)
end

-- [Premium Skill: Golden Freeze]
local function fireGoldenFreeze(caster: Player, target: Player?)
	local casterChar = caster.Character
	if not casterChar or not casterChar.PrimaryPart then return end
	
	setCooldown(caster, "Skill_Premium")
	
	if not target or not target.Character or not target.Character.PrimaryPart then
		print("✨ [SkillServer] Golden Freeze fizzled (No Target) for " .. caster.Name)
		return
	end
	
	print("✨ [SkillServer] Golden Freeze fired by " .. caster.Name .. " at " .. target.Name .. " (Will hit in 1.0 seconds)")
	
	if skillWarningRemote then
		skillWarningRemote:FireAllClients(target.Name, caster.Name, "Skill_Premium")
	end
	
	-- 서버는 타겟을 찾아 1.0초 뒤에 꽂히는 판정 수행
	task.delay(1.0, function()
		if not target or not target.Character or not target.Character.PrimaryPart then return end
		local targetChar = target.Character
		local targetRoot = targetChar.PrimaryPart
		
		if activeGhosts[target.UserId] then
			print("👻 [SkillServer] " .. target.Name .. " DODGED Golden Freeze as a Ghost!")
			return
		end
			
			if not target or not target.Character or not target.Character.PrimaryPart then return end
			local targetChar = target.Character
			local targetRoot = targetChar.PrimaryPart
			
			-- 타격 직전 반사 체크
			if activeReflects[target.UserId] then
				print("🪞 [SkillServer] " .. target.Name .. " REFLECTED Golden Freeze back to " .. caster.Name .. "!")
				activeReflects[target.UserId] = false
				
				if skillWarningRemote then
					skillWarningRemote:FireAllClients(caster.Name, target.Name, "Skill_Reflected")
				end
				
				target = caster
				targetChar = target.Character
				targetRoot = targetChar.PrimaryPart
			elseif activeShields[target.UserId] then
				print("🛡️ [SkillServer] " .. target.Name .. " BLOCKED Golden Freeze with a Shield!")
				activeShields[target.UserId] = false
				
				if skillWarningRemote then
					skillWarningRemote:FireAllClients(caster.Name, target.Name, "Skill_Shield_Break")
				end
				return
			end
			
			-- 타격 파티클 이펙트
			local hitAtt = Instance.new("Attachment", targetRoot)
			local hitEmit = Instance.new("ParticleEmitter")
			hitEmit.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 5), NumberSequenceKeypoint.new(1, 15)})
			hitEmit.Transparency = NumberSequence.new(0, 1)
			hitEmit.Color = ColorSequence.new(Color3.fromRGB(255, 223, 0))
			hitEmit.Speed = NumberRange.new(50, 100)
			hitEmit.Drag = 5
			hitEmit.Lifetime = NumberRange.new(0.5, 1)
			hitEmit.Rate = 0
			hitEmit.SpreadAngle = Vector2.new(180, 180)
			hitEmit.Parent = hitAtt
			hitEmit:Emit(150)
			game:GetService("Debris"):AddItem(hitAtt, 2)
			
			-- FREEZE TARGET (길게 얼림)
			print("✨ [SkillServer] " .. target.Name .. " is GOLDEN FROZEN by " .. caster.Name .. "!")
			
			targetChar:SetAttribute("StatusEffect_Frozen", true)
			
			local hoverboard = targetChar:FindFirstChild("Hoverboard")
			if hoverboard and hoverboard:IsA("Model") and hoverboard.PrimaryPart then
				hoverboard.PrimaryPart.Anchored = true
			else
				targetRoot.Anchored = true
			end
			
			-- 황금 파티클 입자로 몸을 감싸기! (클라이언트에서 200개의 개별 파티클이 감싸므로 서버 안개 파티클 제거)
			local iceAtt = Instance.new("Attachment", targetRoot)
			iceAtt.Name = "GoldenFreezeCoating"
			
			-- 몸 전체에서 빛나도록 조명 추가
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 215, 0)
			light.Range = 12
			light.Brightness = 3
			light.Parent = iceAtt

			
			local humanoid = targetChar:FindFirstChild("Humanoid")
			local animator = humanoid and humanoid:FindFirstChild("Animator")
			local pausedTracks = {}
			if animator then
				for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
					track:AdjustSpeed(0)
					table.insert(pausedTracks, track)
				end
			end
			
			-- 5초간 스무스하게 멈추고 풀림
			task.delay(5, function()
				if targetChar and targetChar.Parent then
					targetChar:SetAttribute("StatusEffect_Frozen", false)
				end
				if hoverboard and hoverboard:IsA("Model") and hoverboard.PrimaryPart then
					hoverboard.PrimaryPart.Anchored = false
				elseif targetRoot and targetRoot.Parent then
					targetRoot.Anchored = false
				end
				
				for _, track in ipairs(pausedTracks) do
					if track.IsPlaying then
						track:AdjustSpeed(1)
					end
				end
				
				if iceAtt and iceAtt.Parent then
					-- 스무스하게 사라지게 하기 위해 빛 꺼지기 (안개 파티클은 제거됨)
					for _, child in ipairs(iceAtt:GetChildren()) do
						if child:IsA("PointLight") then
							game:GetService("TweenService"):Create(child, TweenInfo.new(1), {Brightness = 0}):Play()
						end
					end
					
					-- 남은 입자가 다 사라지면 삭제
					game:GetService("Debris"):AddItem(iceAtt, 2)
				end
				
				local shatterSound = Instance.new("Sound")
				shatterSound.SoundId = "rbxassetid://131148590"
				shatterSound.Volume = 0.8
				shatterSound.Parent = targetRoot
				shatterSound:Play()
				game:GetService("Debris"):AddItem(shatterSound, 2)
			end)
	end)
end

if useSkillRemote then
	useSkillRemote.OnServerEvent:Connect(function(player: Player, skillId: string)
		if not canUseSkill(player, skillId) then
			print("⏳ [SkillServer] " .. player.Name .. " tried to use " .. skillId .. " but it's on cooldown.")
			return
		end
		
		if globalSkillCastRemote then
			globalSkillCastRemote:FireAllClients(player.UserId, skillId)
		end
		
		if skillId == "Skill_IceBomb" then
			local target = LapManager.getPlayerAhead(player.UserId)
			fireIceBomb(player, target)
		elseif skillId == "Skill_Premium" then
			local target = LapManager.getPlayerAhead(player.UserId)
			fireGoldenFreeze(player, target)
		elseif skillId == "Skill_Paintball" then
			local target = LapManager.getPlayerAhead(player.UserId)
			firePaintball(player, target)
		elseif skillId == "Skill_Reflect" then
			activateReflect(player)
		elseif skillId == "Skill_Shield" then
			fireShield(player)
		elseif skillId == "Skill_OrbitalLaser" then
			fireOrbitalLaser(player)
		elseif skillId == "Skill_BlindFog" then
			fireBlindFog(player)
		elseif skillId == "Skill_Ghost" then
			fireGhost(player)
		elseif skillId == "Skill_EMP" then
			fireEMP(player)
		end
	end)
end
