local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CombatPlayer = require(ReplicatedStorage.Modules.Shared.Combat.CombatPlayer)
local Enums = require(ReplicatedStorage.Modules.Shared.Combat.Enums)

local NameTag = {}

local combatGUITemplate: BillboardGui = ReplicatedStorage.Assets.CombatGUI
local lobbyNameTagTemplate: BillboardGui = ReplicatedStorage.Assets.LobbyNameTag
local haloTemplate: Part = ReplicatedStorage.Assets.VFX.General.Halo

local SPINSPEED = 1.5 -- Seconds for full rotation

function NameTag.Init(
	character: Model,
	combatPlayer: CombatPlayer.CombatPlayer,
	hide: Player?,
	anchor: BasePart?,
	isObject: boolean?
)
	local nameTagHolder = combatGUITemplate:Clone()
	local nameTag

	if isObject then
		nameTag = nameTagHolder:FindFirstChild("ObjectNameTag") :: Frame
	elseif RunService:IsClient() then
		nameTag = nameTagHolder:FindFirstChild("FriendlyNameTag") :: Frame
	else
		nameTagHolder.PlayerToHideFrom = hide
		nameTag = nameTagHolder:FindFirstChild("EnemyNameTag") :: Frame
	end

	nameTag.Visible = true

	local halo = haloTemplate:Clone()
	assert(character.Parent, "Character has not been parented to workspace yet!")

	if RunService:IsClient() then
		nameTag.name.nametag.PlayerName.Text = "You"
	elseif not isObject then
		nameTag.name.nametag.PlayerName.Text = character.Name
	end

	task.spawn(function()
		nameTagHolder.Parent = anchor or character:WaitForChild("HumanoidRootPart") :: BasePart

		-- roblox are stupid and made studsoffsetworldspace relative to the object and not the world
		nameTagHolder.StudsOffsetWorldSpace =
			nameTagHolder.Parent.CFrame.Rotation:VectorToObjectSpace(nameTagHolder.StudsOffsetWorldSpace)

		halo.Parent = workspace
		if RunService:IsServer() then
			halo.Name = character.Name .. "ServerHalo"

			-- Hide ammo bar from other players, only yours is visible
		else
			nameTag.stats.ammo.Visible = true
		end

		while true do
			local dt = task.wait()
			if character.Parent == nil or nameTagHolder.Parent == nil then
				break
			end

			if RunService:IsClient() then
				for i = 1, 3 do
					local individualAmmoBar = nameTag.stats.ammo:FindFirstChild("Ammo" .. i)

					if individualAmmoBar then
						individualAmmoBar.Visible = i <= combatPlayer.ammo
					end
				end
			end

			if not isObject then
				nameTag.stats.healthnumber.Text = combatPlayer.health
			end

			local healthRatio = combatPlayer.health / combatPlayer.maxHealth

			-- Size the smaller bar as a percentage of the size of the parent bar, based off player health percentage
			local healthBar = nameTag.stats.healthbar.HealthBar
			healthBar.Size = UDim2.new(healthRatio, 0, 1, 0)

			healthBar.Visible = combatPlayer.health > 0

			-- only render colour gradients for local character
			if RunService:IsClient() and character == Players.LocalPlayer.Character then
				local colour1 = Color3.fromHSV(healthRatio * 100 / 255, 206 / 255, 1)
				local colour2 = Color3.fromHSV(healthRatio * 88 / 255, 197 / 255, 158 / 255)
				healthBar.UIGradient.Color = ColorSequence.new(colour1, colour2)
			else
				healthBar.UIGradient.Color = ColorSequence.new(Color3.fromHex("#f6266e"), Color3.fromHex("#a80050"))
			end

			if not isObject then
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
				local HRP = character:FindFirstChild("HumanoidRootPart")
				local humanoid = character:FindFirstChild("Humanoid")

				halo.CFrame = CFrame.new(HRP.Position)
					* CFrame.new(0, -humanoid.HipHeight - HRP.Size.Y / 2 + 0.2, 0)
					* halo.CFrame.Rotation
					* CFrame.Angles(0, math.pi * 2 * dt / SPINSPEED, 0)
			end
		end

		-- Since it's not parented to the character
		halo:Destroy()
	end)
	return nameTagHolder
end

function NameTag.LobbyInit(player: Player, character: Model, trophies: number)
	local nameTag = lobbyNameTagTemplate:Clone() :: BillboardGui

	local hum = assert(character:FindFirstChildOfClass("Humanoid"))
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

	nameTag.name.name.PlayerName.Text = player.DisplayName
	nameTag.Trophies.TrophyCount.Text = trophies

	nameTag.ExtentsOffset = Vector3.zero
	nameTag.ExtentsOffsetWorldSpace = Vector3.new(0, 3, 0)
	nameTag.Parent = assert(character:FindFirstChild("HumanoidRootPart"), "Character did not have HRP")
end

return NameTag
