local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

task.spawn(function()
    -- 1. Workspace에서 'box folder'를 찾을 때까지 기다립니다.
    local boxFolder = Workspace:WaitForChild("box folder", 30)
    if not boxFolder then return end
    
    -- 2. 그 안에서 'Model1'을 찾습니다.
    local model1 = boxFolder:WaitForChild("Model1", 10)
    if not model1 then return end
    
    -- 3. 호버링 애니메이션 세팅
    local initialPivot = model1:GetPivot()
    local bounceHeight = 0.5 -- 위아래 바운스 높이
    local bounceSpeed = 3    -- 바운스 속도
    
    -- 매 프레임마다 클라이언트에서 부드럽게 움직이도록 RenderStepped 사용
    RunService.RenderStepped:Connect(function()
        local timeNow = tick()
        local yOffset = math.sin(timeNow * bounceSpeed) * bounceHeight
        -- 로컬 좌표계(CFrame)가 아닌 월드 좌표계(Vector3) 기준으로 더해주어야 모델이 회전되어 있어도 항상 정위아래로만 움직입니다.
        local newPivot = initialPivot + Vector3.new(0, yOffset, 0)
        
        -- Model1 이동
        model1:PivotTo(newPivot)
    end)
end)
