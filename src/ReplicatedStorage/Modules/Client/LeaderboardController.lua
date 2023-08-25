-- variables
local Main = {
    PlayerUI = {},
	PlayerData = {}
	
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
function Main:IsAlive()
end

function Main:GetUser(Player)
	-- n NO NO
    -- local User = Scoreboard.List1[Player]

    -- if User then
    --     return User;
    -- else
    --     return Scoreboard.List2[Player]
    -- end
end

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

function Main:UpdateScoreboard(PlayerList)
	self:ClearScoreboard()

	local PlayerAmount = #PlayerList
	local PlayersPerFrame = math.ceil(PlayerAmount / 2)

	local FrameIndex = 1

	for _, Player in pairs(PlayerList) do
		local Frame = Templates:WaitForChild("ScoreboardPlayer"):Clone()
		local Avatar = Players:GetUserThumbnailAsync(Player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
		local Character = Player.Character

		if Character then
			local Humanoid = Character:FindFirstChild("Humanoid")
			local HealthBar = Frame.HealthBar
			
            local CurrentHealth = Humanoid.Health
			local Percent = math.clamp(CurrentHealth / 100 or 0, 0, 1)

			HealthBar.Health.Size = UDim2.new(Percent, 0, 0.1, 0)
		end

		Frame.Avatar.Character.Image = Avatar
		Frame.Name = tostring(Player)
		Frame.Visible = true

		if FrameIndex == 1 then
			Frame.Parent = Scoreboard.List1
		else
			Frame.Parent = Scoreboard.List2
		end

		FrameIndex = (FrameIndex % 2) + 1
		Scoreboard.Visible = true
	end
end

function Main:Initialize()
    spawn(function()
        while wait() do
			for i = 1, #self.Players do
				local User = self:GetUser(i)
				local Percent = math.clamp(User and self:IsAlive(User) and User.Health / 100 or 0, 0, 1)
				
				User.HealthBar.Health.Size = UDim2.new(Percent, 0, 0.1, 0)
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