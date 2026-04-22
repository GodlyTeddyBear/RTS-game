--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ECS = require(ReplicatedStorage.Utilities.ECS)
local ECSIdentitySchema = ECS.IdentitySchema

type ECSRevealOptions = {
	EntityType: string,
	SourceId: string,
	ScopeId: string,
	EntityId: string?,
	Namespace: string?,
}

type ECSRevealBinding = {
	Instance: Instance,
	Options: ECSRevealOptions,
	LastTags: { [string]: boolean }?,
	LastAttributes: { [string]: any }?,
}

--[=[
	@class BaseECSEntityFactory
	Shared world/component guards and deferred-destruction queue helpers.
	@server
]=]
local BaseECSEntityFactory = {}
BaseECSEntityFactory.__index = BaseECSEntityFactory

--[=[
	Creates a new base factory helper.
	@within BaseECSEntityFactory
	@param contextName string -- The owning context label used in assertions.
	@return BaseECSEntityFactory -- The base factory instance.
]=]
function BaseECSEntityFactory.new(contextName: string)
	local self = setmetatable({}, BaseECSEntityFactory)
	self._contextName = contextName
	self._world = nil
	self._components = nil
	self._destructionQueue = {} :: { number }
	self._destructionQueueCounts = {} :: { [number]: number }
	self._revealBindingsByEntity = {} :: { [number]: ECSRevealBinding }
	return self
end

--[=[
	Resolves and validates world/components dependencies for derived factories.
	@within BaseECSEntityFactory
	@param registry any -- The dependency registry for this context.
	@param componentRegistryName string -- Registry key that exposes GetComponents().
]=]
function BaseECSEntityFactory:InitBase(registry: any, componentRegistryName: string)
	self._world = registry:Get("World")
	assert(self._world ~= nil, ("%sEntityFactory: missing World"):format(self._contextName))

	local componentRegistry = registry:Get(componentRegistryName)
	assert(componentRegistry ~= nil, ("%sEntityFactory: missing %s"):format(self._contextName, componentRegistryName))
	assert(type(componentRegistry.GetComponents) == "function", ("%sEntityFactory: %s missing GetComponents"):format(self._contextName, componentRegistryName))

	self._components = componentRegistry:GetComponents()
	assert(self._components ~= nil, ("%sEntityFactory: %s returned nil components"):format(self._contextName, componentRegistryName))
end

--[=[
	Asserts the factory world/components are ready for use.
	@within BaseECSEntityFactory
]=]
function BaseECSEntityFactory:RequireReady()
	assert(self._world ~= nil, ("%sEntityFactory: used before Init"):format(self._contextName))
	assert(self._components ~= nil, ("%sEntityFactory: missing components"):format(self._contextName))
end

-- Backward-compatible alias for pre-v2 call sites.
function BaseECSEntityFactory:_RequireReady()
	self:RequireReady()
end

--[=[
	Returns the world instance after readiness checks.
	@within BaseECSEntityFactory
	@return any -- JECS world.
]=]
function BaseECSEntityFactory:GetWorldOrThrow()
	self:RequireReady()
	return self._world
end

--[=[
	Returns the component lookup after readiness checks.
	@within BaseECSEntityFactory
	@return table -- Frozen components lookup.
]=]
function BaseECSEntityFactory:GetComponentsOrThrow()
	self:RequireReady()
	return self._components
end

--[=[
	Collects entities matching a component/tag query into an array.
	@within BaseECSEntityFactory
	@param componentOrTagId any -- JECS query id.
	@return { number } -- Matching entity ids.
]=]
function BaseECSEntityFactory:CollectQuery(componentOrTagId: any): { number }
	local world = self:GetWorldOrThrow()
	local entities = {}
	for entity in world:query(componentOrTagId) do
		table.insert(entities, entity)
	end
	return entities
end

--[=[
	Queues an entity id for deferred destruction.
	@within BaseECSEntityFactory
	@param entity number? -- The entity to queue.
]=]
function BaseECSEntityFactory:MarkForDestruction(entity: number?)
	if entity == nil then
		return
	end

	self:RequireReady()
	table.insert(self._destructionQueue, entity)
	local currentCount = self._destructionQueueCounts[entity] or 0
	self._destructionQueueCounts[entity] = currentCount + 1
end

--[=[
	Checks whether an entity is currently queued for deferred deletion.
	@within BaseECSEntityFactory
	@param entity number -- Entity id.
	@return boolean -- True when queued at least once.
]=]
function BaseECSEntityFactory:IsMarkedForDestruction(entity: number): boolean
	self:RequireReady()
	return (self._destructionQueueCounts[entity] or 0) > 0
end

--[=[
	Returns the number of queued deferred deletions.
	@within BaseECSEntityFactory
	@return number -- Queue length.
]=]
function BaseECSEntityFactory:GetDestructionQueueSize(): number
	self:RequireReady()
	return #self._destructionQueue
end

--[=[
	Deletes every queued entity and clears the queue.
	@within BaseECSEntityFactory
	@return boolean -- True when at least one entity was deleted.
]=]
function BaseECSEntityFactory:FlushDestructionQueue(): boolean
	self:RequireReady()

	if #self._destructionQueue == 0 then
		return false
	end

	for _, entity in ipairs(self._destructionQueue) do
		self:_ClearRevealForEntity(entity)
		self._world:delete(entity)
	end

	table.clear(self._destructionQueue)
	table.clear(self._destructionQueueCounts)
	return true
end

--[=[
	Returns the ECS utility facade for reveal helper delegation.
	@within BaseECSEntityFactory
	@return any -- ECS utility facade.
]=]
function BaseECSEntityFactory:GetECSUtilities()
	return ECS
end

--[=[
	Builds reveal metadata through the ECS utility facade.
	@within BaseECSEntityFactory
	@param options any -- Reveal builder options.
	@return string, any -- Resolved entity id and reveal state.
]=]
function BaseECSEntityFactory:BuildRevealState(options: any): (string, any)
	return ECS.RevealBuilder.Build(options)
end

--[=[
	Applies reveal metadata to an instance through the ECS utility facade.
	@within BaseECSEntityFactory
	@param instance Instance? -- Instance to stamp.
	@param revealState any -- Reveal state contract.
	@param collectionServiceOverride any -- Optional collection service override.
]=]
function BaseECSEntityFactory:ApplyReveal(instance: Instance?, revealState: any, collectionServiceOverride: any)
	ECS.RevealApplier.Apply(instance, revealState, collectionServiceOverride)
end

--[=[
	Registers a reveal binding and applies reveal state immediately.
	@within BaseECSEntityFactory
	@param entity number -- Entity id owning the reveal binding.
	@param instance Instance -- Instance to reveal on clients.
	@param options ECSRevealOptions -- Explicit reveal identity options.
	@return string -- Resolved reveal entity id.
]=]
function BaseECSEntityFactory:RegisterReveal(entity: number, instance: Instance, options: ECSRevealOptions): string
	self:RequireReady()
	assert(type(entity) == "number", ("%sEntityFactory:RegisterReveal requires entity"):format(self._contextName))
	assert(instance ~= nil, ("%sEntityFactory:RegisterReveal requires instance"):format(self._contextName))
	assert(self._world:exists(entity), ("%sEntityFactory:RegisterReveal entity does not exist"):format(self._contextName))

	local resolvedEntityId, revealState = self:BuildRevealState(options)
	self:ApplyReveal(instance, revealState)

	self._revealBindingsByEntity[entity] = {
		Instance = instance,
		Options = options,
		LastAttributes = revealState.Attributes,
		LastTags = revealState.Tags,
	}

	return resolvedEntityId
end

--[=[
	Rebuilds and reapplies reveal state for a previously registered reveal binding.
	@within BaseECSEntityFactory
	@param entity number -- Entity id whose reveal binding should refresh.
	@return string? -- Resolved reveal entity id or nil when no binding exists.
]=]
function BaseECSEntityFactory:RefreshReveal(entity: number): string?
	self:RequireReady()
	local binding = self._revealBindingsByEntity[entity]
	if binding == nil then
		return nil
	end

	local resolvedEntityId, revealState = self:BuildRevealState(binding.Options)
	self:ApplyReveal(binding.Instance, revealState)
	binding.LastAttributes = revealState.Attributes
	binding.LastTags = revealState.Tags
	return resolvedEntityId
end

--[=[
	Removes a reveal binding without applying clear state.
	@within BaseECSEntityFactory
	@param entity number -- Entity id whose reveal binding should be removed.
]=]
function BaseECSEntityFactory:UnregisterReveal(entity: number)
	self._revealBindingsByEntity[entity] = nil
end

--[=[
	Returns whether the entity currently has an active reveal binding.
	@within BaseECSEntityFactory
	@param entity number -- Entity id to check.
	@return boolean -- True when reveal binding exists.
]=]
function BaseECSEntityFactory:HasReveal(entity: number): boolean
	return self._revealBindingsByEntity[entity] ~= nil
end

function BaseECSEntityFactory:_BuildRevealClearState(binding: ECSRevealBinding): any
	local clearAttributes = {}
	local tags = {}

	-- Always clear canonical identity attributes.
	table.insert(clearAttributes, ECSIdentitySchema.ATTR_ENTITY_TYPE)
	table.insert(clearAttributes, ECSIdentitySchema.ATTR_ENTITY_ID)

	if binding.LastAttributes then
		for attributeName in binding.LastAttributes do
			if attributeName ~= ECSIdentitySchema.ATTR_ENTITY_TYPE and attributeName ~= ECSIdentitySchema.ATTR_ENTITY_ID then
				table.insert(clearAttributes, attributeName)
			end
		end
	end

	if binding.LastTags then
		for tagName in binding.LastTags do
			tags[tagName] = false
		end
	end

	return {
		ClearAttributes = clearAttributes,
		Tags = tags,
	}
end

function BaseECSEntityFactory:_ClearRevealForEntity(entity: number)
	local binding = self._revealBindingsByEntity[entity]
	if binding == nil then
		return
	end

	local clearState = self:_BuildRevealClearState(binding)
	self:ApplyReveal(binding.Instance, clearState)
	self._revealBindingsByEntity[entity] = nil
end

return BaseECSEntityFactory
