--!strict
-- PromoCodeServer.server.luau
-- Manages promotional codes, rewards, and redemption tracking.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local remotesFolder = ReplicatedStorage:WaitForChild("HoverboardRemotes") :: Folder

-- Ensure RemoteFunction exists
local redeemRemote = remotesFolder:FindFirstChild("RedeemPromoCode") :: RemoteFunction?
if not redeemRemote then
	redeemRemote = Instance.new("RemoteFunction")
	redeemRemote.Name = "RedeemPromoCode"
	redeemRemote.Parent = remotesFolder
end

local promoCodeStore = DataStoreService:GetDataStore("PlayerPromoCodes_v1")

-- Valid Promo Codes definition
local VALID_CODES: { [string]: { rewardGold: number, description: string } } = {
	["WELCOME"] = { rewardGold = 1000, description = "웰컴 선물 1,000 골드" },
	["HOVER2026"] = { rewardGold = 1500, description = "2026 호버보드 축하 1,500 골드" },
	["BOOSTER"] = { rewardGold = 800, description = "부스터 응원 800 골드" },
	["SPEED"] = { rewardGold = 1000, description = "스피드 보너스 1,000 골드" },
	["FREEGOLD"] = { rewardGold = 500, description = "골드 충전 500 골드" },
}

-- In-memory cache for redeemed codes per player: [UserId] -> { [CODE] = true }
local playerRedeemedCodes: { [number]: { [string]: boolean } } = {}

-- Load player redeemed codes upon join
local function onPlayerAdded(player: Player)
	local userId = player.UserId
	playerRedeemedCodes[userId] = {}

	task.spawn(function()
		local success, savedList = pcall(function()
			return promoCodeStore:GetAsync(tostring(userId))
		end)

		if success and type(savedList) == "table" and playerRedeemedCodes[userId] then
			for _, codeName in ipairs(savedList) do
				if type(codeName) == "string" then
					playerRedeemedCodes[userId][codeName] = true
				end
			end
		end
	end)
end

local function onPlayerRemoving(player: Player)
	playerRedeemedCodes[player.UserId] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, p in ipairs(Players:GetPlayers()) do
	onPlayerAdded(p)
end

-- Handle Code Redemption Request from Client
redeemRemote.OnServerInvoke = function(player: Player, rawCode: any)
	if type(rawCode) ~= "string" then
		return false, "올바르지 않은 코드 형식입니다."
	end

	local code = string.upper(string.gsub(rawCode, "%s+", ""))
	if code == "" then
		return false, "코드를 입력해 주세요."
	end

	local codeData = VALID_CODES[code]
	if not codeData then
		return false, "유효하지 않거나 존재하지 않는 코드입니다."
	end

	local redeemedMap = playerRedeemedCodes[player.UserId]
	if not redeemedMap then
		redeemedMap = {}
		playerRedeemedCodes[player.UserId] = redeemedMap
	end

	if redeemedMap[code] then
		return false, "이미 사용 완료된 코드입니다."
	end

	-- Mark as redeemed
	redeemedMap[code] = true

	-- Persist to DataStore
	task.spawn(function()
		pcall(function()
			local list = {}
			for c, _ in pairs(redeemedMap) do
				table.insert(list, c)
			end
			promoCodeStore:SetAsync(tostring(player.UserId), list)
		end)
	end)

	-- Award Gold Reward
	local leaderstats = player:FindFirstChild("leaderstats")
	local goldVal = leaderstats and leaderstats:FindFirstChild("Gold") :: IntValue?
	if goldVal then
		goldVal.Value += codeData.rewardGold
	end

	return true, string.format("🎉 코드 등록 성공! +%d 골드가 지급되었습니다.", codeData.rewardGold), codeData.rewardGold
end
