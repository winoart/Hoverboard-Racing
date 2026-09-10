--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MapManager = require(Shared:WaitForChild("MapManager") :: ModuleScript)

local remotesFolder = ReplicatedStorage:WaitForChild("HoverboardRemotes")

local exitTreadmillRemote = remotesFolder:FindFirstChild("ExitTreadmill") :: RemoteEvent?
if not exitTreadmillRemote then
	exitTreadmillRemote = Instance.new("RemoteEvent")
	exitTreadmillRemote.Name = "ExitTreadmill"
	exitTreadmillRemote.Parent = remotesFolder
end

local function getTreadmillModel()
	local lounge = Workspace:FindFirstChild("WaitingRoomLounge") or Workspace:FindFirstChild("WaitingRoom")
	if lounge then
		return lounge:FindFirstChild("Treadmill1")
	end
	return nil
end

local function dismountTreadmill(player: Player)
	if not player:GetAttribute("OnTreadmill") then return end
	player:SetAttribute("OnTreadmill", false)
	
	local char = player.Character
	if char then
		local board = char:FindFirstChild("EquippedHoverboard")
		if board then board:Destroy() end
		
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.PlatformStand = false
			-- Slight jump backward to exit
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if hrp then
				hrp.Anchored = false
				hrp.CFrame = hrp.CFrame * CFrame.new(0, 2, 5)
			end
		end
	end
end

local function mountTreadmill(player: Player, beltPart: BasePart)
	if player:GetAttribute("OnTreadmill") then return end
	if player:GetAttribute("IsRacing") then return end
	if player:GetAttribute("IsAFK") then return end
	
	local char = player.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart
	local hum = char:FindFirstChildOfClass("Humanoid") :: Humanoid
	if not hrp or not hum then return end
	
	player:SetAttribute("OnTreadmill", true)
	
	-- Mount Hoverboard Logic
	local hoverboardModels = ReplicatedStorage:FindFirstChild("HoverboardModels")
	local equippedId = player:FindFirstChild("EquippedHoverboardId")
	local boardName = equippedId and equippedId.Value or "DefaultHoverboard"
	local boardTemplate = hoverboardModels and hoverboardModels:FindFirstChild(boardName)
	if not boardTemplate and hoverboardModels then
		boardTemplate = hoverboardModels:FindFirstChild("DefaultHoverboard") or hoverboardModels:GetChildren()[1]
	end
	
	if boardTemplate then
		for _, child in ipairs(char:GetChildren()) do
			if child.Name == "EquippedHoverboard" then child:Destroy() end
		end
		
		local boardClone = boardTemplate:Clone()
		boardClone.Name = "EquippedHoverboard"
		
		local rootPart = boardClone.PrimaryPart or boardClone:FindFirstChild("RootPart") or boardClone:FindFirstChild("Base")
		if rootPart then
			-- Fix character to treadmill center
			hrp.AssemblyLinearVelocity = Vector3.zero
			hrp.AssemblyAngularVelocity = Vector3.zero
			
			-- Anchor the hrp so they don't slide off
			hrp.Anchored = true
			
			-- Position character hovering slightly above belt, facing the screen (-Z direction)
			hrp.CFrame = beltPart.CFrame * CFrame.new(0, 3.5, 0) * CFrame.Angles(0, math.rad(180), 0)
			
			-- Unanchor board and weld it so it moves together
			for _, part in ipairs(boardClone:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Anchored = false
					part.CanCollide = false
					part.Massless = true
				end
			end
			
			for _, part in ipairs(boardClone:GetDescendants()) do
				if part:IsA("BasePart") and part ~= rootPart then
					local wc = Instance.new("WeldConstraint")
					wc.Part0 = rootPart
					wc.Part1 = part
					wc.Parent = part
				end
			end
			
			-- Safely move the entire model
			boardClone:PivotTo(hrp.CFrame * CFrame.new(0, -3.25, 0))
			boardClone.Parent = char
			
			local weld = Instance.new("Weld")
			weld.Name = "HoverWeld"
			weld.Part0 = hrp
			weld.Part1 = rootPart
			weld.C0 = CFrame.new(0, -3.25, 0)
			weld.Parent = rootPart
			
			-- Notify client so HUD and Camera initialize
			local stateRemote = remotesFolder:FindFirstChild("StateChanged") :: RemoteEvent?
			if stateRemote then
				stateRemote:FireClient(player, true, boardClone)
			end
			
			
		end
	end
end

-- Monitor treadmills and animate belts
task.spawn(function()
	task.wait(5) -- Wait for lounge to spawn
	local model = getTreadmillModel()
	if not model then
		warn("[TreadmillManager] Treadmill1 not found in WaitingRoomLounge!")
		return
	end
	
	local belts = {}
	
	local hitbox = model:FindFirstChild("Hitbox")
	local belt = model:FindFirstChild("Belt")
	if hitbox and belt then
		local tex = belt:FindFirstChild("BeltTexture")
		if tex then table.insert(belts, tex) end
		
		hitbox.Touched:Connect(function(hit)
			local character = hit.Parent
			local player = Players:GetPlayerFromCharacter(character)
			if player then
				mountTreadmill(player, belt)
			end
		end)
	end
	
	RunService.Heartbeat:Connect(function(dt)
		for _, tex in ipairs(belts) do
			if tex and tex:IsA("Texture") and tex.StudsPerTileV > 0 then
				tex.OffsetStudsV = (tex.OffsetStudsV - dt * 2) % tex.StudsPerTileV
			end
		end
	end)
end)

-- Handle Jump Exit
exitTreadmillRemote.OnServerEvent:Connect(function(player)
	dismountTreadmill(player)
end)

-- Force dismount when race phase changes or teleported
Workspace:GetAttributeChangedSignal("GamePhase"):Connect(function()
	local phase = Workspace:GetAttribute("GamePhase")
	if phase == "COUNTDOWN" or phase == "INTERMISSION" then
		for _, player in ipairs(Players:GetPlayers()) do
			dismountTreadmill(player)
		end
	end
end)
