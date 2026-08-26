local tool = script.Parent
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local boardModelTemplate = tool:WaitForChild("BasicBoard")
local activeBoard = nil

local riding = false
local currentCharacter = nil
local rootPart = nil
local humanoid = nil
local rootJoint = nil

local originalHipHeight = 2
local originalWalkSpeed = 16
local originalAutoRotate = true
local originalRootC0 = nil

local moveDir = 0
local steerDir = 0
local currentSpeed = 0
local maxSpeed = 70
local acceleration = 40
local deceleration = 50
local currentTurnSpeed = 0
local turnAcceleration = 12
local maxTurnSpeed = 4

local heartbeatConn = nil

local function getRootJoint(character)
	local hum = character:FindFirstChildOfClass("Humanoid")
	if hum and hum.RigType == Enum.HumanoidRigType.R15 then
		local lowerTorso = character:FindFirstChild("LowerTorso")
		if lowerTorso then return lowerTorso:FindFirstChild("Root") end
	else
		local rp = character:FindFirstChild("HumanoidRootPart")
		if rp then return rp:FindFirstChild("RootJoint") end
	end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or not riding then return end
	if input.KeyCode == Enum.KeyCode.W then moveDir = 1
	elseif input.KeyCode == Enum.KeyCode.S then moveDir = -1
	elseif input.KeyCode == Enum.KeyCode.A then steerDir = 1
	elseif input.KeyCode == Enum.KeyCode.D then steerDir = -1
	end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
	if not riding then return end
	if input.KeyCode == Enum.KeyCode.W and moveDir == 1 then moveDir = 0
	elseif input.KeyCode == Enum.KeyCode.S and moveDir == -1 then moveDir = 0
	elseif input.KeyCode == Enum.KeyCode.A and steerDir == 1 then steerDir = 0
	elseif input.KeyCode == Enum.KeyCode.D and steerDir == -1 then steerDir = 0
	end
end)

tool.Equipped:Connect(function()
	currentCharacter = player.Character
	if not currentCharacter then return end
	
	humanoid = currentCharacter:FindFirstChildOfClass("Humanoid")
	rootPart = currentCharacter:FindFirstChild("HumanoidRootPart")
	if not humanoid or not rootPart then return end
	
	riding = true
	currentSpeed = 0
	currentTurnSpeed = 0
	
	local animateScript = currentCharacter:FindFirstChild("Animate")
	if animateScript then animateScript.Enabled = false end
	
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
			track:Stop()
		end
	end
	
	originalHipHeight = humanoid.HipHeight
	originalWalkSpeed = humanoid.WalkSpeed
	originalAutoRotate = humanoid.AutoRotate
	humanoid.AutoRotate = false 
	
	if originalHipHeight == 0 then originalHipHeight = 2 end
	
	activeBoard = boardModelTemplate:Clone()
	activeBoard.Name = "ActiveHoverboard"
	local primaryPart = activeBoard.PrimaryPart
	
	local hoverLift = 1.5 
	local hoverHeight = originalHipHeight + hoverLift
	
	local rootHeightOffset = rootPart.Size.Y / 2
	local yOffset = - (rootHeightOffset + originalHipHeight + (primaryPart.Size.Y / 2))
	
	-- 보드를 90도 돌려서 긴 쪽이 앞을 보도록 함
	local boardOffset = CFrame.new(0, yOffset, 0) * CFrame.Angles(0, math.rad(90), 0)
	activeBoard:PivotTo(rootPart.CFrame * boardOffset)
	
	for _, part in ipairs(activeBoard:GetDescendants()) do
		if part:IsA("BasePart") and part ~= primaryPart then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = primaryPart
			weld.Part1 = part
			weld.Parent = primaryPart
		end
	end
	
	local rideWeld = Instance.new("WeldConstraint")
	rideWeld.Part0 = rootPart
	rideWeld.Part1 = primaryPart
	rideWeld.Parent = primaryPart
	
	for _, part in ipairs(activeBoard:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.Massless = true
			part.Anchored = false
		end
	end
	
	activeBoard.Parent = currentCharacter
	
	rootJoint = getRootJoint(currentCharacter)
	if rootJoint then
		if not rootJoint:GetAttribute("OriginalC0") then
			rootJoint:SetAttribute("OriginalC0", rootJoint.C0)
		end
		originalRootC0 = rootJoint:GetAttribute("OriginalC0")
	end
	
	humanoid.HipHeight = hoverHeight
	
	local startTime = tick()
	local bounceSpeed = 4
	local bounceAmplitude = 0.2
	
	heartbeatConn = RunService.Heartbeat:Connect(function(dt)
		if not riding or not rootPart then return end
		
		local timePassed = tick() - startTime
		local bounce = math.sin(timePassed * bounceSpeed) * bounceAmplitude
		humanoid.HipHeight = hoverHeight + bounce
		
		-- 몸통은 옆을 보도록 고정
		if rootJoint and originalRootC0 then
			rootJoint.C0 = originalRootC0 * CFrame.Angles(0, math.rad(-90), 0)
		end
		
		if moveDir == 1 then
			currentSpeed = math.min(currentSpeed + (acceleration * dt), maxSpeed)
		elseif moveDir == -1 then
			currentSpeed = math.max(currentSpeed - (deceleration * dt), -maxSpeed/2)
		else
			if currentSpeed > 0 then
				currentSpeed = math.max(currentSpeed - (deceleration * dt), 0)
			elseif currentSpeed < 0 then
				currentSpeed = math.min(currentSpeed + (deceleration * dt), 0)
			end
		end
		
		if steerDir == 1 then
			currentTurnSpeed = math.min(currentTurnSpeed + (turnAcceleration * dt), maxTurnSpeed)
		elseif steerDir == -1 then
			currentTurnSpeed = math.max(currentTurnSpeed - (turnAcceleration * dt), -maxTurnSpeed)
		else
			currentTurnSpeed = currentTurnSpeed * 0.8
		end
		
		local turnAngle = currentTurnSpeed * dt
		local newCFrame = rootPart.CFrame * CFrame.Angles(0, turnAngle, 0)
		
		rootPart.CFrame = CFrame.new(rootPart.Position) * newCFrame.Rotation
		
		humanoid:Move(rootPart.CFrame.LookVector * (currentSpeed / humanoid.WalkSpeed), false)
	end)
end)

tool.Unequipped:Connect(function()
	riding = false
	
	if heartbeatConn then 
		heartbeatConn:Disconnect() 
		heartbeatConn = nil
	end
	
	if currentCharacter then
		local hum = currentCharacter:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.HipHeight = originalHipHeight
			hum.WalkSpeed = originalWalkSpeed
			hum.AutoRotate = originalAutoRotate
			
			local animateScript = currentCharacter:FindFirstChild("Animate")
			if animateScript then animateScript.Enabled = true end
			
			hum:Move(Vector3.new(0,0,0), false)
		end
		
		local rj = getRootJoint(currentCharacter)
		if rj and originalRootC0 then
			rj.C0 = originalRootC0
		end
		
		if activeBoard then
			activeBoard:Destroy()
			activeBoard = nil
		end
		currentCharacter = nil
	end
end)
