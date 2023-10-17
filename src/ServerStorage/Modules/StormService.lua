local StormService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Modules.Shared.Combat.Config)
local CombatService = require(script.Parent.CombatService)
local DataService = require(script.Parent.DataService)
local Bin = require(ReplicatedStorage.Packages.Bin)
local Future = require(ReplicatedStorage.Packages.Future)

local StormConfig = Config.Storm

local Add, Remove = Bin()

local lastDamaged: number
local lastProgressed: number
local currentLayer: number
local centre = assert(workspace.Lobby.MapPivotPoint).Position

function DamageLoop()
	Add(RunService.Stepped:Connect(function()
		if
			os.clock() - lastDamaged < StormConfig.DamageDelay
			or os.clock() - lastProgressed < StormConfig.DamageDelay
		then
			return
		end
		lastDamaged = os.clock()
		local combatPlayers = CombatService:GetAllCombatPlayers()
		for i, combatPlayer in ipairs(combatPlayers) do
			if combatPlayer.isObject then
				continue
			end
			local HRP = assert(combatPlayer.character:FindFirstChild("HumanoidRootPart")) :: BasePart
			local position = HRP.Position
			local difference = (position - centre)
				* Vector3.new(1 / StormConfig.BlockSize, 1, 1 / StormConfig.BlockSize)

			-- Since the storm area is a square not a circle, we can't take the magnitude
			local maxDifference = math.max(math.abs(difference.X), math.abs(difference.Z))

			-- Prevent players from not being killed if they somehow get above the map
			local tooHigh = math.abs(difference.Y) > 20

			if (maxDifference > currentLayer - 1 or tooHigh) and combatPlayer:CanTakeDamage() then
				-- Storm damage is forced, so it bypasses any shields
				combatPlayer:TakeDamage(StormConfig.DamageAmount * combatPlayer.maxHealth)
				if combatPlayer:IsDead() and combatPlayer.player then
					CombatService:HandlePlayerDeath(combatPlayer.player)
				end
			end
		end
	end))
end

function ProgressLoop(delay: number)
	Add(RunService.Stepped:Connect(function()
		if os.clock() - lastProgressed < delay then
			return
		end

		lastProgressed = os.clock()
		DataService.GetGameData().Storm.Progress += 1
		currentLayer = math.max(StormConfig.MinLayer, currentLayer - 1)
	end))
end

function StormService.Start(fastMode: boolean)
	return Future.new(function()
		StormService.Destroy():Await()

		lastDamaged = 0
		local startDelay = StormConfig.StartDelay * (if fastMode then 0.75 else 1)
		local progressDelay = StormConfig.ProgressDelay * (if fastMode then 0.75 else 1)

		-- Start outside the range of the map so no players on the map are damaged
		currentLayer = StormConfig.MapLength / 2 + 1

		local data = DataService.GetGameData().Storm

		data.Active = true
		data.Progress = 0

		lastDamaged = os.clock() + startDelay
		lastProgressed = os.clock() + startDelay - progressDelay
		ProgressLoop(progressDelay)
		DamageLoop()
	end)
end

function StormService.Destroy()
	return Future.new(function()
		Remove()
		local data = DataService.GetGameData().Storm

		data.Active = false
		data.Progress = 0
		DataService.WaitForReplication():Await()
	end)
end

return StormService
