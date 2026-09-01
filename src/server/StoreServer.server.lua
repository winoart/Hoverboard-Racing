--!strict
-- StoreServer.server.luau
-- Handles BoardStore ClickDetector and Roulette Spin Logic

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotesFolder = ReplicatedStorage:WaitForChild("HoverboardRemotes")

local openStoreRemote = remotesFolder:FindFirstChild("OpenStore") :: RemoteEvent
if not openStoreRemote then
	openStoreRemote = Instance.new("RemoteEvent")
	openStoreRemote.Name = "OpenStore"
	openStoreRemote.Parent = remotesFolder
end

-- We create SpinRoulette if it doesn't exist (or just use a new one)
local spinRouletteRemote = remotesFolder:FindFirstChild("SpinRoulette") :: RemoteFunction
if not spinRouletteRemote then
	spinRouletteRemote = Instance.new("RemoteFunction")
	spinRouletteRemote.Name = "SpinRoulette"
	spinRouletteRemote.Parent = remotesFolder
end

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StoreConfig = require(Shared:WaitForChild("StoreConfig") :: ModuleScript)

-- 1. Setup BoardStore ProximityPrompt and Effects
local function setupStorePart(storeObj: Instance)
	if storeObj:FindFirstChildOfClass("ProximityPrompt", true) then return end
	
	-- 상점 모델의 전체 크기(BoundingBox)를 감싸는 투명 파트 생성
	local cf, sz
	if storeObj:IsA("Model") then
		cf, sz = storeObj:GetBoundingBox()
	elseif storeObj:IsA("BasePart") then
		cf, sz = storeObj.CFrame, storeObj.Size
	else
		return -- 지원하지 않는 타입
	end
	
	local effectPart = Instance.new("Part")
	effectPart.Name = "StoreEffectBox"
	effectPart.Size = sz
	effectPart.CFrame = cf
	effectPart.Transparency = 1
	effectPart.CanCollide = false
	effectPart.Anchored = true
	effectPart.CanQuery = true -- ProximityPrompt 상호작용을 위해 필요
	effectPart.Parent = storeObj
	
	-- [새로운 효과 추가] 파티클 및 빛 효과 (Hovering Effect)
	local particle = Instance.new("ParticleEmitter")
	particle.Name = "HoverParticle"
	-- 파티클 텍스처 명시 (기본 스파클)
	particle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	particle.Color = ColorSequence.new(Color3.fromRGB(0, 255, 255)) -- 밝은 시안(Cyan) 색상
	particle.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 0)})
	particle.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)})
	particle.Lifetime = NumberRange.new(1, 2)
	particle.Rate = 20
	particle.Speed = NumberRange.new(0.5, 2)
	particle.SpreadAngle = Vector2.new(180, 180) -- 사방으로 은은하게 퍼짐
	particle.EmissionDirection = Enum.NormalId.Top
	particle.Parent = effectPart -- 보이지 않는 박스 전체에서 뿜어져 나옴
	
	local light = Instance.new("PointLight")
	light.Name = "HoverLight"
	light.Color = Color3.fromRGB(0, 255, 255)
	light.Range = 15
	light.Brightness = 3 -- 빛 밝기를 더 키움
	light.Parent = effectPart
	
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "상점 열기"
	prompt.ObjectText = "보드 뽑기"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = effectPart
	
	prompt.Triggered:Connect(function(player)
		openStoreRemote:FireClient(player)
	end)
	
	print("🛒 [StoreServer] BoardStore ProximityPrompt successfully attached to:", storeObj.Name, "via StoreEffectBox")
end

local function checkAndSetup(obj: Instance)
	local function isTargetName(name)
		return name:lower():gsub("%s+", "") == "model1"
	end
	
	if isTargetName(obj.Name) then
		if obj:IsA("BasePart") or obj:IsA("Model") then
			setupStorePart(obj)
		end
	end
end

-- Check existing parts
for _, child in ipairs(Workspace:GetDescendants()) do
	checkAndSetup(child)
end

-- Listen for dynamically added parts
Workspace.DescendantAdded:Connect(checkAndSetup)

-- 2. Handle Roulette Spin Logic
spinRouletteRemote.OnServerInvoke = function(player: Player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local gold = leaderstats and leaderstats:FindFirstChild("Gold") :: IntValue
	local ownedFolder = player:FindFirstChild("OwnedHoverboards")
	
	if not gold or not ownedFolder then
		return false, "데이터 오류", false
	end
	
	if gold.Value < StoreConfig.RouletteCost then
		return false, "골드가 부족합니다.", false
	end
	
	-- Calculate total weight
	local totalWeight = 0
	local pool = {}
	for _, item in ipairs(StoreConfig.Items) do
		if item.weight and item.weight > 0 then
			totalWeight += item.weight
			table.insert(pool, item)
		end
	end
	
	-- Spin
	local randomVal = math.random(1, totalWeight)
	local currentWeight = 0
	local wonItem = nil
	
	for _, item in ipairs(pool) do
		currentWeight += item.weight
		if randomVal <= currentWeight then
			wonItem = item
			break
		end
	end
	
	if not wonItem then
		return false, "뽑기 실패 (풀 오류)", false
	end
	
	-- Deduct Gold
	gold.Value -= StoreConfig.RouletteCost
	
	local isDuplicate = (ownedFolder:FindFirstChild(wonItem.id) ~= nil)
	
	if isDuplicate then
		-- Refund 1/3
		gold.Value += StoreConfig.RefundAmount
		print("🎰 [StoreServer] " .. player.Name .. " spun and got DUPLICATE " .. wonItem.name .. ". Refunded " .. StoreConfig.RefundAmount .. "G")
	else
		-- Add to inventory
		local owned = Instance.new("StringValue")
		owned.Name = wonItem.id
		owned.Parent = ownedFolder
		print("🎰 [StoreServer] " .. player.Name .. " spun and WON " .. wonItem.name .. "!")
	end
	
	return true, wonItem, isDuplicate
end
