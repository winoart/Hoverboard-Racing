local module = {}

function module.Build()
	local StarterGui = game:GetService("StarterGui")
	if StarterGui:FindFirstChild("SkillActionGui") then
		StarterGui.SkillActionGui:Destroy()
	end
	
	local gui = Instance.new("ScreenGui")
	gui.Name = "SkillActionGui"
	gui.ResetOnSpawn = false
	
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
		corner.CornerRadius = UDim.new(0, 12) -- 조금 더 둥글게 (캐주얼)
		corner.Parent = slotFrame
		
		local stroke = Instance.new("UIStroke")
		stroke.Name = "UIStroke"
		stroke.Color = Color3.fromRGB(30, 30, 30) -- 진한 검은색 테두리
		stroke.Transparency = 0
		stroke.Thickness = 4 -- 두꺼운 테두리 (캐주얼)
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
		hotkeyLabel.Size = UDim2.new(0, 24, 0, 24)
		hotkeyLabel.Position = UDim2.new(1, -10, 0, -10)
		hotkeyLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255) -- 하얀색 배경
		hotkeyLabel.Font = Enum.Font.GothamBlack
		hotkeyLabel.Text = hotkeyStrs[index]
		hotkeyLabel.TextColor3 = Color3.fromRGB(30, 30, 30) -- 검은색 글씨
		hotkeyLabel.TextSize = 14
		hotkeyLabel.Parent = slotFrame
		
		local hkStroke = Instance.new("UIStroke")
		hkStroke.Color = Color3.fromRGB(30, 30, 30)
		hkStroke.Thickness = 3
		hkStroke.Parent = hotkeyLabel
		
		local hkCorner = Instance.new("UICorner")
		hkCorner.CornerRadius = UDim.new(0, 6) -- slightly rounded tag
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
		lockIcon.Font = Enum.Font.GothamBold
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
		nameLabel.Size = UDim2.new(1, -10, 1, -10)
		nameLabel.Position = UDim2.new(0, 5, 0, 5)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.Text = ""
		nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLabel.TextStrokeTransparency = 0.3
		nameLabel.TextSize = 10
		nameLabel.TextWrapped = true
		nameLabel.TextYAlignment = Enum.TextYAlignment.Bottom
		nameLabel.ZIndex = 3
		nameLabel.Parent = slotFrame
		
		local cdLabel = Instance.new("TextLabel")
		cdLabel.Name = "CdLabel"
		cdLabel.Size = UDim2.new(1, 0, 1, 0)
		cdLabel.BackgroundTransparency = 1
		cdLabel.Font = Enum.Font.GothamBlack
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
