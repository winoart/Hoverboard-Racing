--!strict
-- AdminServer.server.lua
-- 관리자 인증, 설정 저장, MessagingService 처리

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")

local ADMIN_USERS = {
	winoart2025 = true
}

local AdminConfigStore = DataStoreService:GetDataStore("AdminConfig_v1")

local remotesFolder = ReplicatedStorage:FindFirstChild("HoverboardRemotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "HoverboardRemotes"
	remotesFolder.Parent = ReplicatedStorage
end

local adminAuthRemote = remotesFolder:FindFirstChild("AdminAuthStatus") :: RemoteEvent?
if not adminAuthRemote then
	adminAuthRemote = Instance.new("RemoteEvent")
	adminAuthRemote.Name = "AdminAuthStatus"
	adminAuthRemote.Parent = remotesFolder
end

local updatePromoFunc = remotesFolder:FindFirstChild("UpdatePromotionData") :: RemoteFunction?
if not updatePromoFunc then
	updatePromoFunc = Instance.new("RemoteFunction")
	updatePromoFunc.Name = "UpdatePromotionData"
	updatePromoFunc.Parent = remotesFolder
end

local getPromoFunc = remotesFolder:FindFirstChild("GetPromotionData") :: RemoteFunction?
if not getPromoFunc then
	getPromoFunc = Instance.new("RemoteFunction")
	getPromoFunc.Name = "GetPromotionData"
	getPromoFunc.Parent = remotesFolder
end

local function isAdmin(player: Player)
	return ADMIN_USERS[player.Name] == true
end

-- 유저 접속 시 관리자 권한 부여
Players.PlayerAdded:Connect(function(player)
	if isAdmin(player) then
		print("👑 [AdminServer] 관리자 접속 확인: " .. player.Name)
		task.delay(2, function()
			if adminAuthRemote then
				adminAuthRemote:FireClient(player, true)
			end
		end)
	end
end)

-- 프로모션 데이터 불러오기 (관리자 패널용)
getPromoFunc.OnServerInvoke = function(player)
	if not isAdmin(player) then return nil end
	
	local success, result = pcall(function()
		return AdminConfigStore:GetAsync("ShopData_v2")
	end)
	
	if success then
		if result and type(result) == "table" and result.Events then
			return result
		else
			-- 기본 구조 반환
			return { Events = {}, Passes = {}, Golds = {} }
		end
	else
		warn("🚨 [AdminServer] 상점 데이터 로드 실패", result)
		return { Events = {}, Passes = {}, Golds = {} }
	end
end

-- 상점 데이터 저장 (관리자 패널용)
updatePromoFunc.OnServerInvoke = function(player, newData)
	if not isAdmin(player) then return false, "권한이 없습니다." end
	
	local success, err = pcall(function()
		AdminConfigStore:SetAsync("ShopData_v2", newData)
	end)
	
	if success then
		print("👑 [AdminServer] " .. player.Name .. "님이 상점 데이터를 업데이트했습니다.")
		-- 다른 서버들에 변경 사항 알림
		pcall(function()
			MessagingService:PublishAsync("ShopDataUpdated", "Updated")
		end)
		return true, "성공적으로 저장되었습니다."
	else
		warn("🚨 [AdminServer] 상점 데이터 저장 실패:", err)
		return false, "저장 실패: " .. tostring(err)
	end
end
