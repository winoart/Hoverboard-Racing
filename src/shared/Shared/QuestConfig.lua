--!strict
local QuestConfig = {}

QuestConfig.Daily = {
	{ id = "d_play", title = "Participant", desc = "Finish any race 3 times", target = 3, reward = 300, icon = "rbxassetid://13583568770" },
	{ id = "d_win", title = "Pro Racer", desc = "Win 1st place in a race", target = 1, reward = 500, icon = "rbxassetid://13583568770" },
	{ id = "d_skill", title = "Skill Master", desc = "Use 5 skills during races", target = 5, reward = 300, icon = "rbxassetid://13583568770" },
	{ id = "d_gold", title = "Rich Kid", desc = "Collect 1,000 Gold", target = 1000, reward = 400, icon = "rbxassetid://13583568770" },
	{ id = "d_dist", title = "Long Runner", desc = "Travel 5,000 distance", target = 5000, reward = 400, icon = "rbxassetid://13583568770" },
	{ id = "d_box", title = "Item Farmer", desc = "Obtain 3 skill boxes", target = 3, reward = 200, icon = "rbxassetid://13583568770" },
}

QuestConfig.Weekly = {
	{ id = "w_play", title = "Veteran Racer", desc = "Finish any race 30 times", target = 30, reward = 2500, icon = "rbxassetid://13583568770" },
	{ id = "w_win", title = "Champion", desc = "Win 1st place 10 times", target = 10, reward = 4000, icon = "rbxassetid://13583568770" },
	{ id = "w_skill", title = "Skill Artisan", desc = "Use 50 skills during races", target = 50, reward = 3000, icon = "rbxassetid://13583568770" },
	{ id = "w_gold", title = "Billionaire", desc = "Collect 10,000 Gold", target = 10000, reward = 3500, icon = "rbxassetid://13583568770" },
	{ id = "w_dist", title = "Marathoner", desc = "Travel 50,000 distance", target = 50000, reward = 3000, icon = "rbxassetid://13583568770" },
	{ id = "w_spend", title = "Big Spender", desc = "Spend 5,000 Gold in shop", target = 5000, reward = 2000, icon = "rbxassetid://13583568770" },
}

return QuestConfig
