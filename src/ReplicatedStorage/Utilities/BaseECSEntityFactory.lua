--!strict

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
function BaseECSEntityFactory._new(contextName: string)
	local self = setmetatable({}, BaseECSEntityFactory)
	self._contextName = contextName
	self._world = nil
	self._components = nil
	self._destructionQueue = {} :: { number }
	self._destructionQueueCounts = {} :: { [number]: number }
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
		self._world:delete(entity)
	end

	table.clear(self._destructionQueue)
	table.clear(self._destructionQueueCounts)
	return true
end

return BaseECSEntityFactory
