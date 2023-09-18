local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CombatPlayer = require(script.Parent.CombatPlayer)
local Enums = require(script.Parent.Enums)
local NameTag = {}

local nameTagTemplate = ReplicatedStorage.Assets.NameTag
local haloTemplate: Part = ReplicatedStorage.Assets.VFX.General.Halo

local SPINSPEED = 1.5 -- Seconds for full rotation

function NameTag.Init(character: Model, combatPlayer: CombatPlayer.CombatPlayer, hide: Player?)
	local nameTag = nameTagTemplate:Clone()
	local halo = haloTemplate:Clone()
	assert(character.Parent, "Character has not been parented to workspace yet!")
	local HRP = assert(character:FindFirstChild("HumanoidRootPart"), "Character did not have a humanoidrootpart")
	local humanoid = assert(character:FindFirstChild("Humanoid"), "Character did not have a humanoid")

	if hide then
		nameTag.PlayerToHideFrom = hide
	end

	nameTag.PlayerName.Text = character.Name

	task.spawn(function()
		nameTag.Parent = character:WaitForChild("Head")
		halo.Parent = workspace
		if RunService:IsServer() then
			halo.Name = character.Name .. "ServerHalo"
		end

		while true do
			local dt = task.wait()
			if character.Parent == nil or nameTag.Parent == nil then
				break
			end

			for i = 1, 3 do
				local AmmoBar = nameTag.AmmoBar:FindFirstChild("Ammo" .. i)

				if AmmoBar then
					AmmoBar.Visible = i <= combatPlayer.ammo
				end
			end
			nameTag.HealthNumber.Text = combatPlayer.health
			local healthRatio = combatPlayer.health / combatPlayer.maxHealth

			-- Size the smaller bar as a percentage of the size of the parent bar, based off player health percentage
			local healthBar = nameTag.HealthBar.HealthBar
			healthBar.Size = UDim2.new(healthRatio, 0, 0, healthBar.Size.Y.Offset)

			-- Fixes weird bug where it would still render with a width at 0, looking incredibly strange.
			if healthBar.AbsoluteSize.X < 2.1 then
				healthBar.Visible = false
			else
				healthBar.Visible = true
			end

			local colour1 = Color3.fromHSV(healthRatio * 100 / 255, 206 / 255, 1)
			local colour2 = Color3.fromHSV(healthRatio * 88 / 255, 197 / 255, 158 / 255)
			nameTag.HealthBar.HealthBar.UIGradient.Color = ColorSequence.new(colour1, colour2)

			if RunService:IsClient() then
				local serverHalo = workspace:FindFirstChild(character.Name .. "ServerHalo")
				if serverHalo then
					serverHalo:Destroy()
				end
			end

			local superAvailable = combatPlayer:CanSuperAttack()
			local aiming = combatPlayer.aiming
			if not superAvailable then
				halo.Decal.Transparency = 1
			else
				halo.Decal.Transparency = 0
				if aiming == Enums.AbilityType.Super then
					halo.Decal.Color3 = Color3.fromHex("#ebb800")
				else
					halo.Decal.Color3 = Color3.fromHex("#619cf5")
				end
			end

			halo.CFrame = CFrame.new(HRP.Position)
				* CFrame.new(0, -humanoid.HipHeight - HRP.Size.Y / 2 + 0.2, 0)
				* halo.CFrame.Rotation
				* CFrame.Angles(0, math.pi * 2 * dt / SPINSPEED, 0)
		end

		-- Since it's not parented to the character
		halo:Destroy()
	end)
	return nameTag
end
return NameTag
