-- GenerateThickCartoonLeaderboard.lua
-- 1~10위까지 샘플 데이터를 스튜디오 편집 모드에서도 바로 볼 수 있도록 정적으로 생성합니다!
-- 닉네임 15자 제한 및 '...' 생략 기능도 적용되었습니다.

local Workspace = game:GetService("Workspace")

local baseCFrame = nil
local existing = Workspace:FindFirstChild("HoverboardLeaderboard", true) or Workspace:FindFirstChild("GlobalLeaderboardBoard", true)
if existing then
	-- 사용자가 스튜디오에서 직접 이동해둔 위치를 기억해둡니다!
	if existing.PrimaryPart then
		baseCFrame = existing:GetPivot()
	elseif existing:FindFirstChild("ScreenPart") then
		baseCFrame = existing.ScreenPart.CFrame
	end
	existing:Destroy()
end

local waitingRoom = Workspace:FindFirstChild("WaitingRoom") or Workspace:FindFirstChild("스폰장소") or Workspace

-- 기존 위치가 없다면(처음 생성시) 대기실 기준으로 기본 위치 지정 (90도 직각)
if not baseCFrame then
	if waitingRoom and waitingRoom:IsA("BasePart") then
		baseCFrame = waitingRoom.CFrame * CFrame.new(0, 12, -30) * CFrame.Angles(0, math.rad(180), 0)
	elseif waitingRoom and waitingRoom:IsA("Model") and waitingRoom.PrimaryPart then
		baseCFrame = waitingRoom:GetPivot() * CFrame.new(0, 12, -30) * CFrame.Angles(0, math.rad(180), 0)
	else
		baseCFrame = CFrame.new(0, 12, -30) * CFrame.Angles(0, math.rad(180), 0)
	end
end

local model = Instance.new("Model")
model.Name = "HoverboardLeaderboard"

-- 1. 메인 투명 스크린 파트 (전체 크기 3/4로 축소)
local screenPart = Instance.new("Part")
screenPart.Name = "ScreenPart"
screenPart.Size = Vector3.new(18, 22.5, 0.1) -- 24x30의 3/4 사이즈
screenPart.Anchored = true
screenPart.CanCollide = false
screenPart.Transparency = 1 
screenPart.Parent = model
model.PrimaryPart = screenPart
screenPart.CFrame = baseCFrame

-- 대형 텍스트(500 사이즈)를 띄울 전용 투명 파트 생성
local titlePart = Instance.new("Part")
titlePart.Name = "TitlePart"
titlePart.Size = Vector3.new(18, 15, 0.1) 
titlePart.Anchored = true
titlePart.CanCollide = false
titlePart.Transparency = 1
-- 3/4 스케일 기준: screenPart 높이(22.5)의 절반 + titlePart 높이(15) 절반 (살짝 겹치게 -1.5)
titlePart.CFrame = baseCFrame * CFrame.new(0, (22.5/2) + (15/2) - 1.5, 0)
titlePart.Parent = model

local titleGui = Instance.new("SurfaceGui")
titleGui.Name = "GiantTitleGui"
titleGui.Face = Enum.NormalId.Front
-- 캔버스 크기를 대폭 줄이면, 글자가 차지하는 비율이 기하급수적으로 커져서 100 제한을 뚫습니다!
titleGui.CanvasSize = Vector2.new(400, 200) 
titleGui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
titleGui.LightInfluence = 0
titleGui.Parent = titlePart

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "TitleLabel"
titleLabel.Size = UDim2.fromScale(1, 1)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "레이싱\n우승횟수"
titleLabel.Font = Enum.Font.GothamBlack
titleLabel.TextScaled = true 
titleLabel.TextColor3 = Color3.fromRGB(255, 230, 0) -- 노란색
titleLabel.TextXAlignment = Enum.TextXAlignment.Center
titleLabel.TextYAlignment = Enum.TextYAlignment.Center
titleLabel.Parent = titleGui

local tStroke = Instance.new("UIStroke")
tStroke.Color = Color3.fromRGB(0, 0, 0)
tStroke.Thickness = 2 -- 캔버스가 작아졌으므로 테두리 두께도 비례해서 2로 설정 (원래의 10 두께 효과)
tStroke.Parent = titleLabel

local function createRoundedBox(name, width, height, depth, cornerRadius, color, offsetZ)
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = model
	
	local function makePart(pName, size, cf)
		local p = Instance.new("Part")
		p.Name = pName
		p.Size = size
		p.Anchored = true
		p.CanCollide = true
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.CFrame = cf
		p.Parent = folder
		return p
	end

	local function makeCylinder(pName, size, cf)
		local p = Instance.new("Part")
		p.Name = pName
		p.Shape = Enum.PartType.Cylinder
		p.Size = size
		p.Anchored = true
		p.CanCollide = true
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.CFrame = cf
		p.Parent = folder
		return p
	end
	
	local centerW = width - (cornerRadius * 2)
	local centerH = height - (cornerRadius * 2)
	local baseCF = baseCFrame * CFrame.new(0, 0, offsetZ)
	
	makePart("Center", Vector3.new(centerW, centerH, depth), baseCF)
	makePart("TopMid", Vector3.new(centerW, cornerRadius, depth), baseCF * CFrame.new(0, centerH/2 + cornerRadius/2, 0))
	makePart("BottomMid", Vector3.new(centerW, cornerRadius, depth), baseCF * CFrame.new(0, -(centerH/2 + cornerRadius/2), 0))
	makePart("LeftMid", Vector3.new(cornerRadius, centerH, depth), baseCF * CFrame.new(-(centerW/2 + cornerRadius/2), 0, 0))
	makePart("RightMid", Vector3.new(cornerRadius, centerH, depth), baseCF * CFrame.new(centerW/2 + cornerRadius/2, 0, 0))
	
	local cylSize = Vector3.new(depth, cornerRadius * 2, cornerRadius * 2)
	makeCylinder("TopLeft", cylSize, baseCF * CFrame.new(-centerW/2, centerH/2, 0) * CFrame.Angles(0, math.pi/2, 0))
	makeCylinder("TopRight", cylSize, baseCF * CFrame.new(centerW/2, centerH/2, 0) * CFrame.Angles(0, math.pi/2, 0))
	makeCylinder("BottomLeft", cylSize, baseCF * CFrame.new(-centerW/2, -centerH/2, 0) * CFrame.Angles(0, math.pi/2, 0))
	makeCylinder("BottomRight", cylSize, baseCF * CFrame.new(centerW/2, -centerH/2, 0) * CFrame.Angles(0, math.pi/2, 0))
end

-- 3D 둥근 사각형 몸통 (전체 크기 3/4로 축소)
local cornerR = 1.5 -- 2의 3/4
createRoundedBox("MainBody", 18, 22.5, 1.125, cornerR, Color3.fromRGB(100, 220, 110), 0.56) 
createRoundedBox("BlackOutline", 18.9, 23.4, 1.5, cornerR + 0.45, Color3.fromRGB(0, 0, 0), 0.825)

-- ==========================================
-- 3. 2D UI (SurfaceGui)
-- ==========================================
local surfaceGui = Instance.new("SurfaceGui")
surfaceGui.Name = "RaceBoard"
surfaceGui.Face = Enum.NormalId.Front
surfaceGui.CanvasSize = Vector2.new(1200, 1500) -- 높이를 1500으로 증가시켜 하단 여백 확보
surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
surfaceGui.LightInfluence = 0
surfaceGui.Parent = screenPart

local root = Instance.new("Frame")
root.Name = "Root"
root.Size = UDim2.fromScale(1, 1)
root.BackgroundColor3 = Color3.fromRGB(100, 220, 110) -- 2D UI 배경색도 초록색으로 변경!
root.BorderSizePixel = 0
root.Parent = surfaceGui

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 100) 
uiCorner.Parent = root
local uiStroke = Instance.new("UIStroke")
uiStroke.Color = Color3.fromRGB(0, 0, 0)
uiStroke.Thickness = 12
uiStroke.Parent = root

local innerHighlight = Instance.new("Frame")
innerHighlight.Size = UDim2.new(1, -24, 1, -24)
innerHighlight.Position = UDim2.new(0, 12, 0, 12)
innerHighlight.BackgroundTransparency = 1
innerHighlight.Parent = root
local ihCorner = Instance.new("UICorner")
ihCorner.CornerRadius = UDim.new(0, 88)
ihCorner.Parent = innerHighlight
local ihStroke = Instance.new("UIStroke")
ihStroke.Color = Color3.fromRGB(255, 255, 255)
ihStroke.Thickness = 6
ihStroke.Parent = innerHighlight

local container = Instance.new("Frame")
container.Name = "Container"
container.Size = UDim2.new(1, -100, 1, -120) -- 타이틀을 별도 파트로 뺐으므로 리스트 공간 최대화
container.Position = UDim2.new(0, 50, 0, 50) -- 리스트를 다시 위로 올림
container.BackgroundTransparency = 1
container.Parent = root

local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 25)
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.Parent = container

-- (이전에 있던 TitleBox 관련 코드는 TitlePart로 분리되면서 완전히 삭제되었습니다)

local spacer = Instance.new("Frame")
spacer.Size = UDim2.new(1, 0, 0, 30) -- 타이틀과 헤더 사이 여백도 증가
spacer.BackgroundTransparency = 1
spacer.LayoutOrder = 0
spacer.Parent = container

local colHeader = Instance.new("Frame")
colHeader.Name = "ColumnHeader"
colHeader.Size = UDim2.new(1, -20, 0, 60)
colHeader.BackgroundColor3 = Color3.fromRGB(40, 180, 255) -- 이미지와 비슷한 쨍한 파란색
colHeader.BackgroundTransparency = 0
colHeader.LayoutOrder = 1
colHeader.Parent = container

local chCorner = Instance.new("UICorner")
chCorner.CornerRadius = UDim.new(0.5, 0)
chCorner.Parent = colHeader
local chStroke = Instance.new("UIStroke")
chStroke.Color = Color3.fromRGB(0, 0, 0)
chStroke.Thickness = 6
chStroke.Parent = colHeader

local function createDivider(xPos)
	local div = Instance.new("Frame")
	div.Size = UDim2.new(0, 3, 0.5, 0)
	div.Position = UDim2.new(0, xPos, 0.25, 0)
	div.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	div.BackgroundTransparency = 0.5
	div.BorderSizePixel = 0
	div.Parent = colHeader
end

-- 순위(140)와 프로필사진 사이
createDivider(155)
-- 닉네임(810)과 우승 횟수(850) 사이
createDivider(830)

local function createText(name, text, size, pos, parent)
	local lbl = Instance.new("TextLabel")
	lbl.Name = name
	lbl.Size = size
	lbl.Position = pos
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.Font = Enum.Font.GothamBlack
	lbl.TextSize = 65 -- 헤더 글씨도 65로 대폭 키움
	lbl.TextColor3 = Color3.fromRGB(30, 30, 30) -- 모든 폰트 검정색으로 변경
	lbl.TextXAlignment = Enum.TextXAlignment.Center
	lbl.Parent = parent
	
	-- 헤더 외곽선 완전히 제거
	return lbl
end

-- 공간 대폭 재배치 (가로 1200 캔버스 기준)
createText("RankTitle", "순위", UDim2.new(0, 100, 1, 0), UDim2.new(0, 40, 0, 0), colHeader)
createText("NameTitle", "닉네임", UDim2.new(0, 550, 1, 0), UDim2.new(0, 260, 0, 0), colHeader)
createText("WinsTitle", "우승 횟수", UDim2.new(0, 200, 1, 0), UDim2.new(0, 850, 0, 0), colHeader)

-- ==========================================
-- Row Template (보이지 않게 숨겨둠)
-- ==========================================
local rowContainer = Instance.new("Frame")
rowContainer.Name = "RowTemplate"
rowContainer.Size = UDim2.new(1, -20, 0, 90) -- 줄 높이를 90으로 대폭 증가시켜 가독성 확보
rowContainer.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
rowContainer.Visible = false
rowContainer.Parent = container

local rsCorner = Instance.new("UICorner")
rsCorner.CornerRadius = UDim.new(0.5, 0) 
rsCorner.Parent = rowContainer
local rsStroke = Instance.new("UIStroke")
rsStroke.Color = Color3.fromRGB(0, 0, 0)
rsStroke.Thickness = 6
rsStroke.Parent = rowContainer

local function createRowText(name, text, size, pos, align, parent)
	local lbl = Instance.new("TextLabel")
	lbl.Name = name
	lbl.Size = size
	lbl.Position = pos
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.Font = Enum.Font.GothamBlack
	lbl.TextSize = 65 
	lbl.TextColor3 = Color3.fromRGB(30, 30, 30) -- 본문 글씨를 검정색으로 변경
	lbl.TextXAlignment = align
	lbl.Parent = parent
	
	-- 외곽선(UIStroke) 완전히 제거
	return lbl
end

createRowText("Rank", "1", UDim2.new(0, 100, 1, 0), UDim2.new(0, 40, 0, 0), Enum.TextXAlignment.Center, rowContainer)

local profilePic = Instance.new("ImageLabel")
profilePic.Name = "ProfilePic"
profilePic.Size = UDim2.new(0, 60, 0, 60)
profilePic.Position = UDim2.new(0, 170, 0.5, -30)
profilePic.BackgroundTransparency = 1
profilePic.Image = "rbxassetid://0"
profilePic.Parent = rowContainer
local picCorner = Instance.new("UICorner")
picCorner.CornerRadius = UDim.new(1, 0)
picCorner.Parent = profilePic
local picStroke = Instance.new("UIStroke")
picStroke.Color = Color3.fromRGB(0, 0, 0)
picStroke.Thickness = 4
picStroke.Parent = profilePic

-- 닉네임 박스를 550픽셀로 초대형화하여 글씨가 절대로 겹치지 않게 함
createRowText("PlayerName", "Username", UDim2.new(0, 550, 1, 0), UDim2.new(0, 260, 0, 0), Enum.TextXAlignment.Left, rowContainer)
createRowText("Wins", "0", UDim2.new(0, 200, 1, 0), UDim2.new(0, 850, 0, 0), Enum.TextXAlignment.Center, rowContainer)

-- ==========================================
-- 샘플 데이터 10개 정적 생성 (스튜디오 프리뷰용)
-- ==========================================
local sampleData = {
	{name = "SpeedDemon", wins = 9999},
	{name = "ProRacer_X", wins = 8520},
	{name = "HoverboardKing", wins = 7431},
	{name = "ThisIsALongNameOver15", wins = 6200},
	{name = "WinoArt2025", wins = 5120},
	{name = "FastAndFurious", wins = 4800},
	{name = "SuperLongNicknameHere", wins = 3300},
	{name = "NoobRacer123", wins = 2100},
	{name = "RobloxMaster", wins = 1500},
	{name = "HoverFanatic", wins = 800},
}

for i = 1, 10 do
	local data = sampleData[i]
	local row = rowContainer:Clone()
	row.Name = "SampleRow_" .. i
	row.Visible = true
	row.LayoutOrder = i + 1
	
	-- 등수 별 색상 적용 (이미지 참고)
	if i == 1 then row.BackgroundColor3 = Color3.fromRGB(255, 200, 50) -- Vibrant Gold
	elseif i == 2 then row.BackgroundColor3 = Color3.fromRGB(210, 220, 230) -- Cool Silver
	elseif i == 3 then row.BackgroundColor3 = Color3.fromRGB(220, 140, 90) -- Warm Bronze
	else row.BackgroundColor3 = Color3.fromRGB(150, 240, 255) end -- Bright Cyan (4th~10th)
	
	row.Rank.Text = tostring(i)
	row.Wins.Text = tostring(data.wins)
	
	-- 닉네임 12자 제한 로직
	local displayName = data.name
	if string.len(displayName) > 12 then
		displayName = string.sub(displayName, 1, 12) .. "..."
	end
	row.PlayerName.Text = displayName
	
	row.Parent = container
end

model.Parent = waitingRoom
print("✅ 1~10위 샘플 데이터가 포함된 시뮬레이터 전광판 생성 완료!")
