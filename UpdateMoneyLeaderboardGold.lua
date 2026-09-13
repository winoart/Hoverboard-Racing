-- Roblox Studio 명령줄(Command Bar) 또는 즉시 실행용 스크립트:
-- 게임 내 워크스페이스에 배치된 머니 리더보드 및 관련 UI에서 '상금액' / '상금' 텍스트를 'Gold'로 일괄 변경합니다.

local count = 0
for _, desc in ipairs(workspace:GetDescendants()) do
	if desc:IsA("TextLabel") or desc:IsA("TextButton") then
		local noSpace = desc.Text:gsub("%s+", ""):lower()
		if noSpace == "상금액" or noSpace == "상금" or desc.Name == "MoneyTitle" then
			local oldText = desc.Text
			desc.Text = "Gold"
			count += 1
			print(string.format("✅ [Leaderboard] '%s' -> 'Gold' 변경 완료: %s", oldText, desc:GetFullName()))
		end
	end
end

print(string.format("🎉 총 %d개의 텍스트가 'Gold'로 성공적으로 변경되었습니다!", count))
