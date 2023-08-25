-- variables
local Main = {
	CurrentPlayerData = {},
	PlayerJoinTime = {},
	DefaultData = {
		Level = 0,
		Experience = 0,
		Rank = "",
		Currency = 0,
		Stats = {
			Kills = 0,
			Deaths = 0,
			Wins = 0,
			Losses = 0,
			WinStreak = 0,
			BestWinStreak = 0,
			KillStreak = 0,
			BestKillStreak = 0,
			DamageDealt = 0,
		},
		Playtime = 0,
	},
}

-- services
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- load modules
local Loader = require(game.ReplicatedStorage.Modules.Shared.Loader)
local Network = Loader:LoadModule("Network")

-- functions
function Main:RecursiveAdd(Data, CompareTo)
	for Key, Value in pairs(CompareTo) do
		if Data[Key] == nil then
			Data[Key] = Value

			print("added", Key, Value)
		elseif typeof(Value) == "table" then
			-- recursively go through array

			self:RecursiveAdd(Data[Key], Value)
		end
	end
end

function Main:HandleData(Player, PlayerData)
	self:RecursiveAdd(PlayerData.Data, self.DefaultData)

	for Key, Value in pairs(PlayerData.Data) do
		if not self.DefaultData[Key] then
			PlayerData.Data[Key] = nil
			print("removing", Key, Value)
		end
	end

	PlayerData.LastSaveTick = tick()
end

function Main:NewPlayer(Player)
	task.spawn(function()
		self.PlayerJoinTime[Player] = tick() -- playtime

		wait(3)

		if self.CurrentPlayerData["Player_" .. Player.UserId] then
			local HttpService = game:GetService("HttpService")

			warn(HttpService:JSONEncode(self.CurrentPlayerData["Player_" .. Player.UserId]))
			Player:Kick("data mismatch")
			return
		end

		if not (Player and Player.Parent) then
			return
		end

		local PlayerId = "Player_" .. Player.UserId
		local PlayerData = {
			Player = Player,
			Data = {},
			Save = false,
			DataLoaded = false,
			--LastSaveTick = 0
		}

		local LoadedData
		local ErrorMessage
		local DataMismatch
		local Success, Error

		local ReturnInfo

		for i = 1, 3 do
			ErrorMessage = nil
			DataMismatch = nil

			Success, Error = pcall(function()
				PlayerDatastore:UpdateAsync(PlayerId, function(Data)
					if Data == nil then
						print("created new data")

						-- don't need to set playerdata's data cuz its already defined above

						local Success, DataError = self:HandleData(Player, PlayerData)

						if DataError then
							ErrorMessage = DataError

							return nil
						end

						LoadedData = true

						return PlayerData.Data
					end

					PlayerData.Data = Data

					local Success, DataError = self:HandleData(Player, PlayerData)

					if DataError then
						ErrorMessage = DataError

						return nil
					end

					LoadedData = true

					return Data
				end)
			end)

			if LoadedData or not Success then
				break
			end

			print("attempting to load data again")

			task.wait(5)
		end

		if not Success then
			warn("failed to load data for", Player.Name)
			Player:Kick("failed to load data, rejoin")
			return
		elseif ErrorMessage then
			Player:Kick(ErrorMessage)
		elseif LoadedData then
			PlayerData.DataLoaded = true
		elseif not LoadedData then
			Player:Kick("failed to load data, rejoin. V2")
			return
		end

		self.CurrentPlayerData["Player_" .. Player.UserId] = PlayerData

		if Success then
			warn("loaded", Player.Name)
			Network:FireClient(Player, "LoadData", PlayerData.Data)
		end
	end)
end

function Main:SaveData(Player, IsLeaving)
	local PlayerData = self.CurrentPlayerData["Player_" .. Player.UserId]
	local PlayerId = "Player_" .. Player.UserId

	if not PlayerData then
		print("data never loaded cannot save")
		return
	end

	if PlayerData.Saving and not (IsLeaving and not PlayerData.Leaving) then
		print("already saving")
		return
	end

	PlayerData.LastSaveTick = tick()
	PlayerData.Save = false

	if not PlayerData.DataLoaded then
		print("cannot save, data not loaded", Player.Name)
		return
	end

	print("saved for", Player.Name)

	local function Save()
		local Success, Error = pcall(function()
			PlayerDatastore:UpdateAsync(PlayerId, function(Data)
				if Data then
					if IsLeaving then
						warn("removed session data")
						self.PlayerJoinTime[Player] = nil
					end

					return PlayerData.Data
				else
					warn("failed to save data")

					return nil
				end
			end)
		end)

		if Error then
			warn(Error)
		end

		PlayerData.Saving = false

		if IsLeaving then
			self.CurrentPlayerData["Player_" .. Player.UserId] = nil
		end
	end

	if IsLeaving then
		PlayerData.Leaving = true

		Save()
	else
		task.spawn(function()
			Save()
		end)
	end
end

function Main:Initialize()
	PlayerDatastore = DataStoreService:GetDataStore("PlayerData")

	for i, v in pairs(Players:GetPlayers()) do
		self:NewPlayer(v)
	end

	game.Players.PlayerAdded:Connect(function(Player)
		self:NewPlayer(Player)
	end)

	game.Players.PlayerRemoving:Connect(function(Player)
		local PlayerData = self.CurrentPlayerData["Player_" .. Player.UserId]

		self:SaveData(Player, true) -- clears session and playerdata table
	end)

	game:GetService("RunService").Heartbeat:Connect(function()
		for PlayerKey, Data in pairs(self.CurrentPlayerData) do
			local PlayerData = self.CurrentPlayerData[PlayerKey]

			if not PlayerData.DataLoaded then
				continue
			end

			if PlayerData.Save and tick() - PlayerData.LastSaveTick >= 20 then
				self:SaveData(PlayerData.Player)
			elseif tick() - PlayerData.LastSaveTick >= 3 * 60 then -- 3 minutes
				self:SaveData(PlayerData.Player)
			end
		end
	end)

	game:BindToClose(function()
		if RunService:IsStudio() then
			-- print("studiop")
		else
			for i, v in pairs(game.Players:GetPlayers()) do
				self:SaveData(v, true)
			end
		end

		if not RunService:IsStudio() then
			task.wait(10)
		end
	end)

	Network:OnServerEvent("GetData", function(Player)
		local PlayerData = self.CurrentPlayerData["Player_" .. Player.UserId]

		if PlayerData then
			return PlayerData.Data
		end
	end)
end

return Main
