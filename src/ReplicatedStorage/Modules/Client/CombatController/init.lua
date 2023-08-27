local CombatController = {}
CombatController.__index = CombatController

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local CombatClient = require(script.CombatClient)
local AttackRenderer = require(script.AttackRenderer)
local FastCast = require(ReplicatedStorage.Modules.Shared.Combat.FastCastRedux)
local FastCastTypes = require(ReplicatedStorage.Modules.Shared.Combat.FastCastRedux.TypeDefinitions)
local HeroData = require(ReplicatedStorage.Modules.Shared.Combat.HeroData)
local Loader = require(ReplicatedStorage.Modules.Shared.Loader)
local Network: typeof(require(ReplicatedStorage.Modules.Shared.Network)) = Loader:LoadModule("Network")

local localPlayer = Players.LocalPlayer

local cachedCasts: { [string]: FastCastTypes.Caster } = {}

local function InitializeCombatClient(heroName)
	-- Can be called before the character has replicated from the server to the client
	if not localPlayer.Character then
		print("Received combat initialise before character loaded, waiting...")
		localPlayer.CharacterAdded:Wait()
		localPlayer.Character:WaitForChild("Humanoid") -- Also need to wait for the character to get populated
	end

	local combatClient = CombatClient.new(heroName)
	localPlayer.CharacterRemoving:Once(function()
		combatClient:Destroy()
	end)
end

local function RayHit(activeCast: FastCastTypes.ActiveCast, result: RaycastResult, velocity: Vector3, bullet: BasePart)
	task.wait()
	bullet:Destroy()
end

function CastTerminating(activeCast: FastCastTypes.ActiveCast)
	local bullet = activeCast.RayInfo.CosmeticBulletObject
	if bullet then
		bullet:Destroy()
	end
end

local function HandleAttackRender(player: Player, attackData: HeroData.AttackData, origin: CFrame)
	-- Don't want to render our own attacks twice
	if player == localPlayer then
		return
	end

	local attackName = attackData.Name
	local cachedCaster = cachedCasts[attackName]
	if not cachedCaster then
		cachedCaster = FastCast.new()
		cachedCasts[attackName] = cachedCaster

		cachedCaster.LengthChanged:Connect(AttackRenderer.GenerateLengthChangedFunction(attackData))
		cachedCaster.RayHit:Connect(RayHit)
		cachedCaster.CastTerminating:Connect(CastTerminating)
	end

	cachedCaster:Fire(
		origin.Position,
		origin.LookVector,
		attackData.ProjectileSpeed,
		AttackRenderer.GetCastBehaviour(attackData, player.Character)
	)
end

function CombatController:Initialize()
	Network:OnClientEvent("CombatPlayer Initialize", InitializeCombatClient)
	Network:OnClientEvent("Attack", HandleAttackRender)
end

return CombatController
