local nameTag = script.NameTag

game.Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		
	
		repeat wait() until character.Head
		local plrTag = nameTag:Clone()
		plrTag.PlayerName.Text = player.Name
		
		plrTag.Parent = character.Head
	end)
end)