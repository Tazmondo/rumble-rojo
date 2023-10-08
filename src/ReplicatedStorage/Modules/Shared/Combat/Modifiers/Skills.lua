local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Types = require(ReplicatedStorage.Modules.Shared.Types)
local Skill: { [string]: Types.Skill } = {}

Skill[""] = {
	Name = "Default",
	Description = "Default skill",
	Activated = function() end,
}

Skill.Dash = {
	Name = "Dash",
	Description = "Dash forwards",
	Activated = function(combatPlayer)
		if RunService:IsServer() then
			-- We only want to do movement on the client
			return
		end

		local dashTime = 0.2
		local dashDistance = 15

		local character = combatPlayer.character
		local HRP = character:FindFirstChild("HumanoidRootPart") :: BasePart

		local startCFrame = CFrame.new(HRP.Position)
		local targetCFrame = CFrame.new((HRP.CFrame * CFrame.new(0, 0, -dashDistance)).Position)

		local start = os.clock()

		combatPlayer:SetStatusEffect("Dash", true)

		local conn
		conn = RunService.PreSimulation:Connect(function()
			local progress = math.clamp(((os.clock() - start) / dashTime), 0, 1)
			local currentCFrame = startCFrame:Lerp(targetCFrame, progress)
			character:PivotTo(currentCFrame * character:GetPivot().Rotation)

			if progress == 1 then
				combatPlayer:SetStatusEffect("Dash")
				conn:Disconnect()
			end
		end)
	end,
}

return Skill
