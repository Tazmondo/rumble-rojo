-- variables
local Main = {
	PlayerUI = {},
	PlayerData = {},
	PlayerFrameMap = {},
}

local Player = game.Players.LocalPlayer
local Mouse = Player:GetMouse()
local UI = Player:WaitForChild("PlayerGui"):WaitForChild("MainUI")
local ArenaUI = Player:WaitForChild("PlayerGui"):WaitForChild("ArenaUI").Interface

local Templates = ArenaUI.Parent.Templates -- laziness
local Scoreboard = ArenaUI:WaitForChild("ScoreBoard")

-- services
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- load modules
local ModuleLoader = require(game.ReplicatedStorage.Modules.Shared.Loader)
local Network = ModuleLoader:LoadModule("Network")
local SharedMemory = ModuleLoader:LoadModule("SharedMemory")
local UIController = ModuleLoader:LoadModule("UIController")

-- functions
function Main:IsAlive() end

function Main:ClearScoreboard() -- bruh
	for i, v in pairs(Scoreboard.List1:GetChildren()) do
		if v:IsA("Frame") then
			v:Destroy()
		end
	end
	for i, v in pairs(Scoreboard.List2:GetChildren()) do
		if v:IsA("Frame") then
			v:Destroy()
		end
	end
end

function Main:CreateScoreboard(PlayerList)
	self:ClearScoreboard()

	local FrameIndex = 1

	for _, Player in pairs(PlayerList) do
		local Frame = Templates:WaitForChild("ScoreboardPlayer"):Clone()
		local Avatar =
			Players:GetUserThumbnailAsync(Player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)

		Frame.Avatar.Character.Image = Avatar
		Frame.Name = tostring(Player)
		Frame.Visible = true

		if FrameIndex == 1 then
			Frame.Parent = Scoreboard.List1
		else
			Frame.Parent = Scoreboard.List2
		end

		self.PlayerFrameMap[Player.Name] = Frame
		FrameIndex = (FrameIndex % 2) + 1
	end
end

function Main:UpdateHealth(Frame, Health)
	local Percent = math.clamp(Health / 100, 0, 1)

	Frame.HealthBar.Health.Size = UDim2.new(Percent, 0, 0.1, 0)
end

function Main:Initialize()
	RunService.RenderStepped:Connect(function()
		Scoreboard.List1.Visible = SharedMemory.InMatch == true -- these 2 lists are just annoying
		Scoreboard.List2.Visible = SharedMemory.InMatch == true

		if SharedMemory.InMatch then
			for _, Player in SharedMemory.MatchedPlayers do
				local Character = Player.Character
				local Frame = self.PlayerFrameMap[Player.Name]

				if Character and Frame then
					self:UpdateHealth(Frame, Character.Humanoid.Health)
				end
			end
		end
	end)

	spawn(function()
		while wait() do
			local Success, Error = pcall(function()
				if not game:GetService("RunService"):IsStudio() then
					StarterGui:SetCore("ResetButtonCallback", false)
				end
			end)

			if not Error then
				break
			end
		end
	end)
end

return Main
