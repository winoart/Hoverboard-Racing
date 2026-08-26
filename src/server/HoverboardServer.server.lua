--!strict
-- HoverboardServer.server.luau
-- Server script managing SINGLE Hoverboard model, horizontal stance, and mount/dismount states for Race Matches

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local HoverboardConfig = require(Shared:WaitForChild("HoverboardConfig") :: ModuleScript)
local HoverboardBuilder = require(Shared:WaitForChild("HoverboardBuilder") :: ModuleScript)

-- Clean up legacy SpawnLocations or BasicBoard models on the track so players spawn in WaitingRoom Lounge
for _, child in ipairs(Workspace:GetDescendants()) do
	if child:IsA("SpawnLocation") and child.Name ~= "LoungeSpawnLocation" then
		child:Destroy()
		print("🗑️ 트랙 임시 스폰지점 삭제 완료:", child.Name)
	end
end

-- Clear StarterPack & Player Backpack default items (Remove slot 1 tool)
local StarterPack = game:GetService("StarterPack")
StarterPack:ClearAllChildren()

local function clearPlayerBackpack(player: Player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		backpack:ClearAllChildren()
	end
	local character = player.Character
	if character then
		for _, child in ipairs(character:GetChildren()) do
			if child:IsA("Tool") then
				child:Destroy()
			end
		end
	end
end

Players.PlayerAdded:Connect(function(player: Player)
	clearPlayerBackpack(player)
	player.CharacterAdded:Connect(function()
		task.wait(0.1)
		clearPlayerBackpack(player)
	end)
end)

for _, player in ipairs(Players:GetPlayers()) do
	clearPlayerBackpack(player)
end

-- Ensure RemoteEvents exist
local remotesFolder = ReplicatedStorage:FindFirstChild("HoverboardRemotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "HoverboardRemotes"
	remotesFolder.Parent = ReplicatedStorage
end

local mountRemote = remotesFolder:FindFirstChild("MountRequest") :: RemoteEvent
if not mountRemote then
	mountRemote = Instance.new("RemoteEvent")
	mountRemote.Name = "MountRequest"
	mountRemote.Parent = remotesFolder
end

local dismountRemote = remotesFolder:FindFirstChild("DismountRequest") :: RemoteEvent
if not dismountRemote then
	dismountRemote = Instance.new("RemoteEvent")
	dismountRemote.Name = "DismountRequest"
	dismountRemote.Parent = remotesFolder
end

local stateRemote = remotesFolder:FindFirstChild("StateChanged") :: RemoteEvent
if not stateRemote then
	stateRemote = Instance.new("RemoteEvent")
	stateRemote.Name = "StateChanged"
	stateRemote.Parent = remotesFolder
end

-- Helper: Attach Hoverboard to Character
local function attachHoverboardToCharacter(player: Player): Model?
	local character = player.Character
	if not character then return nil end

	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not hrp or not humanoid then return nil end

	-- Clean up ANY existing hoverboard models on character (prevent duplicate X-shaped overlapping boards!)
	for _, child in ipairs(character:GetChildren()) do
		if child.Name == "EquippedHoverboard" or child.Name:lower():find("hoverboard") then
			child:Destroy()
		end
	end

	-- Create Hoverboard Model
	local boardModel = HoverboardBuilder.createModel()
	boardModel.Name = "EquippedHoverboard"

	-- Unanchor ALL parts of equipped hoverboard
	for _, part in ipairs(boardModel:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
			part.Massless = true
		end
	end

	local rootPart = boardModel.PrimaryPart
	if not rootPart then return nil end

	local defaultWeldC0 = CFrame.new(0, -3.25, 0)

	rootPart.CFrame = hrp.CFrame * defaultWeldC0
	boardModel.Parent = character

	-- Weld board to HumanoidRootPart
	local weld = Instance.new("Weld")
	weld.Name = "HoverWeld"
	weld.Part0 = hrp
	weld.Part1 = rootPart
	weld.C0 = defaultWeldC0
	weld.Parent = rootPart

	-- Set Character attributes & Humanoid parameters
	humanoid.WalkSpeed = HoverboardConfig.RIDE_WALKSPEED
	humanoid.UseJumpPower = true
	humanoid.JumpPower = HoverboardConfig.RIDE_JUMPPOWER
	humanoid.HipHeight = HoverboardConfig.HOVER_HEIGHT

	player:SetAttribute("IsHoverboarding", true)

	-- Notify client
	stateRemote:FireClient(player, true, boardModel)

	return boardModel
end

-- Helper: Detach Hoverboard from Character
local function detachHoverboardFromCharacter(player: Player)
	local character = player.Character
	if character then
		local boardModel = character:FindFirstChild("EquippedHoverboard")
		if boardModel then
			boardModel:Destroy()
		end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = 16
			humanoid.JumpPower = 50
			humanoid.HipHeight = 0
		end
	end

	player:SetAttribute("IsHoverboarding", false)

	-- Notify client
	stateRemote:FireClient(player, false, nil)
end

-- Remote Listeners
mountRemote.OnServerEvent:Connect(function(player: Player)
	if not player:GetAttribute("IsHoverboarding") then
		attachHoverboardToCharacter(player)
	end
end)

dismountRemote.OnServerEvent:Connect(function(player: Player)
	if player:GetAttribute("IsHoverboarding") then
		detachHoverboardFromCharacter(player)
	end
end)

-- Setup Workspace.Hoverboards Folder for Template Clones
local FOLDER_NAME = "Hoverboards"
local hoverboardFolder = Workspace:FindFirstChild(FOLDER_NAME)
if not hoverboardFolder then
	hoverboardFolder = Instance.new("Folder")
	hoverboardFolder.Name = FOLDER_NAME
	hoverboardFolder.Parent = Workspace
end

-- Template Hoverboard for GameLoopManager race matches
local templateBoard = HoverboardBuilder.createModel()
templateBoard.Name = "Hoverboard_MetallicSlate"
if templateBoard.PrimaryPart then
	templateBoard.PrimaryPart.Anchored = true
end
templateBoard.Parent = hoverboardFolder

print("⚡ [HoverboardServer] 레이스 게임 루프 서버 모듈 준비 완료!")
