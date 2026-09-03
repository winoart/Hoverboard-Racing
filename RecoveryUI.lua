local StarterGui = game:GetService("StarterGui")
for _, v in pairs(StarterGui:GetChildren()) do
    if v.Name == "InventoryGui" then v:Destroy() end
end

local function addStroke(parent, thickness)
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(0, 0, 0)
    stroke.Thickness = thickness or 6
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = parent
    return stroke
end

local function addTextStroke(parent, thickness)
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(0, 0, 0)
    stroke.Thickness = thickness or 3
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
    stroke.Parent = parent
    return stroke
end

local function addCorner(parent, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 12)
    corner.Parent = parent
    return corner
end

local invGui = Instance.new("ScreenGui")
invGui.Name = "InventoryGui"
invGui.ResetOnSpawn = false
invGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
invGui.Parent = StarterGui

local mainContainer = Instance.new("Frame")
mainContainer.Name = "MainContainer"
mainContainer.Size = UDim2.new(0, 850, 0, 550)
mainContainer.Position = UDim2.new(0.5, -425, 0.5, -275)
mainContainer.BackgroundTransparency = 1
mainContainer.Parent = invGui

-- Background
local bgFrame = Instance.new("Frame")
bgFrame.Name = "Background"
bgFrame.Size = UDim2.new(1, 0, 1, -40)
bgFrame.Position = UDim2.new(0, 0, 0, 40)
bgFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
bgFrame.ZIndex = 5
bgFrame.Parent = mainContainer
addCorner(bgFrame, 16)
addStroke(bgFrame, 8)

local reflectionContainer = Instance.new("Frame")
reflectionContainer.Name = "ReflectionContainer"
reflectionContainer.Size = UDim2.new(1, 0, 1, 0)
reflectionContainer.BackgroundTransparency = 1
reflectionContainer.ClipsDescendants = true
reflectionContainer.ZIndex = 6
reflectionContainer.Parent = bgFrame
addCorner(reflectionContainer, 16)

local reflection = Instance.new("Frame")
reflection.Name = "Reflection"
reflection.Size = UDim2.new(2, 0, 0.8, 0)
reflection.Position = UDim2.new(-0.2, 0, 0.3, 0)
reflection.Rotation = -30
reflection.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
reflection.BackgroundTransparency = 0.95
reflection.BorderSizePixel = 0
reflection.ZIndex = 6
reflection.Parent = reflectionContainer

-- Tabs Frame
local tabsFrame = Instance.new("Frame")
tabsFrame.Name = "Tabs"
tabsFrame.Size = UDim2.new(1, -60, 0, 60)
tabsFrame.Position = UDim2.new(0, 30, 0, -28)
tabsFrame.BackgroundTransparency = 1
tabsFrame.ZIndex = 10
tabsFrame.Parent = mainContainer

local tabLayout = Instance.new("UIListLayout", tabsFrame)
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, -8)
tabLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom

-- 호버보드 탭
local boardsTabContainer = Instance.new("Frame", tabsFrame)
boardsTabContainer.Name = "BoardsTabContainer"
boardsTabContainer.Size = UDim2.new(0, 164, 0, 56) 
boardsTabContainer.BackgroundTransparency = 1
boardsTabContainer.ClipsDescendants = true
boardsTabContainer.ZIndex = 10

local boardsTabBg = Instance.new("Frame", boardsTabContainer)
boardsTabBg.Name = "BoardsTabBg"
boardsTabBg.Size = UDim2.new(1, -14, 1, 20) 
boardsTabBg.Position = UDim2.new(0, 7, 0, 6)
boardsTabBg.BackgroundColor3 = Color3.fromRGB(100, 220, 255)
boardsTabBg.ZIndex = 10
addCorner(boardsTabBg, 12)
addStroke(boardsTabBg, 6)

local srFill = Instance.new("Frame", boardsTabBg)
srFill.Size = UDim2.new(0, 12, 0, 12)
srFill.Position = UDim2.new(1, -12, 0, 0)
srFill.BackgroundColor3 = boardsTabBg.BackgroundColor3
srFill.BorderSizePixel = 0
srFill.ZIndex = 10

local srStrokeTop = Instance.new("Frame", boardsTabBg)
srStrokeTop.Size = UDim2.new(0, 12, 0, 6)
srStrokeTop.Position = UDim2.new(1, -12, 0, -6)
srStrokeTop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
srStrokeTop.BorderSizePixel = 0
srStrokeTop.ZIndex = 10

local srStrokeRight = Instance.new("Frame", boardsTabBg)
srStrokeRight.Size = UDim2.new(0, 6, 0, 18)
srStrokeRight.Position = UDim2.new(1, 0, 0, -6)
srStrokeRight.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
srStrokeRight.BorderSizePixel = 0
srStrokeRight.ZIndex = 10

local boardsTabBtn = Instance.new("TextButton", boardsTabContainer)
boardsTabBtn.Name = "BoardsTab"
boardsTabBtn.Size = UDim2.new(1, 0, 1, 0)
boardsTabBtn.BackgroundTransparency = 1
boardsTabBtn.Font = Enum.Font.FredokaOne
boardsTabBtn.Text = "호버보드"
boardsTabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
boardsTabBtn.TextSize = 28
boardsTabBtn.ZIndex = 12
addTextStroke(boardsTabBtn, 3)

-- 스킬 탭
local skillsTabContainer = Instance.new("Frame", tabsFrame)
skillsTabContainer.Name = "SkillsTabContainer"
skillsTabContainer.Size = UDim2.new(0, 164, 0, 56)
skillsTabContainer.BackgroundTransparency = 1
skillsTabContainer.ClipsDescendants = true
skillsTabContainer.ZIndex = 10

local skillsTabBg = Instance.new("Frame", skillsTabContainer)
skillsTabBg.Name = "SkillsTabBg"
skillsTabBg.Size = UDim2.new(1, -14, 1, 20)
skillsTabBg.Position = UDim2.new(0, 7, 0, 6)
skillsTabBg.BackgroundColor3 = Color3.fromRGB(180, 150, 255)
skillsTabBg.ZIndex = 10
addCorner(skillsTabBg, 12)
addStroke(skillsTabBg, 6)

local slFill = Instance.new("Frame", skillsTabBg)
slFill.Size = UDim2.new(0, 12, 0, 12)
slFill.Position = UDim2.new(0, 0, 0, 0)
slFill.BackgroundColor3 = skillsTabBg.BackgroundColor3
slFill.BorderSizePixel = 0
slFill.ZIndex = 10

local slStrokeTop = Instance.new("Frame", skillsTabBg)
slStrokeTop.Size = UDim2.new(0, 12, 0, 6)
slStrokeTop.Position = UDim2.new(0, 0, 0, -6)
slStrokeTop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
slStrokeTop.BorderSizePixel = 0
slStrokeTop.ZIndex = 10

local slStrokeLeft = Instance.new("Frame", skillsTabBg)
slStrokeLeft.Size = UDim2.new(0, 6, 0, 18)
slStrokeLeft.Position = UDim2.new(0, -6, 0, -6)
slStrokeLeft.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
slStrokeLeft.BorderSizePixel = 0
slStrokeLeft.ZIndex = 10

local skillsTabBtn = Instance.new("TextButton", skillsTabContainer)
skillsTabBtn.Name = "SkillsTab"
skillsTabBtn.Size = UDim2.new(1, 0, 1, 0)
skillsTabBtn.BackgroundTransparency = 1
skillsTabBtn.Font = Enum.Font.FredokaOne
skillsTabBtn.Text = "스킬"
skillsTabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
skillsTabBtn.TextSize = 28
skillsTabBtn.ZIndex = 12
addTextStroke(skillsTabBtn, 3)

local closeBtn = Instance.new("TextButton")
closeBtn.Name = "CloseButton"
closeBtn.Size = UDim2.new(0, 40, 0, 40)
closeBtn.Position = UDim2.new(1, -25, 0, -20)
closeBtn.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
closeBtn.Font = Enum.Font.FredokaOne
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.TextSize = 32
closeBtn.ZIndex = 15
closeBtn.Parent = bgFrame
addCorner(closeBtn, 12)
addStroke(closeBtn, 5)
addTextStroke(closeBtn, 3)

local leftCol = Instance.new("Frame", bgFrame)
leftCol.Name = "LeftColumn"
leftCol.Size = UDim2.new(0.6, -10, 1, -60)
leftCol.Position = UDim2.new(0, 30, 0, 30)
leftCol.BackgroundTransparency = 1
leftCol.ZIndex = 7

local boardsScroll = Instance.new("ScrollingFrame", leftCol)
boardsScroll.Name = "BoardsScroll"
boardsScroll.Size = UDim2.new(1, 0, 1, 0)
boardsScroll.BackgroundTransparency = 1
boardsScroll.ScrollBarThickness = 8
boardsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
boardsScroll.Visible = true
boardsScroll.ZIndex = 7
local boardsGrid = Instance.new("UIGridLayout", boardsScroll)
boardsGrid.CellSize = UDim2.new(0, 140, 0, 180)
boardsGrid.CellPadding = UDim2.new(0, 15, 0, 15)
boardsGrid.HorizontalAlignment = Enum.HorizontalAlignment.Left

local skillsScroll = Instance.new("ScrollingFrame", leftCol)
skillsScroll.Name = "SkillsScroll"
skillsScroll.Size = UDim2.new(1, 0, 1, 0)
skillsScroll.BackgroundTransparency = 1
skillsScroll.ScrollBarThickness = 8
skillsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
skillsScroll.Visible = false
skillsScroll.ZIndex = 7
local skillsGrid = Instance.new("UIGridLayout", skillsScroll)
skillsGrid.CellSize = UDim2.new(0, 140, 0, 180)
skillsGrid.CellPadding = UDim2.new(0, 15, 0, 15)
skillsGrid.HorizontalAlignment = Enum.HorizontalAlignment.Left

local rightCol = Instance.new("Frame", bgFrame)
rightCol.Name = "RightColumn"
rightCol.Size = UDim2.new(0.4, -50, 1, -60)
rightCol.Position = UDim2.new(0.6, 20, 0, 30)
rightCol.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
rightCol.ZIndex = 7
addCorner(rightCol, 16)
addStroke(rightCol, 6)

local rImage = Instance.new("ImageLabel", rightCol)
rImage.Name = "ItemImage"
rImage.Size = UDim2.new(0.8, 0, 0.4, 0)
rImage.Position = UDim2.new(0.1, 0, 0.05, 0)
rImage.BackgroundTransparency = 1
rImage.Image = ""
rImage.ScaleType = Enum.ScaleType.Fit
rImage.ZIndex = 8

local rViewport = Instance.new("ViewportFrame", rightCol)
rViewport.Name = "ItemViewport"
rViewport.Size = UDim2.new(0.8, 0, 0.4, 0)
rViewport.Position = UDim2.new(0.1, 0, 0.05, 0)
rViewport.BackgroundColor3 = Color3.fromRGB(255, 230, 100)
rViewport.BackgroundTransparency = 0
rViewport.ZIndex = 8
addCorner(rViewport, 12)
addStroke(rViewport, 5)
rViewport.Visible = false

local rName = Instance.new("TextLabel", rightCol)
rName.Name = "ItemName"
rName.Size = UDim2.new(0.9, 0, 0, 60)
rName.Position = UDim2.new(0.05, 0, 0.48, 0)
rName.BackgroundTransparency = 1
rName.Font = Enum.Font.FredokaOne
rName.Text = "아이템을 선택하세요"
rName.TextColor3 = Color3.fromRGB(255, 255, 255)
rName.TextSize = 56
rName.TextScaled = true
rName.ZIndex = 8
addTextStroke(rName, 3)

local rDesc = Instance.new("TextLabel", rightCol)
rDesc.Name = "ItemDesc"
rDesc.Size = UDim2.new(0.9, 0, 0.25, 0)
rDesc.Position = UDim2.new(0.05, 0, 0.62, 0)
rDesc.BackgroundTransparency = 1
rDesc.Font = Enum.Font.GothamMedium
rDesc.Text = ""
rDesc.TextColor3 = Color3.fromRGB(40, 40, 40) -- 흰 배경이므로 어두운 텍스트가 잘 보임
rDesc.TextSize = 22
rDesc.TextWrapped = true
rDesc.TextYAlignment = Enum.TextYAlignment.Top
rDesc.ZIndex = 8
-- 설명글 외곽선(Stroke) 완전 제거

local actionBtn = Instance.new("TextButton", rightCol)
actionBtn.Name = "ActionButton"
actionBtn.Size = UDim2.new(0.9, 0, 0, 50)
actionBtn.Position = UDim2.new(0.05, 0, 1, -65)
actionBtn.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
actionBtn.Font = Enum.Font.FredokaOne
actionBtn.Text = "선택 안됨"
actionBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
actionBtn.TextSize = 28
actionBtn.Visible = false
actionBtn.ZIndex = 8
addCorner(actionBtn, 12)
addStroke(actionBtn, 5)
addTextStroke(actionBtn, 3)

-- ==========================================
-- 진짜 기능 작동을 위한 완벽한 CardTemplate 생성
-- (더미 카드는 전부 삭제했습니다. 플레이테스트 시 실제 아이템만 뜹니다!)
-- ==========================================
local cardTemplate = Instance.new("TextButton")
cardTemplate.Name = "CardTemplate"
cardTemplate.Size = UDim2.new(0, 140, 0, 180)
cardTemplate.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
cardTemplate.Text = ""
cardTemplate.Visible = false
cardTemplate.ZIndex = 8
addCorner(cardTemplate, 16)
addStroke(cardTemplate, 6)

-- 스킬 아이콘 띄울 이미지 영역
local imgLabel = Instance.new("ImageLabel", cardTemplate)
imgLabel.Name = "Image"
imgLabel.Size = UDim2.new(1, -20, 0, 110)
imgLabel.Position = UDim2.new(0, 10, 0, 10)
imgLabel.BackgroundTransparency = 1
imgLabel.ScaleType = Enum.ScaleType.Fit
imgLabel.ZIndex = 9
imgLabel.Visible = false

-- 호버보드 색상을 띄울 빈 프레임 (Viewport)
local vpf = Instance.new("Frame", cardTemplate)
vpf.Name = "Viewport"
vpf.Size = UDim2.new(1, -20, 0, 110)
vpf.Position = UDim2.new(0, 10, 0, 10)
vpf.BackgroundColor3 = Color3.fromRGB(255, 220, 80)
vpf.ZIndex = 9
addCorner(vpf, 12)
addStroke(vpf, 5)

-- 아이템 이름
local nameLabel2 = Instance.new("TextLabel", cardTemplate)
nameLabel2.Name = "ItemName"
nameLabel2.Size = UDim2.new(1, 0, 0, 30)
nameLabel2.Position = UDim2.new(0, 0, 0, 135)
nameLabel2.BackgroundTransparency = 1
nameLabel2.Font = Enum.Font.FredokaOne
nameLabel2.Text = "아이템"
nameLabel2.TextColor3 = Color3.fromRGB(255, 255, 255)
nameLabel2.TextSize = 24
nameLabel2.ZIndex = 9
addTextStroke(nameLabel2, 3)

cardTemplate.Parent = invGui

print("기능 구현 완벽 수정 완료! 더미 카드를 지우고 스크립트 연결을 100% 지원합니다.")
