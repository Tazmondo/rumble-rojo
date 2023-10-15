local QuestService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ArenaService = require(script.Parent.ArenaService)
local CombatService = require(script.Parent.CombatService)
local Table = require(ReplicatedStorage.Modules.Shared.Table)
local DataService = require(script.Parent.DataService)
local ItemService = require(script.Parent.ItemService)
local Types = require(ReplicatedStorage.Modules.Shared.Types)
local Future = require(ReplicatedStorage.Packages.Future)
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)

local ClaimQuestEvent = require(ReplicatedStorage.Events.Quest.ClaimQuestEvent):Server()

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

local QuestTypes = TableUtil.Keys(QuestData) :: { Types.QuestType }

assert(#QuestTypes >= (QuestCounts.Easy + QuestCounts.Medium + QuestCounts.Hard), "Not enough unique quest types!")

local random = Random.new()

local DAYTIME = 86400 -- 60 * 60 * 24

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
		Type = randomType :: Types.QuestType,
		Difficulty = difficulty,
		CurrentNumber = 0,
		RequiredNumber = questNumber,
		Reward = QuestRewards[difficulty],
		Claimed = false,
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
	end)
end

function GetQuestOfType(player: Player, type: Types.QuestType)
	return Future.new(function()
		local foundQuest: Types.Quest?

		-- Here we need to get the original table, as we cannot iterate through the proxy table
		local data = DataService.GetPrivateData(player, true):Await()
		if not data then
			return foundQuest
		end
		for i, quest in ipairs(data.Quests) do
			if quest.Type == type then
				foundQuest = quest
				return foundQuest
			end
		end
		return foundQuest
	end)
end

function PlayerAdded(player: Player)
	return Future.new(function()
		local data = DataService.GetPrivateData(player):Await()
		if not data then
			return
		end

		local lastQuestTime = data.QuestGivenTime
		local deltaTime = os.time() - lastQuestTime

		if deltaTime >= DAYTIME then
			print("Assigning", player, "new quests.")
			data.QuestGivenTime = os.time()
			GenerateQuests(player)
		else
			-- If they left a game mid-way then we need to reset when they join
			ResetStreakQuests(player)
		end
	end)
end

function AdvanceQuest(player: Player, type: Types.QuestType, count: number?)
	return Future.new(function()
		local quest = GetQuestOfType(player, type):Await()
		if quest then
			quest.CurrentNumber = math.clamp(quest.CurrentNumber + (count or 1), 0, quest.RequiredNumber)
		end

		-- Updating the quests does not trigger the metatable
		-- So we need to manually declare an update
		DataService.SchedulePrivateUpdate(player)
	end)
end

function HandleClaimQuest(player: Player, questIndex: number)
	local data = DataService.GetPrivateData(player, true):Await()
	if not data then
		return
	end

	local quest = data.Quests[questIndex]
	if not quest then
		warn("Passed in an invalid questIndex", player, questIndex)
		return
	end

	local claimable = quest.CurrentNumber >= quest.RequiredNumber
	if not claimable then
		warn("Tried to complete an incomplete quest", player)
		return
	end

	if quest.Claimed then
		warn("Tried to claim an already claimed quest", player)
		return
	end

	quest.Claimed = true
	data.Money += quest.Reward

	DataService.SchedulePrivateUpdate(player)
end

function QuestService.HandleRefreshQuests(player: Player)
	local data = DataService.GetPrivateData(player, true):Await()
	if not data then
		return
	end

	GenerateQuests(player)
	data.QuestGivenTime = os.time()

	DataService.UpdatePrivateData(player)
end

function ResetStreakQuests(player)
	local quest = GetQuestOfType(player, "KillOneGame"):Await()
	if quest then
		quest.CurrentNumber = 0
		DataService.SchedulePrivateUpdate(player)
	end
end

function QuestService.Initialize()
	for i, player in ipairs(Players:GetPlayers()) do
		PlayerAdded(player)
	end
	Players.PlayerAdded:Connect(PlayerAdded)

	ClaimQuestEvent:On(HandleClaimQuest)

	ItemService.CollectBoost:Connect(function(player)
		AdvanceQuest(player, "Collect")
	end)

	ArenaService.PlayerResultsSignal:Connect(function(player, numPlayers)
		if numPlayers <= 1 then
			AdvanceQuest(player, "Win")
		end
		if numPlayers <= 2 then
			AdvanceQuest(player, "Finals")
		end
		AdvanceQuest(player, "Play")

		ResetStreakQuests(player)
	end)

	CombatService.KillSignal:Connect(function(killData)
		local player = killData.Killer
		if player then
			AdvanceQuest(player, "Kill")
			AdvanceQuest(player, "KillOneGame")
		end
	end)

	CombatService.DamageSignal:Connect(function(player, damage)
		if player then
			AdvanceQuest(player, "Damage", damage)
		end
	end)

	CombatService.SkillSignal:Connect(function(player, skill)
		AdvanceQuest(player, "Skills")
	end)

	CombatService.SuperSignal:Connect(function(player)
		AdvanceQuest(player, "Super")
	end)
end

QuestService.Initialize()

return QuestService
