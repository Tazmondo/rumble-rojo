--!strict
--!nolint LocalShadow
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
local HeroData = require(ReplicatedStorage.Modules.Shared.Combat.HeroData)
local Enums = require(ReplicatedStorage.Modules.Shared.Combat.Enums)
local NameTag = require(ReplicatedStorage.Modules.Shared.Combat.NameTag)
local Red = require(ReplicatedStorage.Packages.Red)
local Net = Red.Server("game", { "CombatPlayerInitialize", "CombatKill", "PlayerKill" })

-- Only for players currently fighting.
local CombatPlayerData: { [Model]: CombatPlayer.CombatPlayer } = {}
local PlayersInCombat: { [Player]: string } = {}

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
	attackData: HeroData.AbilityData,
	localAttackDetails: AttackLogic.AttackDetails
)
	local character = assert(player.Character, "character does not exist")
	local HRP = character:FindFirstChild("HumanoidRootPart") :: BasePart
	if (HRP.Position - origin.Position).Magnitude > Config.MaximumPlayerPositionDifference then
		warn(player, "fired from a position too far from their server position")
		return
	end

	print("registering1")

	if attackData.AttackType == "Shotgun" then
		local localAttackDetails = localAttackDetails :: AttackLogic.ShotgunDetails

		local attackDetails =
			AttackLogic.MakeAttack(combatPlayer, origin, attackData, nil, localAttackDetails.seed) :: AttackLogic.ShotgunDetails

		for index, pellet in pairs(attackDetails.pellets) do
			if pellet.id ~= localAttackDetails.pellets[index].id then
				warn(player, "mismatched attack ids, could be cheating.")
				return
			end
			combatPlayer:RegisterBullet(pellet.id, pellet.CFrame, pellet.speed, attackData)
		end

		Net:FireAll("Attack", player, attackData, origin, attackDetails)
	elseif attackData.AttackType == "Shot" then
		local localAttackDetails = localAttackDetails :: AttackLogic.ShotDetails

		local attackDetails = AttackLogic.MakeAttack(combatPlayer, origin, attackData) :: AttackLogic.ShotDetails

		if localAttackDetails.id ~= attackDetails.id then
			warn(player, "mismatched attack ids, could be cheating.")
			return
		end

		combatPlayer:RegisterBullet(
			localAttackDetails.id,
			localAttackDetails.origin,
			attackData.ProjectileSpeed,
			attackData
		)

		Net:FireAll("Attack", player, attackData, origin, attackDetails)
	elseif attackData.AttackType == "Arced" then
		local localAttackDetails = localAttackDetails :: AttackLogic.ArcDetails

		local attackDetails =
			AttackLogic.MakeAttack(combatPlayer, origin, attackData, localAttackDetails.target) :: AttackLogic.ArcDetails

		if localAttackDetails.id ~= attackDetails.id then
			warn(player, "mismatched attack ids, could be cheating.")
			return
		end

		combatPlayer:RegisterBullet(
			localAttackDetails.id,
			localAttackDetails.origin,
			attackData.ProjectileSpeed,
			attackData
		)

		print("registered arc", localAttackDetails.id)

		Net:FireAll("Attack", player, attackData, origin, attackDetails)
	end
end

local function handleAttack(player: Player, origin: CFrame, localAttackDetails): number
	if not player.Character then
		warn(player, "Tried to attack without a character!")
		return 0
	end
	local combatPlayer = CombatPlayerData[player.Character]
	if not combatPlayer or not combatPlayer:CanAttack() then
		return 0
	end

	if not combatPlayer:CanAttack() then
		return combatPlayer.attackId
	end

	local attackData = combatPlayer.heroData.Attack :: HeroData.AttackData

	replicateAttack(player, origin, combatPlayer, attackData, localAttackDetails)

	SoundService:PlayAttack(player, attackData.Name, player.Character)

	combatPlayer:Attack()

	return combatPlayer.attackId
end

local function handleSuper(player: Player, origin: CFrame, localAttackDetails)
	if not player.Character then
		warn(player, "Tried to super without a character!")
		return 0
	end

	local combatPlayer = CombatPlayerData[player.Character]
	if not combatPlayer or not combatPlayer:CanSuperAttack() then
		return 0
	end

	if not combatPlayer:CanSuperAttack() then
		return combatPlayer.attackId
	end
	local superData = combatPlayer.heroData.Super :: HeroData.SuperData

	replicateAttack(player, origin, combatPlayer, superData, localAttackDetails)

	SoundService:PlayAttack(player, superData.Name, player.Character)

	combatPlayer:SuperAttack()

	return combatPlayer.attackId
end

function handleAim(player: Player, aim: string)
	if not player.Character then
		return
	end
	local combatPlayer = CombatPlayerData[player.Character]
	if not combatPlayer then
		return
	end
	combatPlayer:SetAiming(aim)
end

function processHit(
	player: Player,
	target: BasePart,
	localTargetPosition: Vector3,
	combatPlayer: CombatPlayer.CombatPlayer,
	victimCharacter: Model,
	victimCombatPlayer: CombatPlayer.CombatPlayer,
	attackDetails: CombatPlayer.Attack
)
	print("processing hit")
	if (target.Position - localTargetPosition).Magnitude > Config.MaximumPlayerPositionDifference then
		warn("Rejected attack, too far away!", player, localTargetPosition, target, target.Position)
		return
	end

	-- UNCOMMENT THIS WHEN WE RUN SERVER-SIDE ATTACK SIMULATIONS AGAIN
	-- I removed this as it was sort of unnecessary and may have caused server lag
	-- will get back to it when i have more time and can properly benchmark it

	-- need to set the hitposition somewhere else, cant use cast data
	-- local attackPosition = attackData.HitPosition

	-- if not attackPosition then
	-- 	attackPosition = attackData.Cast:GetPosition() :: Vector3
	-- end
	-- assert(attackPosition, "Could not get a server attack position.")
	-- local attackDiff = (attackPosition - localTargetPosition).Magnitude
	-- if attackDiff > Config.MaximumAllowedLatencyVariation * attackData.Speed then
	-- 	warn(
	-- 		player,
	-- 		"Had too large of a difference between bullet positions: ",
	-- 		attackDiff,
	-- 		Config.MaximumAllowedLatencyVariation * attackData.Speed,
	-- 		attackPosition,
	-- 		localTargetPosition
	-- 	)
	-- 	return
	-- end

	if not victimCombatPlayer:CanTakeDamage() then
		return
	end
	if attackDetails.Data.AbilityType == Enums.AbilityType.Attack then
		combatPlayer:ChargeSuper(1)
	end
	-- Don't send the victimCombatPlayer because we'd be sending too much information over the network pointlessly.
	combatPlayer:DealDamage(attackDetails.Data.Damage, victimCharacter)

	-- Update Data
	DataService.GetProfileData(player):Then(function(data: DataService.ProfileData)
		data.Stats.DamageDealt += attackDetails.Data.Damage
	end)

	-- Must be cast to any to prevent "generic subtype escaping scope" error whatever that means
	local beforeState = victimCombatPlayer:GetState() :: any
	victimCombatPlayer:TakeDamage(attackDetails.Data.Damage) -- Will update state to dead if this kills
	local afterState = victimCombatPlayer:GetState() :: any

	local died = victimCombatPlayer:GetState() == "Dead" and beforeState ~= afterState

	local victimPlayer = Players:GetPlayerFromCharacter(victimCharacter)
	if died then
		Net:Fire(player, "CombatKill", victimCombatPlayer)
		if victimPlayer and died then
			local data = {
				Killer = player,
				Victim = victimPlayer,
				Attack = attackDetails.Data,
			} :: KillData
			CombatService.KillSignal:Fire(data)
			Net:FireAll("PlayerKill", data)
		end
	end
end

local function handleClientHit(player: Player, target: BasePart, localTargetPosition: Vector3, attackId: number)
	if not player.Character or not target or not localTargetPosition or not attackId then
		return
	end
	local combatPlayer = CombatPlayerData[player.Character]
	if not combatPlayer then
		return
	end

	local attackDetails = combatPlayer.attacks[attackId]
	if not attackDetails then
		return
	end
	combatPlayer.attacks[attackId] = nil

	local victimCharacter = CombatPlayer.GetAncestorWhichIsACombatPlayer(target)
	if not victimCharacter then
		return
	end

	local victimCombatPlayer = CombatPlayerData[victimCharacter]

	local serverAttackRay = Ray.new(attackDetails.FiredCFrame.Position, attackDetails.FiredCFrame.LookVector)
	local rayDiff = serverAttackRay.Unit:Distance(localTargetPosition)

	-- Accounts for NaN case
	if rayDiff ~= rayDiff then
		rayDiff = 0
	end

	-- Makes sure the trajectory of bullet doesn't change between fire and hit event.
	if rayDiff > 5 then
		warn(player, "Almost certainly exploiting, mismatched fired and hit bullet trajectories.")
		return
	end

	processHit(player, target, localTargetPosition, combatPlayer, victimCharacter, victimCombatPlayer, attackDetails)
end

function handleClientExplosionHit(
	player: Player,
	hitList: {
		{
			instance: BasePart,
			position: Vector3,
		}
	},
	attackId: number,
	explosionCentre: Vector3
)
	if not player.Character then
		return
	end
	local combatPlayer = CombatPlayerData[player.Character]
	if not combatPlayer then
		print("combatplayer not found")
		return
	end

	local attackDetails = combatPlayer.attacks[attackId]
	if not attackDetails then
		print("attack details not found", attackId, combatPlayer.attacks)
		return
	end
	combatPlayer.attacks[attackId] = nil

	local serverAttackRay = Ray.new(attackDetails.FiredCFrame.Position, attackDetails.FiredCFrame.LookVector)
	local rayDiff = serverAttackRay.Unit:Distance(explosionCentre)

	-- Accounts for NaN case
	if rayDiff ~= rayDiff then
		rayDiff = 0
	end

	-- Makes sure the trajectory of bullet doesn't change between fire and hit event.
	if rayDiff > 5 then
		warn(player, "Almost certainly exploiting, mismatched fired and hit bullet trajectories.")
		return
	end

	if (explosionCentre - attackDetails.FiredCFrame.Position).Magnitude > attackDetails.Data.Range + 10 then
		warn(player, "Tried to explode at a point outside of the range of the attack. Probably exploiting.")
		return
	end

	for _, hitData in ipairs(hitList) do
		local victimCharacter = CombatPlayer.GetAncestorWhichIsACombatPlayer(hitData.instance)
		if not victimCharacter then
			return
		end

		local victimCombatPlayer = CombatPlayerData[victimCharacter]
		local data = attackDetails.Data :: HeroData.ArcedData & HeroData.AbilityData
		if ((hitData.position - explosionCentre) * Vector3.new(1, 0, 1)).Magnitude > data.Radius * 1.1 then
			warn("Likely exploiting! Hit player was not in explosion radius!", player)
			return
		end

		processHit(
			player,
			hitData.instance,
			hitData.position,
			combatPlayer,
			victimCharacter,
			victimCombatPlayer,
			attackDetails
		)
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
	print("Setting up", player.Name, "as", heroName)
	local char = assert(player.Character, "no character")
	local humanoid = assert(char:FindFirstChildOfClass("Humanoid"), "no humanoid")

	local combatPlayer = CombatPlayer.new(heroName, humanoid, player) :: CombatPlayer.CombatPlayer
	CombatPlayerData[char] = combatPlayer

	self:InitializeNameTag(char, combatPlayer, player)

	print("Asking client to initialize combat player")
	Net:Fire(player, "CombatPlayerInitialize", heroName)
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
		local connection
		local loadTimeout = task.delay(5, function(...)
			connection:Disconnect()
			warn("Character wasn't spawned after 5 seconds")
			reject("Character wasn't spawned after 5 seconds")
		end)

		connection = player.CharacterAdded:Once(function(char)
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
				-- Use moveto so characters never spawn in the ground
				char:MoveTo(spawnCFrame.Position)
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
	-- 	PlayersInCombat[player] = "Taz"
	-- end

	DataService.PromiseLoad(player):Then(function(resolve)
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
	Net:On("HitMultiple", handleClientExplosionHit)
	Net:On("Aim", handleAim)

	for _, v in pairs(workspace:GetChildren()) do
		if v.Name == "Rig" then
			local combatPlayer = CombatPlayer.new("Frankie", v.Humanoid) :: CombatPlayer.CombatPlayer
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
