--!strict
-- DataAndInventoryServer.server.luau
-- Handles centralized DataStore loading/saving and Inventory (Equip) logic.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local PlayerDataStore = DataStoreService:GetDataStore("HoverboardData_v1")

-- Ensure remote folders exist
local hoverRemotes = ReplicatedStorage:FindFirstChild("HoverboardRemotes")
if not hoverRemotes then
	hoverRemotes = Instance.new("Folder")
	hoverRemotes.Name = "HoverboardRemotes"
	hoverRemotes.Parent = ReplicatedStorage
end

local skillRemotes = ReplicatedStorage:FindFirstChild("SkillRemotes")
if not skillRemotes then
	skillRemotes = Instance.new("Folder")
	skillRemotes.Name = "SkillRemotes"
	skillRemotes.Parent = ReplicatedStorage
end

-- Create Equip Remotes
local equipBoardRemote = Instance.new("RemoteFunction")
equipBoardRemote.Name = "EquipItem"
equipBoardRemote.Parent = hoverRemotes

local equipSkillRemote = Instance.new("RemoteFunction")
equipSkillRemote.Name = "EquipSkill"
equipSkillRemote.Parent = skillRemotes

-- 1. Setup Data on Join
Players.PlayerAdded:Connect(function(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player
	
	local gold = Instance.new("IntValue")
	gold.Name = "Gold"
	gold.Parent = leaderstats
	
	local ownedBoards = Instance.new("Folder")
	ownedBoards.Name = "OwnedHoverboards"
	ownedBoards.Parent = player
	
	local equippedBoardId = Instance.new("StringValue")
	equippedBoardId.Name = "EquippedHoverboardId"
	equippedBoardId.Parent = player
	
	local ownedSkills = Instance.new("Folder")
	ownedSkills.Name = "OwnedSkills"
	ownedSkills.Parent = player
	
	local equippedSkills = Instance.new("Folder")
	equippedSkills.Name = "EquippedSkills"
	equippedSkills.Parent = player
	
	local maxSkillSlots = Instance.new("IntValue")
	maxSkillSlots.Name = "MaxSkillSlots"
	maxSkillSlots.Parent = player
	
	local lastAttendanceDate = Instance.new("StringValue")
	lastAttendanceDate.Name = "LastAttendanceDate"
	lastAttendanceDate.Parent = player
	
	local attendanceStreak = Instance.new("IntValue")
	attendanceStreak.Name = "AttendanceStreak"
	attendanceStreak.Parent = player
	
	local dataLoaded = Instance.new("BoolValue")
	dataLoaded.Name = "DataLoaded"
	dataLoaded.Value = false
	dataLoaded.Parent = player
	
	-- Load Data
	local success, data = pcall(function()
		return PlayerDataStore:GetAsync(tostring(player.UserId))
	end)

	if success and data then
		gold.Value = data.Gold or 1000
		lastAttendanceDate.Value = data.LastAttendanceDate or ""
		attendanceStreak.Value = data.AttendanceStreak or 0
		
		-- [TESTING] Give 3000 gold
		gold.Value += 3000
		
		-- Load Boards
		equippedBoardId.Value = data.EquippedHoverboardId or "DefaultHoverboard"
		local bList = data.OwnedHoverboards or {"DefaultHoverboard"}
		for _, id in ipairs(bList) do
			local b = Instance.new("StringValue")
			b.Name = id
			b.Parent = ownedBoards
		end
		
		-- Load Skills
		maxSkillSlots.Value = data.MaxSkillSlots or 2
		local sList = data.OwnedSkills or {}
		for _, id in ipairs(sList) do
			local s = Instance.new("StringValue")
			s.Name = id
			s.Parent = ownedSkills
		end
		
		-- Migrate old EquippedSkillId to new EquippedSkills list
		local eqSkills = data.EquippedSkills or {}
		if data.EquippedSkillId and data.EquippedSkillId ~= "" and #eqSkills == 0 then
			table.insert(eqSkills, data.EquippedSkillId)
		end
		for _, id in ipairs(eqSkills) do
			local s = Instance.new("StringValue")
			s.Name = id
			s.Value = id
			s.Parent = equippedSkills
		end
		
		print("💾 [DataServer] Data loaded for " .. player.Name)
	else
		-- Default new player data
		gold.Value = 1000 + 3000 -- [TESTING] Give 3000 extra
		lastAttendanceDate.Value = ""
		attendanceStreak.Value = 0
		
		equippedBoardId.Value = "DefaultHoverboard"
		local b = Instance.new("StringValue")
		b.Name = "DefaultHoverboard"
		b.Parent = ownedBoards
		maxSkillSlots.Value = 2
		print("🆕 [DataServer] New profile for " .. player.Name)
	end
	
	-- Mark data as fully loaded
	dataLoaded.Value = true
end)

-- 2. Save Data on Leave
Players.PlayerRemoving:Connect(function(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local gold = leaderstats and leaderstats:FindFirstChild("Gold") :: IntValue
	
	local ownedBoardsFolder = player:FindFirstChild("OwnedHoverboards")
	local equippedBoardId = player:FindFirstChild("EquippedHoverboardId") :: StringValue
	
	local ownedSkillsFolder = player:FindFirstChild("OwnedSkills")
	local equippedSkillsFolder = player:FindFirstChild("EquippedSkills")
	local maxSkillSlots = player:FindFirstChild("MaxSkillSlots") :: IntValue
	
	local lastDate = player:FindFirstChild("LastAttendanceDate") :: StringValue
	local streak = player:FindFirstChild("AttendanceStreak") :: IntValue

	if gold and ownedBoardsFolder and equippedBoardId and ownedSkillsFolder and equippedSkillsFolder and maxSkillSlots then
		local bList = {}
		for _, child in ipairs(ownedBoardsFolder:GetChildren()) do
			table.insert(bList, child.Name)
		end
		
		local sList = {}
		for _, child in ipairs(ownedSkillsFolder:GetChildren()) do
			table.insert(sList, child.Name)
		end
		
		local eList = {}
		for _, child in ipairs(equippedSkillsFolder:GetChildren()) do
			table.insert(eList, child.Name)
		end

		local dataToSave = {
			Gold = gold.Value,
			OwnedHoverboards = bList,
			EquippedHoverboardId = equippedBoardId.Value,
			OwnedSkills = sList,
			EquippedSkills = eList,
			MaxSkillSlots = maxSkillSlots.Value,
			LastAttendanceDate = lastDate and lastDate.Value or "",
			AttendanceStreak = streak and streak.Value or 0
		}

		local success, err = pcall(function()
			PlayerDataStore:SetAsync(tostring(player.UserId), dataToSave)
		end)

		if not success then
			warn("🚨 [DataServer] Failed to save for " .. player.Name .. ": " .. tostring(err))
		else
			print("💾 [DataServer] Data saved for " .. player.Name)
		end
	end
end)

-- 3. Handle Equip Logic
equipBoardRemote.OnServerInvoke = function(player: Player, itemId: string)
	local ownedFolder = player:FindFirstChild("OwnedHoverboards")
	if ownedFolder and ownedFolder:FindFirstChild(itemId) then
		local equippedId = player:FindFirstChild("EquippedHoverboardId") :: StringValue?
		if equippedId then
			equippedId.Value = itemId
			return true, "장착 완료"
		end
	end
	return false, "보유하고 있지 않습니다."
end

equipSkillRemote.OnServerInvoke = function(player: Player, skillId: string)
	local ownedFolder = player:FindFirstChild("OwnedSkills")
	local equippedSkillsFolder = player:FindFirstChild("EquippedSkills")
	local maxSkillSlots = player:FindFirstChild("MaxSkillSlots") :: IntValue?
	
	if ownedFolder and equippedSkillsFolder and maxSkillSlots and ownedFolder:FindFirstChild(skillId) then
		local alreadyEquipped = equippedSkillsFolder:FindFirstChild(skillId)
		
		if alreadyEquipped then
			-- Toggle: Unequip
			alreadyEquipped:Destroy()
			return true, "스킬 해제 완료", false
		else
			-- Toggle: Equip (check slots)
			local currentCount = #equippedSkillsFolder:GetChildren()
			if currentCount >= maxSkillSlots.Value then
				return false, "슬롯이 가득 찼습니다. 기존 스킬을 해제해주세요."
			end
			
			local s = Instance.new("StringValue")
			s.Name = skillId
			s.Value = skillId
			s.Parent = equippedSkillsFolder
			return true, "스킬 장착 완료", true
		end
	end
	return false, "스킬을 보유하고 있지 않습니다."
end

-- 4. Attendance System
local attendanceRemotes = ReplicatedStorage:FindFirstChild("AttendanceRemotes")
if not attendanceRemotes then
	attendanceRemotes = Instance.new("Folder")
	attendanceRemotes.Name = "AttendanceRemotes"
	attendanceRemotes.Parent = ReplicatedStorage
end

local checkAttendanceRemote = Instance.new("RemoteFunction")
checkAttendanceRemote.Name = "CheckAttendance"
checkAttendanceRemote.Parent = attendanceRemotes

local claimAttendanceRemote = Instance.new("RemoteFunction")
claimAttendanceRemote.Name = "ClaimAttendance"
claimAttendanceRemote.Parent = attendanceRemotes

local function getTodayString()
	-- UTC+9 KST
	local kstTime = os.time() + (9 * 60 * 60)
	local dateTable = os.date("!*t", kstTime)
	return string.format("%04d-%02d-%02d", dateTable.year, dateTable.month, dateTable.day)
end

local function getYesterdayString()
	local kstTime = os.time() + (9 * 60 * 60) - (24 * 60 * 60)
	local dateTable = os.date("!*t", kstTime)
	return string.format("%04d-%02d-%02d", dateTable.year, dateTable.month, dateTable.day)
end

checkAttendanceRemote.OnServerInvoke = function(player: Player)
	local dataLoaded = player:WaitForChild("DataLoaded", 10) :: BoolValue?
	if dataLoaded and not dataLoaded.Value then
		dataLoaded.Changed:Wait()
	end

	local lastDateVal = player:FindFirstChild("LastAttendanceDate") :: StringValue?
	local streakVal = player:FindFirstChild("AttendanceStreak") :: IntValue?
	if not lastDateVal or not streakVal then return false, 0 end
	
	local today = getTodayString()
	local yesterday = getYesterdayString()
	local hasClaimedToday = (lastDateVal.Value == today)
	
	local currentStreak = streakVal.Value
	-- If they didn't claim yesterday and didn't claim today, streak resets
	if not hasClaimedToday and lastDateVal.Value ~= yesterday and lastDateVal.Value ~= "" then
		currentStreak = 0
		streakVal.Value = 0
	end
	
	return hasClaimedToday, currentStreak
end

claimAttendanceRemote.OnServerInvoke = function(player: Player)
	local dataLoaded = player:WaitForChild("DataLoaded", 10) :: BoolValue?
	if dataLoaded and not dataLoaded.Value then
		dataLoaded.Changed:Wait()
	end

	local lastDateVal = player:FindFirstChild("LastAttendanceDate") :: StringValue?
	local streakVal = player:FindFirstChild("AttendanceStreak") :: IntValue?
	local leaderstats = player:FindFirstChild("leaderstats")
	local goldVal = leaderstats and leaderstats:FindFirstChild("Gold") :: IntValue?
	
	if not lastDateVal or not streakVal or not goldVal then return false, "데이터 오류" end
	
	local today = getTodayString()
	local yesterday = getYesterdayString()
	
	if lastDateVal.Value == today then
		return false, "오늘은 이미 출석했습니다."
	end
	
	-- Update streak
	if lastDateVal.Value == yesterday then
		streakVal.Value += 1
	else
		streakVal.Value = 1
	end
	
	-- Reset after 14 days (2 weeks limit)
	if streakVal.Value > 14 then
		streakVal.Value = 1
	end
	
	lastDateVal.Value = today
	
	-- Calculate reward: 100 * streak
	local reward = streakVal.Value * 100
	goldVal.Value += reward
	
	return true, streakVal.Value, reward
end

