local Main = {
	LoadedModules = {},
	ModuleLogs = {}
}

local Loader = require(game.ReplicatedStorage.Modules.Shared.Loader)

function Main:LoadModule(ModuleName)
	self.LoadedModules[ModuleName] = true

	local ModuleLog = {
		Status = "Loading",
		Time = os.time()
	}
	self.ModuleLogs[ModuleName] = ModuleLog

	local Module = Loader:LoadModule(ModuleName)
	Module:Initialize()

	ModuleLog.Status = "Loaded"
	ModuleLog.Time = os.time()

	return Module;
end

function Main:Initialize(LoadOrder)
	local Loader = require(game.ReplicatedStorage.Modules.Shared.Loader)
	Loader:LoadAllModules()

	for i = 1, #LoadOrder do
		local ModuleName = LoadOrder[i]

		self:LoadModule(ModuleName)
	end

	local Location = if game:GetService("RunService"):IsClient() then game.ReplicatedStorage.Modules.Client else game.ServerStorage.Modules
	for i,v in pairs(Location:GetChildren()) do
		if not self.LoadedModules[v.Name] then
			self:LoadModule(v.Name)
		end
	end
end

return Main;