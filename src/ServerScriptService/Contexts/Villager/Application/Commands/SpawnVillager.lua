--!strict

--[=[
	@class SpawnVillager
	Command service that spawns villager entities in the game world.
	@server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VillagerConfig = require(ReplicatedStorage.Contexts.Villager.Config.VillagerConfig)
local Result = require(ReplicatedStorage.Utilities.Result)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok, Ensure = Result.Ok, Result.Ensure

local SpawnVillager = {}
SpawnVillager.__index = SpawnVillager

function SpawnVillager.new()
	return setmetatable({}, SpawnVillager)
end

function SpawnVillager:Init(registry: any)
	self.EntityFactory = registry:Get("VillagerEntityFactory")
	self.ModelFactory = registry:Get("VillagerModelFactory")
	self.GameObjectSyncService = registry:Get("VillagerGameObjectSyncService")
	self.RouteDiscoveryService = registry:Get("VillagerRouteDiscoveryService")
end

--[=[
	Spawns a new villager entity and model in the world.
	@within SpawnVillager
	@param archetypeId string? -- Optional archetype ID; if nil, selects weighted random archetype
	@return Result<{ Entity: any, VillagerId: string }> -- Spawned entity and villager ID or error
]=]
function SpawnVillager:Execute(archetypeId: string?): Result.Result<{ Entity: any, VillagerId: string }>
	local archetype = self:_ResolveArchetype(archetypeId)
	Ensure(archetype, "NoArchetype", Errors.NO_ARCHETYPE)

	-- Step 1: Resolve spawn location (default to Y=5 if route not found)
	local spawnCFrame = self.RouteDiscoveryService:GetRandomSpawnCFrame() or CFrame.new(0, 5, 0)

	-- Step 2: Create ECS entity with initial components
	local entity, villagerId = self.EntityFactory:CreateVillager(archetype, spawnCFrame)

	-- Step 3: Create visual model and position it
	local model = self.ModelFactory:CreateVillagerModel(archetype.ModelKey, villagerId, archetype.DisplayName)
	self.ModelFactory:UpdatePosition(model, spawnCFrame)

	-- Step 4: Link model to entity and register for syncing
	self.EntityFactory:SetModelRef(entity, model)
	self.GameObjectSyncService:RegisterEntity(entity)

	return Ok({ Entity = entity, VillagerId = villagerId })
end

-- Returns archetype config for given ID; falls back to weighted random selection if ID is nil or invalid.
function SpawnVillager:_ResolveArchetype(archetypeId: string?): any
	if archetypeId and VillagerConfig.Archetypes[archetypeId] then
		return VillagerConfig.Archetypes[archetypeId]
	end

	return self:_ChooseWeightedArchetype()
end

-- Selects archetype by rolling against cumulative spawn weights; ensures Customer as fallback.
function SpawnVillager:_ChooseWeightedArchetype(): any
	local totalWeight = 0
	for _, archetype in pairs(VillagerConfig.Archetypes) do
		totalWeight += archetype.SpawnWeight
	end

	-- Random roll in [0, totalWeight); find first archetype whose cumulative weight >= roll
	local roll = math.random() * totalWeight
	local runningWeight = 0
	for _, archetype in pairs(VillagerConfig.Archetypes) do
		runningWeight += archetype.SpawnWeight
		if roll <= runningWeight then
			return archetype
		end
	end

	-- Fallback if iteration doesn't match (shouldn't happen, but defensive)
	return VillagerConfig.Archetypes.Customer
end

return SpawnVillager
