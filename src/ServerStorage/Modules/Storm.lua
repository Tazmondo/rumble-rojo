local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CombatService = require(script.Parent.CombatService)
local Bin = require(ReplicatedStorage.Packages.Bin)
local Spawn = require(ReplicatedStorage.Packages.Spawn)

local Storm = {}
Storm.__index = Storm

local STARTDELAY = 14
local PROGRESSDELAY = 8

-- Damage percent of max hp per second
local DAMAGEAMOUNT = 0.2
local DAMAGEDELAY = 0.75
-- Last layer that storm will reach
local MINLAYER = 3

local MAPLENGTH = 24
local SIDELENGTH = 16

local BLOCKSIZE = 8

local arenaFolder = assert(workspace.Arena)

local stormPartTemplate = ReplicatedStorage.Assets.Storm :: BasePart
local stormFolder = Instance.new("Folder", workspace)
stormFolder.Name = "Storm Folder"

local castParams = RaycastParams.new()
castParams.FilterType = Enum.RaycastFilterType.Include
castParams.FilterDescendantsInstances = { arenaFolder }

function TestPart(position: Vector3)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Transparency = 0.5
	part.Color = Color3.new(1.000000, 0.000000, 0.000000)
	part.Position = position
	part.Size = Vector3.one

	part.Parent = workspace
	-- Debris:AddItem(part, 30)
	return part
end

function _self(map: Model)
	local self = setmetatable({}, Storm)

	local Add, Remove = Bin()
	self.Add = Add
	self.Remove = Remove

	self.map = map
	self.centre = map:GetPivot()

	self.lastDamaged = 0

	self.destroyed = false

	-- Start outside the range of the map so no players on the map are damaged
	self.currentLayer = MAPLENGTH / 2 + 1

	self.layers = {}

	return self
end

-- Should only be called once map is in position!
function Storm.new(map: Model): Storm
	local self = _self(map)

	return self :: Storm
end

function Storm.AddCoordinate(self: Storm, layer: number, i: number, j: number, inverseI: boolean, inverseJ: boolean)
	local iCoefficient = if inverseI then -1 else 1
	local jCoefficient = if inverseJ then -1 else 1

	local coordinate = self.centre.Position
		+ Vector3.new(
			iCoefficient * (i * BLOCKSIZE - (BLOCKSIZE / 2)),
			BLOCKSIZE / 2,
			jCoefficient * (j * BLOCKSIZE - (BLOCKSIZE / 2))
		)

	local result = workspace:Raycast(coordinate, Vector3.new(0, -BLOCKSIZE, 0), castParams)
	if result then
		table.insert(self.layers[layer], coordinate)
	end
end

function Storm.RegisterLayers(self: Storm)
	debug.profilebegin("RegisterStormLayers")
	for i = 1, MAPLENGTH / 2 do
		for j = 1, MAPLENGTH / 2 do
			local layer = math.max(i, j)
			if not self.layers[layer] then
				self.layers[layer] = {}
			end

			self:AddCoordinate(layer, i, j, false, false)
			self:AddCoordinate(layer, i, j, false, true)
			self:AddCoordinate(layer, i, j, true, false)
			self:AddCoordinate(layer, i, j, true, true)
		end
	end
	debug.profileend()
end

function Storm.TestRenderLayers(self: Storm)
	for i, layer in pairs(self.layers) do
		for i, position in ipairs(layer) do
			TestPart(position)
		end
		task.wait(2)
	end
end

function Storm.RenderAllPositions(self: Storm)
	local sideOffset = (MAPLENGTH / 2) * BLOCKSIZE - (BLOCKSIZE / 2)
	local corner = self.centre.Position - Vector3.new(sideOffset, -BLOCKSIZE / 2, sideOffset)
	for i = 0, MAPLENGTH - 1 do
		for j = 0, MAPLENGTH - 1 do
			TestPart(corner + Vector3.new(i * BLOCKSIZE, 0, j * BLOCKSIZE))
		end
	end
end

function Storm.RenderStorm(self: Storm, position: Vector3)
	local newStormPart = stormPartTemplate:Clone()
	self.Add(newStormPart)
	newStormPart.Position = position

	newStormPart.Parent = stormFolder

	for i, v in pairs(newStormPart:GetDescendants()) do
		if v:IsA("ParticleEmitter") then
			v:Emit(1)

			-- allow storm to naturally dissipate
			-- self.Add(function()
			-- 	v:Clear()
			-- end)
		end
	end
end

function Storm.DamageLoop(self: Storm)
	self.Add(RunService.Stepped:Connect(function()
		if os.clock() - self.lastDamaged < DAMAGEDELAY then
			return
		end
		self.lastDamaged = os.clock()

		local combatPlayers = CombatService:GetAllCombatPlayers()
		for i, combatPlayer in ipairs(combatPlayers) do
			if combatPlayer.isObject then
				continue
			end
			local HRP = assert(combatPlayer.character:FindFirstChild("HumanoidRootPart")) :: BasePart
			local position = HRP.Position
			local difference = (position - self.centre.Position) * Vector3.new(1 / BLOCKSIZE, 1, 1 / BLOCKSIZE)

			-- Since the storm area is a square not a circle, we can't take the magnitude
			local maxDifference = math.max(math.abs(difference.X), math.abs(difference.Z))

			-- Prevent players from not being killed if they somehow get above the map
			local tooHigh = math.abs(difference.Y) > 10

			if (maxDifference > self.currentLayer - 1 or tooHigh) and combatPlayer:CanTakeDamage() then
				combatPlayer:TakeDamage(DAMAGEAMOUNT * combatPlayer.maxHealth)
			end
		end
	end))
end

function Storm.ProgressLayers(self: Storm)
	task.wait(STARTDELAY)

	while self.currentLayer > MINLAYER and not self.destroyed do
		self.currentLayer -= 1
		for i, position in ipairs(self.layers[self.currentLayer]) do
			self:RenderStorm(position)
		end
		task.wait(PROGRESSDELAY)
		self.lastDamaged = os.clock()
	end
end

function Storm.Start(self: Storm)
	self:RegisterLayers()

	Spawn(function()
		self:ProgressLayers()
	end)
	self:DamageLoop()
end

function Storm.Destroy(self: Storm)
	self.Remove()
	self.destroyed = true
end

-- local storm = Storm.new(workspace.Arena.Map.Dancefloor)
-- storm:Start()

export type Storm = typeof(_self(...))

return Storm
