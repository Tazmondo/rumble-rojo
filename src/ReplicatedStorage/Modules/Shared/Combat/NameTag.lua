local CombatPlayer = require(script.Parent.CombatPlayer)
local NameTag = {}

local nameTagTemplate = game:GetService("ReplicatedStorage").Assets.NameTag

function NameTag.Init(player: Player, combatPlayer: CombatPlayer.CombatPlayer, hide: boolean)
	local char = assert(player.Character, "Tried to initialize nametag on player without a character")
	assert(player.Character.Parent, "Character has not been parented to workspace yet!")
	local NameTag = nameTagTemplate:Clone()

	if hide then
		NameTag.PlayerToHideFrom = player
	end

	NameTag.PlayerName.Text = player.Name

	NameTag.Parent = char.Head

	task.spawn(function()
		while char.Parent ~= nil and NameTag.Parent ~= nil do
			for i = 1, 3 do
				local AmmoBar = NameTag.AmmoBar:FindFirstChild("Ammo" .. i)

				if AmmoBar then
					AmmoBar.Visible = i <= combatPlayer.ammo
				end
			end
			NameTag.HealthNumber.Text = combatPlayer.health
			local healthRatio = combatPlayer.health / combatPlayer.maxHealth

			-- Size the smaller bar as a percentage of the size of the parent bar, based off player health percentage
			NameTag.HealthBar.HealthBar.Size = UDim2.new(healthRatio, 0, 0, NameTag.HealthBar.HealthBar.Size.Y.Offset)

			local colour1 = Color3.fromHSV(healthRatio * 100 / 255, 206 / 255, 1)
			local colour2 = Color3.fromHSV(healthRatio * 88 / 255, 197 / 255, 158 / 255)
			NameTag.HealthBar.HealthBar.UIGradient.Color = ColorSequence.new(colour1, colour2)

			task.wait()
		end
	end)
	return NameTag
end
return NameTag
