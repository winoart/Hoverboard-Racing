local Workspace = game:GetService("Workspace")

local moneyBoard = Workspace:FindFirstChild("MoneyLeaderboard", true) or Workspace:FindFirstChild("MoneyBoard", true)
if not moneyBoard then
    warn("❌ MoneyLeaderboard를 찾을 수 없습니다. 원본 모델이 있어야 레이아웃을 그대로 복제할 수 있습니다.")
    return
end

local existing = Workspace:FindFirstChild("HoverboardLeaderboard", true) or Workspace:FindFirstChild("GlobalLeaderboardBoard", true)
local targetCFrame = nil

if moneyBoard.PrimaryPart then
    targetCFrame = moneyBoard:GetPivot()
elseif moneyBoard:FindFirstChild("ScreenPart") then
    targetCFrame = moneyBoard.ScreenPart.CFrame
end

if existing then
	if existing.PrimaryPart then
		targetCFrame = existing:GetPivot()
	elseif existing:FindFirstChild("ScreenPart") then
		targetCFrame = existing.ScreenPart.CFrame
	end
	existing:Destroy()
else
    -- 기존 우승 보드가 없으면 MoneyBoard의 왼쪽으로 20스터드 이동시켜 배치
    if targetCFrame then
        targetCFrame = targetCFrame * CFrame.new(-20, 0, 0)
    end
end

local cloneBoard = moneyBoard:Clone()
cloneBoard.Name = "HoverboardLeaderboard"
cloneBoard.Parent = moneyBoard.Parent

if not cloneBoard.PrimaryPart and cloneBoard:FindFirstChild("ScreenPart") then
    cloneBoard.PrimaryPart = cloneBoard.ScreenPart
end

if targetCFrame and cloneBoard.PrimaryPart then
    cloneBoard:PivotTo(targetCFrame)
end

-- 텍스트 교체 (상금 관련 텍스트 -> 우승 관련 텍스트)
local function replaceText(obj, findText, replaceTextStr, fontSize)
    for _, desc in ipairs(obj:GetDescendants()) do
        if desc:IsA("TextLabel") or desc:IsA("TextButton") then
            -- 띄어쓰기 무시하고 일치하는지 검사
            local noSpaceCurrent = desc.Text:gsub("%s+", ""):lower()
            local noSpaceFind = findText:gsub("%s+", ""):lower()
            if noSpaceCurrent == noSpaceFind then
                desc.Text = replaceTextStr
                desc.Font = Enum.Font.FredokaOne
                if fontSize then
                    desc.TextSize = fontSize
                end
            end
        end
    end
end

-- 기존 한글 및 영문 모두 체크하여 번역 교체
replaceText(cloneBoard, "상금순위", "TOP\nWINS", 65)
replaceText(cloneBoard, "TOPGOLD", "TOP\nWINS", 65)
replaceText(cloneBoard, "TOP GOLD", "TOP\nWINS", 65)

replaceText(cloneBoard, "상금", "Wins")
replaceText(cloneBoard, "상금액", "Wins")
replaceText(cloneBoard, "Gold", "Wins")

-- 3. 서버 스크립트(LeaderboardServer)가 데이터를 바인딩할 수 있도록 오브젝트 이름(Name) 변경
for _, desc in ipairs(cloneBoard:GetDescendants()) do
    if desc.Name == "Money" then
        desc.Name = "Wins"
    elseif desc.Name == "MoneyTitle" then
        desc.Name = "WinsTitle"
    end
end

print("✅ MoneyLeaderboard 원본 레이아웃을 그대로 복제하여 HoverboardLeaderboard를 생성했습니다!")
