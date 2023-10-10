--!strict
--!nolint LocalShadow
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)
-- Defines hero prices and skin prices

local module = {}

export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary"

type OrderedSkin = {
	Name: string,
	Description: string,
	Price: number,
	Rarity: Rarity,
	Order: number?,
}
export type Skin = {
	Name: string,
	Description: string,
	Price: number,
	Rarity: Rarity,
	Order: number, -- Display order in list
}

type OrderedHero = {
	Name: string,
	Description: string,
	Price: number, -- if zero then free
	DefaultSkin: string,
	Unavailable: boolean?,
	Skins: { OrderedSkin },
	Modifiers: { string },
	Talents: { string },
	Skills: { string },
	Order: number?,
}

export type Hero = {
	Name: string,
	Description: string,
	Price: number, -- if zero then free
	DefaultSkin: string,
	Unavailable: boolean?,
	Skins: { [string]: Skin },
	Modifiers: { string },
	Talents: { string },
	Skills: { string },
	Order: number,
}

local DefaultModifiers = {
	"Fast",
	"Health",
	"Slow",
	"Stealth",
	"Regen",
	"Fury",
	"QuickReload",
	"SuperCharge",
	"Bulwark",
	"Rat",
	"TrueSight",
	"SkillCharge",
}

local DefaultSkills = {
	"Dash",
	"BirdyBomb",
	"Heal",
	"Shield",
	"Sprint",
	"PowerPill",
	"Reflect",
	"Haste",
	"SlowField",
}

local orderedHeroDetails: { OrderedHero } = {
	{
		Name = "Taz",
		Description = "Taz's spread-fire shotgun blasts the enemy with Buckshot. His Super destroys cover and keeps his enemies at a distance!",
		Price = 0,
		DefaultSkin = "Apple",
		Modifiers = table.clone(DefaultModifiers),
		Talents = { "ShellShock", "BandAid" },
		Skills = table.clone(DefaultSkills),
		Skins = {
			{
				Name = "Apple",
				Description = "He's red",
				Price = 0,
				Rarity = "Common",
			},
			{
				Name = "Ninja",
				Description = "Chuck Chuck.",
				Price = 300,
				Rarity = "Uncommon",
			},
			{
				Name = "Bow Tie",
				Description = "You're under dressed.",
				Price = 300,
				Rarity = "Uncommon",
			},
			{
				Name = "Army",
				Description = "Private Taz, reporting for duty.",
				Price = 900,
				Rarity = "Epic",
			},
			{
				Name = "Devil",
				Description = "Spare any blood?",
				Price = 1800,
				Rarity = "Rare",
			},
			{
				Name = "Tech Guy",
				Description = "Sorry I have a meeting.",
				Price = 1800,
				Rarity = "Epic",
			},
			{
				Name = "Golden",
				Description = "Exclusively for the best",
				Price = 7000,
				Rarity = "Legendary",
			},
		},
	},
	{
		Name = "Frankie",
		Description = "Frankie fires damaging energy waves at enemies. He throws a slime bomb for his Super, striking opponents with a powerful blast!",
		Price = 100,
		DefaultSkin = "Aqua",
		Modifiers = table.clone(DefaultModifiers),
		Talents = { "SuperBlast", "Overslime", "Slimed", "Missile" },
		Skills = table.clone(DefaultSkills),
		Skins = {
			{
				Name = "Aqua",
				Description = "You water watch out!",
				Price = 0,
				Rarity = "Common",
			},
			{
				Name = "Melon Head",
				Description = "Whoops, I ate it all.",
				Price = 100,
				Rarity = "Uncommon",
			},
			{
				Name = "Life Guard",
				Description = "I'll save me, but not you.",
				Price = 100,
				Rarity = "Uncommon",
			},
			{
				Name = "Life Jacket",
				Description = "Just floatin on by.",
				Price = 100,
				Rarity = "Uncommon",
			},
			{
				Name = "Sailor",
				Description = "Let's discover new lands!",
				Price = 1300,
				Rarity = "Epic",
			},
			{
				Name = "Hunter",
				Description = "Aim down site, right at you.",
				Price = 1300,
				Rarity = "Rare",
			},
			{
				Name = "Blueberry",
				Description = "Nom Nom",
				Price = 1500,
				Rarity = "Epic",
			},
			{
				Name = "Venom",
				Description = "I'm infected, you will be too.",
				Price = 1500,
				Rarity = "Rare",
			},
			{
				Name = "Candy",
				Description = "Mmmm. Can you taste that?",
				Price = 1550,
				Rarity = "Epic",
			},
			{
				Name = "Grape",
				Description = "How does one make wine?",
				Price = 1500,
				Rarity = "Epic",
			},
			{
				Name = "Pirate",
				Description = "Arrrr Mateyyy",
				Price = 2000,
				Rarity = "Rare",
			},
			{
				Name = "VR",
				Description = "Oh dude this is the future man.",
				Price = 1500,
				Rarity = "Legendary",
			},
			{
				Name = "Champion",
				Description = "Exclusively for the best",
				Price = 7000,
				Rarity = "Legendary",
			},
		},
	},
	{
		Name = "Dino",
		Description = "Dino's combat skills are currently being worked on by the team and will be released in our next big update. Stay tuned.",
		Price = 500,
		DefaultSkin = "Dino",
		Unavailable = true,
		Modifiers = {},
		Talents = {},
		Skills = {},
		Skins = {
			{
				Name = "Dino",
				Price = 0,
				Description = "dinosaur",
				Rarity = "Common",
			},
		},
	},
	{
		Name = "Gobzie",
		Description = "Gobzie's combat skills are currently being worked on by the team and will be released in our next big update. Stay tuned.",
		Price = 500,
		DefaultSkin = "Gobzie",
		Unavailable = true,
		Modifiers = {},
		Talents = {},
		Skills = {},
		Skins = {
			{
				Name = "Gobzie",
				Price = 0,
				Description = "gobbler",
				Rarity = "Common",
			},
		},
	},
}

-- Silly type cheating, there's a better way of doing this but I'm lazy
-- Reason for doing this is to allow indexing by name, but still be ordered.
local heros = {}
for i, hero in pairs(orderedHeroDetails) do
	local hero = hero :: any

	local skins = hero.Skins
	hero.Skins = {}
	for j, skin in pairs(skins) do
		skin.Order = j
		hero.Skins[skin.Name] = skin
	end
	local hero = hero :: Hero
	hero.Order = i
	heros[hero.Name] = hero
end

module.HeroDetails = heros :: { [string]: Hero }

TableUtil.Lock(module.HeroDetails)

function ValidateData()
	local characterFolder = ReplicatedStorage.Assets.CharacterModels

	for hero, heroData in pairs(module.HeroDetails) do
		assert(characterFolder[hero], hero .. " did not have folder in character models")

		for skin, skinData in pairs(heroData.Skins) do
			assert(characterFolder[hero][skin], skinData.Name .. " " .. heroData.Name .. " did not have model")
		end

		assert(heroData.Skins[heroData.DefaultSkin].Price == 0, "Default hero skin is not free!")
	end
end

ValidateData()

function module.GetModelFromName(heroName: string, skinName: string?): Model
	if not skinName then
		skinName = module.HeroDetails[heroName].DefaultSkin
	end

	return ReplicatedStorage.Assets.CharacterModels:FindFirstChild(heroName):FindFirstChild(skinName)
end

return module
