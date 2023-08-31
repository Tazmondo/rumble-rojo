local CombatPlayer = require(script.Parent.CombatPlayer)
local NameTag = {}

local nameTagTemplate = game:GetService("ReplicatedStorage").Assets.NameTag

function NameTag.Init(character: Model, combatPlayer: CombatPlayer.CombatPlayer, hide: Player?)
	local NameTag = nameTagTemplate:Clone()
	assert(character.Parent, "Character has not been parented to workspace yet!")

	if hide then
		NameTag.PlayerToHideFrom = hide
	end

	NameTag.PlayerName.Text = character.Name

	NameTag.Parent = character:FindFirstChild("Head")

	task.spawn(function()
		while character.Parent ~= nil and NameTag.Parent ~= nil do
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
