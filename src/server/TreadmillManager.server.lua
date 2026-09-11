--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local remotesFolder = ReplicatedStorage:WaitForChild("HoverboardRemotes")

-- Remove unused remotes for treadmill
local exitTreadmillRemote = remotesFolder:FindFirstChild("ExitTreadmill")
if exitTreadmillRemote then exitTreadmillRemote:Destroy() end
local toggleTreadmillBoardRemote = remotesFolder:FindFirstChild("ToggleTreadmillBoard")
if toggleTreadmillBoardRemote then toggleTreadmillBoardRemote:Destroy() end

local TREADMILL_MODEL: Model? = nil
local TREADMILL_HITBOX: BasePart? = nil

-- Setup Treadmills
task.spawn(function()
	task.wait(5) -- Wait for lounge to spawn
	local lounge = Workspace:FindFirstChild("WaitingRoomLounge") or Workspace:FindFirstChild("WaitingRoom")
	if not lounge then return end
	
	local firstTreadmill = nil
	for _, model in ipairs(lounge:GetChildren()) do
		if model.Name:find("Treadmill") then
			if not firstTreadmill then
				firstTreadmill = model :: Model
			else
				model:Destroy()
			end
		end
	end
	
	if firstTreadmill then
		TREADMILL_MODEL = firstTreadmill
		TREADMILL_HITBOX = firstTreadmill:FindFirstChild("Hitbox") :: BasePart?
		
		-- Clear screen
		local screen = firstTreadmill:FindFirstChild("Screen") :: BasePart?
		if screen then
			screen.Color = Color3.fromRGB(20, 35, 55)
			for _, child in ipairs(screen:GetChildren()) do
				if child.Name == "DashboardGui" then
					child:Destroy()
				end
			end
		end
		
		-- Scale Treadmill width by 2x
		-- Calculate the center of the treadmill
		local cframe, size = firstTreadmill:GetBoundingBox()
		for _, desc in ipairs(firstTreadmill:GetDescendants()) do
			if desc:IsA("BasePart") then
				-- Convert part's CFrame to the model's local space
				local localCFrame = cframe:ToObjectSpace(desc.CFrame)
				
				-- Double the X position and X size
				local scaledLocalCFrame = CFrame.new(localCFrame.Position * Vector3.new(2, 1, 1))
					* (localCFrame - localCFrame.Position)
					
				desc.Size = desc.Size * Vector3.new(2, 1, 1)
				desc.CFrame = cframe:ToWorldSpace(scaledLocalCFrame)
			end
		end
		
		-- Animate belt
		local belt = firstTreadmill:FindFirstChild("Belt")
		local tex = belt and belt:FindFirstChild("BeltTexture")
		if tex and tex:IsA("Texture") then
			RunService.Heartbeat:Connect(function(dt)
				if tex.StudsPerTileV > 0 then
					tex.OffsetStudsV = (tex.OffsetStudsV - dt * 2) % tex.StudsPerTileV
				end
			end)
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
			
			local rotationOffset = CFrame.new()
			if boardName == "MagicBroom" then
				rotationOffset = CFrame.Angles(0, math.rad(180), 0)
			end

			local weld = Instance.new("Weld")
			weld.Name = "HoverWeld"
			weld.Part0 = hrp
			weld.Part1 = rootPart
			weld.C0 = CFrame.new(0, -3.25, 0) * rotationOffset
			weld.Parent = rootPart

			boardClone:PivotTo(hrp.CFrame * weld.C0)
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
local playersOnTreadmill = {}

RunService.Heartbeat:Connect(function()
	if not TREADMILL_HITBOX then return end
	
	local overlapParams = OverlapParams.new()
	local partsInZone = Workspace:GetPartsInPart(TREADMILL_HITBOX, overlapParams)
	local currentPlayersInZone = {}
	
	for _, part in ipairs(partsInZone) do
		local char = part.Parent
		if char and char:FindFirstChildOfClass("Humanoid") then
			local player = Players:GetPlayerFromCharacter(char)
			if player and not player:GetAttribute("IsRacing") then
				currentPlayersInZone[player] = true
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
