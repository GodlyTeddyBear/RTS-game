--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local JECS = require(ReplicatedStorage.Packages.JECS)
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
	Owns the JECS world/component access surface for one bounded ECS context and
	manages deferred destruction plus reveal binding lifecycle.

	This base creates and mutates ECS entities, exposes typed component accessors
	and queries, and owns deferred destruction. It may store a model reference or
	transform for an entity, but it does not create Workspace instances or apply
	model reveal on its own. `BaseInstanceFactory` owns model creation and reveal
	application, while `BaseGameObjectSyncService` bridges entity state onto the
	resolved model.
	@server
]=]
local BaseECSEntityFactory = {}
BaseECSEntityFactory.__index = BaseECSEntityFactory

-- ── Public ────────────────────────────────────────────────────────────────────

--[=[
	Creates a new base factory helper.
	@within BaseECSEntityFactory
	@param contextName string -- Owning context label used in assertions and diagnostics.
	@return BaseECSEntityFactory -- The base factory instance.
]=]
function BaseECSEntityFactory.new(contextName: string)
	local self = setmetatable({}, BaseECSEntityFactory)
	self._contextName = contextName
	self._world = nil
	self._components = nil
	self._childOfComponent = JECS.ChildOf
	self._modelRefComponent = nil
	self._transformComponent = nil
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
function BaseECSEntityFactory:Init(registry: any, name: string)
	local componentRegistryName = self:_GetComponentRegistryName()
	assert(type(componentRegistryName) == "string" and componentRegistryName ~= "", ("%sEntityFactory: missing component registry name"):format(self._contextName))
	self:InitBase(registry, componentRegistryName)

	local componentRegistry = registry:Get(componentRegistryName)
	if type(self._OnInit) == "function" then
		self:_OnInit(registry, name, componentRegistry)
	end
end

--[=[
	Resolves the world and component registry before the derived factory starts using JECS.
	@within BaseECSEntityFactory
	@param registry any -- Dependency registry for this context.
	@param componentRegistryName string -- Registry key that exposes `GetComponents()`.
]=]
function BaseECSEntityFactory:InitBase(registry: any, componentRegistryName: string)
	self._world = registry:Get("World")
	assert(self._world ~= nil, ("%sEntityFactory: missing World"):format(self._contextName))

	local componentRegistry = registry:Get(componentRegistryName)
	assert(componentRegistry ~= nil, ("%sEntityFactory: missing %s"):format(self._contextName, componentRegistryName))
	assert(type(componentRegistry.GetComponents) == "function", ("%sEntityFactory: %s missing GetComponents"):format(self._contextName, componentRegistryName))

	self._components = componentRegistry:GetComponents()
	assert(self._components ~= nil, ("%sEntityFactory: %s returned nil components"):format(self._contextName, componentRegistryName))
	if self._components.ChildOf ~= nil then
		self._childOfComponent = self._components.ChildOf
	end
end

--[=[
	@within BaseECSEntityFactory
	@private
	Returns the component registry name owned by the derived factory.
]=]
function BaseECSEntityFactory:_GetComponentRegistryName(): string
	error(("%sEntityFactory must implement _GetComponentRegistryName"):format(self._contextName))
end

--[=[
	Runs the derived init hook after the base world and component lookup are ready.
	@within BaseECSEntityFactory
	@private
]=]
function BaseECSEntityFactory:_OnInit(_registry: any, _name: string, _componentRegistry: any)
	return
end

--[=[
	Asserts the factory world/components are ready for use.
	@within BaseECSEntityFactory
]=]
function BaseECSEntityFactory:RequireReady()
	assert(self._world ~= nil, ("%sEntityFactory: used before Init"):format(self._contextName))
	assert(self._components ~= nil, ("%sEntityFactory: missing components"):format(self._contextName))
end

--[=[
	Backward-compatible alias for pre-v2 call sites.
	@within BaseECSEntityFactory
	@private
]=]
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
	@within BaseECSEntityFactory
	@private
	Returns the world without repeating the public accessor name.
]=]
function BaseECSEntityFactory:_GetWorldUnsafe()
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
	@within BaseECSEntityFactory
	@private
	Validates that the supplied entity exists before JECS mutation.
]=]
function BaseECSEntityFactory:_RequireEntityExists(entity: number, methodName: string?)
	self:RequireReady()
	assert(type(entity) == "number", ("%sEntityFactory:%s requires entity"):format(self._contextName, methodName or "Unknown"))
	assert(self:_Exists(entity), ("%sEntityFactory:%s entity does not exist"):format(self._contextName, methodName or "Unknown"))
end

--[=[
	@within BaseECSEntityFactory
	@private
	Creates a new JECS entity in the context world.
]=]
function BaseECSEntityFactory:_CreateEntity(): number
	local world = self:GetWorldOrThrow()
	return world:entity()
end

--[=[
	@within BaseECSEntityFactory
	@private
	Creates a child entity and links it to the supplied parent entity.
]=]
function BaseECSEntityFactory:_CreateChildEntity(parentEntity: number): number
	self:_RequireEntityExists(parentEntity, "_CreateChildEntity")
	local childEntity = self:_CreateEntity()
	self:_SetParent(childEntity, parentEntity)
	return childEntity
end

--[=[
	@within BaseECSEntityFactory
	@private
	Sets the JECS name component for an entity.
]=]
function BaseECSEntityFactory:_SetName(entity: number, name: string)
	self:_RequireEntityExists(entity, "_SetName")
	assert(type(name) == "string" and name ~= "", ("%sEntityFactory:_SetName requires name"):format(self._contextName))
	self._world:set(entity, JECS.Name, name)
end

--[=[
	@within BaseECSEntityFactory
	@private
	Sets a component value on an entity.
]=]
function BaseECSEntityFactory:_Set(entity: number, component: any, value: any)
	self:_RequireEntityExists(entity, "_Set")
	self._world:set(entity, component, value)
end

--[=[
	@within BaseECSEntityFactory
	@private
	Adds a tag or component pair to an entity.
]=]
function BaseECSEntityFactory:_Add(entity: number, tag: any)
	self:_RequireEntityExists(entity, "_Add")
	self._world:add(entity, tag)
end

--[=[
	@within BaseECSEntityFactory
	@private
	Removes a tag or component from an entity.
]=]
function BaseECSEntityFactory:_Remove(entity: number, tag: any)
	self:_RequireEntityExists(entity, "_Remove")
	self._world:remove(entity, tag)
end

--[=[
	@within BaseECSEntityFactory
	@private
	Reads a component or tag from an entity.
]=]
function BaseECSEntityFactory:_Get(entity: number, component: any)
	self:_RequireEntityExists(entity, "_Get")
	return self._world:get(entity, component)
end

--[=[
	@within BaseECSEntityFactory
	@private
	Checks whether an entity has a component or tag.
]=]
function BaseECSEntityFactory:_Has(entity: number, componentOrTag: any): boolean
	self:_RequireEntityExists(entity, "_Has")
	return self._world:has(entity, componentOrTag)
end

--[=[
	@within BaseECSEntityFactory
	@private
	Checks whether the entity still exists in the world.
]=]
function BaseECSEntityFactory:_Exists(entity: number): boolean
	self:RequireReady()
	return self._world:exists(entity)
end

--[=[
	@within BaseECSEntityFactory
	@private
	Deletes an entity immediately after clearing reveal state.
]=]
function BaseECSEntityFactory:_DeleteNow(entity: number)
	self:_RequireEntityExists(entity, "_DeleteNow")
	self:_ClearRevealForEntity(entity)
	self._world:delete(entity)
end

--[=[
	@within BaseECSEntityFactory
	@private
	Sets the `ChildOf` parent relationship for two entities.
]=]
function BaseECSEntityFactory:_SetParent(childEntity: number, parentEntity: number)
	self:_RequireEntityExists(childEntity, "_SetParent")
	self:_RequireEntityExists(parentEntity, "_SetParent")
	self:_Add(childEntity, JECS.pair(self._childOfComponent, parentEntity))
end

--[=[
	Returns the parent entity for a child-of relationship, if one exists.
	@within BaseECSEntityFactory
	@param entity number -- Entity id to inspect.
	@return number? -- Parent entity id or nil.
]=]
function BaseECSEntityFactory:GetParentEntity(entity: number): number?
	self:_RequireEntityExists(entity, "GetParentEntity")
	return self._world:target(entity, self._childOfComponent)
end

--[=[
	@within BaseECSEntityFactory
	@private
	Configures the model-ref and transform components used by spatial accessors.
]=]
function BaseECSEntityFactory:_ConfigureSpatialComponents(modelRefComponentKey: string?, transformComponentKey: string?)
	self:RequireReady()

	if modelRefComponentKey ~= nil then
		local modelRefComponent = self._components[modelRefComponentKey]
		assert(modelRefComponent ~= nil, ("%sEntityFactory: missing spatial component '%s'"):format(self._contextName, modelRefComponentKey))
		self._modelRefComponent = modelRefComponent
	end

	if transformComponentKey ~= nil then
		local transformComponent = self._components[transformComponentKey]
		assert(transformComponent ~= nil, ("%sEntityFactory: missing spatial component '%s'"):format(self._contextName, transformComponentKey))
		self._transformComponent = transformComponent
	end
end

--[=[
	@within BaseECSEntityFactory
	@private
	Returns the configured model-ref component.
]=]
function BaseECSEntityFactory:_GetModelRefComponent()
	assert(self._modelRefComponent ~= nil, ("%sEntityFactory: model ref component not configured"):format(self._contextName))
	return self._modelRefComponent
end

--[=[
	@within BaseECSEntityFactory
	@private
	Returns the configured transform component.
]=]
function BaseECSEntityFactory:_GetTransformComponent()
	assert(self._transformComponent ~= nil, ("%sEntityFactory: transform component not configured"):format(self._contextName))
	return self._transformComponent
end

--[=[
	Sets the model reference component for an entity.
	@within BaseECSEntityFactory
	@param entity number -- Entity id to update.
	@param model Model -- Live model to bind to the entity.
]=]
function BaseECSEntityFactory:SetModelRef(entity: number, model: Model)
	self:_Set(entity, self:_GetModelRefComponent(), {
		Model = model,
	})
end

--[=[
	Clears the model reference component for an entity.
	@within BaseECSEntityFactory
	@param entity number -- Entity id to update.
]=]
function BaseECSEntityFactory:ClearModelRef(entity: number)
	self:_Remove(entity, self:_GetModelRefComponent())
end

--[=[
	Returns the model reference component for an entity, if one exists.
	@within BaseECSEntityFactory
	@param entity number -- Entity id to inspect.
	@return { Model: Model }? -- Stored model reference or nil.
]=]
function BaseECSEntityFactory:GetModelRef(entity: number): { Model: Model }?
	return self:_Get(entity, self:_GetModelRefComponent())
end

--[=[
	Returns the live model bound to an entity, if one exists.
	@within BaseECSEntityFactory
	@param entity number -- Entity id to inspect.
	@return Model? -- Bound model or nil.
]=]
function BaseECSEntityFactory:GetEntityModel(entity: number): Model?
	local modelRef = self:GetModelRef(entity)
	return modelRef and modelRef.Model or nil
end

--[=[
	Sets the transform component for an entity.
	@within BaseECSEntityFactory
	@param entity number -- Entity id to update.
	@param cframe CFrame -- World-space transform to store.
]=]
function BaseECSEntityFactory:SetTransformCFrame(entity: number, cframe: CFrame)
	self:_Set(entity, self:_GetTransformComponent(), {
		CFrame = cframe,
	})
end

--[=[
	Returns the stored transform component for an entity, if one exists.
	@within BaseECSEntityFactory
	@param entity number -- Entity id to inspect.
	@return { CFrame: CFrame }? -- Stored transform or nil.
]=]
function BaseECSEntityFactory:GetTransform(entity: number): { CFrame: CFrame }?
	return self:_Get(entity, self:_GetTransformComponent())
end

--[=[
	Returns the entity's world CFrame from either the bound model or stored transform.
	@within BaseECSEntityFactory
	@param entity number -- Entity id to inspect.
	@return CFrame? -- Current world CFrame or nil.
]=]
function BaseECSEntityFactory:GetEntityCFrame(entity: number): CFrame?
	local model = self:GetEntityModel(entity)
	if model ~= nil then
		return model:GetPivot()
	end

	local transform = self:GetTransform(entity)
	return transform and transform.CFrame or nil
end

--[=[
	Returns the entity's world position from either the bound model or stored transform.
	@within BaseECSEntityFactory
	@param entity number -- Entity id to inspect.
	@return Vector3? -- Current world position or nil.
]=]
function BaseECSEntityFactory:GetEntityPosition(entity: number): Vector3?
	local cframe = self:GetEntityCFrame(entity)
	return cframe and cframe.Position or nil
end

--[=[
	Collects entities matching a component/tag query into an array.
	@within BaseECSEntityFactory
	@param componentOrTagId any -- JECS query id.
	@return { number } -- Matching entity ids.
]=]
function BaseECSEntityFactory:CollectQuery(...: any): { number }
	local world = self:GetWorldOrThrow()
	local queryIds = { ... }
	assert(#queryIds > 0, ("%sEntityFactory:CollectQuery requires at least one query id"):format(self._contextName))
	local entities = {}
	for entity in world:query(table.unpack(queryIds)) do
		table.insert(entities, entity)
	end
	return entities
end

-- Collects children through `ChildOf` so derived factories do not repeat query setup.
--[=[
	Collects children of the supplied parent entity into an array.
	@within BaseECSEntityFactory
	@param parentEntity number -- Parent entity id.
	@param childOfComponent any -- JECS `ChildOf` component or compatible pair id.
	@return { number } -- Matching child entity ids.
]=]
function BaseECSEntityFactory:CollectChildren(parentEntity: number, childOfComponent: any?): { number }
	self:_RequireEntityExists(parentEntity, "CollectChildren")

	local world = self:GetWorldOrThrow()
	local entities = {}
	for entity in world:query(JECS.pair(childOfComponent or self._childOfComponent, parentEntity)) do
		table.insert(entities, entity)
	end
	return entities
end

--[=[
	Returns the first entity that matches the supplied tag, or nil when no entity matches.
	@within BaseECSEntityFactory
	@param tagId any -- JECS tag id.
	@return number? -- First matching entity id or nil.
]=]
function BaseECSEntityFactory:FindFirstWithTag(tagId: any): number?
	local world = self:GetWorldOrThrow()
	for entity in world:query(tagId) do
		return entity
	end
	return nil
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
	self:_MarkForDestructionRecursive(entity, {})
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
		if self:_Exists(entity) then
			self:_DeleteNow(entity)
		end
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

-- Builds the clear state used when a revealed entity is destroyed or unregistered.
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

-- Clears the reveal binding after applying the matching clear state to the instance.
function BaseECSEntityFactory:_ClearRevealForEntity(entity: number)
	local binding = self._revealBindingsByEntity[entity]
	if binding == nil then
		return
	end

	local clearState = self:_BuildRevealClearState(binding)
	self:ApplyReveal(binding.Instance, clearState)
	self._revealBindingsByEntity[entity] = nil
end

function BaseECSEntityFactory:_MarkForDestructionRecursive(entity: number, visited: { [number]: boolean })
	if visited[entity] == true then
		return
	end
	visited[entity] = true

	if not self:_Exists(entity) then
		return
	end

	for _, childEntity in ipairs(self:CollectChildren(entity)) do
		self:_MarkForDestructionRecursive(childEntity, visited)
	end

	if (self._destructionQueueCounts[entity] or 0) > 0 then
		self._destructionQueueCounts[entity] += 1
		return
	end

	table.insert(self._destructionQueue, entity)
	self._destructionQueueCounts[entity] = 1
end

return BaseECSEntityFactory
