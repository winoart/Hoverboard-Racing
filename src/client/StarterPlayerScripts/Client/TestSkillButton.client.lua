--!strict
-- TestSkillButton.client.lua
-- (스타터팩 테스트 버튼 비활성화)

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

local gui = PlayerGui:FindFirstChild("TestSkillGUI")
if gui then
	gui:Destroy()
end
