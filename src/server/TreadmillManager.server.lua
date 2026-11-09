--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local HoverboardConfig = require(Shared:WaitForChild("HoverboardConfig"))

local remotesFolder = ReplicatedStorage:WaitForChild("HoverboardRemotes")

-- Remove unused remotes for treadmill
local exitTreadmillRemote = remotesFolder:FindFirstChild("ExitTreadmill")
if exitTreadmillRemote then exitTreadmillRemote:Destroy() end
local toggleTreadmillBoardRemote = remotesFolder:FindFirstChild("ToggleTreadmillBoard")
if toggleTreadmillBoardRemote then toggleTreadmillBoardRemote:Destroy() end

local TREADMILL_MODELS = {}
local TREADMILL_HITBOXES = {}
local playersOnTreadmill = {}

-- Setup Treadmills
task.spawn(function()
	local lounge = nil
	for _ = 1, 20 do
		lounge = Workspace:FindFirstChild("WaitingRoomLounge") or Workspace:FindFirstChild("WaitingRoom")
		if lounge then break end
		task.wait(0.5)
	end
	if not lounge then return end
	
	for _, model in ipairs(lounge:GetChildren()) do
		if model.Name:find("Treadmill") then
			table.insert(TREADMILL_MODELS, model)
			
			local hitbox = model:FindFirstChild("Hitbox") :: BasePart?
			if hitbox then
				hitbox.CanCollide = false
				hitbox.CanQuery = false
				table.insert(TREADMILL_HITBOXES, hitbox)
			end
			
			-- Screen UI 초기화 (기존 템플릿 제거 방지, HUD 유지)
			local screen = model:FindFirstChild("Screen") :: BasePart?
			if screen then
				for _, child in ipairs(screen:GetChildren()) do
					if child.Name == "DashboardGui" then
						child:Destroy()
					end
				end
			end
		end
	end
end)

local function attachBoardToPlayer(player: Player)
	local char = player.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then return end

	local hoverboardModels = ReplicatedStorage:FindFirstChild("HoverboardModels")
	local equippedId = player:FindFirstChild("EquippedHoverboardId")
	local boardName = equippedId and equippedId.Value or "DefaultHoverboard"
	local boardTemplate = hoverboardModels and hoverboardModels:FindFirstChild(boardName)
	if not boardTemplate and hoverboardModels then
		boardTemplate = hoverboardModels:FindFirstChild("DefaultHoverboard") or hoverboardModels:GetChildren()[1]
	end
	
	if boardTemplate then
		for _, child in ipairs(char:GetChildren()) do
			if child.Name == "EquippedHoverboard" or child.Name:lower():find("hoverboard") then
				child:Destroy()
			end
		end
		
		local boardClone = boardTemplate:Clone()
		boardClone.Name = "EquippedHoverboard"
		
		for _, part in ipairs(boardClone:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Anchored = false
				part.CanCollide = false
				part.CanQuery = false
				part.Massless = true
			end
		end
		
		local rootPart = boardClone.PrimaryPart or boardClone:FindFirstChild("RootPart") or boardClone:FindFirstChild("Base")
		if rootPart then
			for _, part in ipairs(boardClone:GetDescendants()) do
				if part:IsA("BasePart") and part ~= rootPart then
					local wc = Instance.new("WeldConstraint")
					wc.Part0 = rootPart
					wc.Part1 = part
					wc.Parent = part
				end
			end
			
			local rotYaw = boardTemplate:GetAttribute("RotationYaw")
			if rotYaw == nil then
				local success, _, bboxSize = pcall(function() return boardTemplate:GetBoundingBox() end)
				if success and bboxSize and bboxSize.X > bboxSize.Z then
					rotYaw = 90
				else
					rotYaw = 0
				end
			end
			if boardName == "MagicBroom" and rotYaw == 0 then rotYaw = 180 end
			local heightOffset = boardTemplate:GetAttribute("HeightOffset") or 0

			boardClone:SetAttribute("RotationYaw", rotYaw)
			boardClone:SetAttribute("HeightOffset", heightOffset)

			local rotationOffset = CFrame.Angles(0, math.rad(rotYaw), 0)
			local weldC0 = CFrame.new(0, -3.25 + heightOffset, 0) * rotationOffset

			local weld = Instance.new("Weld")
			weld.Name = "HoverWeld"
			weld.Part0 = hrp
			weld.Part1 = rootPart
			weld.C0 = weldC0
			weld.Parent = rootPart

			boardClone:PivotTo(hrp.CFrame * weldC0)
			boardClone.Parent = char
		end
	end
end

local function removeBoardFromPlayer(player: Player)
	local char = player.Character
	if char then
		for _, child in ipairs(char:GetChildren()) do
			if child.Name == "EquippedHoverboard" or child.Name:lower():find("hoverboard") then
				child:Destroy()
			end
		end
	end
end

-- Zone Detection Loop
-- (playersOnTreadmill is declared at the top of script)

RunService.Heartbeat:Connect(function()
	if #TREADMILL_HITBOXES == 0 then return end
	
	local overlapParams = OverlapParams.new()
	local currentPlayersInZone = {}
	
	for _, hitbox in ipairs(TREADMILL_HITBOXES) do
		local partsInZone = Workspace:GetPartsInPart(hitbox, overlapParams)
		for _, part in ipairs(partsInZone) do
			local char = part.Parent
			if char and char:FindFirstChildOfClass("Humanoid") then
				local player = Players:GetPlayerFromCharacter(char)
				if player and not player:GetAttribute("IsRacing") then
					currentPlayersInZone[player] = true
				end
			end
		end
	end
	
	-- Handle entering
	for player, _ in pairs(currentPlayersInZone) do
		if not playersOnTreadmill[player] then
			playersOnTreadmill[player] = true
			player:SetAttribute("OnTreadmill", true)
			attachBoardToPlayer(player)
		end
	end
	
	-- Handle exiting
	for player, _ in pairs(playersOnTreadmill) do
		if not currentPlayersInZone[player] then
			playersOnTreadmill[player] = nil
			if player.Parent then -- Player still in game
				if not player:GetAttribute("IsRacing") then
					player:SetAttribute("OnTreadmill", false)
					removeBoardFromPlayer(player)
				end
			end
		end
	end
end)

-- Handle respawns & disconnections
Players.PlayerRemoving:Connect(function(player)
	playersOnTreadmill[player] = nil
end)

-- Handle player board change while on treadmill
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(char)
		local eqVal = player:WaitForChild("EquippedHoverboardId", 5)
		if eqVal then
			eqVal:GetPropertyChangedSignal("Value"):Connect(function()
				if player:GetAttribute("OnTreadmill") then
					attachBoardToPlayer(player)
				end
			end)
		end
	end)
end)
