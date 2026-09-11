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

local function dismountTreadmill(player: Player, skipTeleport: boolean?, reason: string?)
	reason = reason or "Unknown"
	print(string.format("[DEBUG-TM] dismountTreadmill called for %s | Reason: %s | skipTeleport: %s | OnTreadmill: %s", player.Name, reason, tostring(skipTeleport), tostring(player:GetAttribute("OnTreadmill"))))
	if not player:GetAttribute("OnTreadmill") then return end
	player:SetAttribute("OnTreadmill", false)
	player:SetAttribute("LastTreadmillDismount", os.clock())
	
	local char = player.Character
	if char then
		local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = char:FindFirstChildOfClass("Humanoid")
		if hrp and humanoid then
			print("[DEBUG-TM] Destroying hoverboards for " .. player.Name)
			for _, child in ipairs(char:GetChildren()) do
				if child.Name == "EquippedHoverboard" or child.Name:lower():find("hoverboard") then
					child:Destroy()
				end
			end
			
			if not skipTeleport then
				print("[DEBUG-TM] Teleporting " .. player.Name .. " back to savedPos")
				task.spawn(function()
					-- 클라이언트 물리 개입(AlignPosition)을 막기 위해 앵커 처리 및 속도 초기화
					hrp.Anchored = true
					hrp.AssemblyLinearVelocity = Vector3.zero
					hrp.AssemblyAngularVelocity = Vector3.zero
					
					-- 서버에서도 직접 AlignPosition 찌꺼기 삭제 (클라이언트보다 먼저 처리)
					if hrp:FindFirstChild("TreadmillSwayPos") then hrp.TreadmillSwayPos:Destroy() end
					if hrp:FindFirstChild("TreadmillSwayOri") then hrp.TreadmillSwayOri:Destroy() end
					if hrp:FindFirstChild("SwayAttach0") then hrp.SwayAttach0:Destroy() end
					
					local savedPos = player:GetAttribute("PreTreadmillPosition")
					if savedPos then
						hrp.CFrame = CFrame.new(savedPos + Vector3.new(0, 3, 0))
						player:SetAttribute("PreTreadmillPosition", nil)
					else
						local spawnLocation = Workspace:FindFirstChild("SpawnLocation")
						if spawnLocation then
							hrp.CFrame = spawnLocation.CFrame + Vector3.new(0, 5, 0)
						end
					end
					
					-- 클라이언트가 변경된 위치와 어트리뷰트를 동기화할 수 있도록 잠시 대기 후 언앵커
					task.wait(0.1)
					hrp.Anchored = false
				end)
			end
		end
	end
	
	local stateRemote = remotesFolder:FindFirstChild("StateChanged") :: RemoteEvent?
	if stateRemote then
		stateRemote:FireClient(player, false, nil)
	end
	
	-- 화면 초기화
	local lounge = Workspace:FindFirstChild("WaitingRoomLounge") or Workspace:FindFirstChild("WaitingRoom")
	if lounge then
		local screenGui = lounge:FindFirstChild("DashboardScreen")
		if screenGui then
			local tGui = screenGui:FindFirstChild("TreadmillGui")
			if tGui then
				local charViewport = tGui:FindFirstChild("CharacterViewport")
				if charViewport then
					for _, child in ipairs(charViewport:GetChildren()) do
						child:Destroy()
					end
				end
			end
		end
		for _, treadmill in ipairs(lounge:GetChildren()) do
			if treadmill.Name:find("Treadmill") then
				local updateFn = _G.UpdateTreadmillScreen
				if updateFn then updateFn(treadmill, nil) end
			end
		end
	end
end

local function updateTreadmillScreen(model: Model, player: Player?)
	local screen = model:FindFirstChild("Screen") :: BasePart
	if not screen then return end
	
	-- 까만 화면 대신 어두운 네이비색(시안 톤)으로 변경
	screen.Color = Color3.fromRGB(20, 35, 55)
	
	-- 기존 GUI 삭제
	for _, child in ipairs(screen:GetChildren()) do
		if child.Name == "DashboardGui" then
			child:Destroy()
		end
	end
	
	if not player then return end
	
	-- 앞, 뒤쪽에만 생성 (얇은 파트의 윗면/옆면에 생성되면 이미지가 길게 늘어나는 문제 방지)
	for _, face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
		local gui = Instance.new("SurfaceGui")
		gui.Name = "DashboardGui"
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 50
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		
		local container = Instance.new("Frame")
		container.Size = UDim2.new(1, 0, 1, 0)
		container.BackgroundTransparency = 1
		container.Parent = gui
		
		local layout = Instance.new("UIListLayout")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.Padding = UDim.new(0, 15)
		layout.Parent = container
		
		local profileImage = Instance.new("ImageLabel")
		profileImage.Name = "ProfileImage"
		profileImage.Size = UDim2.new(0.8, 0, 0.8, 0) -- 화면 높이의 80% 크기
		profileImage.SizeConstraint = Enum.SizeConstraint.RelativeYY -- 정사각형 유지 (가로/세로 비율을 Y축 기준에 맞춤)
		profileImage.BackgroundColor3 = Color3.fromRGB(40, 60, 80)
		profileImage.Image = Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
		
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = profileImage
		
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(0, 255, 255)
		stroke.Thickness = 4
		stroke.Parent = profileImage
		
		profileImage.Parent = container
		
		gui.Parent = screen
	end
end
_G.UpdateTreadmillScreen = updateTreadmillScreen

local function mountTreadmill(player: Player, beltPart: BasePart)
	if player:GetAttribute("OnTreadmill") then return end
	if player:GetAttribute("IsRacing") then return end
	
	local lastDismount = player:GetAttribute("LastTreadmillDismount") or 0
	if os.clock() - lastDismount < 2.5 then return end
	print("[DEBUG-TM] mountTreadmill called for " .. player.Name)

	local char = player.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char:FindFirstChildOfClass("Humanoid") :: Humanoid?
	if not hrp or not hum then return end
	
	player:SetAttribute("OnTreadmill", true)
	if not player:GetAttribute("PreTreadmillPosition") then
		-- 디버깅용: 내리는 위치를 계산합니다.
		local backPos = (beltPart.CFrame * CFrame.new(0, 0, 13)).Position
		player:SetAttribute("PreTreadmillPosition", backPos)
		
		-- 디버그 시각화: 빨간색 구체를 생성하여 내리는 위치를 표시
		local debugPart = Instance.new("Part")
		debugPart.Shape = Enum.PartType.Ball
		debugPart.Size = Vector3.new(2, 2, 2)
		debugPart.Color = Color3.new(1, 0, 0) -- 빨강 (하차 위치)
		debugPart.Anchored = true
		debugPart.CanCollide = false
		debugPart.Position = backPos
		debugPart.Parent = Workspace
		game.Debris:AddItem(debugPart, 5) -- 5초 뒤 삭제
		
		print("[DEBUG-TM] Dismount position set to: ", backPos)
	end
	
	local function attachBoardToTreadmill(player: Player, beltPart: BasePart)
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
				hrp.AssemblyLinearVelocity = Vector3.zero
				hrp.AssemblyAngularVelocity = Vector3.zero
				hrp.Anchored = false
				hrp.CFrame = beltPart.CFrame * CFrame.new(0, 3.5, 0) * CFrame.Angles(0, math.rad(90), 0)
				
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
				
				local stateRemote = remotesFolder:FindFirstChild("StateChanged") :: RemoteEvent?
				if stateRemote then
					stateRemote:FireClient(player, true, boardClone)
				end
			end
		end
	end

	attachBoardToTreadmill(player, beltPart)
	
	-- 화면 업데이트: 현재 탑승한 플레이어 정보 띄우기
	if beltPart and beltPart.Parent then
		local updateFn = _G.UpdateTreadmillScreen
		if updateFn then updateFn(beltPart.Parent, player) end
	end
	
	-- Listen for respawns/deaths
	local connName = "TreadmillDeathConn_" .. player.Name
	local existing = player:FindFirstChild(connName)
	if existing then existing:Destroy() end
	
	if char then
		local humanoid = char:FindFirstChildOfClass("Humanoid")
		if humanoid then
			local conn
			conn = humanoid.Died:Connect(function()
				dismountTreadmill(player, true, "PlayerDied")
				conn:Disconnect()
			end)
			
			local connObj = Instance.new("BindableEvent")
			connObj.Name = connName
			connObj.Parent = player
			connObj.Event:Connect(function() conn:Disconnect() end)
		end
	end
	
	-- Setup listener for this session
	local connNameBoard = "TreadmillBoardSwap_" .. player.UserId
	if player:FindFirstChild(connNameBoard) then player[connNameBoard]:Destroy() end
	local eqVal = player:FindFirstChild("EquippedHoverboardId")
	if eqVal then
		local conn = eqVal:GetPropertyChangedSignal("Value"):Connect(function()
			if player:GetAttribute("OnTreadmill") then
				attachBoardToTreadmill(player, beltPart)
			end
		end)
		local connObj = Instance.new("BindableEvent")
		connObj.Name = connNameBoard
		connObj.Parent = player
		connObj.Event:Connect(function() conn:Disconnect() end)
	end
end

-- Monitor treadmills and animate belts
task.spawn(function()
	task.wait(5) -- Wait for lounge to spawn
	local lounge = Workspace:FindFirstChild("WaitingRoomLounge") or Workspace:FindFirstChild("WaitingRoom")
	if not lounge then return end
	
	local belts = {}
	
	for _, model in ipairs(lounge:GetChildren()) do
		if model.Name:find("Treadmill") then
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
		end
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
	dismountTreadmill(player, false, "PlayerJumpedExit")
end)

-- Force dismount when race phase changes or teleported
Workspace:GetAttributeChangedSignal("GamePhase"):Connect(function()
	local phase = Workspace:GetAttribute("GamePhase")
	print("[DEBUG-TM] GamePhase changed to: " .. tostring(phase))
	if phase == "COUNTDOWN" or phase == "INTERMISSION" or phase == "RACE_MATCH" then
		print("[DEBUG-TM] Forcing dismount due to phase: " .. phase)
		for _, player in ipairs(Players:GetPlayers()) do
			-- AFK 유저(트레드밀 훈련 유저)는 게임 페이즈 변경에 의해 강제 하차당하지 않도록 보호합니다.
			if not player:GetAttribute("IsAFK") then
				dismountTreadmill(player, true, "GamePhaseChanged_" .. phase)
			else
				print("[DEBUG-TM] Ignored dismount for AFK Player: " .. player.Name)
			end
		end
	end
end)
