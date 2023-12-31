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
local ServerScriptService = game:GetService("ServerScriptService")
local StarterGui = game:GetService("StarterGui")

local FieldEffect = require(script.FieldEffect)
local DataService = require(script.Parent.DataService)
local ItemService = require(script.Parent.ItemService)
local LoadCharacterService = require(script.Parent.LoadCharacterService)
local SoundService = require(script.Parent.SoundService)

local AttackLogic = require(ReplicatedStorage.Modules.Shared.Combat.AttackLogic)
local CombatPlayer = require(ReplicatedStorage.Modules.Shared.Combat.CombatPlayer)
local Config = require(ReplicatedStorage.Modules.Shared.Combat.Config)
local Enums = require(ReplicatedStorage.Modules.Shared.Combat.Enums)
local HeroDetails = require(ReplicatedStorage.Modules.Shared.HeroDetails)
local ServerConfig = require(ReplicatedStorage.Modules.Shared.ServerConfig)
local Types = require(ReplicatedStorage.Modules.Shared.Types)
local Future = require(ReplicatedStorage.Packages.Future)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Skills = require(ReplicatedStorage.Modules.Shared.Combat.Modifiers.Skills)
local Modifiers = require(ReplicatedStorage.Modules.Shared.Combat.Modifiers)
local ModifierCollection = require(ReplicatedStorage.Modules.Shared.Combat.Modifiers.ModifierCollection)

local AttackFunction = require(ReplicatedStorage.Events.Combat.AttackFunction)

local AimEvent = require(ReplicatedStorage.Events.Combat.AimEvent):Server()
local FirePelletEvent = require(ReplicatedStorage.Events.Combat.FirePelletEvent):Server()
local SkillAbilityEvent = require(ReplicatedStorage.Events.Combat.SkillAbilityEvent):Server()
local HitEvent = require(ReplicatedStorage.Events.Combat.HitEvent):Server()
local HitMultipleEvent = require(ReplicatedStorage.Events.Combat.HitMultipleEvent):Server()
local DamagedEvent = require(ReplicatedStorage.Events.Combat.DamagedEvent):Server()
local CombatPlayerInitializeEvent = require(ReplicatedStorage.Events.Combat.CombatPlayerInitializeEvent):Server()
local PlayerKilledEvent = require(ReplicatedStorage.Events.Combat.PlayerKilledEvent):Server()
local ReplicateAttackEvent = require(ReplicatedStorage.Events.Combat.ReplicateAttackEvent):Server()

-- Quest signals
CombatService.KillSignal = Signal()
CombatService.DamageSignal = Signal()
CombatService.SkillSignal = Signal()
CombatService.SuperSignal = Signal()

type PlayerCombatDetails = {
	HeroName: string,
	SkinName: string,
	Modifiers: { string },
	Talent: string,
	Skill: string,
}

-- Only for players currently fighting.
local CombatPlayerData: { [Model]: CombatPlayer.CombatPlayer } = {}
local PlayersInCombat: { [Player]: PlayerCombatDetails } = {}

local function replicateAttack(
	player: Player,
	origin: CFrame,
	combatPlayer: CombatPlayer.CombatPlayer,
	attackData: Types.AbilityData,
	localAttackDetails: AttackLogic.AttackDetails,
	chained: boolean?
)
	local character = assert(player.Character, "character does not exist")
	local HRP = character:FindFirstChild("HumanoidRootPart") :: BasePart
	if (HRP.Position - origin.Position).Magnitude > Config.MaximumPlayerPositionDifference and not chained then
		warn(player, "fired from a position too far from their server position")
		return
	end

	print("registering1")
	local attackLogicCombatPlayer = if chained then nil else combatPlayer
	local heroName = combatPlayer.heroData.Name

	if attackData.Data.AttackType == "Shotgun" then
		local localAttackDetails = localAttackDetails :: AttackLogic.ShotgunDetails

		local attackDetails = AttackLogic.MakeAttack(
			attackLogicCombatPlayer,
			origin,
			attackData,
			nil,
			localAttackDetails.seed
		) :: AttackLogic.ShotgunDetails

		local delayTime = attackData.Data.TimeBetweenShots or 0

		for index, pellet in pairs(attackDetails.pellets) do
			if pellet.id ~= localAttackDetails.pellets[index].id then
				warn(player, "mismatched attack ids, could be cheating.")
				return
			end
			combatPlayer:RegisterBullet(pellet.id, pellet.CFrame, pellet.speed, attackData, (index - 1) * delayTime)
		end

		ReplicateAttackEvent:FireAll(player, heroName, attackData, origin, attackDetails)
	elseif attackData.Data.AttackType == "Shot" then
		local localAttackDetails = localAttackDetails :: AttackLogic.ShotDetails

		local attackDetails =
			AttackLogic.MakeAttack(attackLogicCombatPlayer, origin, attackData) :: AttackLogic.ShotDetails

		if localAttackDetails.id ~= attackDetails.id then
			warn(player, "mismatched attack ids, could be cheating.")
			return
		end

		combatPlayer:RegisterBullet(attackDetails.id, attackDetails.origin, attackData.Data.ProjectileSpeed, attackData)

		ReplicateAttackEvent:FireAll(player, heroName, attackData, origin, attackDetails)
	elseif attackData.Data.AttackType == "Arced" then
		local localAttackDetails = localAttackDetails :: AttackLogic.ArcDetails

		local attackDetails = AttackLogic.MakeAttack(
			attackLogicCombatPlayer,
			origin,
			attackData,
			localAttackDetails.target
		) :: AttackLogic.ArcDetails

		if localAttackDetails.id ~= attackDetails.id then
			warn(player, "mismatched attack ids, could be cheating.")
			return
		end

		combatPlayer:RegisterBullet(attackDetails.id, attackDetails.origin, attackData.Data.ProjectileSpeed, attackData)

		ReplicateAttackEvent:FireAll(player, heroName, attackData, origin, attackDetails)
	elseif attackData.Data.AttackType == "Field" then
		local localAttackDetails = localAttackDetails :: AttackLogic.FieldDetails

		local attackDetails = AttackLogic.MakeAttack(
			attackLogicCombatPlayer,
			origin,
			attackData,
			if not chained then localAttackDetails.origin.Position else nil
		) :: AttackLogic.FieldDetails

		FieldEffect.new(
			attackDetails.origin.Position,
			attackData,
			combatPlayer,
			CombatPlayerData,
			function(victim, multiplier)
				local character = victim.character
				local HRP = character:FindFirstChild("HumanoidRootPart") :: BasePart
				if not HRP then
					return
				end

				processHit(player, HRP, nil, combatPlayer, character, victim, attackData, nil, multiplier)
			end,
			function(victim)
				return victim ~= combatPlayer
			end
		)

		if not chained then
			ReplicateAttackEvent:FireAll(player, heroName, attackData, origin, attackDetails)
		end
	else
		warn("Invalid attack received: ", attackData.Data.AttackType)
	end
end

local function handleAttack(player: Player, origin: CFrame, localAttackDetails): number
	if not player.Character then
		warn(player, "Tried to attack without a character!")
		return 0
	end
	local combatPlayer = CombatPlayerData[player.Character]
	if not combatPlayer then
		warn(player, "Tried to attack without a combatplayer!")
		return 0
	end

	if not combatPlayer:CanAttack() then
		warn(
			player,
			"Tried to attack when they couldn't",
			combatPlayer.ammo,
			os.clock() - combatPlayer.lastAttackTime,
			combatPlayer.reloadSpeed,
			combatPlayer:GetState(),
			combatPlayer:AbilitiesEnabled()
		)
		return combatPlayer.attackId
	end

	local attackData = combatPlayer.heroData.Attack :: Types.AttackData

	replicateAttack(player, origin, combatPlayer, attackData, localAttackDetails)

	SoundService:PlayHeroAttack(player, combatPlayer.heroData, false, player.Character)

	combatPlayer:Attack()

	return combatPlayer.attackId
end

-- For handling delayed shots
function handleBulletFire(player: Player, attackId: number, position: Vector3)
	if not player.Character then
		warn("Tried to bullet fire without a character!")
		return
	end

	local combatPlayer = CombatPlayerData[player.Character]
	if not combatPlayer then
		warn("Tried to bullet fire without a combatplayer!")
		return
	end

	local HRP = combatPlayer.HRP
	if not HRP then
		warn("Tried to process new bullet fire on combatplayer without an HRP.")
		return
	end

	if (HRP.Position - position).Magnitude > Config.MaximumPlayerPositionDifference then
		warn("Tried to update bullet with position too far away")
		return
	end

	local attack = combatPlayer.attacks[attackId]
	if not attack then
		warn("Tried to update a non-existing or non-pending attack.")
		return
	end

	if not attack.Pending then
		warn("Tried to update a non-pending attack")
		return
	end

	if math.abs(os.clock() - attack.FiredTime) > Config.MaximumAllowedLatencyVariation then
		warn("Tried to update an attack too early or too late")
		return
	end

	attack.FiredCFrame = CFrame.new(position) * attack.FiredCFrame.Rotation
	attack.Pending = false
end

local function handleSuper(player: Player, origin: CFrame, localAttackDetails)
	if not player.Character then
		warn(player, "Tried to super without a character!")
		return 0
	end

	local combatPlayer = CombatPlayerData[player.Character]
	if not combatPlayer then
		return 0
	end

	if not combatPlayer:CanSuperAttack() then
		warn(player, "Tried to super when they couldn't")
		return combatPlayer.attackId
	end
	local superData = combatPlayer.heroData.Super :: Types.SuperData

	replicateAttack(player, origin, combatPlayer, superData, localAttackDetails)

	SoundService:PlayHeroAttack(player, combatPlayer.heroData, true, player.Character)

	combatPlayer:SuperAttack()
	CombatService.SuperSignal:Fire(player)

	return combatPlayer.attackId
end

function handleAttackSkill(player: Player, origin: CFrame, localAttackDetails)
	if not player.Character then
		warn(player, "Tried to super without a character!")
		return 0
	end

	local combatPlayer = CombatPlayerData[player.Character]
	if not combatPlayer then
		return 0
	end

	if not combatPlayer:CanUseSkill() then
		warn(player, "Tried to use skill when they couldn't")
		return combatPlayer.attackId
	end
	local skillData = combatPlayer.skill.AttackData
	if not skillData then
		warn(player, "Tried to attack with a skill without an attack data:", combatPlayer.skill.Name)
		return combatPlayer.attackId
	end

	replicateAttack(player, origin, combatPlayer, skillData, localAttackDetails)

	SoundService:PlayHeroAttack(player, combatPlayer.heroData, true, player.Character)

	combatPlayer:UseSkill()

	CombatService.SkillSignal:Fire(player, combatPlayer.skill)

	return combatPlayer.attackId
end

function handleAbilitySkill(player: Player)
	if not player.Character then
		return
	end

	local combatPlayer = CombatPlayerData[player.Character]
	if not combatPlayer then
		return
	end

	if not combatPlayer:CanUseSkill() then
		warn("Tried to use a skill when it could not be used.")
		return
	end

	CombatService.SkillSignal:Fire(player, combatPlayer.skill)
	combatPlayer:UseSkill()
end

function handleAim(player: Player, aim: string?)
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
	player: Player?,
	target: BasePart,
	localTargetPosition: Vector3?,
	combatPlayer: CombatPlayer.CombatPlayer,
	victimCharacter: Model,
	victimCombatPlayer: CombatPlayer.CombatPlayer,
	attackDetails: Types.AbilityData,
	reflected: number?, -- Used for reflect skill
	multiplier: number? -- Used for DPS effect on fields
)
	if
		localTargetPosition
		and (target.Position - localTargetPosition).Magnitude > Config.MaximumPlayerPositionDifference
	then
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
	if attackDetails.AbilityType == Enums.AbilityType.Attack and victimCombatPlayer:CanGiveSuperCharge() then
		combatPlayer:ChargeSuper(1)
	end
	-- Don't send the victimCombatPlayer because we'd be sending too much information over the network pointlessly.
	local beforeState = victimCombatPlayer:GetState()

	local actualDamage
	if reflected then
		-- We need to get the damage of the original attack if it was reflected
		local damage = CombatPlayer.GetDamageBetween(victimCombatPlayer, combatPlayer, attackDetails, multiplier)
			* reflected
		actualDamage = victimCombatPlayer:TakeDamage(damage) -- Will update state to dead if this kills
	else
		local damage = CombatPlayer.GetDamageBetween(combatPlayer, victimCombatPlayer, attackDetails, multiplier)
		actualDamage = victimCombatPlayer:TakeDamage(damage) -- Will update state to dead if this kills
	end

	combatPlayer:DealDamage(actualDamage, victimCharacter)
	CombatService.DamageSignal:Fire(player, actualDamage)

	local afterState = victimCombatPlayer:GetState()

	DamagedEvent:FireAll(victimCharacter, actualDamage)

	if not reflected and victimCombatPlayer:GetStatusEffect("Reflect") then
		local HRP = combatPlayer.character:FindFirstChild("HumanoidRootPart") :: BasePart
		if HRP then
			local reflectValues = assert(victimCombatPlayer:GetStatusEffect("Reflect"))

			-- Since reflection also reduces the damage taken, we need to adjust the multiplier so it is based off of the original damage value
			local reflectMultiplier = reflectValues[1] / reflectValues[2]

			processHit(
				victimCombatPlayer.player,
				HRP :: BasePart,
				HRP.Position,
				victimCombatPlayer,
				combatPlayer.character,
				combatPlayer,
				attackDetails,
				reflectMultiplier
			)
		end
	end

	-- Update Data
	if player then
		DataService.WritePrivateData(player):After(function(data)
			if data then
				data.Stats.DamageDealt += actualDamage
			end
		end)
	end

	combatPlayer.modifiers.OnHit(combatPlayer, victimCombatPlayer, attackDetails)
	victimCombatPlayer.modifiers.OnReceiveHit(victimCombatPlayer, combatPlayer, attackDetails)

	local died = victimCombatPlayer:GetState() == "Dead" and beforeState ~= afterState

	local victimPlayer = Players:GetPlayerFromCharacter(victimCharacter)
	if died then
		if victimPlayer and died then
			local data = {
				Killer = player,
				Victim = victimPlayer,
				Attack = attackDetails,
			} :: Types.KillData
			CombatService:HandlePlayerDeath(victimPlayer, data)
		end
		local victimHRP = (
			victimCharacter:FindFirstChild("box") or victimCharacter:FindFirstChild("HumanoidRootPart")
		) :: BasePart
		ItemService.ExplodeBoosters(victimHRP.Position, victimCombatPlayer.boosterCount + 1)
	end
end

local function handleClientHit(player: Player, target: BasePart?, localTargetPosition: Vector3, attackId: number)
	if not player.Character or not localTargetPosition or not attackId then
		return
	end
	local combatPlayer = CombatPlayerData[player.Character]
	if not combatPlayer then
		return
	end

	local attackDetails = combatPlayer.attacks[attackId]
	if not attackDetails then
		warn("Invalid attack id for hit given", attackId, combatPlayer.attacks)
		return
	end
	if attackDetails.Pending then
		warn("Tried to hit before bullet was fired.")
		return
	end

	combatPlayer.attacks[attackId] = nil

	-- flatten everything because the target can be at a different height to the initial firing position
	local flatVector = Vector3.new(1, 0, 1)

	local serverAttackRay =
		Ray.new(attackDetails.FiredCFrame.Position * flatVector, attackDetails.FiredCFrame.LookVector * flatVector)
	local rayDiff = serverAttackRay.Unit:Distance(localTargetPosition * flatVector)

	-- Accounts for NaN case
	if rayDiff ~= rayDiff then
		rayDiff = 0
	end

	-- Makes sure the trajectory of bullet doesn't change between fire and hit event.
	if rayDiff > 5 then
		warn(player, "Almost certainly exploiting, mismatched fired and hit bullet trajectories.")
		return
	end

	if attackDetails.Data.Data.Chain then
		local chainData: any = table.clone(attackDetails.Data)
		chainData.Data = chainData.Data.Chain

		replicateAttack(
			player,
			CFrame.new(localTargetPosition),
			combatPlayer,
			chainData,
			AttackLogic.MakeAttack(nil, CFrame.new(localTargetPosition), chainData),
			true
		)
	end

	if not target then
		return
	end

	local victimCharacter = CombatPlayer.GetAncestorWhichIsACombatPlayer(target)
	if not victimCharacter then
		return
	end

	local victimCombatPlayer = CombatPlayerData[victimCharacter]

	processHit(
		player,
		target,
		localTargetPosition,
		combatPlayer,
		victimCharacter,
		victimCombatPlayer,
		attackDetails.Data
	)
end

function handleClientExplosionHit(player: Player, hitList: Types.HitList, attackId: number, explosionCentre: Vector3)
	if not player.Character then
		return
	end
	local combatPlayer = CombatPlayerData[player.Character]
	if not combatPlayer then
		warn("combatplayer not found")
		return
	end

	local attackDetails = combatPlayer.attacks[attackId]
	if not attackDetails then
		warn("attack details not found", attackId, combatPlayer.attacks)
		return
	end
	combatPlayer.attacks[attackId] = nil

	if attackDetails.Pending then
		warn("Tried to hit before bullet was fired.")
		return
	end

	-- flatten everything because the target can be at a different height to the initial firing position
	local flatVector = Vector3.new(1, 0, 1)
	local serverAttackRay =
		Ray.new(attackDetails.FiredCFrame.Position * flatVector, attackDetails.FiredCFrame.LookVector * flatVector)
	local rayDiff = serverAttackRay.Unit:Distance(explosionCentre * flatVector)

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
		local data = attackDetails.Data
		assert(data.Data.AttackType == "Arced")
		if ((hitData.position - explosionCentre) * Vector3.new(1, 0, 1)).Magnitude > data.Data.Radius * 1.1 then
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
			attackDetails.Data
		)
	end
end

function CombatService:GetAllCombatPlayers()
	local out = {}
	for model, combatPlayer in pairs(CombatPlayerData) do
		table.insert(out, combatPlayer)
	end
	return out
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

function CombatService:EnterPlayerCombat(player: Player, newCFrame: CFrame?)
	self = self :: CombatService
	return Future.new(function()
		print("Entering combat", player)
		if PlayersInCombat[player] then
			CombatService:ExitPlayerCombat(player):Await()
		end

		local data = DataService.ReadPrivateData(player):Await()
		local dataPublic = DataService.WritePublicData(player):Await()
		if not data or not dataPublic then
			return nil :: boolean?, nil :: Model?
		end

		local hero = data.SelectedHero

		local modifiers = data.OwnedHeroes[hero].SelectedModifiers
		local talent = data.OwnedHeroes[hero].SelectedTalent
		local skill = data.OwnedHeroes[hero].SelectedSkill

		PlayersInCombat[player] = {
			HeroName = hero,
			SkinName = data.OwnedHeroes[hero].SelectedSkin,
			Modifiers = modifiers,
			Talent = talent,
			Skill = skill,
		}

		dataPublic.InCombat = true
		DataService.WaitForReplication():Await()

		self:SpawnCharacter(player, newCFrame):Await()
		return true
	end)
end

function CombatService:ExitPlayerCombat(player: Player)
	self = self :: CombatService

	return Future.new(function()
		local publicData = DataService.WritePublicData(player):Await()
		if publicData then
			publicData.InCombat = false
		end

		PlayersInCombat[player] = nil
		if player.Character and CombatPlayerData[player.Character] then
			CombatPlayerData[player.Character]:Destroy()
			CombatPlayerData[player.Character] = nil
		end

		-- Must wait for replication, otherwise the client will still think the player is in combat
		-- when the character loads
		DataService.WaitForReplication():Await()
		local char: Model = self:SpawnCharacter(player):Await()

		return char
	end)
end

function CombatService:HandlePlayerDeath(player: Player, data: Types.KillData?)
	if data then
		CombatService.KillSignal:Fire(data)
		PlayerKilledEvent:FireAll(data)
	else
		local data = { Victim = player }
		CombatService.KillSignal:Fire(data)
		PlayerKilledEvent:FireAll(data)
	end

	task.delay(1, function()
		CombatService:ExitPlayerCombat(player)
	end)
end

function CombatService:SetupCombatPlayer(player: Player, details: PlayerCombatDetails)
	self = self :: CombatService
	print("Setting up", player.Name, "as", details.HeroName)
	local char = assert(player.Character, "no character")

	local modifierStrings = { details.Modifiers[1], details.Modifiers[2], details.Talent }
	local modifiers = { Modifiers[details.Modifiers[1]], Modifiers[details.Modifiers[2]], Modifiers[details.Talent] }

	local combatPlayer = CombatPlayer.new(
		details.HeroName,
		char,
		ModifierCollection.new(modifiers),
		player,
		Skills[details.Skill]
	) :: CombatPlayer.CombatPlayer
	CombatPlayerData[char] = combatPlayer

	print("Asking client to initialize combat player")
	CombatPlayerInitializeEvent:Fire(player, details.HeroName, modifierStrings, details.Skill)

	return combatPlayer
end

function CombatService:SpawnCharacter(player: Player, spawnCFrame: CFrame?)
	self = self :: CombatService
	print("Spawning Character", player)

	return Future.new(function()
		local details = PlayersInCombat[player]
		local heroModel = if details
			then HeroDetails.GetModelFromName(details.HeroName, details.SkinName):Clone()
			else nil

		print(player, "Loading character...")
		local character = LoadCharacterService.SpawnCharacter(player, spawnCFrame, heroModel):Await()
		print(player, "Character loaded")

		local humanoid = assert(
			character:FindFirstChild("Humanoid"),
			"Humanoid was not found during character spawning."
		) :: Humanoid

		local combatPlayer
		if PlayersInCombat[player] then
			combatPlayer = self:SetupCombatPlayer(player, PlayersInCombat[player])
		else
			character:ScaleTo(ServerConfig.LobbyPlayerScale)
			humanoid.WalkSpeed = ServerConfig.LobbyMovementSpeed
			humanoid.JumpPower = ServerConfig.LobbyJumpPower -- Scaled jump power (75) is too high and looks weird
		end

		-- This shouldn't cause a memory leak if the character is respawned instead of dying, as humanoid being destroyed will disconnect thi
		humanoid.Died:Once(function()
			if not combatPlayer or (combatPlayer and not combatPlayer:IsDead()) then
				self:HandlePlayerDeath(player)
				if combatPlayer then
					combatPlayer:Kill()
				end
			end
		end)

		return character
	end)
end

-- We must remove the starterguis from startergui so they do not get parented when the player spawns,
-- because we do this parenting ourselves, players end up with two copies of the gui which breaks scripts.
local starterGuis = StarterGui:GetChildren()
for _, gui in pairs(starterGuis) do
	gui.Parent = script
end

function CombatService.RegisterChest(chest: Model)
	local lid = chest:FindFirstChild("lid") :: BasePart

	local combatPlayer = CombatPlayer.newChest(2000, chest)
	CombatPlayerData[chest] = combatPlayer

	combatPlayer.DiedSignal:Connect(function()
		combatPlayer:Destroy()
		lid.Anchored = false
		lid:SetNetworkOwner(nil)
		-- lid.CanCollide = false
		-- lid.CanTouch = false
		-- lid.CanQuery = false

		lid.AssemblyLinearVelocity = (
			CFrame.Angles(math.rad(90), 0, Random.new():NextNumber() * 2 * math.pi)
			* CFrame.Angles(-math.rad(30), 0, 0)
		).LookVector * 150

		task.wait(1)
		chest:Destroy()
	end)
end

function CombatService:ForceUpdateCombatPlayers()
	for character, combatPlayer in pairs(CombatPlayerData) do
		combatPlayer:Update()
	end
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

	if DataService.PlayerLoaded(player):Await() then
		if
			(RunService:IsStudio() and ServerScriptService:GetAttribute("combat"))
			or ServerScriptService:GetAttribute("livecombat")
		then
			local hero = ServerScriptService:GetAttribute("hero") or "Taz"
			local skin = ServerScriptService:GetAttribute("skin")
			local modifiers = {
				ServerScriptService:GetAttribute("modifier1") or "",
				ServerScriptService:GetAttribute("modifier2") or "",
			}
			if not skin or skin == "" then
				skin = HeroDetails.HeroDetails[hero].DefaultSkin
			end

			PlayersInCombat[player] = {
				HeroName = hero,
				SkinName = skin,
				Modifiers = modifiers,
				Talent = ServerScriptService:GetAttribute("talent") or "",
				Skill = ServerScriptService:GetAttribute("skill") or "",
			}

			local data = assert(DataService.WritePublicData(player):Await(), "In studio, doesnt matter.")
			data.InCombat = true
		end

		self:SpawnCharacter(player):Await()

		-- ensure nametags appear for combatplayers that already existed
		CombatService:ForceUpdateCombatPlayers()
	end
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

	AttackFunction:SetCallback(
		function(player: Player, type: string, origin: CFrame, details: AttackLogic.AttackDetails)
			if type == "Super" then
				return handleSuper(player, origin, details)
			elseif type == "Attack" then
				return handleAttack(player, origin, details)
			elseif type == "Skill" then
				return handleAttackSkill(player, origin, details)
			else
				warn("Invalid type passed", type)
			end
			return 0
		end
	)
	HitEvent:On(handleClientHit)
	HitMultipleEvent:On(handleClientExplosionHit)
	AimEvent:On(handleAim)
	SkillAbilityEvent:On(handleAbilitySkill)
	FirePelletEvent:On(handleBulletFire)

	for _, v in pairs(workspace:GetChildren()) do
		if v.Name == "TestDummy" and v:IsA("Model") then
			local HRP = v:FindFirstChild("HumanoidRootPart") :: BasePart
			HRP:SetNetworkOwner(nil)
			print("Initializing test dummy")
			local combatPlayer =
				CombatPlayer.new("Frankie", v, ModifierCollection.new({ Modifiers.Default })) :: CombatPlayer.CombatPlayer
			CombatPlayerData[v] = combatPlayer
			combatPlayer.DiedSignal:Connect(function()
				task.wait(3)
				v:Destroy()
				CombatPlayerData[v] = nil
			end)
		elseif v.Name == "Chest" then
			CombatService.RegisterChest(v)
		end
	end

	ItemService.Initialize(CombatPlayerData)
end

export type CombatService = typeof(CombatService)

CombatService:Initialize()
return CombatService
