local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CombatPlayerController = require(ReplicatedStorage.Modules.Client.CombatController.CombatPlayerController)
local CombatPlayer = require(ReplicatedStorage.Modules.Shared.Combat.CombatPlayer)
local Config = require(ReplicatedStorage.Modules.Shared.Combat.Config)
local AutoAim = {}

export type AimData = {
	direction: Vector3,
	target: Vector3,
}

function AutoAim.GetData(range: number)
	local character = Players.LocalPlayer.Character
	if not character then
		return nil :: Vector3?, nil :: Vector3?
	end

	local humanoid = character:FindFirstChild("Humanoid") :: Humanoid?
	if not humanoid then
		return nil
	end

	local HRP = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not HRP then
		return nil
	end

	local closest = AutoAim.GetClosest(range, HRP.Position)
	if not closest then
		return nil
	end

	local closestCFrame = closest:GetPivot()
	local lookDirection = (closestCFrame.Position - HRP.Position).Unit

	local target = closestCFrame.Position - Vector3.new(0, humanoid.HipHeight + HRP.Size.Y / 2) + Vector3.new(0, 0.1, 0)

	return lookDirection, target
end

function AutoAim.GetClosest(range: number, origin: Vector3): Model?
	local targets = CombatPlayer.GetAllCombatPlayerCharacters()
	local closestChest = nil
	local closestPlayer = nil

	for i, model in ipairs(targets) do
		local data = CombatPlayerController.GetData(model):UnwrapOr(nil :: any)
		if not data or data.State == "Dead" then
			continue
		end

		local distance = (model:GetPivot().Position - origin).Magnitude

		if model:HasTag(Config.ChestTag) then
			if not closestChest or closestChest.distance > distance then
				closestChest = { distance = distance, model = model }
			end
		elseif model ~= Players.LocalPlayer.Character then
			if not closestPlayer or closestPlayer.distance > distance then
				closestPlayer = { distance = distance, model = model }
			end
		end
	end

	if closestChest and closestPlayer then
		if closestPlayer.distance <= range or closestPlayer.distance < closestChest.distance then
			return closestPlayer.model
		else
			return closestChest.model
		end
	elseif closestChest and closestChest.distance <= range then
		return closestChest.model
	elseif closestPlayer then
		return closestPlayer.model
	else
		return nil
	end
end

return AutoAim
