local QuestService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Table = require(ReplicatedStorage.Modules.Shared.Table)
local DataService = require(script.Parent.DataService)
local Types = require(ReplicatedStorage.Modules.Shared.Types)
local Future = require(ReplicatedStorage.Packages.Future)
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)

-- QUEST TYPES:
-- Get X kills
-- Get X wins
-- Play X matches
-- Collect X boosters
-- Deal X amount of damage
-- Use X skills  ( this one is a bit iffy, but they'll also be trying to complete other quests so I don't think
--                 it'd cause people to just waste their skills in order to complete the quest )
-- Final 2
-- Use X supers

local QuestCounts = {
	Easy = 3,
	Medium = 2,
	Hard = 1,
}

local QuestRewards = {
	Easy = 100,
	Medium = 200,
	Hard = 400,
}

-- Defines number of kills etc needed to complete the quest for each difficulty
local QuestData = {
	Kill = {
		Easy = 5,
		Medium = 15,
		Hard = 30,
		Text = "Kill %d players",
	},
	KillOneGame = {
		Easy = 2,
		Medium = 3,
		Hard = 4,
		Text = "Kill %d players in one game",
	},
	Win = {
		Easy = 1,
		Medium = 3,
		Hard = 5,
		Text = "Win %d games",
		SingularText = "Win 1 game",
	},
	Finals = {
		Easy = 3,
		Medium = 6,
		Hard = 9,
		Text = "Get in the top two %d times.",
	},
	Play = {
		Easy = 8,
		Medium = 20,
		Hard = 35,
		Text = "Play %d games",
	},
	Collect = {
		Easy = 10,
		Medium = 25,
		Hard = 40,
		Text = "Collect %d boosters",
	},
	Damage = {
		Easy = 20000,
		Medium = 50000,
		Hard = 80000,
		Text = "Deal %d damage",
	},
	Skills = {
		Easy = 15,
		Medium = 30,
		Hard = 45,
		Text = "Use your skill %d times",
	},
	Super = {
		Easy = 5,
		Medium = 15,
		Hard = 25,
		Text = "Use your super %d times",
	},
}

local QuestTypes = TableUtil.Keys(QuestData)

assert(#QuestTypes >= (QuestCounts.Easy + QuestCounts.Medium + QuestCounts.Hard), "Not enough unique quest types!")

local random = Random.new()

function GetQuestText(questType: string, value: number)
	local questData = QuestData[questType]
	if value == 1 then
		return questData.SingularText
	else
		return string.format(questData.Text, value)
	end
end

function GenerateRandomQuest(difficulty: "Easy" | "Medium" | "Hard"): Types.Quest
	local randomIndex = random:NextInteger(1, #QuestTypes)
	local randomType = QuestTypes[randomIndex]
	local typeData = QuestData[randomType]

	local questNumber = typeData[difficulty]

	return {
		Type = randomType,
		Difficulty = difficulty,
		CurrentNumber = 0,
		RequiredNumber = questNumber,
		Reward = QuestRewards[difficulty],
		Text = GetQuestText(randomType, questNumber),
	}
end

function GenerateQuests(player: Player)
	return Future.new(function()
		local data = DataService.GetPrivateData(player):Await()
		if not data then
			return
		end

		-- Must do this instead of clearing table so we do not overwrite the metatable
		-- Which would cause it to stop working properly
		Table.ReplaceTable(data, "Quests", {})

		local totalCount = 0
		local doneTypes = {}
		for difficulty, count in pairs(QuestCounts) do
			for i = 1, count do
				totalCount += 1
				local quest
				repeat
					quest = GenerateRandomQuest(difficulty)
				until not doneTypes[quest.Type]
				doneTypes[quest.Type] = true

				-- Don't use table.insert as it doesn't trigger __newindex. this might not matter, but better not to anyway
				data.Quests[totalCount] = quest
			end
		end

		RunService.Stepped:Connect(function()
			data.Quests[1].CurrentNumber += 1
		end)
	end)
end

function PlayerAdded(player: Player)
	return Future.new(function()
		local loaded = DataService.PlayerLoaded(player):Await()
		if not loaded then
			return
		end

		GenerateQuests(player)
	end)
end

function QuestService.Initialize()
	for i, player in ipairs(Players:GetPlayers()) do
		PlayerAdded(player)
	end
	Players.PlayerAdded:Connect(PlayerAdded)
end

QuestService.Initialize()

return QuestService
