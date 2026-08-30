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

-- Skill Cooldown Tracking (Server side)
local playerCooldowns: { [number]: { [string]: number } } = {}
local SKILL_COOLDOWNS = {
	Skill_IceBomb = 10,
}

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
	local speed = 80 -- studs per sec
	
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
	
	-- Max duration safety
	task.delay(5, function()
		if connection then connection:Disconnect() end
		if projectile.Parent then projectile:Destroy() end
	end)
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
		end
	end)
end
