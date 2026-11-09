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

-- Setup Treadmills & Animation Loop
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
			
			-- 셰브론 화살표 & 벨트 & 터빈 애니메이션
			local chevronsFolder = model:FindFirstChild("Chevrons")
			local chevrons = {}
			if chevronsFolder then
				for i = 1, 5 do
					local ch = chevronsFolder:FindFirstChild("Chevron_" .. i)
					if ch and ch:IsA("Model") then
						local apex = ch:FindFirstChild("Apex") :: BasePart?
						if apex then ch.PrimaryPart = apex end
						table.insert(chevrons, ch)
					end
				end
			end
			
			local belt = model:FindFirstChild("Belt")
			local tex = belt and belt:FindFirstChild("BeltTexture") :: Texture?
			
			local turbineEmitters = {}
			for _, child in ipairs(model:GetChildren()) do
				if child.Name == "TurbineCore" then
					local pe = child:FindFirstChild("WindStream")
					if pe and pe:IsA("ParticleEmitter") then
						table.insert(turbineEmitters, pe)
					end
				end
			end
			
			local hudSpeedVal = nil
			local hudBarFill = nil
			local hudSubHeader = nil
			if screen then
				local sg = screen:FindFirstChild("HoverSimulatorHUD")
				local bg = sg and sg:FindFirstChildOfClass("Frame")
				if bg then
					hudSubHeader = bg:FindFirstChild("TextLabel") and bg:GetChildren()[3] :: TextLabel?
					local gaugeBox = bg:FindFirstChild("Frame") :: Frame?
					if gaugeBox then
						hudSpeedVal = gaugeBox:FindFirstChild("TextLabel") and gaugeBox:GetChildren()[3] :: TextLabel?
						local pBarBg = gaugeBox:FindFirstChildOfClass("Frame") :: Frame?
						hudBarFill = pBarBg and pBarBg:FindFirstChildOfClass("Frame") :: Frame?
					end
				end
			end
			
			-- 상수 정의
			local X_MIN = -21.0
			local X_MAX = -5.5
			local X_LEN = X_MAX - X_MIN
			local BASE_Y = 89.83
			local CENTER_Z = -32.0
			local SPACING = X_LEN / #chevrons
			if #chevrons == 0 then SPACING = 3.1 end
			
			local currentAnimSpeed = 12.0
			local scrollOffset = 0
			local elapsedRide = 0
			
			RunService.Heartbeat:Connect(function(dt)
				local isAnyoneRiding = (next(playersOnTreadmill) ~= nil)
				local targetSpeed = isAnyoneRiding and 40.0 or 12.0
				currentAnimSpeed = currentAnimSpeed + (targetSpeed - currentAnimSpeed) * math.clamp(dt * 6, 0, 1)
				
				-- 1. 셰브론 3D 네온 화살표 이동
				if #chevrons > 0 then
					scrollOffset = (scrollOffset + currentAnimSpeed * dt) % X_LEN
					
					for i, chModel in ipairs(chevrons) do
						local newX = X_MIN + (((i - 1) * SPACING) + scrollOffset) % X_LEN
						chModel:PivotTo(CFrame.new(newX, BASE_Y, CENTER_Z))
						
						-- 양 끝단 부드러운 페이드 인/아웃
						local fadeDist = 1.8
						local alpha = 0
						if newX < (X_MIN + fadeDist) then
							alpha = 1 - math.clamp((newX - X_MIN) / fadeDist, 0, 1)
						elseif newX > (X_MAX - fadeDist) then
							alpha = math.clamp((newX - (X_MAX - fadeDist)) / fadeDist, 0, 1)
						end
						
						for _, p in ipairs(chModel:GetChildren()) do
							if p:IsA("BasePart") then
								p.Transparency = alpha
							end
						end
					end
				end
				
				-- 2. 벨트 텍스처 스크롤
				if tex and tex.StudsPerTileV > 0 then
					tex.OffsetStudsV = (tex.OffsetStudsV - dt * currentAnimSpeed * 0.4) % tex.StudsPerTileV
				end
				
				-- 3. 터빈 바람 파티클 조절
				local targetRate = isAnyoneRiding and 50 or 12
				local targetWindSpeed = isAnyoneRiding and 35 or 15
				for _, pe in ipairs(turbineEmitters) do
					pe.Rate = targetRate
					pe.Speed = NumberRange.new(targetWindSpeed * 0.85, targetWindSpeed * 1.15)
				end
				
				-- 4. 전면 HUD 디스플레이 갱신
				if hudSpeedVal and hudBarFill then
					if isAnyoneRiding then
						elapsedRide = elapsedRide + dt
						local jitter = math.sin(elapsedRide * 8) * 3
						local spd = math.floor(150 + jitter)
						hudSpeedVal.Text = string.format("%d <font size=\"32\" color=\"#FFB91E\">KM/H</font>", spd)
						hudBarFill.Size = UDim2.new(0.88, 0, 1, 0)
						hudBarFill.BackgroundColor3 = Color3.fromRGB(0, 255, 180)
						if hudSubHeader then
							hudSubHeader.Text = "SYSTEM STATUS: 🔥 HIGH VELOCITY TEST 🔥"
							hudSubHeader.TextColor3 = Color3.fromRGB(255, 190, 40)
						end
					else
						elapsedRide = 0
						hudSpeedVal.Text = "0 <font size=\"32\" color=\"#7890AA\">KM/H</font>"
						hudBarFill.Size = UDim2.new(0.08, 0, 1, 0)
						hudBarFill.BackgroundColor3 = Color3.fromRGB(0, 240, 255)
						if hudSubHeader then
							hudSubHeader.Text = "SYSTEM STATUS: READY  |  WIND TUNNEL: IDLE"
							hudSubHeader.TextColor3 = Color3.fromRGB(120, 255, 150)
						end
					end
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
