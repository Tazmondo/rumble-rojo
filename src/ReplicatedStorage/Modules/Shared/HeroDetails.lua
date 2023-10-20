--!strict
--!nolint LocalShadow
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)
-- Defines hero prices and skin prices

local module = {}

export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary"

type OrderedSkin = {
	Name: string,
	DisplayName: string?,
	Description: string,
	Price: number,
	Rarity: Rarity,
	Order: number?,
}
export type Skin = {
	Name: string,
	DisplayName: string?,
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
	"Birdy Bomb",
	"Heal",
	"Shield",
	"Sprint",
	"Power Pill",
	"Reflect",
	"Haste",
	"Slow Field",
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
				Price = 1500,
				Rarity = "Rare",
			},
			{
				Name = "Devil",
				Description = "Spare any blood?",
				Price = 1800,
				Rarity = "Epic",
			},
			{
				Name = "Tech Guy",
				Description = "Sorry I have a meeting.",
				Price = 2300,
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
				Name = "Hunter",
				Description = "Aim down site, right at you.",
				Price = 1300,
				Rarity = "Rare",
			},
			{
				Name = "Blueberry",
				Description = "Nom Nom",
				Price = 1500,
				Rarity = "Rare",
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
				Rarity = "Rare",
			},
			{
				Name = "Grape",
				Description = "How does one make wine?",
				Price = 1500,
				Rarity = "Rare",
			},
			{
				Name = "Sailor",
				Description = "Let's discover new lands!",
				Price = 1900,
				Rarity = "Epic",
			},
			{
				Name = "Pirate",
				Description = "Arrrr Mateyyy",
				Price = 2000,
				Rarity = "Epic",
			},
			{
				Name = "VR",
				Description = "Oh dude this is the future man.",
				Price = 2300,
				Rarity = "Legendary",
			},
			{
				Name = "Champion",
				DisplayName = "Golden",
				Description = "Exclusively for the best",
				Price = 7000,
				Rarity = "Legendary",
			},
		},
	},
	{
		Name = "Gobzie",
		Description = "Gobzie shoots bacteria in a flurry. His super shoots a field of infection that slows enemies while doing damage.",
		Price = 400,
		DefaultSkin = "Gobzie",
		Modifiers = table.clone(DefaultModifiers),
		Talents = { "Violent Infection", "Slowing Infection" },
		Skills = table.clone(DefaultSkills),
		Skins = {
			{
				Name = "Gobzie",
				Price = 0,
				Description = "gobbler",
				Rarity = "Common",
			},
			{
				Name = "Sombrero",
				Price = 800,
				Description = "Let's party!",
				Rarity = "Uncommon",
			},

			{
				Name = "Freddy",
				Price = 850,
				Description = "I beat my high score!",
				Rarity = "Uncommon",
			},
			{
				Name = "Beret",
				Price = 1200,
				Description = "At ease, soldier!",
				Rarity = "Rare",
			},
			{
				Name = "Devil Trident",
				Price = 1800,
				Description = "I need blood...",
				Rarity = "Epic",
			},
			{
				Name = "Space Ghost",
				Price = 2300,
				Description = "wsgwu?",
				Rarity = "Epic",
			},
			{
				Name = "Jester",
				Price = 3200,
				Description = "gobbler",
				Rarity = "Legendary",
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
		Name = "Boxy",
		Description = "Boxy runs around throwing his own head at people. His super shoots lightning bolts in every direction.",
		Price = 400,
		DefaultSkin = "Boxy",
		Modifiers = table.clone(DefaultModifiers),
		Talents = { "Electrocution", "Microwave", "Current Outbreak" },
		Skills = table.clone(DefaultSkills),
		Skins = {
			{
				Name = "Boxy",
				Price = 0,
				Description = "Beep Beep",
				Rarity = "Common",
			},
			{
				Name = "Crush",
				Price = 900,
				Description = "I crush, on you...",
				Rarity = "Uncommon",
			},
			{
				Name = "Biker",
				Price = 950,
				Description = "Vroom Vroom.",
				Rarity = "Rare",
			},
			{
				Name = "Devil",
				Price = 2200,
				Description = "Yummmm. Blood.",
				Rarity = "Epic",
			},
			{
				Name = "Viper",
				Price = 3200,
				Description = "Do you even lift, bro?",
				Rarity = "Epic",
			},
			{
				Name = "Pixeler",
				Price = 1200,
				Description = "Cooler than you",
				Rarity = "Legendary",
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
		Name = "Buzzer",
		Description = "Buzzer is a slow but lethal killing machine. He spits out deadly sawblades to shred his enemies to pieces.",
		Price = 400,
		DefaultSkin = "Buzzer",
		Modifiers = table.clone(DefaultModifiers),
		Talents = { "Electrocution", "Microwave", "Current Outbreak" },
		Skills = table.clone(DefaultSkills),
		Skins = {
			{
				Name = "Buzzer",
				Price = 0,
				Description = "BZZZZZ",
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
