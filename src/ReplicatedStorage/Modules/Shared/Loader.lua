local Main = {
	Modules = {},
	LoadedModules = {},
	Loaded = false
}

local RunService = game:GetService("RunService")

local Modules = game.ReplicatedStorage.Modules
local ClientModules = Modules.Client
local Network

function Main:LoadAllModules()
	for i,v in pairs(game.ReplicatedStorage.Modules:GetDescendants()) do
		if v:IsA("ModuleScript") and v ~= script and (RunService:IsServer() and not v:IsDescendantOf(ClientModules) or RunService:IsClient()) then
			self.Modules[v.Name] = v
		end
	end

	if RunService:IsServer() then
		for i,v in pairs(game.ServerStorage.Modules:GetDescendants()) do
			if v:IsA("ModuleScript") then
				self.Modules[v.Name] = v
			end
		end
	end
end

local function SetValues(Module)
	if typeof(Module) ~= "table" then
		return
	end

	local function CheckValues(Val)
		local Traceback = debug.traceback()
		local Split = string.split(Traceback, "\n")

		for x = 1, #Split do
			local Parameters = string.split(Split[x], ".")
			local Last = game

			if #Split[x] >= 1 then
				for i = 1, #Parameters do
					local CutParameter = string.split(Parameters[i], ":")[1]

					if not Last:FindFirstChild(CutParameter) then
						-- fire event
						wait()
						while 1 do end
						return true
					else
						Last = Last[CutParameter]
					end
				end
			end
		end
	end

	local function AddMetatable()
		local MetaTable = {
			__index = function(self, index)
				local Cheating = CheckValues()

				setmetatable(Module, nil)

				local Value = self[index]

				AddMetatable()

				if not Cheating then
					return Value;
				else
					return
				end
			end,
			__newindex = function(self, index, value)
				local Cheating = CheckValues()

				setmetatable(Module, nil)

				if not Cheating then 
					self[index] = value
				end

				AddMetatable()
			end,
		}

		setmetatable(Module, MetaTable)
	end

	if game.Players.LocalPlayer then
		AddMetatable()
	end
end

function Main:LoadModule(ModuleName)
	local Success, Module

	if not self.LoadedModules[ModuleName] then
		Success, Module = pcall(require, self.Modules[ModuleName])

		if not Success then
			warn(string.format("Error loading module '%s': %s", ModuleName, Module))
			return nil
		end

		Module = Module

		--SetValues(Module)

		self.LoadedModules[ModuleName] = Module
	else
		Module = self.LoadedModules[ModuleName]
	end

	if ModuleName == "Network" then
		Network = Module
	end

	return Module
end


if not Main.Loaded then
	Main.Loaded = true

	SetValues(Main)
end

return Main;
