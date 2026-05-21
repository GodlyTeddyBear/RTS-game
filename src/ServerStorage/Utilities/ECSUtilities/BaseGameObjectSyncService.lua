--!strict

--[=[
	@type TRegistry
	@within BaseGameObjectSyncService
	@private
	Minimal dependency-registry surface required by the sync base.
]=]
type TRegistry = {
	Get: (self: any, name: string) -> any,
}

--[=[
	@class BaseGameObjectSyncService
	Owns safe ECS-backed Roblox model synchronization for one bounded context.

	Derived services supply the context-specific component and entity access
	surfaces, then implement `_SyncEntity()` plus any entity query or cleanup
	hooks they need. The base class handles readiness checks, model resolution,
	fail-safe sync/poll execution, and dirty-tag collection without taking JECS
	mutation ownership.

	This layer sits between the entity factory and the instance factory. It may
	resolve a model from an explicit argument, the optional instance factory, or
	the entity factory's model ref, but it does not create models, mutate JECS
	state, or own reveal bindings. Those responsibilities stay with the entity
	and instance factory layers.
	@server
]=]
local BaseGameObjectSyncService = {}
BaseGameObjectSyncService.__index = BaseGameObjectSyncService

-- ── Private ───────────────────────────────────────────────────────────────────

-- Validates string inputs that must exist before the helper can resolve registry keys.
local function _AssertNonEmptyString(value: any, message: string): string
	assert(type(value) == "string" and value ~= "", message)
	return value
end

-- Narrows a resolved instance to `Model` because sync code only operates on models.
local function _AsModel(instance: Instance?): Model?
	if instance ~= nil and instance:IsA("Model") then
		return instance :: Model
	end

	return nil
end

-- ── Public ────────────────────────────────────────────────────────────────────

--[=[
	Creates a new base sync service helper.
	@within BaseGameObjectSyncService
	@param contextName string -- Owning context label used in diagnostics.
	@return BaseGameObjectSyncService -- The base service instance.
]=]
function BaseGameObjectSyncService.new(contextName: string)
	local self = setmetatable({}, BaseGameObjectSyncService)
	self._contextName = contextName
	self._world = nil
	self._components = nil
	self._entityFactory = nil
	self._instanceFactory = nil
	self._initialized = false
	return self
end

--[=[
	Resolves the standard world, component registry, entity factory, and optional
	instance factory dependencies before derived services start syncing models.
	@within BaseGameObjectSyncService
	@param registry TRegistry -- Dependency registry for this context.
	@param name string -- Registered module name.
]=]
function BaseGameObjectSyncService:Init(registry: TRegistry, name: string)
	-- Resolve the registry keys required by the derived sync implementation.
	local componentRegistryName = _AssertNonEmptyString(
		self:_GetComponentRegistryName(),
		("%sGameObjectSyncService: missing component registry name"):format(self._contextName)
	)
	local entityFactoryName = _AssertNonEmptyString(
		self:_GetEntityFactoryName(),
		("%sGameObjectSyncService: missing entity factory name"):format(self._contextName)
	)

	-- Load the shared JECS world and the context-specific component lookup.
	self._world = registry:Get("World")
	assert(self._world ~= nil, ("%sGameObjectSyncService: missing World"):format(self._contextName))

	local componentRegistry = registry:Get(componentRegistryName)
	assert(componentRegistry ~= nil, ("%sGameObjectSyncService: missing %s"):format(self._contextName, componentRegistryName))
	assert(
		type(componentRegistry.GetComponents) == "function",
		("%sGameObjectSyncService: %s missing GetComponents"):format(self._contextName, componentRegistryName)
	)

	self._components = componentRegistry:GetComponents()
	assert(self._components ~= nil, ("%sGameObjectSyncService: %s returned nil components"):format(self._contextName, componentRegistryName))

	-- Load the context entity factory that owns authoritative ECS reads.
	self._entityFactory = registry:Get(entityFactoryName)
	assert(self._entityFactory ~= nil, ("%sGameObjectSyncService: missing %s"):format(self._contextName, entityFactoryName))

	-- Resolve the optional instance factory only when the derived service uses one.
	local instanceFactoryName = self:_GetInstanceFactoryName()
	if instanceFactoryName ~= nil and instanceFactoryName ~= "" then
		self._instanceFactory = registry:Get(instanceFactoryName)
		assert(
			self._instanceFactory ~= nil,
			("%sGameObjectSyncService: missing %s"):format(self._contextName, instanceFactoryName)
		)
	end

	-- Let the derived service finish any custom initialization before marking ready.
	self:_OnInit(registry, name)
	self._initialized = true
end

--[=[
	Asserts that `Init()` has completed.
	@within BaseGameObjectSyncService
]=]
function BaseGameObjectSyncService:RequireReady()
	assert(self._initialized, ("%sGameObjectSyncService: used before Init"):format(self._contextName))
	assert(self._world ~= nil, ("%sGameObjectSyncService: missing World"):format(self._contextName))
	assert(self._components ~= nil, ("%sGameObjectSyncService: missing components"):format(self._contextName))
	assert(self._entityFactory ~= nil, ("%sGameObjectSyncService: missing entity factory"):format(self._contextName))
end

--[=[
	Returns the initialized ECS world.
	@within BaseGameObjectSyncService
	@return any -- Context JECS world.
]=]
function BaseGameObjectSyncService:GetWorldOrThrow(): any
	self:RequireReady()
	return self._world
end

--[=[
	Returns the initialized component lookup.
	@within BaseGameObjectSyncService
	@return any -- Frozen component lookup from the context registry.
]=]
function BaseGameObjectSyncService:GetComponentsOrThrow(): any
	self:RequireReady()
	return self._components
end

--[=[
	Returns the initialized entity factory.
	@within BaseGameObjectSyncService
	@return any -- Context entity factory.
]=]
function BaseGameObjectSyncService:GetEntityFactoryOrThrow(): any
	self:RequireReady()
	return self._entityFactory
end

--[=[
	Returns the optional instance factory, if one was configured.
	@within BaseGameObjectSyncService
	@return any? -- Context instance factory or nil.
]=]
function BaseGameObjectSyncService:GetInstanceFactory(): any?
	self:RequireReady()
	return self._instanceFactory
end

--[=[
	Sets an instance attribute only when the value changed.
	@within BaseGameObjectSyncService
	@param instance Instance -- Instance to update.
	@param attributeName string -- Attribute key.
	@param value any -- Attribute value.
]=]
function BaseGameObjectSyncService:SetAttributeIfChanged(instance: Instance, attributeName: string, value: any)
	if instance:GetAttribute(attributeName) == value then
		return
	end

	instance:SetAttribute(attributeName, value)
end

--[=[
	Resolves and immediately syncs one entity model.
	@within BaseGameObjectSyncService
	@param entity number -- Entity id to register.
	@param model Model? -- Optional already-resolved model.
]=]
function BaseGameObjectSyncService:RegisterEntity(entity: number, model: Model?)
	self:RequireReady()
	self:_SafeSyncEntity(entity, model, "RegisterEntity", false)
end

--[=[
	Synchronizes every entity returned by `_QueryAllEntities()`.
	@within BaseGameObjectSyncService
]=]
function BaseGameObjectSyncService:SyncAll()
	self:RequireReady()

	for _, entity in ipairs(self:_QueryAllEntities()) do
		self:_SafeSyncEntity(entity, nil, "SyncAll", false)
	end
end

--[=[
	Synchronizes dirty entities and delegates dirty clearing to `_ClearDirty()`.
	@within BaseGameObjectSyncService
]=]
function BaseGameObjectSyncService:SyncDirtyEntities()
	self:RequireReady()

	for _, entity in ipairs(self:_QueryDirtyEntities()) do
		self:_SafeSyncEntity(entity, nil, "SyncDirtyEntities", true)
	end
end

--[=[
	Polls runtime model state for every entity returned by `_QueryPollEntities()`.
	@within BaseGameObjectSyncService
]=]
function BaseGameObjectSyncService:Poll()
	self:RequireReady()

	-- Poll only the entities the derived service explicitly opted into runtime reads.
	for _, entity in ipairs(self:_QueryPollEntities()) do
		local model = self:_ResolveModel(entity, nil)
		if model == nil or model.Parent == nil then
			continue
		end

		local success, err = pcall(function()
			self:_PollEntity(entity, model)
		end)

		if not success then
			self:_OnSyncFailed(entity, err, "Poll")
		end
	end
end

--[=[
	Returns the currently resolved model for an entity, if present.
	@within BaseGameObjectSyncService
	@param entity number -- Entity id to resolve.
	@return Model? -- Resolved model or nil.
]=]
function BaseGameObjectSyncService:GetInstanceForEntity(entity: number): Model?
	self:RequireReady()
	return self:_ResolveModel(entity, nil)
end

--[=[
	Runs derived cleanup behavior.
	@within BaseGameObjectSyncService
]=]
function BaseGameObjectSyncService:CleanupAll()
	self:RequireReady()
	self:_OnCleanupAll()
end

-- ── Private Overrides ─────────────────────────────────────────────────────────

--[=[
	Derived services must point the base helper at the context's component registry.
	@within BaseGameObjectSyncService
	@private
]=]
function BaseGameObjectSyncService:_GetComponentRegistryName(): string
	error(("%sGameObjectSyncService must implement _GetComponentRegistryName"):format(self._contextName))
end

--[=[
	Derived services must point the base helper at the context's entity factory.
	@within BaseGameObjectSyncService
	@private
]=]
function BaseGameObjectSyncService:_GetEntityFactoryName(): string
	error(("%sGameObjectSyncService must implement _GetEntityFactoryName"):format(self._contextName))
end

--[=[
	Derived services may opt into a dedicated instance factory when they own one.
	@within BaseGameObjectSyncService
	@private
]=]
function BaseGameObjectSyncService:_GetInstanceFactoryName(): string?
	return nil
end

--[=[
	Derived services can extend initialization after the base dependencies are ready.
	@within BaseGameObjectSyncService
	@private
]=]
function BaseGameObjectSyncService:_OnInit(_registry: TRegistry, _name: string)
	return
end

--[=[
	Resolves models in priority order so explicit overrides win over factory lookups.
	@within BaseGameObjectSyncService
	@private
]=]
function BaseGameObjectSyncService:_ResolveModel(entity: number, explicitModel: Model?): Model?
	if explicitModel ~= nil then
		return explicitModel
	end

	local instanceFactory = self._instanceFactory
	if instanceFactory ~= nil and type(instanceFactory.GetInstance) == "function" then
		local instance = instanceFactory:GetInstance(entity)
		local model = _AsModel(instance)
		if model ~= nil then
			return model
		end
	end

	local entityFactory = self._entityFactory
	if entityFactory ~= nil and type(entityFactory.GetModelRef) == "function" then
		local modelRef = entityFactory:GetModelRef(entity)
		if modelRef ~= nil then
			return _AsModel(modelRef.Model)
		end
	end

	return nil
end

--[=[
	Returns the entity list that should be synced during `SyncAll()`.
	@within BaseGameObjectSyncService
	@private
]=]
function BaseGameObjectSyncService:_QueryAllEntities(): { number }
	return {}
end

--[=[
	Returns the entity list that should be polled during `Poll()`.
	@within BaseGameObjectSyncService
	@private
]=]
function BaseGameObjectSyncService:_QueryPollEntities(): { number }
	return {}
end

--[=[
	Collects dirty entities through the context's dirty tag when the derived
	service uses tag-driven sync invalidation.
	@within BaseGameObjectSyncService
	@private
]=]
function BaseGameObjectSyncService:_QueryDirtyEntities(): { number }
	local dirtyTag = self:_GetDirtyTag()
	if dirtyTag == nil then
		return {}
	end

	local world = self:GetWorldOrThrow()
	local entities = {}
	for entity in world:query(dirtyTag) do
		table.insert(entities, entity)
	end
	return entities
end

--[=[
	Returns the dirty tag used by `SyncDirtyEntities()`, if the derived service has one.
	@within BaseGameObjectSyncService
	@private
]=]
function BaseGameObjectSyncService:_GetDirtyTag(): any?
	return nil
end

--[=[
	Derived services clear their own dirty markers after a successful sync pass.
	@within BaseGameObjectSyncService
	@private
]=]
function BaseGameObjectSyncService:_ClearDirty(_entity: number)
	return
end

--[=[
	Derived services implement the actual model-to-ECS sync work here.
	@within BaseGameObjectSyncService
	@private
]=]
function BaseGameObjectSyncService:_SyncEntity(_entity: number, _model: Model)
	error(("%sGameObjectSyncService must implement _SyncEntity"):format(self._contextName))
end

--[=[
	Derived services can override this to copy runtime model state back into ECS.
	@within BaseGameObjectSyncService
	@private
]=]
function BaseGameObjectSyncService:_PollEntity(_entity: number, _model: Model)
	return
end

--[=[
	Centralizes failure logging so one bad entity does not abort the whole pass.
	@within BaseGameObjectSyncService
	@private
]=]
function BaseGameObjectSyncService:_OnSyncFailed(entity: number, err: any, operation: string)
	warn(("[%sGameObjectSyncService] Failed during %s: %s - %s"):format(
		self._contextName,
		operation,
		tostring(entity),
		tostring(err)
	))
end

--[=[
	Runs derived cleanup behavior when the service is torn down.
	@within BaseGameObjectSyncService
	@private
]=]
function BaseGameObjectSyncService:_OnCleanupAll()
	return
end

--[=[
	@within BaseGameObjectSyncService
	@private
	Resolves a model and safely runs the derived sync step for one entity.
]=]
function BaseGameObjectSyncService:_SafeSyncEntity(entity: number, explicitModel: Model?, operation: string, shouldClearDirty: boolean)
	-- Resolve the target model and skip the pass when the entity no longer has a live model.
	local model = self:_ResolveModel(entity, explicitModel)
	if model == nil or (explicitModel == nil and model.Parent == nil) then
		if shouldClearDirty then
			self:_ClearDirty(entity)
		end
		return
	end

	-- Guard the derived sync logic so one entity failure does not stop the batch.
	local success, err = pcall(function()
		self:_SyncEntity(entity, model)
	end)

	if not success then
		self:_OnSyncFailed(entity, err, operation)
	end

	-- Clear dirty state only after the sync attempt has finished.
	if shouldClearDirty then
		self:_ClearDirty(entity)
	end
end

return BaseGameObjectSyncService
