--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Result = require(ReplicatedStorage.Utilities.Result)

local Errors = require(script.Parent.Parent.Parent.Errors)

local function _FindOrCreateFolder(parent: Instance, name: string): Folder
	local existing = parent:FindFirstChild(name)
	if existing ~= nil and existing:IsA("Folder") then
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function _ResolvePath(root: Instance, path: string): Instance?
	local current = root
	for segment in string.gmatch(path, "[^/%.]+") do
		current = current:FindFirstChild(segment)
		if current == nil then
			return nil
		end
	end

	return current
end

local function _DeepClone(value: any): any
	if type(value) ~= "table" then
		return value
	end

	local clone = {}
	for key, nestedValue in pairs(value) do
		clone[key] = _DeepClone(nestedValue)
	end
	return clone
end

local function _BuildClearRevealState(lastRevealState: any?): any?
	if lastRevealState == nil then
		return nil
	end

	local clearAttributes = {}
	local tags = {}

	if type(lastRevealState.Attributes) == "table" then
		for attributeName in pairs(lastRevealState.Attributes) do
			table.insert(clearAttributes, attributeName)
		end
	end

	if type(lastRevealState.ClearAttributes) == "table" then
		for _, attributeName in ipairs(lastRevealState.ClearAttributes) do
			table.insert(clearAttributes, attributeName)
		end
	end

	if type(lastRevealState.Tags) == "table" then
		for tagName in pairs(lastRevealState.Tags) do
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

local function _BuildRevealState(compiledBinding: any, entityContext: any, snapshot: any): any?
	local attributes = nil
	local tags = nil
	local clearAttributes = nil

	if type(compiledBinding.BuildRevealAttributes) == "function" then
		attributes = compiledBinding.BuildRevealAttributes(entityContext, snapshot)
		if attributes ~= nil and type(attributes) ~= "table" then
			attributes = nil
		end
	end

	if type(compiledBinding.BuildRevealTags) == "function" then
		tags = compiledBinding.BuildRevealTags(entityContext, snapshot)
		if tags ~= nil and type(tags) ~= "table" then
			tags = nil
		end
	end

	if type(compiledBinding.BuildRevealClearAttributes) == "function" then
		clearAttributes = compiledBinding.BuildRevealClearAttributes(entityContext, snapshot)
		if clearAttributes ~= nil and type(clearAttributes) ~= "table" then
			clearAttributes = nil
		end
	end

	if attributes == nil and tags == nil and clearAttributes == nil then
		return nil
	end

	return {
		Attributes = attributes,
		Tags = tags,
		ClearAttributes = clearAttributes,
	}
end

local EntityInstanceBindingService = {}
EntityInstanceBindingService.__index = EntityInstanceBindingService

function EntityInstanceBindingService.new()
	local self = setmetatable({}, EntityInstanceBindingService)
	self._bindingRegistry = nil
	self._revealService = nil
	self._snapshotBuilder = nil
	self._rootFolder = nil
	self._entityToBinding = {}
	self._instanceToEntity = {}
	self._pendingBindQueue = {}
	self._pendingBindCounts = {}
	return self
end

function EntityInstanceBindingService:Init(registry: any, _name: string)
	self._bindingRegistry = registry:Get("EntityInstanceBindingRegistry")
	self._revealService = registry:Get("EntityRevealService")
	self._snapshotBuilder = registry:Get("EntityRuntimeSnapshotBuilder")
	self._rootFolder = _FindOrCreateFolder(Workspace, "EntityRuntime")
end

function EntityInstanceBindingService:BindEntityInstance(entityContext: any, entity: number): Result.Result<Instance?>
	return Result.Catch(function()
		local snapshotResult = self._snapshotBuilder:BuildSnapshot(entity)
		if not snapshotResult.success then
			return snapshotResult
		end

		local snapshot = snapshotResult.value
		local compiledBinding = self._bindingRegistry:GetBinding(snapshot.FeatureName)
		if compiledBinding == nil then
			return Result.Err("UnknownInstanceBinding", Errors.UNKNOWN_INSTANCE_BINDING, {
				Entity = entity,
				FeatureName = snapshot.FeatureName,
			})
		end

		self:UnbindEntityInstance(entity)

		local assetResult = self:_ResolveAsset(compiledBinding, entityContext, snapshot)
		if not assetResult.success then
			return assetResult
		end

		local instance = assetResult.value
		local parentFolder = self:_ResolveParentFolder(compiledBinding, entityContext, snapshot)
		if not parentFolder.success then
			instance:Destroy()
			return parentFolder
		end

		local preparedResult = self:_PrepareInstance(compiledBinding, entityContext, instance, snapshot)
		if not preparedResult.success then
			instance:Destroy()
			return preparedResult
		end

		local buildName = compiledBinding.BuildName
		if type(buildName) == "function" then
			local didBuildName, nextName = pcall(buildName, entityContext, snapshot)
			if didBuildName and type(nextName) == "string" and nextName ~= "" then
				instance.Name = nextName
			end
		end

		instance.Parent = parentFolder.value

		local revealState = _BuildRevealState(compiledBinding, entityContext, snapshot)
		if revealState ~= nil then
			self._revealService:Apply(instance, revealState)
		end

		local actorKind = nil
		if type(compiledBinding.BuildActorKind) == "function" then
			local didBuildActorKind, nextActorKind = pcall(compiledBinding.BuildActorKind, entityContext, entity)
			if didBuildActorKind and type(nextActorKind) == "string" and nextActorKind ~= "" then
				actorKind = nextActorKind
			end
		end

		local bindingRecord = {
			Entity = entity,
			FeatureName = snapshot.FeatureName,
			Instance = instance,
			LastRevealState = revealState and _DeepClone(revealState) or nil,
			Snapshot = snapshot,
			ActorKind = actorKind,
		}

		self._entityToBinding[entity] = bindingRecord
		self._instanceToEntity[instance] = entity
		return Result.Ok(instance)
	end, "EntityInstanceBindingService:BindEntityInstance")
end

function EntityInstanceBindingService:UnbindEntityInstance(entity: number): Result.Result<boolean>
	return Result.Catch(function()
		local bindingRecord = self._entityToBinding[entity]
		if bindingRecord == nil then
			return Result.Ok(false)
		end

		local instance = bindingRecord.Instance
		local clearRevealState = _BuildClearRevealState(bindingRecord.LastRevealState)
		if instance.Parent ~= nil and clearRevealState ~= nil then
			self._revealService:Apply(instance, clearRevealState)
		end

		self._entityToBinding[entity] = nil
		self._instanceToEntity[instance] = nil
		instance:Destroy()
		return Result.Ok(true)
	end, "EntityInstanceBindingService:UnbindEntityInstance")
end

function EntityInstanceBindingService:GetBoundInstance(entity: number): Instance?
	local bindingRecord = self._entityToBinding[entity]
	if bindingRecord == nil then
		return nil
	end

	return bindingRecord.Instance
end

function EntityInstanceBindingService:GetBoundEntity(instance: Instance): number?
	local current = instance
	while current ~= nil do
		local entity = self._instanceToEntity[current]
		if entity ~= nil then
			return entity
		end
		current = current.Parent
	end

	return nil
end

function EntityInstanceBindingService:QueueEntityBind(entity: number): Result.Result<boolean>
	return Result.Catch(function()
		local snapshotResult = self._snapshotBuilder:BuildSnapshot(entity)
		if not snapshotResult.success then
			return snapshotResult
		end

		if (self._pendingBindCounts[entity] or 0) > 0 then
			return Result.Ok(true)
		end

		table.insert(self._pendingBindQueue, entity)
		self._pendingBindCounts[entity] = 1
		return Result.Ok(true)
	end, "EntityInstanceBindingService:QueueEntityBind")
end

function EntityInstanceBindingService:ClearQueuedBind(entity: number)
	self._pendingBindCounts[entity] = nil
end

function EntityInstanceBindingService:FlushBindQueue(
	entityContext: any,
	onBound: ((number, Instance) -> ())?
): Result.Result<number>
	return Result.Catch(function()
		if #self._pendingBindQueue == 0 then
			return Result.Ok(0)
		end

		local queuedEntities = table.clone(self._pendingBindQueue)
		table.clear(self._pendingBindQueue)
		table.clear(self._pendingBindCounts)

		local boundCount = 0
		for _, entity in ipairs(queuedEntities) do
			local bindResult = self:BindEntityInstance(entityContext, entity)
			if bindResult.success and bindResult.value ~= nil then
				boundCount += 1
				if onBound ~= nil then
					onBound(entity, bindResult.value)
				end
			end
		end

		return Result.Ok(boundCount)
	end, "EntityInstanceBindingService:FlushBindQueue")
end

function EntityInstanceBindingService:DestroyAll()
	local entities = {}
	for entity in pairs(self._entityToBinding) do
		table.insert(entities, entity)
	end

	for _, entity in ipairs(entities) do
		self:UnbindEntityInstance(entity)
	end

	table.clear(self._pendingBindQueue)
	table.clear(self._pendingBindCounts)
end

function EntityInstanceBindingService:GetStatus(): any
	local boundEntityCount = 0
	for _ in pairs(self._entityToBinding) do
		boundEntityCount += 1
	end

	local pendingBindCount = 0
	for _ in pairs(self._pendingBindCounts) do
		pendingBindCount += 1
	end

	return table.freeze({
		BoundEntityCount = boundEntityCount,
		PendingBindCount = pendingBindCount,
		HasRuntimeRootFolder = self._rootFolder ~= nil,
	})
end

function EntityInstanceBindingService:_ResolveAsset(compiledBinding: any, entityContext: any, snapshot: any): Result.Result<Instance>
	local didResolve, assetOrPath = pcall(compiledBinding.ResolveAsset, entityContext, snapshot)
	if not didResolve then
		return Result.Err("InvalidInstanceBinding", Errors.INVALID_INSTANCE_BINDING, {
			FeatureName = snapshot.FeatureName,
			Entity = snapshot.Entity,
			Reason = "ResolveAssetFailed",
			CauseMessage = assetOrPath,
		})
	end

	if type(assetOrPath) == "string" then
		local assetsRoot = ReplicatedStorage:FindFirstChild("Assets")
		local resolved = nil
		if assetsRoot ~= nil then
			resolved = _ResolvePath(assetsRoot, assetOrPath)
		end
		if resolved == nil then
			resolved = _ResolvePath(ReplicatedStorage, assetOrPath)
		end
		assetOrPath = resolved
	end

	if typeof(assetOrPath) ~= "Instance" then
		return Result.Err("UnsupportedBindingAsset", Errors.UNSUPPORTED_BINDING_ASSET, {
			FeatureName = snapshot.FeatureName,
			Entity = snapshot.Entity,
			AssetType = typeof(assetOrPath),
		})
	end

	if assetOrPath.Parent == nil then
		return Result.Ok(assetOrPath)
	end

	local didClone, cloned = pcall(function()
		return assetOrPath:Clone()
	end)
	if didClone and typeof(cloned) == "Instance" then
		return Result.Ok(cloned)
	end

	return Result.Err("UnsupportedBindingAsset", Errors.UNSUPPORTED_BINDING_ASSET, {
		FeatureName = snapshot.FeatureName,
		Entity = snapshot.Entity,
		AssetName = assetOrPath.Name,
	})
end

function EntityInstanceBindingService:_ResolveParentFolder(
	compiledBinding: any,
	entityContext: any,
	snapshot: any
): Result.Result<Instance>
	if type(compiledBinding.ResolveParentFolder) ~= "function" then
		return Result.Ok(self._rootFolder)
	end

	local didResolve, parentFolder = pcall(compiledBinding.ResolveParentFolder, entityContext, snapshot)
	if not didResolve then
		return Result.Err("InvalidInstanceBinding", Errors.INVALID_INSTANCE_BINDING, {
			FeatureName = snapshot.FeatureName,
			Entity = snapshot.Entity,
			Reason = "ResolveParentFolderFailed",
			CauseMessage = parentFolder,
		})
	end

	if parentFolder == nil then
		return Result.Ok(self._rootFolder)
	end

	if typeof(parentFolder) ~= "Instance" then
		return Result.Err("InvalidInstanceBinding", Errors.INVALID_INSTANCE_BINDING, {
			FeatureName = snapshot.FeatureName,
			Entity = snapshot.Entity,
			Reason = "ResolveParentFolderFailed",
			CauseMessage = tostring(parentFolder),
		})
	end

	return Result.Ok(parentFolder)
end

function EntityInstanceBindingService:_PrepareInstance(
	compiledBinding: any,
	entityContext: any,
	instance: Instance,
	snapshot: any
): Result.Result<boolean>
	if type(compiledBinding.PrepareInstance) ~= "function" then
		return Result.Ok(true)
	end

	local didPrepare, prepareError = pcall(compiledBinding.PrepareInstance, entityContext, instance, snapshot)
	if not didPrepare then
		return Result.Err("InvalidInstanceBinding", Errors.INVALID_INSTANCE_BINDING, {
			FeatureName = snapshot.FeatureName,
			Entity = snapshot.Entity,
			Reason = "PrepareInstanceFailed",
			CauseMessage = prepareError,
		})
	end

	return Result.Ok(true)
end

return EntityInstanceBindingService
