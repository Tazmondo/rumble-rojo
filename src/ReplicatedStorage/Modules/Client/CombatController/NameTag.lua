local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CombatPlayer = require(ReplicatedStorage.Modules.Shared.Combat.CombatPlayer)
local Enums = require(ReplicatedStorage.Modules.Shared.Combat.Enums)

local NameTag = {}

local combatGUITemplate: BillboardGui = ReplicatedStorage.Assets.CombatGUI
local haloTemplate: Part = ReplicatedStorage.Assets.VFX.General.Halo

local HaloFolder = Instance.new("Folder", workspace)
HaloFolder.Name = "Halo Folder"

local SPINSPEED = 1.5 -- Seconds for full rotation

function NameTag.InitFriendly(combatPlayer: CombatPlayer.CombatPlayer)
	local character = combatPlayer.character
	local HRP = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChild("Humanoid")
	if not HRP or not humanoid then
		warn("No HRP/humanoid", HRP, humanoid)
		return
	end

	local gui = HRP:FindFirstChild("CombatGUI")
	if not gui then
		gui = combatGUITemplate:Clone()
		gui.DamagePopup.Visible = false

		gui.EnemyNameTag.Visible = false
		gui.ObjectNameTag.Visible = false
		gui.FriendlyNameTag.Visible = true

		gui.Parent = HRP
	end

	local nameTag = gui.FriendlyNameTag

	local halo = haloTemplate:Clone()

	halo.Parent = HaloFolder

	assert(character.Parent, "Character has not been parented to workspace yet!")

	nameTag.name.nametag.PlayerName.Text = "You"
	-- roblox are stupid and made studsoffsetworldspace relative to the object and not the world
	gui.StudsOffsetWorldSpace = gui.Parent.CFrame.Rotation:VectorToObjectSpace(gui.StudsOffsetWorldSpace)

	local run: RBXScriptConnection
	run = RunService.RenderStepped:Connect(function(dt)
		if character.Parent == nil or gui.Parent == nil then
			run:Disconnect()
			halo:Destroy()
			return
		end

		for i = 1, 3 do
			local individualAmmoBar = nameTag.stats.ammo:FindFirstChild("Ammo" .. i)

			if individualAmmoBar then
				individualAmmoBar.Visible = i <= combatPlayer.ammo
			end
		end

		nameTag.stats.healthnumber.Text = combatPlayer.health

		local healthRatio = combatPlayer.health / combatPlayer.maxHealth

		-- Size the smaller bar as a percentage of the size of the parent bar, based off player health percentage
		local healthBar = nameTag.stats.healthbar.HealthBar
		healthBar.Size = UDim2.new(healthRatio, 0, 1, 0)

		healthBar.Visible = combatPlayer.health > 0

		local colour1 = Color3.fromHSV(healthRatio * 100 / 255, 206 / 255, 1)
		local colour2 = Color3.fromHSV(healthRatio * 88 / 255, 197 / 255, 158 / 255)
		healthBar.UIGradient.Color = ColorSequence.new(colour1, colour2)

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
	end)
end

function NameTag.Test()
	warn("oweihfwei98ufhwiuafhiuewafhweaiu")
end

function NameTag.InitEnemy(data: CombatPlayer.UpdateData)
	local character = data.Character

	assert(character.Parent, "Character has not been parented to workspace yet!")

	local lid
	local HRP
	local humanoid
	if data.IsObject then
		lid = character:WaitForChild("lid", 5)
		if not lid then
			warn("Chest did not have lid!")
			return
		end
	else
		HRP = character:WaitForChild("HumanoidRootPart", 5)
		humanoid = character:FindFirstChild("Humanoid")
		if not HRP or not humanoid then
			warn("No HRP/humanoid", character, HRP, humanoid)
			return
		end
	end

	local anchor = HRP or lid
	if not anchor then
		warn("no anchor found, object:", data.IsObject)
		return
	end

	local gui = anchor:FindFirstChild("CombatGUI")
	if not gui then
		gui = combatGUITemplate:Clone()
		gui.DamagePopup.Visible = false

		gui.EnemyNameTag.Visible = false
		gui.ObjectNameTag.Visible = false
		gui.FriendlyNameTag.Visible = false

		gui.Parent = anchor
	end

	local nameTag = if data.IsObject then gui.ObjectNameTag else gui.EnemyNameTag
	nameTag.Visible = true

	local halo
	if not data.IsObject then
		halo = haloTemplate:Clone()

		halo.Parent = HaloFolder
	end

	if not data.IsObject then
		nameTag.name.nametag.PlayerName.Text = data.Name
	end
	-- roblox are stupid and made studsoffsetworldspace relative to the object and not the world
	gui.StudsOffsetWorldSpace = gui.Parent.CFrame.Rotation:VectorToObjectSpace(gui.StudsOffsetWorldSpace)

	local run: RBXScriptConnection
	run = RunService.RenderStepped:Connect(function(dt)
		if character.Parent == nil or gui.Parent == nil then
			run:Disconnect()
			if halo then
				halo:Destroy()
			end
			return
		end

		if not data.IsObject then
			nameTag.stats.healthnumber.Text = data.Health
		end

		local healthRatio = data.Health / data.MaxHealth

		-- Size the smaller bar as a percentage of the size of the parent bar, based off player health percentage
		local healthBar = nameTag.stats.healthbar.HealthBar
		healthBar.Size = UDim2.new(healthRatio, 0, 1, 0)

		healthBar.Visible = data.Health > 0

		-- only render colour gradients for local character
		healthBar.UIGradient.Color = ColorSequence.new(Color3.fromHex("#f6266e"), Color3.fromHex("#a80050"))

		if not data.IsObject then
			if not data.SuperAvailable then
				halo.Decal.Transparency = 1
			else
				halo.Decal.Transparency = 0
				if data.AimingSuper then
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
	end)

	return true
end

return NameTag
