--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ECS = require(ReplicatedStorage.Utilities.ECS)

--[=[
	@type ECSRevealState
	@within BaseInstanceFactory
	@private
	Reveal payload currently applied to a bound instance.
]=]
type ECSRevealState = {
	Attributes: { [string]: any }?,
	ClearAttributes: { string }?,
	Tags: { [string]: boolean }?,
}

--[=[
	@type ECSRevealOptions
	@within BaseInstanceFactory
	@private
	Identity fields used to build reveal metadata.
]=]
type ECSRevealOptions = {
	EntityType: string,
	SourceId: string,
	ScopeId: string,
	EntityId: string?,
	Namespace: string?,
}

--[=[
	@type TInstanceBinding
	@within BaseInstanceFactory
	@private
	Tracks the entity-instance binding and last applied reveal state.
]=]
type TInstanceBinding = {
	EntityId: number,
	Instance: Instance,
	CreateOptions: any,
	RevealOptions: ECSRevealOptions?,
	LastRevealState: ECSRevealState?,
}

--[=[
	@class BaseInstanceFactory
	Owns Workspace instance lifecycle and reveal state for ECS-backed runtime
	objects.

	This base handles model creation or cloning, asset-template lookup, entity to
	instance binding, reveal metadata, and instance cleanup. It does not own JECS
	world mutation, component queries, or entity lifecycle; those belong to the
	entity factory layer. `BaseGameObjectSyncService` may read from an instance
	factory to resolve the live model, but it does not transfer ownership of the
	model itself.
	@server
]=]
local BaseInstanceFactory = {}
BaseInstanceFactory.__index = BaseInstanceFactory

-- ── Private ───────────────────────────────────────────────────────────────────

local function _FindOrCreateFolder(parent: Instance, name: string): Folder
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function _BuildClearRevealState(lastRevealState: ECSRevealState?): ECSRevealState?
	if lastRevealState == nil then
		return nil
	end

	local clearAttributes = {}
	local tags = {}

	if lastRevealState.Attributes ~= nil then
		for attributeName in lastRevealState.Attributes do
			table.insert(clearAttributes, attributeName)
		end
	end

	if lastRevealState.ClearAttributes ~= nil then
		for _, attributeName in ipairs(lastRevealState.ClearAttributes) do
			table.insert(clearAttributes, attributeName)
		end
	end

	if lastRevealState.Tags ~= nil then
		for tagName in lastRevealState.Tags do
			tags[tagName] = false
		end
	end

	if #clearAttributes == 0 and next(tags) == nil then
		return nil
	end

	return {
		ClearAttributes = clearAttributes,
		Tags = tags,
	}
end

-- ── Public ────────────────────────────────────────────────────────────────────

--[=[
	Creates a new base instance factory helper.
	@within BaseInstanceFactory
	@param contextName string -- Owning context label used in assertions and diagnostics.
	@return BaseInstanceFactory -- The base factory instance.
]=]
function BaseInstanceFactory.new(contextName: string)
	local self = setmetatable({}, BaseInstanceFactory)
	self._contextName = contextName
	self._rootFolder = nil :: Folder?
	self._assetRegistry = nil
	self._entityToInstance = {} :: { [number]: Instance }
	self._instanceToEntity = {} :: { [Instance]: number }
	self._revealBindingsByEntity = {} :: { [number]: TInstanceBinding }
	return self
end

--[=[
	Initializes the workspace folder and optional asset registry for the context.
	@within BaseInstanceFactory
	@param registry any -- Dependency registry for this context.
	@param name string -- Registered module name.
]=]
function BaseInstanceFactory:Init(registry: any, name: string)
	assert(RunService:IsServer(), ("%sInstanceFactory is server-only"):format(self._contextName))

	local folderName = self:_GetWorkspaceFolderName()
	assert(type(folderName) == "string" and folderName ~= "", ("%sInstanceFactory: missing workspace folder name"):format(self._contextName))
	self._rootFolder = _FindOrCreateFolder(Workspace, folderName)

	local assetsRoot = ReplicatedStorage:FindFirstChild("Assets")
	if assetsRoot ~= nil and assetsRoot:IsA("Folder") then
		self._assetRegistry = self:_CreateAssetRegistry(assetsRoot)
	end

	self:_OnInit(registry, name)
end

--[=[
	@within BaseInstanceFactory
	@private
	Returns the Workspace folder name that stores bound instances.
]=]
function BaseInstanceFactory:_GetWorkspaceFolderName(): string
	error(("%sInstanceFactory must implement _GetWorkspaceFolderName"):format(self._contextName))
end

--[=[
	@within BaseInstanceFactory
	@private
	Builds the optional asset registry from the context's `Assets` folder.
]=]
function BaseInstanceFactory:_CreateAssetRegistry(_assetsRoot: Folder): any
	return nil
end

--[=[
	@within BaseInstanceFactory
	@private
	Runs derived initialization after the base folder and asset registry are ready.
]=]
function BaseInstanceFactory:_OnInit(_registry: any, _name: string)
	return
end

--[=[
	@within BaseInstanceFactory
	@private
	Creates the live instance for a single entity.
]=]
function BaseInstanceFactory:_CreateInstanceForEntity(_entityId: number, _options: any): Instance
	error(("%sInstanceFactory must implement _CreateInstanceForEntity"):format(self._contextName))
end

--[=[
	@within BaseInstanceFactory
	@private
	Returns identity options for reveal metadata, if the instance should be revealed.
]=]
function BaseInstanceFactory:_BuildRevealIdentityOptions(_entityId: number, _instance: Instance, _options: any): ECSRevealOptions?
	return nil
end

--[=[
	@within BaseInstanceFactory
	@private
	Returns custom attributes to apply when the instance is revealed.
]=]
function BaseInstanceFactory:_BuildRevealAttributes(_entityId: number, _instance: Instance, _options: any): { [string]: any }?
	return nil
end

--[=[
	@within BaseInstanceFactory
	@private
	Returns custom tags to apply when the instance is revealed.
]=]
function BaseInstanceFactory:_BuildRevealTags(_entityId: number, _instance: Instance, _options: any): { [string]: boolean }?
	return nil
end

--[=[
	@within BaseInstanceFactory
	@private
	Returns attributes that should be cleared when the instance is destroyed.
]=]
function BaseInstanceFactory:_BuildRevealClearAttributes(_entityId: number, _instance: Instance, _options: any): { string }?
	return nil
end

--[=[
	@within BaseInstanceFactory
	@private
	Applies any instance-specific setup before the model is parented.
]=]
function BaseInstanceFactory:_PrepareInstance(_instance: Instance, _entityId: number, _options: any)
	return
end

--[=[
	Rebuilds the clear state for a destroyed binding so stale identity data is removed.
	@within BaseInstanceFactory
	@private
]=]
function BaseInstanceFactory:_BuildClearRevealState(_instance: Instance, entityId: number): ECSRevealState?
	local binding = self._revealBindingsByEntity[entityId]
	local clearState = _BuildClearRevealState(binding and binding.LastRevealState or nil)
	if clearState == nil then
		return nil
	end

	local explicitClearAttributes = self:_BuildRevealClearAttributes(entityId, binding.Instance, binding.CreateOptions)
	if explicitClearAttributes ~= nil then
		clearState.ClearAttributes = clearState.ClearAttributes or {}
		for _, attributeName in ipairs(explicitClearAttributes) do
			table.insert(clearState.ClearAttributes, attributeName)
		end
	end

	return clearState
end

--[=[
	@within BaseInstanceFactory
	@private
	Returns the cached asset registry, if one was created during `Init`.
]=]
function BaseInstanceFactory:_GetAssetRegistry()
	return self._assetRegistry
end

--[=[
	@within BaseInstanceFactory
	@private
	Returns the root Workspace folder or throws when the factory has not been initialized.
]=]
function BaseInstanceFactory:_GetRootFolderOrThrow(): Folder
	local rootFolder = self._rootFolder
	assert(rootFolder ~= nil, ("%sInstanceFactory used before Init"):format(self._contextName))
	return rootFolder
end

--[=[
	Returns the ECS utility facade for reveal helper delegation.
	@within BaseInstanceFactory
	@return any -- ECS utility facade.
]=]
function BaseInstanceFactory:GetECSUtilities()
	return ECS
end

--[=[
	Builds reveal identity metadata through the ECS utility facade.
	@within BaseInstanceFactory
	@param revealOptions ECSRevealOptions -- Reveal identity payload.
	@return string, ECSRevealState -- Resolved identity id and reveal state.
]=]
function BaseInstanceFactory:BuildIdentityRevealState(revealOptions: ECSRevealOptions): (string, ECSRevealState)
	return ECS.RevealBuilder.Build(revealOptions)
end

--[=[
	Merges multiple reveal states into one state table.
	@within BaseInstanceFactory
	@param ... ECSRevealState? -- Reveal states to merge in priority order.
	@return ECSRevealState? -- Combined reveal state or nil when all inputs are empty.
]=]
function BaseInstanceFactory:MergeRevealStates(...: ECSRevealState?): ECSRevealState?
	local attributes = nil :: { [string]: any }?
	local clearAttributes = nil :: { string }?
	local tags = nil :: { [string]: boolean }?

	for _, revealState in ipairs({ ... }) do
		if revealState ~= nil then
			if revealState.Attributes ~= nil then
				attributes = attributes or {}
				for attributeName, value in revealState.Attributes do
					attributes[attributeName] = value
				end
			end

			if revealState.ClearAttributes ~= nil then
				clearAttributes = clearAttributes or {}
				for _, attributeName in ipairs(revealState.ClearAttributes) do
					table.insert(clearAttributes, attributeName)
				end
			end

			if revealState.Tags ~= nil then
				tags = tags or {}
				for tagName, shouldHaveTag in revealState.Tags do
					tags[tagName] = shouldHaveTag
				end
			end
		end
	end

	if attributes == nil and clearAttributes == nil and tags == nil then
		return nil
	end

	return {
		Attributes = attributes,
		ClearAttributes = clearAttributes,
		Tags = tags,
	}
end

--[=[
	Builds the complete reveal state for an entity instance and its options.
	@within BaseInstanceFactory
	@param entityId number -- Entity id being revealed.
	@param instance Instance -- Instance to stamp.
	@param options any -- Factory-specific reveal options.
	@return ECSRevealState? -- Combined reveal state or nil when no reveal metadata exists.
]=]
function BaseInstanceFactory:BuildRevealState(entityId: number, instance: Instance, options: any): ECSRevealState?
	local identityOptions = self:_BuildRevealIdentityOptions(entityId, instance, options)
	local identityRevealState = nil :: ECSRevealState?
	local revealAttributes = self:_BuildRevealAttributes(entityId, instance, options)
	local revealTags = self:_BuildRevealTags(entityId, instance, options)
	local revealClearAttributes = self:_BuildRevealClearAttributes(entityId, instance, options)

	if identityOptions ~= nil then
		local _, builtRevealState = self:BuildIdentityRevealState(identityOptions)
		identityRevealState = builtRevealState
	end

	local customRevealState = self:MergeRevealStates(
		if revealAttributes ~= nil then {
			Attributes = revealAttributes,
		} else nil,
		if revealTags ~= nil then {
			Tags = revealTags,
		} else nil,
		if revealClearAttributes ~= nil then {
			ClearAttributes = revealClearAttributes,
		} else nil
	)

	return self:MergeRevealStates(identityRevealState, customRevealState)
end

--[=[
	Registers a reveal binding and applies reveal state immediately.
	@within BaseInstanceFactory
	@param entityId number -- Entity id owning the reveal binding.
	@param instance Instance -- Instance to reveal on clients.
	@param options any -- Factory-specific create options.
]=]
function BaseInstanceFactory:RegisterReveal(entityId: number, instance: Instance, options: any)
	local revealOptions = self:_BuildRevealIdentityOptions(entityId, instance, options)
	local revealState = self:BuildRevealState(entityId, instance, options)

	if revealState ~= nil then
		self:ApplyReveal(instance, revealState)
	end

	self._revealBindingsByEntity[entityId] = {
		EntityId = entityId,
		Instance = instance,
		CreateOptions = options,
		RevealOptions = revealOptions,
		LastRevealState = revealState,
	}
end

--[=[
	Rebuilds and reapplies reveal state for a previously registered reveal binding.
	@within BaseInstanceFactory
	@param entityId number -- Entity id whose reveal binding should refresh.
	@param optionsOverride any? -- Optional replacement options for the refresh.
	@return ECSRevealState? -- Refreshed reveal state or nil when no binding exists.
]=]
function BaseInstanceFactory:RefreshReveal(entityId: number, optionsOverride: any?): ECSRevealState?
	local binding = self._revealBindingsByEntity[entityId]
	if binding == nil then
		return nil
	end

	local nextOptions = optionsOverride or binding.CreateOptions
	local revealOptions = self:_BuildRevealIdentityOptions(entityId, binding.Instance, nextOptions)
	local revealState = self:BuildRevealState(entityId, binding.Instance, nextOptions)

	if revealState ~= nil then
		self:ApplyReveal(binding.Instance, revealState)
	end

	binding.CreateOptions = nextOptions
	binding.RevealOptions = revealOptions
	binding.LastRevealState = revealState
	return revealState
end

--[=[
	Creates, prepares, and registers the instance before reveal metadata is applied.
	@within BaseInstanceFactory
	@private
]=]
function BaseInstanceFactory:_CreateBoundInstance(entityId: number, options: any): Instance
	assert(type(entityId) == "number", ("%sInstanceFactory:_CreateBoundInstance requires entity id"):format(self._contextName))

	if self:HasInstance(entityId) then
		self:DestroyInstance(entityId)
	end

	local instance = self:_CreateInstanceForEntity(entityId, options)
	assert(instance ~= nil and instance:IsA("Instance"), ("%sInstanceFactory:_CreateInstanceForEntity must return an Instance"):format(self._contextName))

	self:_PrepareInstance(instance, entityId, options)
	instance.Parent = self:_GetRootFolderOrThrow()

	self._entityToInstance[entityId] = instance
	self._instanceToEntity[instance] = entityId
	self:RegisterReveal(entityId, instance, options)
	return instance
end

--[=[
	Returns the instance bound to an entity, if one exists.
	@within BaseInstanceFactory
	@param entityId number -- Entity id to resolve.
	@return Instance? -- Bound instance or nil.
]=]
function BaseInstanceFactory:GetInstance(entityId: number): Instance?
	return self._entityToInstance[entityId]
end

--[=[
	Returns the entity bound to an instance, if one exists.
	@within BaseInstanceFactory
	@param instance Instance -- Instance to resolve.
	@return number? -- Bound entity id or nil.
]=]
function BaseInstanceFactory:GetEntity(instance: Instance): number?
	return self._instanceToEntity[instance]
end

--[=[
	Returns whether the entity currently has a bound instance.
	@within BaseInstanceFactory
	@param entityId number -- Entity id to check.
	@return boolean -- True when a bound instance exists.
]=]
function BaseInstanceFactory:HasInstance(entityId: number): boolean
	return self._entityToInstance[entityId] ~= nil
end

--[=[
	Applies reveal metadata to an instance through the ECS utility facade.
	@within BaseInstanceFactory
	@param instance Instance? -- Instance to stamp.
	@param revealState ECSRevealState -- Reveal state contract.
]=]
function BaseInstanceFactory:ApplyReveal(instance: Instance, revealState: ECSRevealState)
	ECS.RevealApplier.Apply(instance, revealState)
end

--[=[
	Applies clear reveal metadata to an instance through the ECS utility facade.
	@within BaseInstanceFactory
	@param instance Instance? -- Instance to clear.
	@param clearState ECSRevealState? -- Clear-state contract.
]=]
function BaseInstanceFactory:ClearReveal(instance: Instance, clearState: ECSRevealState?)
	ECS.RevealApplier.Apply(instance, clearState)
end

--[=[
	Deletes the instance bound to an entity and clears its reveal binding.
	@within BaseInstanceFactory
	@param entityId number -- Entity id to destroy.
	@return boolean -- True when an instance was destroyed.
]=]
function BaseInstanceFactory:DestroyInstance(entityId: number): boolean
	local instance = self._entityToInstance[entityId]
	if instance == nil then
		return false
	end

	local clearState = self:_BuildClearRevealState(instance, entityId)
	if clearState ~= nil and instance.Parent ~= nil then
		self:ClearReveal(instance, clearState)
	end

	self._entityToInstance[entityId] = nil
	self._instanceToEntity[instance] = nil
	self._revealBindingsByEntity[entityId] = nil

	instance:Destroy()
	return true
end

--[=[
	Deletes every bound instance and clears all bindings.
	@within BaseInstanceFactory
]=]
function BaseInstanceFactory:DestroyAll()
	local entityIds = {}

	for entityId in self._entityToInstance do
		table.insert(entityIds, entityId)
	end

	for _, entityId in ipairs(entityIds) do
		self:DestroyInstance(entityId)
	end
end

return BaseInstanceFactory
