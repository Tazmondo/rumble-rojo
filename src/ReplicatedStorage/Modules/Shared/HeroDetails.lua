--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- Defines hero prices and skin prices

local module = {}

export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary"

export type Skin = {
	Name: string,
	Description: string,
	Price: number,
	Rarity: Rarity,
}

export type Hero = {
	Name: string,
	Description: string,
	Price: number, -- if zero then free
	Offence: number,
	Defence: number,
	DefaultSkin: string,
	Skins: { [string]: Skin },
}

module.HeroDetails = {
	Taz = {
		Name = "Taz",
		Description = "Taz specializes in range spray combat. With a fierce super shell.",
		Price = 500,
		Offence = 4,
		Defence = 2,
		DefaultSkin = "Apple",
		Skins = {
			Apple = {
				Name = "Apple",
				Description = "He's red",
				Price = 0,
				Rarity = "Common",
			},
			Golden = {
				Name = "Golden",
				Description = "kingly",
				Price = 500,
				Rarity = "Legendary",
			},
		},
	},
	Frankie = {
		Name = "Frankie",
		Description = "Frankie is a boss. Guy tosses mad water balloons and mushrooms.",
		Price = 0,
		Offence = 2,
		Defence = 4,
		DefaultSkin = "Blueberry",
		Skins = {
			Blueberry = {
				Name = "Blueberry",
				Description = "He's from the sea",
				Price = 0,
				Rarity = "Common",
			},
			Venom = {
				Name = "Venom",
				Description = "spiderman",
				Price = 0,
				Rarity = "Rare",
			},
			VR = {
				Name = "VR",
				Description = "Tech guy",
				Price = 0,
				Rarity = "Legendary",
			},
		},
	},
} :: { [string]: Hero }

module.HeroDetails = table.freeze(module.HeroDetails)

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
