-- Initializes and handles the of the server-side combat system
-- Shouldn't be very long, as combat data is mostly decided by scripts in client
-- This just validates that they haven't been tampered with before replicating them to other clients
-- The way this is programmed may seem convoluted, but I want to avoid race conditions from CharacterAdded and make sure
-- 		the whole spawning process is clearly defined

local CombatService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local LoadedService = require(script.Parent.LoadedService)
local DataService = require(script.Parent.DataService)
local SoundService = require(script.Parent.SoundService)

local AttackLogic = require(ReplicatedStorage.Modules.Shared.Combat.AttackLogic)
local CombatPlayer = require(ReplicatedStorage.Modules.Shared.Combat.CombatPlayer)
local Config = require(ReplicatedStorage.Modules.Shared.Combat.Config)
local FastCast = require(ReplicatedStorage.Modules.Shared.Combat.FastCastRedux)
local HeroData = require(ReplicatedStorage.Modules.Shared.Combat.HeroData)
local Enums = require(ReplicatedStorage.Modules.Shared.Combat.Enums)
local NameTag = require(ReplicatedStorage.Modules.Shared.Combat.NameTag)
local Red = require(ReplicatedStorage.Packages.Red)
local Net = Red.Server("game", { "CombatPlayerInitialize", "CombatKill", "PlayerKill" })

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

local function replicateAttack(
	player: Player,
	origin: CFrame,
	combatPlayer: CombatPlayer.CombatPlayer,
	attackData: HeroData.AttackData,
	localAttackDetails
)
	local character = assert(player.Character, "character does not exist")
	local HRP = character:FindFirstChild("HumanoidRootPart") :: BasePart
	if (HRP.Position - origin.Position).Magnitude > Config.MaximumPlayerPositionDifference then
		warn(player, "fired from a position too far from their server position")
		return
	end
	local behaviour = FastCast.newBehavior()
	behaviour.MaxDistance = attackData.Range
	behaviour.RaycastParams = RaycastParams.new()
	assert(behaviour.RaycastParams, "Appease type checker")

	-- Don't collide with characters, as they move around they could move in front of the server bullet, but not client bullet
	-- which will mess up hit detection
	behaviour.RaycastParams.FilterDescendantsInstances = getAllCombatPlayerCharacters()
	behaviour.RaycastParams.FilterType = Enum.RaycastFilterType.Exclude

	if attackData.AttackType == Enums.AttackType.Shotgun then
		local attackDetails = AttackLogic.MakeAttack(combatPlayer, origin, attackData, localAttackDetails.seed)
		localAttackDetails = localAttackDetails :: typeof(attackDetails)

		for index, pellet in pairs(attackDetails.pellets) do
			if pellet.id ~= localAttackDetails.pellets[index].id then
				warn(player, "mismatched attack ids, could be cheating.")
				return
			end
			local cast = fastCast:Fire(pellet.CFrame.Position, pellet.CFrame.LookVector, pellet.speed, behaviour)
			cast.UserData.Id = pellet.id
			cast.UserData.CombatPlayer = combatPlayer
			combatPlayer:RegisterAttack(pellet.id, pellet.CFrame, pellet.speed, cast, attackData)
		end
		Net:FireAll("Attack", player, attackData, origin, attackDetails)
	end
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

	replicateAttack(player, origin, combatPlayer, attackData, localAttackDetails)

	SoundService:PlayAttack(player, attackData.Name, player.Character)

	combatPlayer:Attack()
end

local function handleSuper(player: Player, origin: CFrame, localAttackDetails)
	if not player.Character then
		return
	end
	local combatPlayer = CombatPlayerData[player.Character]
	if not combatPlayer or not combatPlayer:CanSuperAttack() then
		return
	end
	local superData = combatPlayer.heroData.Super :: HeroData.SuperData

	replicateAttack(player, origin, combatPlayer, superData, localAttackDetails)

	SoundService:PlayAttack(player, superData.Name, player.Character)

	combatPlayer:SuperAttack()
end

local function handleRayHit(cast, result)
	local combatPlayer = cast.UserData.CombatPlayer :: CombatPlayer.CombatPlayer
	combatPlayer:HandleAttackHit(cast, result.Position)
end

local function handleCastTerminate(cast)
	local combatPlayer = cast.UserData.CombatPlayer :: CombatPlayer.CombatPlayer
	combatPlayer:HandleAttackHit(cast, cast:GetPosition())
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

	-- need to set the hitposition somewhere else, cant use cast data
	local attackPosition = attackData.HitPosition

	if not attackPosition then
		attackPosition = attackData.Cast:GetPosition() :: Vector3
	end
	assert(attackPosition, "Could not get a server attack position.")
	local attackDiff = (attackPosition - localTargetPosition).Magnitude
	if attackDiff > Config.MaximumAllowedLatencyVariation * attackData.Speed then
		warn(
			player,
			"Had too large of a difference between bullet positions: ",
			attackDiff,
			Config.MaximumAllowedLatencyVariation * attackData.Speed,
			attackPosition,
			localTargetPosition
		)
		return
	end

	if not victimCombatPlayer:CanTakeDamage() then
		return
	end
	if attackData.Data.AbilityType == Enums.AbilityType.Attack then
		combatPlayer:ChargeSuper(1)
	end
	-- Don't send the victimCombatPlayer because we'd be sending too much information over the network pointlessly.
	combatPlayer:DealDamage(attackData.Data.Damage, victimCharacter)

	-- Update Data
	DataService.GetProfileData(player):Then(function(data: DataService.ProfileData)
		data.Stats.DamageDealt += attackData.Data.Damage
	end)

	local beforeState = victimCombatPlayer:GetState()
	victimCombatPlayer:TakeDamage(attackData.Data.Damage) -- Will update state to dead if this kills
	local afterState = victimCombatPlayer:GetState()

	local died = victimCombatPlayer:GetState() == CombatPlayer.StateEnum.Dead and beforeState ~= afterState

	local victimPlayer = Players:GetPlayerFromCharacter(victimCharacter)
	if died then
		Net:Fire(player, "CombatKill", victimCombatPlayer)
		if victimPlayer and died then
			local data = {
				Killer = player,
				Victim = victimPlayer,
				Attack = attackData.Data,
			} :: KillData
			CombatService.KillSignal:Fire(data)
			Net:FireAll("PlayerKill", data)
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

function CombatService:GetCombatPlayerForCharacter(character: Model): CombatPlayer.CombatPlayer?
	return CombatPlayerData[character]
end

function CombatService:InitializeNameTag(character: Model, combatPlayer: CombatPlayer.CombatPlayer, player: Player?)
	self = self :: CombatService

	local nameTag = NameTag.Init(character, combatPlayer, player)
	task.spawn(function()
		while character and CombatPlayerData[character] do
			task.wait()
		end
		nameTag:Destroy()
	end)
end

function CombatService:EnterPlayerCombat(player: Player, heroName: string, newCFrame: CFrame?)
	self = self :: CombatService

	PlayersInCombat[player] = heroName
	return self:SpawnCharacter(player, newCFrame)
end

function CombatService:ExitPlayerCombat(player: Player)
	self = self :: CombatService

	PlayersInCombat[player] = nil
	if player.Character and CombatPlayerData[player.Character] then
		CombatPlayerData[player.Character]:Destroy()
		CombatPlayerData[player.Character] = nil
	end
	self:SpawnCharacter(player)
end

function CombatService:SetupCombatPlayer(player: Player, heroName: string)
	self = self :: CombatService
	local char = assert(player.Character, "no character")
	local humanoid = assert(char:FindFirstChildOfClass("Humanoid"), "no humanoid")

	local combatPlayer = CombatPlayer.new(heroName, humanoid, player)
	CombatPlayerData[char] = combatPlayer

	print("Asking client to initialize combat player")
	Net:Fire(player, "CombatPlayerInitialize", heroName)

	self:InitializeNameTag(char, combatPlayer, player)
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

	return Red.Promise.new(function(resolve, reject)
		local loadTimeout = task.delay(5, reject, "Character was not spawned after 5 seconds.")
		player.CharacterAdded:Once(function(char)
			coroutine.close(loadTimeout)

			print(player, "Character was added, processing")

			task.wait() -- Let it get parented to workspace
			print(player, "Character initialized to workspace")

			if PlayersInCombat[player] then
				self:SetupCombatPlayer(player, PlayersInCombat[player])
			end

			local humanoid = char:FindFirstChild("Humanoid") :: Humanoid
			assert(humanoid, "Humanoid was not found during character spawning.").Died:Once(function()
				-- This shouldn't cause a memory leak if the character is respawned instead of dying, as humanoid being destroyed will disconnect thi
				task.wait(3)
				if PlayersInCombat[player] then
					self:ExitPlayerCombat(player)
				else
					self:SpawnCharacter(player)
				end
			end)

			if spawnCFrame then
				char:PivotTo(spawnCFrame)
			end
			resolve(char)
		end)
		print(player, "Loading char")

		local heroName = PlayersInCombat[player] or ""

		self:LoadCharacterWithModel(player, ReplicatedStorage.Assets.CharacterModels:FindFirstChild(heroName))
	end)
end

-- We must remove the starterguis from startergui so they do not get parented when the player spawns,
-- because we do this parenting ourselves, players end up with two copies of the gui which breaks scripts.
local starterGuis = StarterGui:GetChildren()
for _, gui in pairs(starterGuis) do
	gui.Parent = script
end

function CombatService:LoadPlayerGuis(player: Player)
	-- This function is necessary as startergui is only cloned into playergui when character spawns, but we take control of character spawning.
	for _, gui in pairs(starterGuis) do
		gui:Clone().Parent = player.PlayerGui
	end
end

function CombatService:PlayerAdded(player: Player)
	self = self :: CombatService

	self:LoadPlayerGuis(player)

	-- if RunService:IsStudio() then
	-- 	PlayersInCombat[player] = "Fabio"
	-- end

	LoadedService.PromiseLoad(player):Then(function(resolve)
		print("Resolved:", resolve)
		if resolve then
			self:SpawnCharacter(player)
		end
	end, function(reject)
		print(reject)
		player:Kick("Failed to load: " .. reject)
	end)
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

	Net:On("Attack", handleAttack)
	Net:On("Super", handleSuper)
	Net:On("Hit", handleClientHit)

	for _, v in pairs(workspace:GetChildren()) do
		if v.Name == "Rig" then
			local combatPlayer = CombatPlayer.new("Fabio", v.Humanoid)
			CombatPlayerData[v] = combatPlayer
			self:InitializeNameTag(v, combatPlayer)
		end
	end
end

CombatService.KillSignal = Red.Signal.new()

export type KillData = {
	Killer: Player,
	Victim: Player,
	Attack: HeroData.AttackData | HeroData.SuperData,
}
export type CombatService = typeof(CombatService)

CombatService:Initialize()
return CombatService
