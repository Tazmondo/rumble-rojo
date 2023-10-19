print("Initialize command controller")

local CommandController = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local Spawn = require(ReplicatedStorage.Packages.Spawn)

function CommandController.Initialize()
	local Cmdr = require(ReplicatedStorage:WaitForChild("CmdrClient")) :: any -- booo bad module, shouldnt have to cast this
	Cmdr:SetActivationKeys({ Enum.KeyCode.Semicolon })
	Cmdr:SetEnabled(false)
	Spawn(function()
		while Players.LocalPlayer:GetAttribute("Cmdr_Admin") == nil do
			task.wait()
		end
		Cmdr:SetEnabled(Players.LocalPlayer:GetAttribute("Cmdr_Admin"))
	end)

	TextChatService.SendingMessage:Connect(function(message)
		if message.Text:lower() == "cmdr" then
			Cmdr:Toggle()
		end
	end)
end

Spawn(CommandController.Initialize)

return CommandController
