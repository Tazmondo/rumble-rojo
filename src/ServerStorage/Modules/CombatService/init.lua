-- Initializes and handles the of the server-side combat system
-- Shouldn't be very long, as combat data is mostly decided by scripts in client
-- This just validates that they haven't been tampered with before replicating them to other clients

local Main = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local AttackLogic = require(ReplicatedStorage.Modules.Shared.Combat.AttackLogic)
local CombatPlayer = require(ReplicatedStorage.Modules.Shared.Combat.CombatPlayer)
local Config = require(ReplicatedStorage.Modules.Shared.Combat.Config)
local FastCast = require(ReplicatedStorage.Modules.Shared.Combat.FastCastRedux)
local HeroData = require(ReplicatedStorage.Modules.Shared.Combat.HeroData)
local Enums = require(ReplicatedStorage.Modules.Shared.Combat.Enums)
local Loader = require(ReplicatedStorage.Modules.Shared.Loader)

local Network: typeof(require(ReplicatedStorage.Modules.Shared.Network)) = Loader:LoadModule("Network")

-- Only for players currently fighting.
local CombatPlayerData: { [Model]: CombatPlayer.CombatPlayer } = {}
local fastCast = FastCast.new()

local function getAllCombatPlayerCharacters()
	local out = {}
	for model, combatPlayer in pairs(CombatPlayerData) do
		table.insert(out, model)
	end
	return out
end

local function handleAttack(player: Player, origin: CFrame, localAttackDetails)
	if not player.Character then
		return
	end
	local combatPlayer = CombatPlayerData[player.Character]
	if not combatPlayer or not combatPlayer:CanAttack() then
		return
	end
	local attackData = combatPlayer.heroData.Attack :: HeroData.AttackData

	local behaviour = FastCast.newBehavior()
	behaviour.MaxDistance = attackData.Range
	behaviour.RaycastParams = RaycastParams.new()

	-- Don't collide with characters, as they move around they could move in front of the server bullet, but not client bullet
	-- which will mess up hit detection
	behaviour.RaycastParams.FilterDescendantsInstances = getAllCombatPlayerCharacters()
	behaviour.RaycastParams.FilterType = Enum.RaycastFilterType.Exclude

	if attackData.AttackType == Enums.AttackType.Shotgun then
		local attackDetails = AttackLogic.Shotgun(attackData.Angle, attackData.ShotCount, origin, function()
			return combatPlayer:GetNextAttackId()
		end, localAttackDetails.seed)
		localAttackDetails = localAttackDetails :: typeof(attackDetails)

		for index, pellet in pairs(attackDetails.pellets) do
			if pellet.id ~= localAttackDetails.pellets[index].id then
				warn(player, "mismatched attack ids, could be cheating.")
				return
			end
			local cast =
				fastCast:Fire(pellet.CFrame.Position, pellet.CFrame.LookVector, attackData.ProjectileSpeed, behaviour)
			cast.UserData.Id = pellet.id
			combatPlayer:RegisterAttack(pellet.id, pellet.CFrame, cast)
		end
		Network:FireAllClients("Attack", player, attackData, attackDetails, origin)
	end

	combatPlayer:Attack()
end

local function handleRayHit(cast, result)
	cast.UserData.HitPosition = result.Position
end
fastCast.RayHit:Connect(handleRayHit)

local function handleClientHit(player: Player, target: BasePart, localTargetPosition: Vector3, attackId: number)
	if not player.Character or not target or not localTargetPosition or not attackId then
		return
	end
	local combatPlayer = CombatPlayerData[player.Character]
	if not combatPlayer then
		return
	end

	local attackData = combatPlayer.attacks[attackId]
	if not attackData then
		return
	end

	local victimCharacter = CombatPlayer.GetCombatPlayerFromInstance(target)
	if not victimCharacter then
		return
	end

	if (target.Position - localTargetPosition).Magnitude > Config.MaximumPlayerPositionDifference then
		warn("Rejected attack, too far away!", player, localTargetPosition, target, target.Position)
		return
	end

	local attackRay = Ray.new(attackData.FiredCFrame.Position, attackData.FiredCFrame.LookVector)
	local rayDiff = attackRay.Unit:Distance(localTargetPosition)

	-- Accounts for NaN case
	if rayDiff ~= rayDiff then
		rayDiff = 0
	end

	if rayDiff > 5 then
		warn(player, "Almost certainly exploiting, mismatched fired and hit bullet trajectories.")
		return
	end

	local attackPosition = attackData.HitPosition or attackData.Cast:GetPosition()
	local attackDiff = (attackPosition - localTargetPosition).Magnitude
	if attackDiff > Config.MaximumAllowedLatencyVariation * attackData.Data.ProjectileSpeed then
		warn(player, "Had too large of a difference between bullet positions")
		return
	end

	CombatPlayerData[victimCharacter]:TakeDamage(attackData.Data.Damage)
end

function Main:Initialize()
	Players.PlayerAdded:Connect(function(player: Player)
		player.CharacterAdded:Connect(function(char)
			local heroName = "Fabio"
			local combatPlayer = CombatPlayer.new(heroName, char.Humanoid)
			CombatPlayerData[char] = combatPlayer

			Network:FireClient(player, "CombatPlayer Initialize", heroName)

			char.Destroying:Wait()
			CombatPlayerData[char] = nil
		end)
	end)

	Network:OnServerEvent("Attack", handleAttack)
	Network:OnServerEvent("Hit", handleClientHit)

	if workspace:FindFirstChild("Rig") then
		CombatPlayerData[workspace.Rig] = CombatPlayer.new("Fabio", workspace.Rig.Humanoid)
	end
end

return Main