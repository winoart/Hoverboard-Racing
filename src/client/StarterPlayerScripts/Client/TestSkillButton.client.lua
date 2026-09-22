-- 테스트용 골든 프리즈 발사 버튼 생성 스크립트
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

local gui = PlayerGui:FindFirstChild("TestSkillGUI")
if gui then gui:Destroy() end

gui = Instance.new("ScreenGui")
gui.Name = "TestSkillGUI"
gui.ResetOnSpawn = false
gui.Parent = PlayerGui

local btn = Instance.new("TextButton")
btn.Size = UDim2.new(0, 120, 0, 40)
btn.Position = UDim2.new(0, 20, 1, -60)
btn.Text = "스타터팩"
btn.Font = Enum.Font.FredokaOne
btn.TextScaled = true
btn.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
btn.TextColor3 = Color3.fromRGB(0, 0, 0)
btn.Parent = gui

btn.MouseButton1Click:Connect(function()
    local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("HoverboardRemotes")
    local useRemote = remotes and remotes:FindFirstChild("UseSkill")
    
    if useRemote then
        useRemote:FireServer("Skill_Premium")
        print("버튼 클릭! 골든 프리즈 발사!!!")
    else
        warn("UseSkill 리모트를 찾을 수 없습니다!")
    end
end)
