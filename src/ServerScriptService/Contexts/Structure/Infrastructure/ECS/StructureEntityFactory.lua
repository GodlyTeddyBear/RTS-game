--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StructureConfig = require(ReplicatedStorage.Contexts.Structure.Config.StructureConfig)
local StructureTypes = require(ReplicatedStorage.Contexts.Structure.Types.StructureTypes)

type StructureType = StructureTypes.StructureType
type TAttackStatsComponent = StructureTypes.TAttackStatsComponent
type TAttackCooldownComponent = StructureTypes.TAttackCooldownComponent
type TIdentityComponent = StructureTypes.TIdentityComponent
type TInstanceRefComponent = StructureTypes.TInstanceRefComponent
type ResolvedStructureRecord = StructureTypes.ResolvedStructureRecord

--[=[
	@class StructureEntityFactory
	Creates and mutates structure entities in the StructureContext ECS world.
	@server
]=]
local StructureEntityFactory = {}
StructureEntityFactory.__index = StructureEntityFactory

--[=[
	Creates a new entity factory wrapper.
	@within StructureEntityFactory
	@return StructureEntityFactory -- The new factory instance.
]=]
function StructureEntityFactory.new()
	return setmetatable({}, StructureEntityFactory)
end

--[=[
	Caches the world and component ids for later entity operations.
	@within StructureEntityFactory
	@param registry any -- The dependency registry for this context.
	@param _name string -- The registered module name.
]=]
function StructureEntityFactory:Init(registry: any, _name: string)
	self._world = registry:Get("World")
	self._components = registry:Get("StructureComponentRegistry"):GetComponents()
end

--[=[
	Creates a structure entity from a resolved placement record.
	@within StructureEntityFactory
	@param record ResolvedStructureRecord -- The validated placement data.
	@return number -- The new ECS entity id.
]=]
function StructureEntityFactory:CreateStructure(record: ResolvedStructureRecord): number
	local structureConfig = StructureConfig.STRUCTURES[record.structureType]
	assert(structureConfig ~= nil, "Unknown structure type: " .. tostring(record.structureType))

	-- Create the entity first so every component write targets the same ECS id.
	local entity = self._world:entity()
	local structureId = tostring(record.instanceId)

	-- Copy the combat stats from config so later balance changes stay data-driven.
	self._world:set(entity, self._components.AttackStatsComponent, {
		AttackRange = structureConfig.AttackRange,
		AttackDamage = structureConfig.AttackDamage,
		AttackCooldown = structureConfig.AttackCooldown,
	} :: TAttackStatsComponent)

	-- Start every structure with an empty cooldown so the first target can fire immediately once ready.
	self._world:set(entity, self._components.AttackCooldownComponent, {
		Elapsed = 0,
	} :: TAttackCooldownComponent)

	-- Store a nil target until the targeting system resolves a nearby enemy.
	self._world:set(entity, self._components.TargetComponent, {
		Entity = nil,
	})

	-- Persist the runtime instance id and world-space anchor for targeting queries.
	self._world:set(entity, self._components.InstanceRefComponent, {
		InstanceId = record.instanceId,
		WorldPos = record.worldPos,
	} :: TInstanceRefComponent)

	-- Keep the canonical identity separate from the runtime instance ref.
	self._world:set(entity, self._components.IdentityComponent, {
		StructureId = structureId,
		StructureType = record.structureType,
	} :: TIdentityComponent)

	-- Mark the entity active so queries and systems can pick it up this frame.
	self._world:add(entity, self._components.ActiveTag)
	return entity
end

--[=[
	Sets or clears the current target for a structure entity.
	@within StructureEntityFactory
	@param entity number? -- The ECS entity to mutate.
	@param targetEntity number? -- The target entity or `nil` to clear.
]=]
-- Updates or clears the current attack target for a structure entity.
function StructureEntityFactory:SetTarget(entity: number?, targetEntity: number?)
	if entity == nil then
		return
	end

	self._world:set(entity, self._components.TargetComponent, {
		Entity = targetEntity,
	})
end

--[=[
	Returns the current target entity for a structure.
	@within StructureEntityFactory
	@param entity number? -- The ECS entity to inspect.
	@return number? -- The targeted enemy entity or `nil`.
]=]
function StructureEntityFactory:GetTarget(entity: number?): number?
	if entity == nil then
		return nil
	end

	local targetComponent = self._world:get(entity, self._components.TargetComponent)
	if targetComponent == nil then
		return nil
	end

	return targetComponent.Entity
end

--[=[
	Returns the attack stats component for a structure entity.
	@within StructureEntityFactory
	@param entity number? -- The ECS entity to inspect.
	@return TAttackStatsComponent? -- The attack stats or `nil`.
]=]
function StructureEntityFactory:GetAttackStats(entity: number?): TAttackStatsComponent?
	if entity == nil then
		return nil
	end

	return self._world:get(entity, self._components.AttackStatsComponent)
end

--[=[
	Returns the attack cooldown component for a structure entity.
	@within StructureEntityFactory
	@param entity number? -- The ECS entity to inspect.
	@return TAttackCooldownComponent? -- The cooldown state or `nil`.
]=]
function StructureEntityFactory:GetCooldown(entity: number?): TAttackCooldownComponent?
	if entity == nil then
		return nil
	end

	return self._world:get(entity, self._components.AttackCooldownComponent)
end

--[=[
	Sets the elapsed cooldown value for a structure entity.
	@within StructureEntityFactory
	@param entity number? -- The ECS entity to mutate.
	@param elapsed number -- The new elapsed cooldown in seconds.
]=]
function StructureEntityFactory:SetCooldownElapsed(entity: number?, elapsed: number)
	if entity == nil then
		return
	end

	-- Read the current component first so we can preserve the entity when it has already been removed.
	local current = self:GetCooldown(entity)
	if current == nil then
		return
	end

	self._world:set(entity, self._components.AttackCooldownComponent, {
		Elapsed = elapsed,
	} :: TAttackCooldownComponent)
end

--[=[
	Returns the identity component for a structure entity.
	@within StructureEntityFactory
	@param entity number? -- The ECS entity to inspect.
	@return TIdentityComponent? -- The identity data or `nil`.
]=]
function StructureEntityFactory:GetIdentity(entity: number?): TIdentityComponent?
	if entity == nil then
		return nil
	end

	return self._world:get(entity, self._components.IdentityComponent)
end

--[=[
	Returns the instance reference component for a structure entity.
	@within StructureEntityFactory
	@param entity number? -- The ECS entity to inspect.
	@return TInstanceRefComponent? -- The instance reference or `nil`.
]=]
function StructureEntityFactory:GetInstanceRef(entity: number?): TInstanceRefComponent?
	if entity == nil then
		return nil
	end

	return self._world:get(entity, self._components.InstanceRefComponent)
end

--[=[
	Collects every active structure entity into an array.
	@within StructureEntityFactory
	@return { number } -- All active structure entity ids.
]=]
function StructureEntityFactory:QueryActiveEntities(): { number }
	local entities = {}
	for entity in self._world:query(self._components.ActiveTag) do
		table.insert(entities, entity)
	end
	return entities
end

--[=[
	Deletes a single structure entity if it still exists.
	@within StructureEntityFactory
	@param entity number? -- The ECS entity to delete.
]=]
function StructureEntityFactory:DeleteEntity(entity: number?)
	if entity == nil then
		return
	end

	self._world:delete(entity)
end

--[=[
	Deletes every active structure entity.
	@within StructureEntityFactory
]=]
function StructureEntityFactory:DeleteAll()
	for _, entity in ipairs(self:QueryActiveEntities()) do
		self:DeleteEntity(entity)
	end
end

return StructureEntityFactory
