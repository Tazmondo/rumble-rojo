-- Initializes and handles the of the server-side combat system
-- Shouldn't be very long, as combat data is mostly decided by scripts in client
-- This just validates that they haven't been tampered with before replicating them to other clients
-- The way this is programmed may seem convoluted, but I want to avoid race conditions from CharacterAdded and make sure
-- 		the whole spawning process is clearly defined

local CombatService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local AttackLogic = require(ReplicatedStorage.Modules.Shared.Combat.AttackLogic)
local CombatPlayer = require(ReplicatedStorage.Modules.Shared.Combat.CombatPlayer)
local Config = require(ReplicatedStorage.Modules.Shared.Combat.Config)
local FastCast = require(ReplicatedStorage.Modules.Shared.Combat.FastCastRedux)
local HeroData = require(ReplicatedStorage.Modules.Shared.Combat.HeroData)
local Enums = require(ReplicatedStorage.Modules.Shared.Combat.Enums)
local NameTag = require(ReplicatedStorage.Modules.Shared.Combat.NameTag)
local Loader = require(ReplicatedStorage.Modules.Shared.Loader)

local Network: typeof(require(ReplicatedStorage.Modules.Shared.Network)) = Loader:LoadModule("Network")
local DataService: typeof(require(script.Parent.DataService)) = Loader:LoadModule("DataService")

local nameTagTemplate = ReplicatedStorage.Assets.NameTag

-- Only for players currently fighting.
local CombatPlayerData: { [Model]: CombatPlayer.CombatPlayer } = {}
local PlayersInCombat: { [Player]: string } = {}
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
	assert(behaviour.RaycastParams)

	-- Don't collide with characters, as they move around they could move in front of the server bullet, but not client bullet
	-- which will mess up hit detection
	behaviour.RaycastParams.FilterDescendantsInstances = getAllCombatPlayerCharacters()
	behaviour.RaycastParams.FilterType = Enum.RaycastFilterType.Exclude

	if attackData.AttackType == Enums.AttackType.Shotgun then
		local attackDetails = AttackLogic.Shotgun(
			attackData.Angle,
			attackData.ShotCount,
			attackData.ProjectileSpeed,
			origin,
			localAttackDetails.seed,
			function()
				return combatPlayer:GetNextAttackId()
			end
		)
		localAttackDetails = localAttackDetails :: typeof(attackDetails)

		for index, pellet in pairs(attackDetails.pellets) do
			if pellet.id ~= localAttackDetails.pellets[index].id then
				warn(player, "mismatched attack ids, could be cheating.")
				return
			end
			local cast = fastCast:Fire(pellet.CFrame.Position, pellet.CFrame.LookVector, pellet.speed, behaviour)
			cast.UserData.Id = pellet.id
			combatPlayer:RegisterAttack(pellet.id, pellet.CFrame, cast)
		end
		Network:FireAllClients("Attack", player, attackData, origin, attackDetails)
	end

	combatPlayer:Attack()
end

local function handleRayHit(cast, result)
	cast.UserData.HitPosition = result.Position
end

local function handleCastTerminate(cast)
	-- We want to prioritise the RayHit hitposition
	if not cast.UserData.HitPosition then
		cast.UserData.HitPosition = cast:GetPosition()
	end
end
fastCast.RayHit:Connect(handleRayHit)
fastCast.CastTerminating:Connect(handleCastTerminate)

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

	local victimCharacter = CombatPlayer.GetAncestorWhichIsACombatPlayer(target)
	if not victimCharacter then
		return
	end
	local victimCombatPlayer = CombatPlayerData[victimCharacter]

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

	-- Makes sure the trajectory of bullet doesn't change between fire and hit event.
	if rayDiff > 5 then
		warn(player, "Almost certainly exploiting, mismatched fired and hit bullet trajectories.")
		return
	end

	local attackPosition = attackData.HitPosition or attackData.Cast:GetPosition()
	local attackDiff = (attackPosition - localTargetPosition).Magnitude
	if attackDiff > Config.MaximumAllowedLatencyVariation * attackData.Data.ProjectileSpeed then
		warn(
			player,
			"Had too large of a difference between bullet positions: ",
			attackDiff,
			attackPosition,
			localTargetPosition
		)
		return
	end

	local beforeState = victimCombatPlayer:GetState()
	victimCombatPlayer:TakeDamage(attackData.Data.Damage) -- Will update state to dead if this kills
	local afterState = victimCombatPlayer:GetState()

	local died = victimCombatPlayer:GetState() == CombatPlayer.StateEnum.Dead and beforeState ~= afterState

	-- Update Data
	local killerData = DataService:GetDataTableForPlayer(player)
	killerData.Stats.DamageDealt += attackData.Data.Damage

	if died then
		-- TODO: Add experience and level handling
		killerData.Stats.Kills += 1
		killerData.Stats.KillStreak += 1 -- This could continue between matches, so it should be set to 0 elsewhere
		killerData.Stats.BestKillStreak = math.max(killerData.Stats.BestKillStreak, killerData.Stats.KillStreak)

		local victimPlayer = Players:GetPlayerFromCharacter(victimCharacter)
		if victimPlayer then
			local victimData = DataService:GetDataTableForPlayer(victimPlayer)
			victimData.Stats.Deaths += 1
			victimData.Stats.KillStreak = 0
		end
	end
end

function CombatService:GetCombatPlayerForPlayer(player: Player): CombatPlayer.CombatPlayer?
	self = self :: CombatService

	if player.Character and CombatPlayerData[player.Character] then
		return CombatPlayerData[player.Character]
	else
		return
	end
end

function CombatService:InitializeNameTag(player: Player, combatPlayer: CombatPlayer.CombatPlayer)
	self = self :: CombatService

	local nameTag = NameTag.Init(player, combatPlayer, true)
	task.spawn(function()
		while player.Character and CombatPlayerData[player.Character] do
			task.wait()
		end
		nameTag:Destroy()
	end)
end

function CombatService:EnterPlayerCombat(player: Player, heroName: string, newCFrame: CFrame?)
	self = self :: CombatService

	PlayersInCombat[player] = heroName
	self:SpawnCharacter(player, newCFrame)
end

function CombatService:ExitPlayerCombat(player: Player)
	self = self :: CombatService

	PlayersInCombat[player] = nil
	if player.Character then
		CombatPlayerData[player.Character]:Destroy()
		CombatPlayerData[player.Character] = nil
	end
	self:SpawnCharacter(player)
end

function CombatService:SetupCombatPlayer(player: Player, heroName: string)
	self = self :: CombatService
	local char = assert(player.Character, "no character")
	local humanoid = assert(char:FindFirstChildOfClass("Humanoid"), "no humanoid")

	local combatPlayer = CombatPlayer.new(heroName, humanoid)
	CombatPlayerData[char] = combatPlayer

	Network:FireClient(player, "CombatPlayer Initialize", heroName)

	self:InitializeNameTag(player, combatPlayer)
end

function CombatService:LoadCharacterWithModel(player: Player, characterModel: Model?)
	self = self :: CombatService

	if characterModel then
		local starterChar = characterModel:Clone()
		starterChar.Name = "StarterCharacter"
		starterChar.Parent = game.StarterPlayer
		player:LoadCharacter()
		starterChar:Destroy()
	else
		player:LoadCharacter()
	end
end

function CombatService:SpawnCharacter(player: Player, spawnCFrame: CFrame?)
	self = self :: CombatService
	print("Spawning Character", player, debug.traceback())

	-- TODO: Do spawning
	player.CharacterAdded:Once(function(char)
		print(player, "Character was added, processing")

		task.wait() -- Let it get parented to workspace
		print(player, "Character initialized to workspace")

		if PlayersInCombat[player] then
			self:SetupCombatPlayer(player, PlayersInCombat[player])
		end

		char:FindFirstChild("Humanoid").Died:Once(function()
			-- This shouldn't cause a memory leak if the character is respawned instead of dying, as humanoid being destroyed will disconnect thi
			task.wait(1)
			if PlayersInCombat[player] then
				self:ExitPlayerCombat(player)
			else
				self:SpawnCharacter(player)
			end
		end)

		if spawnCFrame then
			char:PivotTo(spawnCFrame)
		end
	end)
	print(player, "Loading char")

	local heroName = PlayersInCombat[player] or ""

	self:LoadCharacterWithModel(player, ReplicatedStorage.Assets.CharacterModels:FindFirstChild(heroName))
end

function CombatService:PlayerAdded(player: Player)
	self = self :: CombatService

	-- warn("Testing combatservice: All players auto enter combat")
	-- PlayersInCombat[player] = "Fabio"
	self:SpawnCharacter(player)
end

function CombatService:Initialize()
	self = self :: CombatService

	game.Players.CharacterAutoLoads = false

	Players.PlayerAdded:Connect(function(...)
		self:PlayerAdded(...)
	end)
	for _, player in pairs(Players:GetPlayers()) do
		self:PlayerAdded(player)
	end

	Network:OnServerEvent("Attack", handleAttack)
	Network:OnServerEvent("Hit", handleClientHit)

	if workspace:FindFirstChild("Rig") then
		CombatPlayerData[workspace.Rig] = CombatPlayer.new("Fabio", workspace.Rig.Humanoid)
	end
end

export type CombatService = typeof(CombatService)

return CombatService
