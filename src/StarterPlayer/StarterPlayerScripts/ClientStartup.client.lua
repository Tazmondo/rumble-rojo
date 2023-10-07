--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Loader = require(ReplicatedStorage.Packages.Loader)
local Spawn = require(ReplicatedStorage.Packages.Spawn)

local LoadedEvent = require(ReplicatedStorage.Events.Loaded):Client()

local Client = ReplicatedStorage.Modules.Client

print("Beginning loading.")

local scripts = Client:GetDescendants()
for i, moduleScript in ipairs(scripts) do
	if not moduleScript:IsA("ModuleScript") then
		continue
	end
	local yielded = true
	Spawn(function()
		require(moduleScript)
		yielded = false
	end)

	if yielded then
		error("Yielded while requiring " .. moduleScript:GetFullName())
	end
end

print("Finished loading, firing server.")

LoadedEvent:Fire()
