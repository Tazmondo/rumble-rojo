--!nolint LocalShadow
-- I opted for a declarative approach to the UI. There are a lot of elements and dealing with state for each individual one
-- is too much effort.
-- There are some exceptions, e.g. for tweening.
print("init uicontroller")

-- variables
local UIController = {}

local Player = game.Players.LocalPlayer :: Player

local PlayerGui = Player:WaitForChild("PlayerGui") :: PlayerGui

local MainUI = PlayerGui:WaitForChild("MainUI") :: any
local ArenaUI = PlayerGui:WaitForChild("ArenaUI") :: any
local ResultsUI = PlayerGui:WaitForChild("ResultsUI") :: any
local HeroSelect = PlayerGui:WaitForChild("HeroSelectUI") :: any
local BuyBucksUI = PlayerGui:WaitForChild("BuyBucksUI") :: any

local TopText = ArenaUI.Interface.TopBar.TopText

-- services
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Config = require(ReplicatedStorage.Modules.Shared.Combat.Config)
local HeroData = require(ReplicatedStorage.Modules.Shared.Combat.HeroData)
local Modifiers = require(ReplicatedStorage.Modules.Shared.Combat.Modifiers)
local Skills = require(ReplicatedStorage.Modules.Shared.Combat.Modifiers.Skills)
local DataController = require(script.Parent.DataController)
local PurchaseController = require(script.Parent.PurchaseController)
local QuestController = require(script.Parent.QuestController)
local HeroDetails = require(ReplicatedStorage.Modules.Shared.HeroDetails)
local Types = require(ReplicatedStorage.Modules.Shared.Types)
local SoundController = require(script.Parent.SoundController)
local ViewportFrameController = require(script.Parent.ViewportFrameController)

local QueueEvent = require(ReplicatedStorage.Events.Arena.QueueEvent):Client()
local FighterDiedEvent = require(ReplicatedStorage.Events.Arena.FighterDiedEvent):Client()
local MatchResultsEvent = require(ReplicatedStorage.Events.Arena.MatchResultsEvent):Client()

local modifierTemplate = ReplicatedStorage.Assets.UI.Modifier
local talentTemplate = ReplicatedStorage.Assets.UI.Talent
local skillTemplate = ReplicatedStorage.Assets.UI.Skill

local heroSelectOpen = false
local displayResults = false

local selectedHero: string
local displayedHero: string

local selectedSkin: string
local displayedSkin: string

local boostPage: "Modifier1" | "Modifier2" | "Skill" | "Talent" = "Modifier1"
local displayBoost = nil :: string?
local updateBoost = true

local emptyModifier = "rbxassetid://14996185517"
local emptySkill = "rbxassetid://15025136170"
local emptyTalent = "rbxassetid://14988074815"

local shouldTryHide = false
local UIState = ""

local shouldReRenderCharacterSelectButtons = true
local shouldReRenderSkinSelectButtons = true

-- functions

function ShowBuyBucks()
	BuyBucksUI.Enabled = true
end

function UpdateQueueButtons()
	local gameData = DataController.GetGameData():Unwrap()
	local playerData = DataController.GetLocalData():Unwrap()
	local ready = playerData.Public.Queued

	MainUI.Queue.Visible = true
	if ready then
		MainUI.Queue.Ready.Visible = false
		MainUI.Queue.Exit.Visible = true
	else
		MainUI.Queue.Ready.Visible = true
		MainUI.Queue.Exit.Visible = false
	end
	local playerCount = gameData.NumQueuedPlayers
	MainUI.Queue.Frame.Title.Text = "Players Ready: " .. playerCount
end

function HideAll()
	ArenaUI.Enabled = false
	MainUI.Enabled = false
	MainUI.Queue.Visible = false
	MainUI.Interface.Inventory.Visible = false
	MainUI.Interface.MenuBar.Visible = false
	MainUI.Interface.Quest.Visible = false
	ArenaUI.Interface.CharacterSelection.Visible = false
	ArenaUI.Interface.Game.Visible = false
	HeroSelect.Enabled = false

	TopText.Visible = false

	for _, element in pairs(ArenaUI.Interface.Game:GetChildren()) do
		if element:IsA("UIListLayout") then
			continue
		end
		element.Visible = false
	end
end

function RenderStats()
	MainUI.Enabled = true
	MainUI.Interface.Inventory.Visible = true

	local trophies = DataController.GetTrophies()
	local money = DataController.GetMoney()

	MainUI.Interface.Inventory.Trophies.TrophyCount.Text = trophies
	MainUI.Interface.Inventory["G Bucks"].GBucksCount.Text = money

	MainUI.Interface.Inventory.Mute.Visible = not SoundController:Muted()
	MainUI.Interface.Inventory.Unmute.Visible = SoundController:Muted()

	HeroSelect.Frame.Inventory.Trophies.TrophyCount.Text = trophies
	HeroSelect.Frame.Inventory["G Bucks"].GBucksCount.Text = money

	local questButton = MainUI.Interface.Inventory.Quests
	local questCount = QuestController.GetClaimableQuests()

	questButton.Notification.Visible = questCount > 0
	questButton.Notification.Number.Text = questCount
end

function OpenHeroSelect()
	heroSelectOpen = true
	shouldTryHide = true
end

local prevHero = nil
local prevSkin = nil
function RenderHeroIcon()
	MainUI.Enabled = true
	MainUI.Interface.MenuBar.Visible = true

	if prevHero ~= selectedHero or prevSkin ~= selectedSkin then
		prevHero = selectedHero
		prevSkin = selectedSkin

		local frame = MainUI.Interface.MenuBar:FindFirstChild("Current Character") :: Frame
		frame:ClearAllChildren()

		local model = assert(
			HeroDetails.GetModelFromName(selectedHero, selectedSkin),
			"Model not found for " .. selectedHero .. " " .. selectedSkin
		)

		local button = ViewportFrameController.NewHeadButton(model)
		button.Size = UDim2.fromScale(1, 1)
		button.ViewportFrame.Equipped.Visible = false

		button.Activated:Connect(function()
			SoundController:ButtonClick()
			OpenHeroSelect()
		end)
		button.Parent = frame
	end
end

function NotEnoughPlayersRender(changed)
	if changed then
		ArenaUI.Enabled = true
		MainUI.Enabled = true
	end

	ArenaUI.Interface.TopBar.Visible = true
	TopText.Visible = true
	TopText.Text.Text = "Ready up!"

	RenderStats()
	UpdateQueueButtons()
	RenderHeroIcon()
end

function IntermissionRender(changed)
	local gameData = DataController.GetGameData():Unwrap()
	if changed then
		ArenaUI.Enabled = true
		MainUI.Enabled = true

		ArenaUI.Interface.TopBar.Visible = true
	end

	RenderStats()
	UpdateQueueButtons()
	RenderHeroIcon()
	TopText.Visible = true
	TopText.Text.Text = "Game Starting in: " .. gameData.IntermissionTime
end

function BattleStartingRender(changed)
	local gameData = DataController.GetGameData():Unwrap()
	local playerData = DataController.GetLocalData():Unwrap()
	ArenaUI.Enabled = true

	local gameFrame = ArenaUI.Interface.Game
	gameFrame.Visible = true

	if playerData.Public.Queued then
		if changed then
			SoundController:PlayGeneralSound("FightStart")
			gameFrame.StartFight.Position = UDim2.fromScale(0.5, 0.5)
		end

		gameFrame.StartFight.Visible = true

		-- gameFrame.StartFight:TweenPosition(
		-- 	UDim2.fromScale(0.5, 0.5),
		-- 	Enum.EasingDirection.Out,
		-- 	Enum.EasingStyle.Quad,
		-- 	0.4
		-- )
		-- gameFrame.Countdown:Tween
	elseif not playerData.Public.InCombat then
		RenderStats()
		RenderHeroIcon()
		UpdateQueueButtons()
	end

	TopText.Visible = true
	local fighters = gameData.NumAlivePlayers
	if fighters == nil then
		fighters = 0
	end
	TopText.Text.Text = "Fighters left: " .. fighters

	-- ready = false
end

local died = false
local diedHandled = false
function BattleRender(changed)
	local gameData = DataController.GetGameData():Unwrap()
	local playerData = DataController.GetLocalData():Unwrap()
	-- Combat UI rendering is handled by the combat client
	ArenaUI.Enabled = true

	if changed then
		died = false
		diedHandled = false
	end

	local gameFrame = ArenaUI.Interface.Game
	gameFrame.Visible = true

	if died then
		if not diedHandled then
			diedHandled = true
			task.delay(3, function()
				died = false
			end)
		end
	end

	if not playerData.Public.InCombat then
		RenderStats()
		RenderHeroIcon()
		UpdateQueueButtons()
	end

	TopText.Visible = true
	TopText.Text.Text = "Fighters left: " .. gameData.NumAlivePlayers
end

function BattleEndedRender(changed)
	if displayResults then
		return
	end

	ArenaUI.Enabled = true

	-- local roundOver = ArenaUI.Interface.Game.RoundOver
	-- ArenaUI.Interface.Game.Visible = true
	-- if changed and ready then
	-- 	SoundController:PlayGeneralSound("BattleOver")
	-- 	roundOver.Visible = true
	-- 	task.delay(1, function()
	-- 		roundOver.Visible = false
	-- 	end)
	-- end

	RenderStats()
	RenderHeroIcon()
	UpdateQueueButtons()

	DataController.GetGameData():After(function(data)
		TopText.Visible = true
		TopText.Text.Text = data.WinnerName .. " won!"
	end)
end

function LabelRenderTrophyCount(label: TextLabel, trophyCount: number)
	local positive = trophyCount >= 0
	label.Text = tostring(if positive then "+" .. trophyCount else trophyCount)
	label.TextColor3 = if positive then Color3.fromRGB(67, 179, 69) else Color3.fromRGB(228, 2, 43)
end

function RenderMatchResults(trophies: number, data: Types.PlayerBattleResults)
	displayResults = true
	HideAll()

	ArenaUI.Enabled = true
	ArenaUI.Interface.Game.Visible = true
	local victory = ArenaUI.Interface.Game.Victory
	local defeat = ArenaUI.Interface.Game.Defeat

	if data.Won then
		SoundController:PlayGeneralSound("Victory")
		victory.Visible = true
	else
		SoundController:PlayGeneralSound("Died")
		defeat.Visible = true
	end

	task.wait(2)
	ArenaUI.Enabled = false
	victory.Visible = false
	defeat.Visible = false

	ResultsUI.Enabled = true
	local blur = assert(Lighting:FindFirstChild("ResultsBlur"), "Could not find blur effect in lighting.") :: BlurEffect
	blur.Enabled = true

	-- DISPLAY TROPHY COUNT --
	print("displaying results", data)
	local statsFrame = ResultsUI.Frame.ImageLabel.Frame.Stats:FindFirstChild("Stat Lines")
	statsFrame.Victory.Visible = data.Won
	LabelRenderTrophyCount(statsFrame.Victory.TrophyCount, Config.TrophyWin)
	LabelRenderTrophyCount(statsFrame.Total.Frame.TrophyCount, trophies)

	statsFrame.Total.Frame.GBucksCount.Text = "+" .. data.Kills * Config.MoneyKill
	statsFrame.Total.Frame.GBucksCount.Visible = data.Kills > 0
	statsFrame.Total.Frame.GBucksImage.Visible = data.Kills > 0

	statsFrame.Died.Visible = data.Died
	LabelRenderTrophyCount(statsFrame.Died.TrophyCount, Config.TrophyDeath)

	if data.Kills > 0 then
		statsFrame.Knockouts.Visible = true
		statsFrame.Knockouts.Total.Text = if data.Kills > 1 then "Knockouts x " .. data.Kills else "Knockout"
		LabelRenderTrophyCount(statsFrame.Knockouts.Frame.TrophyCount, data.Kills * Config.TrophyKill)
		statsFrame.Knockouts.Frame.GBucksCount.Text = "+" .. data.Kills * Config.MoneyKill
	else
		statsFrame.Knockouts.Visible = false
	end

	ResultsUI.Frame.ImageLabel.Frame.Action.Proceed.Activated:Wait()
	SoundController:PlayGeneralSound("ButtonClick")

	ResultsUI.Enabled = false
	displayResults = false
	blur.Enabled = false

	return
end

local prevOpen = false
local prevModel: Model? = nil
function RenderHeroSelectScreen()
	HeroSelect.Enabled = true

	RenderStats()

	-- RENDERING HERO SELECT
	RenderCharacterSelectButtons()

	local frame = HeroSelect.Frame.Select
	local details = frame.Information:FindFirstChild("2-Details")

	local data = DataController.GetLocalData():Unwrap()
	local ownedHeroes = data.Private.OwnedHeroes

	if prevOpen ~= heroSelectOpen then
		-- tween stuff
	end
	prevOpen = heroSelectOpen

	local heroData = HeroDetails.HeroDetails[displayedHero]
	if not heroData then
		warn("Tried to get data for hero", displayedHero, "but it didn't exist!")
		return
	end

	local heroStats = ownedHeroes[displayedHero] or nil -- for making it an optional type
	local trophyCount = if heroStats then heroStats.Trophies else 0

	details:FindFirstChild("Trophies").TrophyCount.Text = trophyCount
	details:FindFirstChild("2-Name").Text = string.upper(displayedHero)
	details:FindFirstChild("3-Description").Text = heroData.Description

	local statsFrame = frame.Stats.Frame

	local combatData = HeroData.HeroData[displayedHero]

	local damageText
	local healthText

	if combatData then
		healthText = tostring(combatData.Health)
		local attackData = combatData.Attack
		if attackData.Data.AttackType == "Shotgun" then
			damageText = attackData.Data.ShotCount .. " x " .. attackData.Data.Damage
		else
			damageText = tostring(attackData.Data.Damage)
		end
	else
		healthText = "Coming soon!"
		damageText = "Coming soon!"
	end
	statsFrame.Health.Frame.Number.Text = healthText
	statsFrame.Damage.Frame.Number.Text = damageText

	-- Allow for unavailable heroes to show up in shop
	local superName = if combatData then combatData.Super.Name else "Coming soon!"

	statsFrame.Super.Frame.SuperName.Text = superName

	details.Unavailable.Visible = if heroData.Unavailable and not heroStats then true else false
	details.Unlock.Cost.Text = heroData.Price
	details.Unlock.Visible = if heroStats or heroData.Unavailable then false else true
	details.ChangeOutfit.Visible = if heroStats then true else false

	-- Don't try to render skins if the hero isn't owned
	if heroStats then
		-- RENDERING SKIN SELECT
		RenderSkinSelectButtons()
		local skinFrame = HeroSelect.Frame.Skin
		local skinInfo = skinFrame.Info

		local skinData = heroData.Skins[displayedSkin]
		if not skinData then
			warn("Could not find skinData", displayedSkin, selectedHero, displayedHero)
			return
		end
		local rarity = skinData.Rarity

		skinInfo.Common.Visible = rarity == "Common"
		skinInfo.Uncommon.Visible = rarity == "Uncommon"
		skinInfo.Rare.Visible = rarity == "Rare"
		skinInfo.Epic.Visible = rarity == "Epic"
		skinInfo.Legendary.Visible = rarity == "Legendary"

		skinInfo["2-Details"]["2-Name"].Text = skinData.Name
		skinInfo["2-Details"]["3-Description"].Text = skinData.Description

		local owned = heroStats.Skins[displayedSkin] ~= nil

		skinInfo.Equip.Visible = displayedSkin ~= selectedSkin and owned
		skinInfo.Equipped.Visible = displayedSkin == selectedSkin and owned

		skinInfo.Unlock.Cost.Text = skinData.Price
		skinInfo.Unlock.Visible = not owned
	end

	-- RENDER BOOST SHOP
	local boostFrame = HeroSelect.BoostShop
	if updateBoost then
		updateBoost = false

		local contentFrame = boostFrame.ItemShop.Content
		local shopDisplay = contentFrame.LeftSide.ScrollingFrame
		local rightSide = contentFrame.RightSide
		local infoFrame = rightSide.Information
		local headerFrame = boostFrame.ItemShop.Header.Frame
		local selectBoostsFrame = statsFrame.Boosts

		headerFrame.Modifier1.Modifier.Image = if boostPage == "Modifier1"
			then headerFrame.Modifier1.Modifier.HoverImage
			else ""
		headerFrame.Modifier2.Modifier.Image = if boostPage == "Modifier2"
			then headerFrame.Modifier2.Modifier.HoverImage
			else ""
		headerFrame.Skill.Modifier.Image = if boostPage == "Skill" then headerFrame.Skill.Modifier.HoverImage else ""
		headerFrame.Talent.Modifier.Image = if boostPage == "Talent" then headerFrame.Talent.Modifier.HoverImage else ""

		-- sorry for this mess. but it does kinda make sense when u read it
		headerFrame.Modifier1.Modifier.Icon.Image = if heroStats and heroStats.SelectedModifiers[1] ~= ""
			then Modifiers[heroStats.SelectedModifiers[1]].UnlockedImage
			else emptyModifier
		selectBoostsFrame.Modifier1.Icon.Image = headerFrame.Modifier1.Modifier.Icon.Image

		headerFrame.Modifier2.Modifier.Icon.Image = if heroStats and heroStats.SelectedModifiers[2] ~= ""
			then Modifiers[heroStats.SelectedModifiers[2]].UnlockedImage
			else emptyModifier
		selectBoostsFrame.Modifier2.Icon.Image = headerFrame.Modifier2.Modifier.Icon.Image

		headerFrame.Talent.Modifier.Icon.Image = if heroStats and heroStats.SelectedTalent ~= ""
			then Modifiers[heroStats.SelectedTalent].UnlockedImage
			else emptyTalent
		selectBoostsFrame.Talent.Icon.Image = headerFrame.Talent.Modifier.Icon.Image

		headerFrame.Skill.Modifier.Icon.Image = if heroStats and heroStats.SelectedSkill ~= ""
			then Skills[heroStats.SelectedSkill].UnlockedImage
			else emptySkill
		selectBoostsFrame.Skill.Icon.Image = headerFrame.Skill.Modifier.Icon.Image

		selectBoostsFrame.Count.Number.Text = DataController.GetNumberOwnedBoosts(displayedHero)
			.. "/"
			.. DataController.GetTotalBoosts(displayedHero)

		for i, item in ipairs(shopDisplay:GetChildren()) do
			if item:IsA("ImageButton") then
				item:Destroy()
			end
		end

		if boostPage == "Modifier1" or boostPage == "Modifier2" then
			local slotNumber = if boostPage == "Modifier1" then 1 else 2
			local modifiers = heroData.Modifiers
			for i, modifierName in ipairs(modifiers) do
				if modifierName == "" then
					continue
				end

				local owned = heroStats and heroStats.Modifiers[modifierName] == true
				local modifierData = Modifiers[modifierName]

				local newButton = modifierTemplate:Clone()
				newButton.LayoutOrder = i

				newButton.Icon.Image = if owned then modifierData.UnlockedImage else modifierData.LockedImage

				-- If selected then show the hover
				if displayBoost == modifierName then
					newButton.Image = newButton.HoverImage
					newButton.HoverImage = ""
				else
					newButton.Icon.Activated:Connect(function()
						SoundController:ButtonClick()
						updateBoost = true
						displayBoost = modifierName
					end)
				end

				newButton.Parent = shopDisplay
			end

			if displayBoost and displayBoost ~= "" then
				local equipped = DataController.IsModifierEquipped(displayedHero, displayBoost, slotNumber)
				local owned = heroStats and heroStats.Modifiers[displayBoost] == true

				local modifierData = Modifiers[displayBoost]

				infoFrame.Title.Text = modifierData.Name
				infoFrame.Description.Text = modifierData.Description

				rightSide:FindFirstChild("Remove").Visible = owned and equipped
				rightSide.Equip.Visible = owned and not equipped
				rightSide.Unlock.Visible = not owned and modifierData.Price and heroStats

				if rightSide.Unlock.Visible then
					rightSide.Unlock.Cost.Text = modifierData.Price
				end
			else
				infoFrame.Title.Text = "Modifiers"
				infoFrame.Description.Text =
					"Modifiers allow you to augment your character with new abilities! Mix and match, and create a build that truly fits your playstyle."

				rightSide:FindFirstChild("Remove").Visible = false
				rightSide.Equip.Visible = false
				rightSide.Unlock.Visible = false
			end
		elseif boostPage == "Talent" then
			local talents = heroData.Talents
			for i, talentName in ipairs(talents) do
				if talentName == "" then
					continue
				end

				local owned = heroStats and heroStats.Talents[talentName] == true
				local talentData = Modifiers[talentName]

				local newButton = talentTemplate:Clone()
				newButton.LayoutOrder = i

				newButton.Icon.Image = if owned then talentData.UnlockedImage else talentData.LockedImage

				-- If selected then show the hover
				if displayBoost == talentName then
					newButton.Image = newButton.HoverImage
					newButton.HoverImage = ""
				else
					newButton.Icon.Activated:Connect(function()
						SoundController:ButtonClick()
						updateBoost = true
						displayBoost = talentName
					end)
				end

				newButton.Parent = shopDisplay
			end

			if displayBoost and displayBoost ~= "" then
				local equipped = heroStats and heroStats.SelectedTalent == displayBoost
				local owned = heroStats and heroStats.Talents[displayBoost] == true

				local talentData = Modifiers[displayBoost]

				infoFrame.Title.Text = talentData.Name
				infoFrame.Description.Text = talentData.Description

				rightSide:FindFirstChild("Remove").Visible = owned and equipped
				rightSide.Equip.Visible = owned and not equipped
				rightSide.Unlock.Visible = not owned and talentData.Price and heroStats

				if rightSide.Unlock.Visible then
					rightSide.Unlock.Cost.Text = talentData.Price
				end
			else
				infoFrame.Title.Text = "Talents"
				infoFrame.Description.Text =
					"Talents are powerful, unique abilities with large effects. Choose them carefully."

				rightSide:FindFirstChild("Remove").Visible = false
				rightSide.Equip.Visible = false
				rightSide.Unlock.Visible = false
			end
		elseif boostPage == "Skill" then
			local skills = heroData.Skills
			for i, skillName in ipairs(skills) do
				if skillName == "" then
					continue
				end

				local owned = heroStats and heroStats.Skills[skillName] == true
				local skillData = Skills[skillName]

				local newButton = skillTemplate:Clone()
				newButton.LayoutOrder = i

				newButton.Icon.Image = if owned then skillData.UnlockedImage else skillData.LockedImage

				-- If selected then show the hover
				if displayBoost == skillName then
					newButton.Image = newButton.HoverImage
					newButton.HoverImage = ""
				else
					newButton.Icon.Activated:Connect(function()
						SoundController:ButtonClick()
						updateBoost = true
						displayBoost = skillName
					end)
				end

				newButton.Parent = shopDisplay
			end

			if displayBoost and displayBoost ~= "" then
				local equipped = heroStats and heroStats.SelectedSkill == displayBoost
				local owned = heroStats and heroStats.Skills[displayBoost] == true

				local skillData = Skills[displayBoost]

				infoFrame.Title.Text = skillData.Name
				infoFrame.Description.Text = skillData.Description

				rightSide:FindFirstChild("Remove").Visible = owned and equipped
				rightSide.Equip.Visible = owned and not equipped
				rightSide.Unlock.Visible = not owned and skillData.Price and heroStats

				if rightSide.Unlock.Visible then
					rightSide.Unlock.Cost.Text = skillData.Price
				end
			else
				infoFrame.Title.Text = "Skills"
				infoFrame.Description.Text =
					"Skills, once activated, can have devastating effects for your enemies. Pick your skill carefully, and use it at the right time!"

				rightSide:FindFirstChild("Remove").Visible = false
				rightSide.Equip.Visible = false
				rightSide.Unlock.Visible = false
			end
		end
	end

	-- RENDER PREVIEW
	local model = HeroDetails.GetModelFromName(displayedHero, displayedSkin)
	if model == prevModel then
		return
	end
	prevModel = model

	local viewportController = ViewportFrameController.get(HeroSelect.Frame.Character.ViewportFrame)
	viewportController:UpdateModel(model)
end

function ResetRoundVariables() end

function UIController:RenderAllUI()
	-- Might appear a weird way of doing it, but means we can get precise control over how the UI renders by just editing the function for the corresponding gamestate.
	-- Checking if it's changed also allows us to do tweening.
	debug.profilebegin("UIControllerRender")

	local gameData = DataController.GetGameData():Unwrap()
	local playerData = DataController.GetLocalData():Unwrap()
	local state = gameData.Status

	if displayResults then
		-- HideAll()
		return
	end

	local changed = state ~= UIState
	if shouldTryHide then
		changed = true
		shouldTryHide = false
	end
	if changed then
		print("UI State changed to ", UIState, state)
		HideAll()
	end

	if playerData.Public.InCombat and state == "NotEnoughPlayers" then
		UIState = state
		debug.profileend()
		return
	end

	if
		heroSelectOpen and not (playerData.Public.InCombat and state ~= "NotEnoughPlayers" and state ~= "Intermission")
	then
		RenderHeroSelectScreen()
	else
		if state == "NotEnoughPlayers" then
			NotEnoughPlayersRender(changed)
		elseif state == "Intermission" then
			IntermissionRender(changed)
		elseif state == "BattleStarting" then
			BattleStartingRender(changed)
			if playerData.Public.Queued then
				BuyBucksUI.Enabled = false
				heroSelectOpen = false
				-- ready = false
			end
		elseif state == "Battle" then
			BattleRender(changed)
		elseif state == "BattleEnded" then
			BattleEndedRender(changed)
		end
	end

	if changed and state == "Ended" then
		ResetRoundVariables()
	end

	UIState = state
	debug.profileend()
end

function UIController:ReadyClick()
	local playerData = DataController.GetLocalData():Unwrap()
	playerData.Public.Queued = true

	QueueEvent:Fire(true)

	SoundController:PlayGeneralSound("JoinQueue")
end

function UIController:ExitClick()
	local playerData = DataController.GetLocalData():Unwrap()
	playerData.Public.Queued = false

	QueueEvent:Fire(false)

	SoundController:PlayGeneralSound("LeaveQueue")
end

function RenderCharacterSelectButtons()
	local characterSelect = HeroSelect.Frame.Select["Character Select"]
	if shouldReRenderCharacterSelectButtons then
		shouldReRenderCharacterSelectButtons = false

		for i, v in pairs(characterSelect:GetChildren()) do
			if v:IsA("TextButton") then
				v:Destroy()
			end
		end
	end

	task.spawn(function()
		-- Wait for data to be received from server
		local data = DataController.GetLocalData():Await()
		local ownedHeroes = data.Private.OwnedHeroes

		for hero, heroData in pairs(HeroDetails.HeroDetails) do
			local owned = ownedHeroes[hero] ~= nil

			local button = characterSelect:FindFirstChild(hero)

			if not button then
				local skinName = if owned
					then assert(ownedHeroes[hero].SelectedSkin)
					else HeroDetails.HeroDetails[heroData.Name].DefaultSkin
				local model = assert(
					HeroDetails.GetModelFromName(heroData.Name, skinName),
					"Model not found for " .. heroData.Name .. " " .. skinName
				)

				button = ViewportFrameController.NewHeadButton(model)
				button.Parent = characterSelect
				button.Name = hero
				button.LayoutOrder = heroData.Order
				button.Activated:Connect(function()
					SoundController:ButtonClick()

					-- Data can change inbetween rendering and this code running, so we need to fetch it again.
					data = DataController.GetLocalData():Await()
					ownedHeroes = data.Private.OwnedHeroes

					shouldReRenderSkinSelectButtons = true
					updateBoost = true

					displayedHero = hero

					local data = ownedHeroes[hero]
					if data then
						selectedSkin = data.SelectedSkin
						DataController.SelectHero(hero)
						characterSelect[selectedHero].ViewportFrame.Equipped.Visible = false

						selectedHero = hero

						characterSelect[selectedHero].ViewportFrame.Equipped.Visible = true

						displayedSkin = selectedSkin
					else
						displayedSkin = HeroDetails.HeroDetails[hero].DefaultSkin
					end
				end)
			end

			if selectedHero == hero then
				button.ViewportFrame.Equipped.Visible = true
			else
				button.ViewportFrame.Equipped.Visible = false
			end
			if displayedHero == hero then
				button.UIScale.Scale = 1.2
			else
				button.UIScale.Scale = 1
			end

			if not owned then
				button.BackgroundTransparency = 0.7
				button.ViewportFrame.ImageTransparency = 0.7
			else
				button.BackgroundTransparency = 0
				button.ViewportFrame.ImageTransparency = 0
			end
		end
	end)
end

function RenderSkinSelectButtons()
	local skinSelect = HeroSelect.Frame.Skin.SkinSelect

	local currentHero = displayedHero

	if shouldReRenderSkinSelectButtons then
		shouldReRenderSkinSelectButtons = false
		for i, v in pairs(skinSelect:GetChildren()) do
			if v:IsA("TextButton") then
				v:Destroy()
			end
		end
	end

	task.spawn(function()
		-- Wait for data to be received from server
		local data = DataController.GetLocalData():Await()

		for skin, skinData in pairs(HeroDetails.HeroDetails[currentHero].Skins) do
			local owned = data.Private.OwnedHeroes[currentHero].Skins[skin] ~= nil
			local button = skinSelect:FindFirstChild(skin)
			if not button then
				local model =
					assert(HeroDetails.GetModelFromName(currentHero, skin), "No model " .. currentHero .. " " .. skin)
				button = ViewportFrameController.NewHeadButton(model)
				button.Parent = skinSelect
				button.Name = skin
				button.LayoutOrder = skinData.Order
				button.Activated:Connect(function()
					SoundController:ButtonClick()
					displayedSkin = skin
				end)
			end

			if selectedSkin == skin then
				button.ViewportFrame.Equipped.Visible = true
			else
				button.ViewportFrame.Equipped.Visible = false
			end

			if displayedSkin == skin then
				button.UIScale.Scale = 1.2
			else
				button.UIScale.Scale = 1
			end

			if not owned then
				button.BackgroundTransparency = 0.7
				button.ViewportFrame.ImageTransparency = 0.7
			else
				button.BackgroundTransparency = 0
				button.ViewportFrame.ImageTransparency = 0
			end
		end
	end)
end

function Mute()
	SoundController:ButtonClick()
	SoundController:MuteMusic(true)
end

function UnMute()
	SoundController:ButtonClick()
	SoundController:MuteMusic(false)
end

function ShowModifier1()
	SoundController:ButtonClick()
	local data = DataController.GetLocalData():Await().Private.OwnedHeroes[displayedHero]
	displayBoost = if data then data.SelectedModifiers[1] else ""
	updateBoost = true
	boostPage = "Modifier1"
end

function ShowModifier2()
	SoundController:ButtonClick()
	local data = DataController.GetLocalData():Await().Private.OwnedHeroes[displayedHero]
	displayBoost = if data then data.SelectedModifiers[2] else ""
	updateBoost = true
	boostPage = "Modifier2"
end

function ShowSkill()
	SoundController:ButtonClick()
	local data = DataController.GetLocalData():Await().Private.OwnedHeroes[displayedHero]
	displayBoost = if data then data.SelectedSkill else ""
	updateBoost = true
	boostPage = "Skill"
end

function ShowTalent()
	SoundController:ButtonClick()
	local data = DataController.GetLocalData():Await().Private.OwnedHeroes[displayedHero]
	displayBoost = if data then data.SelectedTalent else ""
	updateBoost = true
	boostPage = "Talent"
end

function UIController:Initialize()
	-- This function is spawned so we can wait here
	DataController.HasLoadedData():Await()

	FighterDiedEvent:On(function()
		died = true
		SoundController:PlayGeneralSound("Died")
	end)

	MatchResultsEvent:On(RenderMatchResults)

	local playerData = DataController.GetLocalData():Await()

	selectedHero = playerData.Private.SelectedHero
	displayedHero = selectedHero

	selectedSkin = playerData.Public.SelectedSkin
	displayedSkin = selectedSkin

	DataController.LocalDataUpdated:Connect(function(newData)
		if newData.Private.SelectedHero ~= selectedHero then
			selectedHero = newData.Private.SelectedHero
			displayedHero = selectedHero
			selectedSkin = newData.Private.OwnedHeroes[selectedHero].SelectedSkin
			displayedSkin = selectedSkin
		else
			selectedSkin = newData.Public.SelectedSkin
		end
	end)

	RunService.RenderStepped:Connect(function(...)
		UIController:RenderAllUI(...)
	end)

	MainUI.Queue.Ready.Activated:Connect(function()
		UIController:ReadyClick()
	end)
	MainUI.Queue.Exit.Activated:Connect(function()
		UIController:ExitClick()
	end)

	MainUI.Interface.Inventory.Mute.Activated:Connect(Mute)
	MainUI.Interface.Inventory.Unmute.Activated:Connect(UnMute)

	HeroSelect.Frame.Inventory.Exit.Activated:Connect(function(input: InputObject)
		SoundController:ButtonClick()
		heroSelectOpen = false
		shouldTryHide = true
	end)

	HeroSelect.Frame.Skin.Info.Equip.Activated:Connect(function()
		SoundController:ButtonClick()
		shouldReRenderCharacterSelectButtons = true
		DataController.SelectSkin(selectedHero, displayedSkin)

		local skinSelect = HeroSelect.Frame.Skin.SkinSelect
		if skinSelect:FindFirstChild(selectedSkin) then
			-- if switch to a different character then the previous one wont exist
			skinSelect[selectedSkin].ViewportFrame.Equipped.Visible = false
		end

		selectedSkin = displayedSkin

		skinSelect[selectedSkin].ViewportFrame.Equipped.Visible = true
	end)

	local TRANSITIONTIME = 0
	local STYLE = Enum.EasingStyle.Quad
	local transitioning = false
	local inScale = 0.9
	local outScale = 1 / inScale

	local tweenInfo = TweenInfo.new(TRANSITIONTIME, STYLE, Enum.EasingDirection.Out)

	HeroSelect.Frame.Select.Information["2-Details"].ChangeOutfit.Activated:Connect(function()
		SoundController:ButtonClick()
		if transitioning then
			return
		end

		transitioning = true

		HeroSelect.Frame.Skin.Visible = true

		HeroSelect.Frame.Select.UIScale.Scale = 1
		TweenService:Create(HeroSelect.Frame.Select.UIScale, tweenInfo, { Scale = outScale }):Play()

		HeroSelect.Frame.Skin.UIScale.Scale = inScale
		TweenService:Create(HeroSelect.Frame.Skin.UIScale, tweenInfo, { Scale = 1 }):Play()

		task.delay(TRANSITIONTIME, function()
			transitioning = false
			HeroSelect.Frame.Select.Visible = false
		end)
	end)

	HeroSelect.Frame.Skin.Back.Exit.Activated:Connect(function()
		SoundController:ButtonClick()
		if transitioning then
			return
		end

		displayedSkin = selectedSkin

		transitioning = true

		HeroSelect.Frame.Select.Visible = true

		HeroSelect.Frame.Select.UIScale.Scale = outScale
		TweenService:Create(HeroSelect.Frame.Select.UIScale, tweenInfo, { Scale = 1 }):Play()

		HeroSelect.Frame.Skin.UIScale.Scale = 1
		TweenService:Create(HeroSelect.Frame.Skin.UIScale, tweenInfo, { Scale = inScale }):Play()

		task.delay(TRANSITIONTIME, function()
			transitioning = false
			HeroSelect.Frame.Skin.Visible = false
		end)
	end)

	HeroSelect.Frame.Select.Information["2-Details"].Unlock.Activated:Connect(function()
		if not DataController.CanAffordHero(displayedHero) then
			ShowBuyBucks()
			return
		end
		SoundController:ButtonClick(true)
		DataController.PurchaseHero(displayedHero, true)
		shouldReRenderSkinSelectButtons = true

		local characterSelect = HeroSelect.Frame.Select["Character Select"]
		characterSelect[selectedHero].ViewportFrame.Equipped.Visible = false

		selectedHero = displayedHero

		characterSelect[selectedHero].ViewportFrame.Equipped.Visible = true
	end)

	HeroSelect.Frame.Skin.Info.Unlock.Activated:Connect(function()
		if not DataController.CanAffordSkin(displayedHero, displayedSkin) then
			ShowBuyBucks()
			return
		end
		SoundController:ButtonClick(true)
		DataController.PurchaseSkin(displayedHero, displayedSkin)
	end)

	MainUI.Interface.Inventory["G Bucks"].Activated:Connect(function()
		SoundController:ButtonClick()
		ShowBuyBucks()
	end)

	HeroSelect.Frame.Inventory["G Bucks"].Activated:Connect(function()
		SoundController:ButtonClick()
		ShowBuyBucks()
	end)

	BuyBucksUI.Frame.ImageLabel.Header.Title.Exit.Activated:Connect(function()
		SoundController:ButtonClick()
		BuyBucksUI.Enabled = false
	end)

	MainUI.Interface.Inventory.Shop.Activated:Connect(function()
		SoundController:ButtonClick()
		OpenHeroSelect()
	end)

	for i, button in pairs(BuyBucksUI.Frame.ImageLabel.BuyButtons:GetChildren()) do
		if not button:IsA("ImageButton") then
			continue
		end
		local idNum = tonumber(button.Name)
		if not idNum then
			warn("could not convert name to id", button:GetFullName())
			return
		end
		button.Activated:Connect(function()
			SoundController:ButtonClick()
			PurchaseController.Purchase(idNum)
		end)
	end

	-- Boost Shop
	local boostHeaderFrame = HeroSelect.BoostShop.ItemShop.Header.Frame
	local boostShopButtons = HeroSelect.BoostShop.ItemShop.Content.RightSide
	local selectBoostIcons = HeroSelect.Frame.Select.Stats.Frame.Boosts

	boostShopButtons.Unlock.Activated:Connect(function()
		if not displayBoost then
			return
		end
		updateBoost = true

		if boostPage == "Modifier1" or boostPage == "Modifier2" then
			if not DataController.CanAffordModifier(displayBoost) then
				ShowBuyBucks()
				return
			end
			DataController.PurchaseModifier(displayedHero, displayBoost)
			SoundController:ButtonClick(true)
		elseif boostPage == "Talent" then
			if not DataController.CanAffordTalent(displayBoost) then
				ShowBuyBucks()
				return
			end
			DataController.PurchaseTalent(displayedHero, displayBoost)
			SoundController:ButtonClick(true)
		elseif boostPage == "Skill" then
			if not DataController.CanAffordSkill(displayBoost) then
				ShowBuyBucks()
				return
			end
			DataController.PurchaseSkill(displayedHero, displayBoost)
			SoundController:ButtonClick(true)
		end
	end)

	boostShopButtons.Equip.Activated:Connect(function()
		if not displayBoost then
			return
		end
		updateBoost = true

		if boostPage == "Modifier1" or boostPage == "Modifier2" then
			local slot = if boostPage == "Modifier1" then 1 else 2
			DataController.SelectModifier(displayedHero, displayBoost, slot)
		elseif boostPage == "Talent" then
			DataController.SelectTalent(displayedHero, displayBoost)
		elseif boostPage == "Skill" then
			DataController.SelectSkill(displayedHero, displayBoost)
		end
		SoundController:ButtonClick()
	end)

	boostShopButtons:FindFirstChild("Remove").Activated:Connect(function()
		updateBoost = true

		if boostPage == "Modifier1" or boostPage == "Modifier2" then
			local slot = if boostPage == "Modifier1" then 1 else 2
			DataController.SelectModifier(displayedHero, "", slot)
		elseif boostPage == "Talent" then
			DataController.SelectTalent(displayedHero, "")
		elseif boostPage == "Skill" then
			DataController.SelectSkill(displayedHero, "")
		end
		SoundController:ButtonClick()
	end)

	boostHeaderFrame.Modifier1.Modifier.Icon.Activated:Connect(ShowModifier1)
	boostHeaderFrame.Modifier2.Modifier.Icon.Activated:Connect(ShowModifier2)
	boostHeaderFrame.Skill.Modifier.Icon.Activated:Connect(ShowSkill)
	boostHeaderFrame.Talent.Modifier.Icon.Activated:Connect(ShowTalent)

	HeroSelect.Frame.Select.Stats.Frame.Boosts.Activated:Connect(function()
		SoundController:ButtonClick()
		updateBoost = true
		HeroSelect.BoostShop.Visible = true
	end)

	HeroSelect.BoostShop.ItemShop.Header.Exit.Activated:Connect(function()
		SoundController:ButtonClick()
		updateBoost = true
		HeroSelect.BoostShop.Visible = false
	end)

	MainUI.Interface.Inventory.Quests.Activated:Connect(function()
		SoundController:ButtonClick()
		MainUI.Interface.Quest.Visible = true
	end)

	MainUI.Interface.Quest.Header.Exit.Activated:Connect(function()
		SoundController:ButtonClick()
		MainUI.Interface.Quest.Visible = false
	end)

	-- For clicking on the background to close the booster shop
	-- It's a frame, not a button, so I can't use .Activated
	UserInputService.InputEnded:Connect(function(input, processed)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			local position = input.Position
			local objects = PlayerGui:GetGuiObjectsAtPosition(position.X, position.Y)
			if objects[1] == HeroSelect.BoostShop then
				HeroSelect.BoostShop.Visible = false
			end
		end
	end)

	selectBoostIcons.Modifier1.Icon.Activated:Connect(function()
		HeroSelect.BoostShop.Visible = true
		ShowModifier1()
	end)
	selectBoostIcons.Modifier2.Icon.Activated:Connect(function()
		HeroSelect.BoostShop.Visible = true
		ShowModifier2()
	end)
	selectBoostIcons.Talent.Icon.Activated:Connect(function()
		HeroSelect.BoostShop.Visible = true
		ShowTalent()
	end)
	selectBoostIcons.Skill.Icon.Activated:Connect(function()
		HeroSelect.BoostShop.Visible = true
		ShowSkill()
	end)
end

-- In a new thread since we don't want to delay client loading,
-- which would delay the data loading
-- and this script is reliant on data loading,
-- so it would be a deadlock
task.spawn(function()
	UIController:Initialize()
end)

return UIController
