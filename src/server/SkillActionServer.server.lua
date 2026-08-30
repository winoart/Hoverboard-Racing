--!strict
-- SkillActionServer.server.lua
-- Handles skill usages during the race

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local LapManager = require(script.Parent:WaitForChild("LapManager") :: ModuleScript)

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

local empEffectRemote = remotesFolder:FindFirstChild("EMPEffect") :: RemoteEvent?
if not empEffectRemote then
	empEffectRemote = Instance.new("RemoteEvent")
	empEffectRemote.Name = "EMPEffect"
	empEffectRemote.Parent = remotesFolder
end

-- Skill Cooldown Tracking (Server side)
local playerCooldowns: { [number]: { [string]: number } } = {}
local SKILL_COOLDOWNS = {
	Skill_IceBomb = 10,
	Skill_Shield = 15,
	Skill_IceTrap = 15,
	Skill_BlindFog = 15,
	Skill_Ghost = 20,
	Skill_EMP = 30,
}

local activeShields: { [number]: boolean } = {}
local activeGhosts: { [number]: boolean } = {}

local function canUseSkill(player: Player, skillId: string): boolean
	local pCooldowns = playerCooldowns[player.UserId]
	if not pCooldowns then return true end
	
	local lastUsed = pCooldowns[skillId]
	if not lastUsed then return true end
	
	local cooldownDuration = SKILL_COOLDOWNS[skillId] or 10
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
end

-- Create Ice Bomb Projectile and Fire
local function fireIceBomb(caster: Player, target: Player?)
	local casterChar = caster.Character
	if not casterChar or not casterChar.PrimaryPart then return end
	
	setCooldown(caster, "Skill_IceBomb")
	
	-- 1. Create Projectile Part
	local projectile = Instance.new("Part")
	projectile.Name = "IceBombProjectile"
	projectile.Shape = Enum.PartType.Ball
	projectile.Size = Vector3.new(2, 2, 2)
	projectile.Color = Color3.fromRGB(100, 200, 255)
	projectile.Material = Enum.Material.Ice
	projectile.CanCollide = false
	projectile.Anchored = true
	projectile.Position = casterChar.PrimaryPart.Position + Vector3.new(0, 5, 0)
	projectile.Parent = Workspace
	
	-- Add some basic particle to projectile
	local trail = Instance.new("Trail")
	local a0 = Instance.new("Attachment", projectile)
	a0.Position = Vector3.new(0, 1, 0)
	local a1 = Instance.new("Attachment", projectile)
	a1.Position = Vector3.new(0, -1, 0)
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.5
	trail.Color = ColorSequence.new(Color3.fromRGB(150, 220, 255))
	trail.Parent = projectile
	
	if not target or not target.Character or not target.Character.PrimaryPart then
		-- Fizzle (No Target / 1st place)
		print("❄️ [SkillServer] Ice Bomb fizzled (No Target) for " .. caster.Name)
		
		-- Small pop animation
		local ts = TweenService:Create(projectile, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(4, 4, 4),
			Transparency = 1
		})
		ts:Play()
		ts.Completed:Connect(function()
			projectile:Destroy()
		end)
		return
	end
	
	-- We have a target! Tween it to the target
	print("❄️ [SkillServer] Ice Bomb fired by " .. caster.Name .. " at " .. target.Name)
	
	if skillWarningRemote then
		skillWarningRemote:FireClient(target, caster.Name, "Skill_IceBomb")
	end
	
	local targetChar = target.Character
	local targetRoot = targetChar.PrimaryPart
	
	-- Simple following logic using Heartbeat (since target is moving)
	local RunService = game:GetService("RunService")
	local connection
	local speed = 120 -- studs per sec
	
	connection = RunService.Heartbeat:Connect(function(dt)
		if not projectile.Parent or not targetRoot or not targetRoot.Parent then
			if connection then connection:Disconnect() end
			projectile:Destroy()
			return
		end
		
		local dir = (targetRoot.Position - projectile.Position)
		local dist = dir.Magnitude
		
		if dist < 5 then
			-- Hit!
			connection:Disconnect()
			projectile:Destroy()
			
			if activeGhosts[target.UserId] then
				print("👻 [SkillServer] " .. target.Name .. " DODGED Ice Bomb as a Ghost!")
				return
			end
			
			if activeShields[target.UserId] then
				print("🛡️ [SkillServer] " .. target.Name .. " BLOCKED Ice Bomb with a Shield!")
				
				-- Break shield
				activeShields[target.UserId] = false
				
				local shieldBreakSound = Instance.new("Sound")
				shieldBreakSound.SoundId = "rbxassetid://600832910" -- Glass shatter sound (placeholder)
				shieldBreakSound.Volume = 1
				shieldBreakSound.Parent = targetRoot
				shieldBreakSound:Play()
				
				if skillWarningRemote then
					skillWarningRemote:FireClient(caster, target.Name, "Skill_Shield_Break")
				end
				
				game.Debris:AddItem(shieldBreakSound, 2)
				return
			end
			
			-- FREEZE TARGET
			print("❄️ [SkillServer] " .. target.Name .. " is FROZEN by " .. caster.Name .. "!")
			
			local hoverboard = targetChar:FindFirstChild("Hoverboard")
			if hoverboard and hoverboard:IsA("Model") and hoverboard.PrimaryPart then
				hoverboard.PrimaryPart.Anchored = true
			else
				targetRoot.Anchored = true
			end
			
			-- Ice Block visual on target
			local iceBlock = Instance.new("Part")
			iceBlock.Name = "IceBlockFreeze"
			iceBlock.Size = Vector3.new(6, 6, 6)
			iceBlock.CFrame = targetRoot.CFrame
			iceBlock.Color = Color3.fromRGB(150, 220, 255)
			iceBlock.Material = Enum.Material.Ice
			iceBlock.Transparency = 0.4
			iceBlock.Anchored = true
			iceBlock.CanCollide = false
			iceBlock.Parent = targetChar
			
			-- Unfreeze after 2 seconds
			task.delay(2, function()
				if hoverboard and hoverboard:IsA("Model") and hoverboard.PrimaryPart then
					hoverboard.PrimaryPart.Anchored = false
				elseif targetRoot and targetRoot.Parent then
					targetRoot.Anchored = false
				end
				
				if iceBlock and iceBlock.Parent then
					-- Shatter animation
					local shatterTween = TweenService:Create(iceBlock, TweenInfo.new(0.3), {
						Size = Vector3.new(8, 8, 8),
						Transparency = 1
					})
					shatterTween:Play()
					shatterTween.Completed:Connect(function()
						iceBlock:Destroy()
					end)
				end
			end)
		else
			-- Move towards target
			projectile.Position += dir.Unit * speed * dt
		end
	end)
end

-- Create Shield
local function fireShield(player: Player)
	local char = player.Character
	if not char or not char.PrimaryPart then return end
	
	setCooldown(player, "Skill_Shield")
	activeShields[player.UserId] = true
	
	print("🛡️ [SkillServer] " .. player.Name .. " activated Shield!")
	
	local root = char.PrimaryPart
	
	local shieldPart = Instance.new("Part")
	shieldPart.Name = "SkillShield"
	shieldPart.Shape = Enum.PartType.Ball
	shieldPart.Size = Vector3.new(12, 12, 12)
	shieldPart.Color = Color3.fromRGB(150, 200, 255)
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
	
	-- Keep track of state
	task.delay(5, function()
		if activeShields[player.UserId] then
			activeShields[player.UserId] = false
			print("🛡️ [SkillServer] " .. player.Name .. "'s Shield expired naturally.")
			
			if shieldPart.Parent then
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
				local ts = TweenService:Create(shieldPart, TweenInfo.new(0.2), {Transparency = 1, Size = Vector3.new(15, 15, 15)})
				ts:Play()
				ts.Completed:Connect(function()
					shieldPart:Destroy()
				end)
				break
			end
			task.wait(0.1)
		end
	end)
end

-- Create Ice Trap
local function fireIceTrap(player: Player)
	local char = player.Character
	if not char or not char.PrimaryPart then return end
	
	setCooldown(player, "Skill_IceTrap")
	
	print("🧊 [SkillServer] " .. player.Name .. " placed an Ice Trap!")
	
	local root = char.PrimaryPart
	-- Find position behind player
	local backwardCFrame = root.CFrame * CFrame.new(0, 0, 15) -- 15 studs behind
	
	-- Raycast down to find ground
	local rayOrigin = backwardCFrame.Position + Vector3.new(0, 10, 0)
	local rayDirection = Vector3.new(0, -50, 0)
	
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {char}
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	
	local rayResult = Workspace:Raycast(rayOrigin, rayDirection, raycastParams)
	local trapPosition = rayResult and rayResult.Position or (backwardCFrame.Position - Vector3.new(0, 3, 0))
	local trapNormal = rayResult and rayResult.Normal or Vector3.new(0, 1, 0)
	
	-- Create Ice Trap part (A flat cylinder/disc)
	local trapPart = Instance.new("Part")
	trapPart.Name = "IceTrapField"
	trapPart.Shape = Enum.PartType.Cylinder
	trapPart.Size = Vector3.new(1, 20, 20) -- Flat disc (Cylinder is oriented along X axis by default)
	trapPart.CFrame = CFrame.lookAt(trapPosition, trapPosition + trapNormal) * CFrame.Angles(0, math.pi/2, 0)
	-- To make a flat disc on the ground:
	trapPart.CFrame = CFrame.new(trapPosition) * CFrame.Angles(0, 0, math.pi/2) 
	-- If ground is sloped, we align with normal
	if rayResult then
		trapPart.CFrame = CFrame.lookAt(trapPosition, trapPosition + trapNormal) * CFrame.Angles(0, math.pi/2, 0)
	end
	
	trapPart.Color = Color3.fromRGB(150, 220, 255)
	trapPart.Material = Enum.Material.Ice
	trapPart.Transparency = 0.5
	trapPart.Anchored = true
	trapPart.CanCollide = false
	trapPart.Parent = Workspace
	
	local hitDebounce = {}
	
	trapPart.Touched:Connect(function(hit)
		if not trapPart.Parent then return end
		local targetChar = hit.Parent
		if not targetChar then return end
		
		-- Also support if it hits Hoverboard parts
		if targetChar.Name == "Hoverboard" then
			targetChar = targetChar.Parent
		end
		
		local targetPlayer = Players:GetPlayerFromCharacter(targetChar)
		if not targetPlayer then return end
		
		if targetPlayer.UserId == player.UserId then return end -- Caster is immune
		if hitDebounce[targetPlayer.UserId] then return end
		if activeGhosts[targetPlayer.UserId] then return end -- Ghosts are immune
		
		hitDebounce[targetPlayer.UserId] = true
		
		-- Target stepped on trap!
		local targetRoot = targetChar.PrimaryPart
		if not targetRoot then return end
		
		if activeShields[targetPlayer.UserId] then
			print("🛡️ [SkillServer] " .. targetPlayer.Name .. " BLOCKED Ice Trap with a Shield!")
			activeShields[targetPlayer.UserId] = false
			
			local shieldBreakSound = Instance.new("Sound")
			shieldBreakSound.SoundId = "rbxassetid://600832910" 
			shieldBreakSound.Volume = 1
			shieldBreakSound.Parent = targetRoot
			shieldBreakSound:Play()
			
			if skillWarningRemote then
				skillWarningRemote:FireClient(player, targetPlayer.Name, "Skill_Shield_Break")
			end
			
			game.Debris:AddItem(shieldBreakSound, 2)
			
			-- Debounce clear in case they step on it again later?
			task.delay(1, function() hitDebounce[targetPlayer.UserId] = nil end)
			return
		end
		
		-- Apply Slip Effect (Option C)
		print("🌀 [SkillServer] " .. targetPlayer.Name .. " slipped on Ice Trap!")
		
		if skillWarningRemote then
			skillWarningRemote:FireClient(targetPlayer, player.Name, "Skill_IceTrap")
		end
		
		-- Spin out of control using AngularVelocity
		local spinAttachment = Instance.new("Attachment", targetRoot)
		local spinMover = Instance.new("AngularVelocity")
		spinMover.Attachment0 = spinAttachment
		spinMover.AngularVelocity = Vector3.new(0, 30, 0) -- Spin rapidly around Y axis
		spinMover.MaxTorque = 10000000
		spinMover.Parent = targetRoot
		
		-- Slip sound
		local slipSound = Instance.new("Sound")
		slipSound.SoundId = "rbxassetid://4612261623" -- Funny slip/spin sound placeholder
		slipSound.Volume = 1
		slipSound.Parent = targetRoot
		slipSound:Play()
		game.Debris:AddItem(slipSound, 2)
		
		-- Optional: Freeze their forward momentum by disabling thrust locally?
		-- We can just let them spin wildly for 2 seconds.
		
		task.delay(2, function()
			if spinMover.Parent then spinMover:Destroy() end
			if spinAttachment.Parent then spinAttachment:Destroy() end
			hitDebounce[targetPlayer.UserId] = nil -- Can be hit again if they stay
		end)
	end)
	
	-- Destroy trap after 5 seconds
	task.delay(5, function()
		if trapPart.Parent then
			local ts = TweenService:Create(trapPart, TweenInfo.new(0.5), {Transparency = 1, Size = Vector3.new(1, 0, 0)})
			ts:Play()
			ts.Completed:Connect(function()
				trapPart:Destroy()
			end)
		end
	end)
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
	fogZone.Size = Vector3.new(60, 20, 100)
	fogZone.CFrame = CFrame.new(fogPosition + Vector3.new(0, 10, 0), fogPosition + root.CFrame.LookVector)
	fogZone.Transparency = 1
	fogZone.Anchored = true
	fogZone.CanCollide = false
	fogZone.Parent = Workspace
	
	-- Visual Particle for the fog
	local attachment = Instance.new("Attachment", fogZone)
	local fogParticle = Instance.new("ParticleEmitter")
	fogParticle.Texture = "rbxassetid://6834047814" -- Smoke texture placeholder
	fogParticle.Color = ColorSequence.new(Color3.fromRGB(150, 150, 150))
	fogParticle.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 20), NumberSequenceKeypoint.new(1, 30)})
	fogParticle.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.4), NumberSequenceKeypoint.new(0.8, 0.4), NumberSequenceKeypoint.new(1, 1)})
	fogParticle.Lifetime = NumberRange.new(2, 3)
	fogParticle.Rate = 50
	fogParticle.Speed = NumberRange.new(5, 10)
	fogParticle.SpreadAngle = Vector2.new(180, 180)
	fogParticle.EmissionDirection = Enum.NormalId.Top
	fogParticle.Parent = attachment
	
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
		if activeGhosts[targetPlayer.UserId] then return end -- Ghosts are immune
		
		-- Blind them! (Shield does NOT block this)
		if not activePlayersInFog[targetPlayer.UserId] then
			activePlayersInFog[targetPlayer.UserId] = targetPlayer
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
			if blindEffectRemote then
				blindEffectRemote:FireClient(targetPlayer, false)
			end
		end
	end)
	
	-- Destroy after 5 seconds
	task.delay(5, function()
		fogParticle.Enabled = false
		
		-- Clear everyone currently in fog
		for userId, p in pairs(activePlayersInFog) do
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
	
	-- Process all other players
	for _, target in ipairs(Players:GetPlayers()) do
		if target.UserId ~= player.UserId then
			local tChar = target.Character
			local tRoot = tChar and tChar.PrimaryPart
			if tChar and tRoot then
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
						skillWarningRemote:FireClient(player, target.Name, "Skill_Shield_Break")
					end
					continue
				end
				
				-- Stun target!
				print("⚡ [SkillServer] " .. target.Name .. "'s engine SHUTDOWN by EMP!")
				
				local hoverboard = tChar:FindFirstChild("Hoverboard")
				if hoverboard and hoverboard:IsA("Model") and hoverboard.PrimaryPart then
					hoverboard.PrimaryPart.Anchored = true
				else
					tRoot.Anchored = true
				end
				
				-- Zap particle
				local zap = Instance.new("ParticleEmitter")
				zap.Texture = "rbxassetid://725099363" -- Lightning/spark texture
				zap.Color = ColorSequence.new(Color3.fromRGB(0, 255, 255))
				zap.Rate = 50
				zap.Speed = NumberRange.new(5, 10)
				zap.Lifetime = NumberRange.new(0.5, 1)
				zap.Size = NumberSequence.new(2)
				zap.Parent = tRoot
				
				task.delay(2, function()
					if hoverboard and hoverboard:IsA("Model") and hoverboard.PrimaryPart then
						hoverboard.PrimaryPart.Anchored = false
					elseif tRoot and tRoot.Parent then
						tRoot.Anchored = false
					end
					zap.Enabled = false
					game.Debris:AddItem(zap, 1)
				end)
			end
		end
	end
end

if useSkillRemote then
	useSkillRemote.OnServerEvent:Connect(function(player: Player, skillId: string)
		if not canUseSkill(player, skillId) then
			print("⏳ [SkillServer] " .. player.Name .. " tried to use " .. skillId .. " but it's on cooldown.")
			return
		end
		
		if skillId == "Skill_IceBomb" then
			local target = LapManager.getPlayerAhead(player.UserId)
			fireIceBomb(player, target)
		elseif skillId == "Skill_Shield" then
			fireShield(player)
		elseif skillId == "Skill_IceTrap" then
			fireIceTrap(player)
		elseif skillId == "Skill_BlindFog" then
			fireBlindFog(player)
		elseif skillId == "Skill_Ghost" then
			fireGhost(player)
		elseif skillId == "Skill_EMP" then
			fireEMP(player)
		end
	end)
end
