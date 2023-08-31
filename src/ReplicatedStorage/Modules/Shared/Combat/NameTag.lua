local CombatPlayer = require(script.Parent.CombatPlayer)
local NameTag = {}

local nameTagTemplate = game:GetService("ReplicatedStorage").Assets.NameTag

function NameTag.Init(character: Model, combatPlayer: CombatPlayer.CombatPlayer, hide: Player?)
	local nameTag = nameTagTemplate:Clone()
	assert(character.Parent, "Character has not been parented to workspace yet!")

	if hide then
		nameTag.PlayerToHideFrom = hide
	end

	nameTag.PlayerName.Text = character.Name

	nameTag.Parent = character:FindFirstChild("Head")

	task.spawn(function()
		while character.Parent ~= nil and nameTag.Parent ~= nil do
			for i = 1, 3 do
				local AmmoBar = nameTag.AmmoBar:FindFirstChild("Ammo" .. i)

				if AmmoBar then
					AmmoBar.Visible = i <= combatPlayer.ammo
				end
			end
			nameTag.HealthNumber.Text = combatPlayer.health
			local healthRatio = combatPlayer.health / combatPlayer.maxHealth

			-- Size the smaller bar as a percentage of the size of the parent bar, based off player health percentage
			local healthBar = nameTag.HealthBar.HealthBar
			healthBar.Size = UDim2.new(healthRatio, 0, 0, healthBar.Size.Y.Offset)

			-- Fixes weird bug where it would still render with a width at 0, looking incredibly strange.
			if healthBar.AbsoluteSize.X < 2.1 then
				healthBar.Visible = false
			else
				healthBar.Visible = true
			end

			local colour1 = Color3.fromHSV(healthRatio * 100 / 255, 206 / 255, 1)
			local colour2 = Color3.fromHSV(healthRatio * 88 / 255, 197 / 255, 158 / 255)
			nameTag.HealthBar.HealthBar.UIGradient.Color = ColorSequence.new(colour1, colour2)

			task.wait()
		end
	end)
	return nameTag
end
return NameTag
