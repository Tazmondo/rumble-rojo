local CommandController = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Spawn = require(ReplicatedStorage.Packages.Spawn)
local Cmdr = require(ReplicatedStorage:WaitForChild("CmdrClient")) :: any -- booo bad module, shouldnt have to cast this

function CommandController.Initialize()
	print("Initialize command controller")
	Cmdr:SetActivationKeys({ Enum.KeyCode.F2 })
	Cmdr:SetEnabled(false)
	Spawn(function()
		while Players.LocalPlayer:GetAttribute("Cmdr_Admin") == nil do
			task.wait()
		end
		Cmdr:SetEnabled(Players.LocalPlayer:GetAttribute("Cmdr_Admin"))
	end)
end

CommandController.Initialize()

return CommandController
