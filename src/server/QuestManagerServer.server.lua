--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local QuestConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("QuestConfig"))

-- Remotes
local hoverRemotes = ReplicatedStorage:FindFirstChild("HoverboardRemotes")
if not hoverRemotes then
	hoverRemotes = Instance.new("Folder")
	hoverRemotes.Name = "HoverboardRemotes"
	hoverRemotes.Parent = ReplicatedStorage
end

local claimQuestRemote = Instance.new("RemoteFunction")
claimQuestRemote.Name = "ClaimQuestReward"
claimQuestRemote.Parent = hoverRemotes

local getQuestsRemote = Instance.new("RemoteFunction")
getQuestsRemote.Name = "GetQuestData"
getQuestsRemote.Parent = hoverRemotes

local questUpdateEvent = Instance.new("RemoteEvent")
questUpdateEvent.Name = "QuestUpdateEvent"
questUpdateEvent.Parent = hoverRemotes

-- Bindable Events for Server-side tracking
local QuestBindables = Instance.new("Folder")
QuestBindables.Name = "QuestBindables"
QuestBindables.Parent = ReplicatedStorage

local addProgressEvent = Instance.new("BindableEvent")
addProgressEvent.Name = "AddQuestProgress"
addProgressEvent.Parent = QuestBindables

local function getUTCStartOfDay()
	local now = os.time()
	local date = os.date("!*t", now)
	return os.time({year=date.year, month=date.month, day=date.day, hour=0, min=0, sec=0})
end

local function getUTCStartOfWeek()
	local now = os.time()
	local date = os.date("!*t", now)
	-- In Lua, wday is 1 for Sunday. Let's make week start on Monday.
	local wday = date.wday
	local daysSinceMonday = wday == 1 and 6 or (wday - 2)
	local startOfDay = os.time({year=date.year, month=date.month, day=date.day, hour=0, min=0, sec=0})
	return startOfDay - (daysSinceMonday * 86400)
end

-- select n random items from list
local function selectRandomQuests(list, n)
	local result = {}
	local copy = {}
	for _, v in ipairs(list) do table.insert(copy, v) end
	for i = 1, n do
		if #copy == 0 then break end
		local idx = math.random(1, #copy)
		table.insert(result, copy[idx].id)
		table.remove(copy, idx)
	end
	return result
end

local function initializeQuests(player, questData)
	local nowDaily = getUTCStartOfDay()
	local nowWeekly = getUTCStartOfWeek()
	
	local changed = false
	
	if not questData.DailyResetTime or questData.DailyResetTime < nowDaily then
		questData.DailyResetTime = nowDaily
		questData.DailyQuests = {}
		local selected = selectRandomQuests(QuestConfig.Daily, 2)
		for _, id in ipairs(selected) do
			table.insert(questData.DailyQuests, {id = id, progress = 0, completed = false, claimed = false})
		end
		changed = true
	end
	
	if not questData.WeeklyResetTime or questData.WeeklyResetTime < nowWeekly then
		questData.WeeklyResetTime = nowWeekly
		questData.WeeklyQuests = {}
		local selected = selectRandomQuests(QuestConfig.Weekly, 2)
		for _, id in ipairs(selected) do
			table.insert(questData.WeeklyQuests, {id = id, progress = 0, completed = false, claimed = false})
		end
		changed = true
	end
	
	return changed
end

local function syncQuestData(player, questData)
	local qStr = player:FindFirstChild("QuestDataJSON")
	if qStr then
		qStr.Value = HttpService:JSONEncode(questData)
		questUpdateEvent:FireClient(player)
	end
end

local function getParsedQuestData(player)
	local qStr = player:FindFirstChild("QuestDataJSON")
	if not qStr or qStr.Value == "" or qStr.Value == "{}" then return {} end
	local s, d = pcall(function() return HttpService:JSONDecode(qStr.Value) end)
	return (s and d) and d or {}
end

local function onPlayerAdded(player)
	task.spawn(function()
		local dataLoaded = player:WaitForChild("DataLoaded", 30)
		if dataLoaded then
			if not dataLoaded.Value then
				dataLoaded:GetPropertyChangedSignal("Value"):Wait()
			end
			local questData = getParsedQuestData(player)
			local changed = initializeQuests(player, questData)
			if changed or not questData.DailyResetTime then
				syncQuestData(player, questData)
			end
		end
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

getQuestsRemote.OnServerInvoke = function(player)
	return getParsedQuestData(player)
end

claimQuestRemote.OnServerInvoke = function(player, questId, isWeekly)
	local questData = getParsedQuestData(player)
	local list = isWeekly and questData.WeeklyQuests or questData.DailyQuests
	if not list then return false, "No quests found" end
	
	for _, q in ipairs(list) do
		if q.id == questId then
			if q.claimed then return false, "Already claimed" end
			if not q.completed then return false, "Not completed" end
			
			q.claimed = true
			
			-- Find reward amount
			local cfgList = isWeekly and QuestConfig.Weekly or QuestConfig.Daily
			local reward = 0
			for _, cfg in ipairs(cfgList) do
				if cfg.id == questId then
					reward = cfg.reward
					break
				end
			end
			
			if reward > 0 then
				local ls = player:FindFirstChild("leaderstats")
				local g = ls and ls:FindFirstChild("Gold")
				if g then
					g.Value += reward
				end
			end
			
			syncQuestData(player, questData)
			return true, reward
		end
	end
	return false, "Quest not found"
end

addProgressEvent.Event:Connect(function(userId, prefixMatch, amount)
	local player = Players:GetPlayerByUserId(userId)
	if not player then return end
	
	local questData = getParsedQuestData(player)
	local changed = false
	
	local function updateList(list, cfgList)
		if not list then return end
		for _, q in ipairs(list) do
			-- Check if the quest ID contains the prefix (e.g. "_play", "_win")
			if string.find(q.id, prefixMatch) and not q.completed then
				-- Find target
				local target = 999999
				for _, cfg in ipairs(cfgList) do
					if cfg.id == q.id then
						target = cfg.target
						break
					end
				end
				
				q.progress += amount
				if q.progress >= target then
					q.progress = target
					q.completed = true
				end
				changed = true
			end
		end
	end
	
	updateList(questData.DailyQuests, QuestConfig.Daily)
	updateList(questData.WeeklyQuests, QuestConfig.Weekly)
	
	if changed then
		syncQuestData(player, questData)
	end
end)
