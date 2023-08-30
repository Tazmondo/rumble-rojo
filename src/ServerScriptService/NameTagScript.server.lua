local nameTag = script.NameTag
local CombatService = require(game.ServerStorage.Modules.CombatService)

game.Players.PlayerAdded:Connect(function(Player)
	Player.CharacterAdded:Connect(function(Character)
		repeat
			wait()
		until Character.Head

		local NameTag = nameTag:Clone()
		local CombatPlayer = CombatService:GetCombatPlayerForPlayer(Player)

		NameTag.PlayerName.Text = Player.Name
		NameTag.HealthNumber.Text = Character.Humanoid.Health

		NameTag.Parent = Character.Head

		while true do
			for i = 1, 3 do
				local AmmoBar = NameTag.AmmoBar:FindFirstChild("Ammo" .. i)

				if AmmoBar then
					AmmoBar.Visible = i <= CombatPlayer.ammo
				end
			end

			wait()
		end
	end)
end)
