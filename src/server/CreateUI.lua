local module = {}

function module.Build()
	local StarterGui = game:GetService("StarterGui")
	if StarterGui:FindFirstChild("SkillActionGui") then
		StarterGui.SkillActionGui:Destroy()
	end
	
	local gui = Instance.new("ScreenGui")
	gui.Name = "SkillActionGui"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
	
	local container = Instance.new("Frame")
	container.Name = "SlotsContainer"
	container.Size = UDim2.new(0, 175, 0, 175)
	container.Position = UDim2.new(1, -190, 0.5, -87)
	container.BackgroundTransparency = 1
	container.Parent = gui
	
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellPadding = UDim2.new(0, 15, 0, 15)
	gridLayout.CellSize = UDim2.new(0, 80, 0, 80)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = container

	local hbContainer = Instance.new("Frame")
	hbContainer.Name = "HoverboardDisplay"
	hbContainer.Size = UDim2.new(0, 175, 0, 60)
	hbContainer.Position = UDim2.new(1, -190, 0.5, -155) -- SlotsContainer 바로 위
	hbContainer.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
	hbContainer.BackgroundTransparency = 0.2
	hbContainer.Parent = gui

	local hbCorner = Instance.new("UICorner")
	hbCorner.CornerRadius = UDim.new(0, 12)
	hbCorner.Parent = hbContainer

	local hbStroke = Instance.new("UIStroke")
	hbStroke.Color = Color3.fromRGB(30, 30, 30)
	hbStroke.Thickness = 4
	hbStroke.Parent = hbContainer

	local hbIcon = Instance.new("ImageLabel")
	hbIcon.Name = "Icon"
	hbIcon.Size = UDim2.new(0, 40, 0, 40)
	hbIcon.Position = UDim2.new(0, 10, 0.5, -20)
	hbIcon.BackgroundTransparency = 1
	hbIcon.Image = ""
	hbIcon.Parent = hbContainer
	
	local hbIconCorner = Instance.new("UICorner")
	hbIconCorner.CornerRadius = UDim.new(0, 6)
	hbIconCorner.Parent = hbIcon

	local hbName = Instance.new("TextLabel")
	hbName.Name = "NameLabel"
	hbName.Size = UDim2.new(1, -65, 1, 0)
	hbName.Position = UDim2.new(0, 60, 0, 0)
	hbName.BackgroundTransparency = 1
	hbName.Font = Enum.Font.FredokaOne
	hbName.Text = "호버보드"
	hbName.TextColor3 = Color3.fromRGB(255, 255, 255)
	hbName.TextSize = 14
	hbName.TextWrapped = true
	hbName.TextXAlignment = Enum.TextXAlignment.Left
	hbName.Parent = hbContainer
	
	local hotkeyStrs = { "Q", "E", "R", "T" }
	local slotColors = {
		Color3.fromRGB(255, 210, 80), -- 노란색 (Yellow)
		Color3.fromRGB(255, 120, 170), -- 핑크색 (Pink)
		Color3.fromRGB(80, 180, 255), -- 파란색 (Blue)
		Color3.fromRGB(100, 220, 120) -- 녹색 (Green)
	}
	
	local glitchOverlay = Instance.new("Frame")
	glitchOverlay.Name = "EMPGlitchOverlay"
	glitchOverlay.Size = UDim2.new(1, 0, 1, 0)
	glitchOverlay.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
	glitchOverlay.BackgroundTransparency = 1
	glitchOverlay.ZIndex = 99
	glitchOverlay.Visible = false
	glitchOverlay.Parent = gui
	
	for index = 1, 4 do
		local slotFrame = Instance.new("ImageButton")
		slotFrame.Name = "Slot" .. index
		slotFrame.Size = UDim2.new(0, 70, 0, 70)
		slotFrame.BackgroundColor3 = slotColors[index]
		slotFrame.BackgroundTransparency = 0 -- 완전 불투명하게 (캐주얼 느낌)
		slotFrame.LayoutOrder = index
		slotFrame.Parent = container
		
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 16) -- 디자인 가이드에 맞게 수정
		corner.Parent = slotFrame
		
		local aspect = Instance.new("UIAspectRatioConstraint")
		aspect.AspectRatio = 1
		aspect.Parent = slotFrame
		
		local stroke = Instance.new("UIStroke")
		stroke.Name = "UIStroke"
		stroke.Color = Color3.fromRGB(0, 0, 0) -- 진한 검은색 테두리
		stroke.Transparency = 0
		stroke.Thickness = 3 -- 디자인 가이드
		stroke.Parent = slotFrame
		
		local icon = Instance.new("ImageLabel")
		icon.Name = "Icon"
		icon.Size = UDim2.new(1, -12, 1, -12)
		icon.Position = UDim2.new(0.5, 0, 0.5, 0)
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.BackgroundTransparency = 1
		icon.Image = ""
		icon.Parent = slotFrame
		
		local cornerIcon = Instance.new("UICorner")
		cornerIcon.CornerRadius = UDim.new(0, 6)
		cornerIcon.Parent = icon
		
		local hotkeyLabel = Instance.new("TextLabel")
		hotkeyLabel.Name = "HotkeyLabel"
		hotkeyLabel.Size = UDim2.new(0, 26, 0, 26)
		hotkeyLabel.Position = UDim2.new(1, -10, 0, -10)
		hotkeyLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		hotkeyLabel.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Bold)
		hotkeyLabel.Text = hotkeyStrs[index]
		hotkeyLabel.TextColor3 = Color3.fromRGB(0, 0, 0)
		hotkeyLabel.TextSize = 19
		hotkeyLabel.ZIndex = 10
		hotkeyLabel.Parent = slotFrame
		
		local hkCorner = Instance.new("UICorner")
		hkCorner.CornerRadius = UDim.new(1, 0) -- 원형
		hkCorner.Parent = hotkeyLabel
		
		local overlay = Instance.new("Frame")
		overlay.Name = "Overlay"
		overlay.Size = UDim2.new(1, 0, 1, 0)
		overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		overlay.BackgroundTransparency = 0.5
		overlay.Visible = false
		overlay.Parent = slotFrame
		
		local overlayCorner = Instance.new("UICorner")
		overlayCorner.CornerRadius = UDim.new(0, 12)
		overlayCorner.Parent = overlay
		
		local lockIcon = Instance.new("TextLabel")
		lockIcon.Name = "LockIcon"
		lockIcon.Size = UDim2.new(1, 0, 1, 0)
		lockIcon.BackgroundTransparency = 1
		lockIcon.Font = Enum.Font.FredokaOne
		lockIcon.TextColor3 = Color3.fromRGB(255, 100, 100)
		lockIcon.TextSize = 16
		lockIcon.Visible = false
		lockIcon.Parent = slotFrame
		
		if index == 3 then
			lockIcon.Text = "🔒\n50 R$"
		elseif index == 4 then
			lockIcon.Text = "🔒\n100 R$"
		end
		
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "NameLabel"
		nameLabel.Size = UDim2.new(2, 0, 0, 30)
		nameLabel.Position = UDim2.new(0.5, 0, 1, 0)
		nameLabel.AnchorPoint = Vector2.new(0.5, 0.5)
		nameLabel.BackgroundTransparency = 1
		nameLabel.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Bold)
		nameLabel.Text = ""
		nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLabel.TextStrokeTransparency = 1
		nameLabel.TextSize = 22
		nameLabel.TextWrapped = false
		nameLabel.TextXAlignment = Enum.TextXAlignment.Center
		nameLabel.TextYAlignment = Enum.TextYAlignment.Center
		nameLabel.ZIndex = 4
		nameLabel.Parent = slotFrame
		
		local nlStroke = Instance.new("UIStroke")
		nlStroke.Color = Color3.fromRGB(0, 0, 0)
		nlStroke.Thickness = 3
		nlStroke.Parent = nameLabel
		
		local cdLabel = Instance.new("TextLabel")
		cdLabel.Name = "CdLabel"
		cdLabel.Size = UDim2.new(1, 0, 1, 0)
		cdLabel.BackgroundTransparency = 1
		cdLabel.Font = Enum.Font.FredokaOne
		cdLabel.Text = ""
		cdLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		cdLabel.TextStrokeTransparency = 0
		cdLabel.TextSize = 30
		cdLabel.Visible = false
		cdLabel.ZIndex = 5
		cdLabel.Parent = slotFrame
	end
	
	gui.Parent = StarterGui
	print("✅ SkillActionGui successfully created in StarterGui!")
end

return module
