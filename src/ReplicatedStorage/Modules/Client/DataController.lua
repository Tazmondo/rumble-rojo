-- variables
local Main = {
	DataLoaded = false,
	OnLoadListeners = {},
	OnUpdateListeners = {},
}

local Player = game.Players.LocalPlayer
local Mouse = Player:GetMouse()

-- services

-- load modules
local ModuleLoader = require(game.ReplicatedStorage.Modules.Shared.Loader)
local Network = ModuleLoader:LoadModule("Network")

-- functions
function Main:OnLoad(ReturnFunction)
	table.insert(self.OnLoadListeners, ReturnFunction)

	if self.DataLoaded then
		ReturnFunction()
	end
end

function Main:OnUpdate(Values, ReturnFunction)
	if typeof(Values) ~= "table" then
		Values = { Values }
	end

	for i = 1, #Values do
		local Value = Values[i]

		if not self.OnUpdateListeners[Value] then
			self.OnUpdateListeners[Value] = {}
		end

		table.insert(self.OnUpdateListeners[Value], ReturnFunction)
	end
end

function Main:LoadData(Data)
	if self.DataLoaded then
		return
	end

	print("loaded data")

	self.Data = Data
	self.DataLoaded = true

	for i = 1, #self.OnLoadListeners do
		local Listener = self.OnLoadListeners[i]

		Listener()
	end
end

function Main:Initialize()
	warn("initialized data controller")

	Network:OnClientEvent("LoadData", function(Data)
		self:LoadData(Data)
	end)

	Network:OnClientEvent("UpdateData", function(ToUpdate)
		for Key, Value in pairs(ToUpdate) do
			self.Data[Key] = Value

			if self.OnUpdateListeners[Key] then
				for i = 1, #self.OnUpdateListeners[Key] do
					self.OnUpdateListeners[Key][i]()
				end
			end
		end
	end)

	local Data = Network:InvokeServer("GetData")

	if Data then
		self:LoadData(Data) -- if for some reason the server sends you data before you are initialized
	end
end

return Main
