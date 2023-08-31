local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Red = require(ReplicatedStorage.Packages.Red)
-- variables
local Main = {
	DataLoaded = false,
	OnLoadListeners = {},
	OnUpdateListeners = {},
}

local Player = game.Players.LocalPlayer

-- services

-- load modules
local Net = Red.Client("game")

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
	-- warn("initialized data controller")

	Net:On("LoadData", function(Data)
		self:LoadData(Data)
	end)

	Net:On("UpdateData", function(ToUpdate)
		for Key, Value in pairs(ToUpdate) do
			self.Data[Key] = Value

			if self.OnUpdateListeners[Key] then
				for i = 1, #self.OnUpdateListeners[Key] do
					self.OnUpdateListeners[Key][i]()
				end
			end
		end
	end)

	local Data = Net:Call("GetData"):Await()

	if Data then
		self:LoadData(Data) -- if for some reason the server sends you data before you are initialized
	end
end

return Main
