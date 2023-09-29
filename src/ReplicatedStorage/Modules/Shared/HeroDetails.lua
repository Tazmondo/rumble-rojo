--!strict
--!nolint LocalShadow
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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
	Offence: number,
	Defence: number,
	DefaultSkin: string,
	Skins: { OrderedSkin },
	Order: number?,
}

export type Hero = {
	Name: string,
	Description: string,
	Price: number, -- if zero then free
	Offence: number,
	Defence: number,
	DefaultSkin: string,
	Skins: { [string]: Skin },
	Order: number,
}

local orderedHeroDetails: { OrderedHero } = {
	{
		Name = "Taz",
		Description = "Taz specializes in range spray combat. With a fierce super shell.",
		Price = 0,
		Offence = 4,
		Defence = 2,
		DefaultSkin = "Apple",
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
				Price = 299,
				Rarity = "Uncommon",
			},
			{
				Name = "Bow Tie",
				Description = "You're under dressed.",
				Price = 299,
				Rarity = "Uncommon",
			},
			{
				Name = "Army",
				Description = "Private Taz, reporting for duty.",
				Price = 899,
				Rarity = "Epic",
			},
			{
				Name = "Devil",
				Description = "Spare any blood?",
				Price = 1799,
				Rarity = "Rare",
			},
			{
				Name = "Tech Guy",
				Description = "Sorry I have a meeting.",
				Price = 1799,
				Rarity = "Epic",
			},
			{
				Name = "Golden",
				Description = "Exclusively for the best",
				Price = 3900,
				Rarity = "Legendary",
			},
		},
	},
	{
		Name = "Frankie",
		Description = "Frankie is a boss. Guy tosses mad water balloons and mushrooms.",
		Price = 299,
		Offence = 2,
		Defence = 4,
		DefaultSkin = "Aqua",
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
				Price = 399,
				Rarity = "Uncommon",
			},
			{
				Name = "Life Guard",
				Description = "I'll save me, but not you.",
				Price = 439,
				Rarity = "Uncommon",
			},
			{
				Name = "Life Jacket",
				Description = "Just floatin on by.",
				Price = 365,
				Rarity = "Uncommon",
			},
			{
				Name = "Sailor",
				Description = "Let's discover new lands!",
				Price = 549,
				Rarity = "Epic",
			},
			{
				Name = "Hunter",
				Description = "Aim down site, right at you.",
				Price = 899,
				Rarity = "Rare",
			},
			{
				Name = "Blueberry",
				Description = "Nom Nom",
				Price = 500,
				Rarity = "Epic",
			},
			{
				Name = "Venom",
				Description = "I'm infected, you will be too.",
				Price = 600,
				Rarity = "Rare",
			},
			{
				Name = "Candy",
				Description = "Mmmm. Can you taste that?",
				Price = 1299,
				Rarity = "Epic",
			},
			{
				Name = "Grape",
				Description = "How does one make wine?",
				Price = 849,
				Rarity = "Epic",
			},
			{
				Name = "Pirate",
				Description = "Arrrr Mateyyy",
				Price = 999,
				Rarity = "Rare",
			},
			{
				Name = "VR",
				Description = "Oh dude this is the future man.",
				Price = 1499,
				Rarity = "Legendary",
			},
			{
				Name = "Champion",
				Description = "Exclusively for the best",
				Price = 3900,
				Rarity = "Legendary",
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

module.HeroDetails = table.freeze(module.HeroDetails)

print(module.HeroDetails)

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

function module.GetModelFromName(heroName: string, skinName: string?)
	if not skinName then
		skinName = module.HeroDetails[heroName].DefaultSkin
	end

	return ReplicatedStorage.Assets.CharacterModels:FindFirstChild(heroName):FindFirstChild(skinName)
end

return module
