--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local BaseECSReplicationService = require(ServerStorage.Utilities.ECSUtilities.BaseECSReplicationService)

local Errors = require(script.Parent.Parent.Parent.Errors)

local EntityReplicationService = {}
EntityReplicationService.__index = EntityReplicationService
setmetatable(EntityReplicationService, { __index = BaseECSReplicationService })

function EntityReplicationService.new()
	local self = setmetatable(BaseECSReplicationService.new("Entity"), EntityReplicationService)
	self._clientSignals = nil
	self._replicationRegistry = nil
	self._runtimeParticipation = nil
	self._schemaRegistry = nil
	self._enabledFeatures = {}
	self._registeredEntities = {}
	return self
end

function EntityReplicationService:_GetComponentRegistryName(): string
	return "EntitySchemaRegistry"
end

function EntityReplicationService:_GetEntityFactoryName(): string
	return "EntityEntityFactory"
end

function EntityReplicationService:_OnInit(registry: any, _name: string)
	self._clientSignals = registry:Get("ClientSignals")
	self._replicationRegistry = registry:Get("EntityReplicationRegistry")
	self._runtimeParticipation = registry:Get("EntityRuntimeParticipationService")
	self._schemaRegistry = registry:Get("EntitySchemaRegistry")
	assert(self._clientSignals ~= nil, "EntityReplicationService: missing ClientSignals")
	assert(self._replicationRegistry ~= nil, "EntityReplicationService: missing EntityReplicationRegistry")
	assert(self._runtimeParticipation ~= nil, "EntityReplicationService: missing EntityRuntimeParticipationService")
	assert(self._schemaRegistry ~= nil, "EntityReplicationService: missing EntitySchemaRegistry")
end

function EntityReplicationService:_GetSharedSchema()
	return nil
end

function EntityReplicationService:_RegisterReplicatedSurface(_registry: any)
	return
end

function EntityReplicationService:_SendBootstrap(player: Player, payload: any)
	payload.SchemaMetadata = self:_BuildClientSchemaMetadata()
	self._clientSignals.EntityBootstrap:Fire(player, payload)
end

function EntityReplicationService:_SendReliable(player: Player, payload: any)
	self._clientSignals.EntityReliable:Fire(player, payload)
end

function EntityReplicationService:_SendUnreliable(player: Player, payload: any)
	self._clientSignals.EntityUnreliable:Fire(player, payload)
end

function EntityReplicationService:_SendEntity(player: Player, payload: any)
	self._clientSignals.EntityEntity:Fire(player, payload)
end

function EntityReplicationService:BuildFeatureSchema(entityContext: any, featureName: string): Result.Result<any?>
	return Result.Catch(function()
		local surface = self._replicationRegistry:GetReplicationSurface(featureName)
		if surface == nil then
			return Result.Err("UnknownReplicationSurface", Errors.UNKNOWN_REPLICATION_SURFACE, {
				FeatureName = featureName,
			})
		end

		local fallbackSchema = {
			sharedComponents = surface.SharedComponents,
			sharedTags = surface.SharedTags,
		}

		if type(surface.BuildSchema) ~= "function" then
			return Result.Ok(self:_AugmentSharedSchemaWithRuntimeMetadata(fallbackSchema))
		end

		local didBuild, schema = pcall(surface.BuildSchema, entityContext)
		if not didBuild or type(schema) ~= "table" then
			return Result.Err("InvalidReplicationSurface", Errors.INVALID_REPLICATION_SURFACE, {
				FeatureName = featureName,
				Reason = "BuildSchemaFailed",
				CauseMessage = schema,
			})
		end

		if schema.sharedComponents == nil then
			schema.sharedComponents = fallbackSchema.sharedComponents
		end
		if schema.sharedTags == nil then
			schema.sharedTags = fallbackSchema.sharedTags
		end

		schema = self:_AugmentSharedSchemaWithRuntimeMetadata(schema)

		return Result.Ok(schema)
	end, "EntityReplicationService:BuildFeatureSchema")
end

function EntityReplicationService:_AugmentSharedSchemaWithRuntimeMetadata(schema: any)
	local runtimeMetadataComponents = self._schemaRegistry:GetRuntimeMetadataComponents()
	local coreSchema = self._schemaRegistry:GetCoreCompiledSchema()
	if runtimeMetadataComponents == nil and coreSchema == nil then
		return schema
	end

	local sharedComponents = {}
	if type(schema.sharedComponents) == "table" then
		for _, componentId in ipairs(schema.sharedComponents) do
			table.insert(sharedComponents, componentId)
		end
	end

	local function canReplicate(componentId: any): boolean
		local metadata = self._schemaRegistry:GetComponentMetadataById(componentId)
		return metadata ~= nil and metadata.Replication ~= "ServerOnly"
	end

	local function appendUnique(componentId: any)
		if not canReplicate(componentId) then
			return
		end
		for _, existing in ipairs(sharedComponents) do
			if existing == componentId then
				return
			end
		end
		table.insert(sharedComponents, componentId)
	end

	local sharedTags = {}
	if type(schema.sharedTags) == "table" then
		for _, tagId in ipairs(schema.sharedTags) do
			table.insert(sharedTags, tagId)
		end
	end

	local function appendUniqueTag(tagId: any)
		if not canReplicate(tagId) then
			return
		end
		for _, existing in ipairs(sharedTags) do
			if existing == tagId then
				return
			end
		end
		table.insert(sharedTags, tagId)
	end

	if runtimeMetadataComponents ~= nil then
		appendUnique(runtimeMetadataComponents.FeatureNameComponent)
		appendUnique(runtimeMetadataComponents.ArchetypeNameComponent)
	end

	if coreSchema ~= nil then
		for _, componentId in pairs(coreSchema.Components) do
			appendUnique(componentId)
		end
		for _, tagId in pairs(coreSchema.Tags) do
			appendUniqueTag(tagId)
		end
	end

	local nextSchema = table.clone(schema)
	nextSchema.sharedComponents = sharedComponents
	nextSchema.sharedTags = sharedTags
	return nextSchema
end

function EntityReplicationService:_BuildClientSchemaMetadata()
	if not self:HasAppliedSharedSchema() then
		return {
			SharedComponents = {},
			SharedTags = {},
		}
	end

	local metadata = {
		SharedComponents = {},
		SharedTags = {},
	}

	for componentId in self._schemaState.SharedComponents do
		local componentMetadata = self._schemaRegistry:GetComponentMetadataById(componentId)
		if componentMetadata ~= nil then
			table.insert(metadata.SharedComponents, {
				ECSName = componentMetadata.ECSName,
				FeatureName = componentMetadata.FeatureName,
				Key = componentMetadata.Key,
			})
		end
	end

	for tagId in self._schemaState.SharedTags do
		local tagMetadata = self._schemaRegistry:GetComponentMetadataById(tagId)
		if tagMetadata ~= nil then
			table.insert(metadata.SharedTags, {
				ECSName = tagMetadata.ECSName,
				FeatureName = tagMetadata.FeatureName,
				Key = tagMetadata.Key,
			})
		end
	end

	table.sort(metadata.SharedComponents, function(left, right)
		return left.ECSName < right.ECSName
	end)
	table.sort(metadata.SharedTags, function(left, right)
		return left.ECSName < right.ECSName
	end)

	return metadata
end

function EntityReplicationService:EnableFeature(entityContext: any, featureName: string): Result.Result<boolean>
	return Result.Catch(function()
		if self._enabledFeatures[featureName] == true then
			return Result.Ok(true)
		end

		local schemaResult = self:BuildFeatureSchema(entityContext, featureName)
		if not schemaResult.success then
			return schemaResult
		end

		if schemaResult.value ~= nil then
			self:ApplySharedSchema(schemaResult.value)
		end

		self._enabledFeatures[featureName] = true
		return Result.Ok(true)
	end, "EntityReplicationService:EnableFeature")
end

function EntityReplicationService:RegisterRuntimeEntity(entityContext: any, entity: number): Result.Result<boolean>
	return Result.Catch(function()
		local featureName = self._runtimeParticipation:GetFeatureName(entity)
		if featureName == nil or self._enabledFeatures[featureName] ~= true then
			return Result.Ok(false)
		end

		if self._registeredEntities[entity] == true then
			return Result.Ok(true)
		end

		local surface = self._replicationRegistry:GetReplicationSurface(featureName)
		if surface == nil then
			return Result.Err("UnknownReplicationSurface", Errors.UNKNOWN_REPLICATION_SURFACE, {
				Entity = entity,
				FeatureName = featureName,
			})
		end

		if type(surface.RegisterEntity) == "function" then
			local didRegister, registerError = pcall(surface.RegisterEntity, entityContext, entity)
			if not didRegister then
				return Result.Err("InvalidReplicationSurface", Errors.INVALID_REPLICATION_SURFACE, {
					Entity = entity,
					FeatureName = featureName,
					Reason = "RegisterEntityFailed",
					CauseMessage = registerError,
				})
			end
		else
			self:RegisterNetworkedEntity(entity)
		end

		self._registeredEntities[entity] = true
		return Result.Ok(true)
	end, "EntityReplicationService:RegisterRuntimeEntity")
end

function EntityReplicationService:UnregisterRuntimeEntity(entityContext: any, entity: number): Result.Result<boolean>
	return Result.Catch(function()
		if self._registeredEntities[entity] ~= true then
			return Result.Ok(false)
		end

		local featureName = self._runtimeParticipation:GetFeatureName(entity)
		if featureName ~= nil then
			local surface = self._replicationRegistry:GetReplicationSurface(featureName)
			if surface ~= nil and type(surface.UnregisterEntity) == "function" then
				pcall(surface.UnregisterEntity, entityContext, entity)
			else
				self:StopReplicatingEntity(entity)
			end
		else
			self:StopReplicatingEntity(entity)
		end

		self._registeredEntities[entity] = nil
		return Result.Ok(true)
	end, "EntityReplicationService:UnregisterRuntimeEntity")
end

function EntityReplicationService:HydratePlayerResult(player: Player): Result.Result<boolean>
	return Result.Catch(function()
		return Result.Ok(self:HydratePlayer(player))
	end, "EntityReplicationService:HydratePlayerResult")
end

function EntityReplicationService:CompleteBootstrapResult(player: Player): Result.Result<boolean>
	return Result.Catch(function()
		return Result.Ok(self:CompleteBootstrap(player))
	end, "EntityReplicationService:CompleteBootstrapResult")
end

function EntityReplicationService:FlushReliableResult(): Result.Result<boolean>
	return Result.Catch(function()
		self:FlushReliable()
		return Result.Ok(true)
	end, "EntityReplicationService:FlushReliableResult")
end

function EntityReplicationService:FlushUnreliableResult(): Result.Result<boolean>
	return Result.Catch(function()
		self:FlushUnreliable()
		return Result.Ok(true)
	end, "EntityReplicationService:FlushUnreliableResult")
end

function EntityReplicationService:FlushEntityResult(entity: number): Result.Result<number>
	return Result.Catch(function()
		return Result.Ok(self:CollectEntityPackets(entity))
	end, "EntityReplicationService:FlushEntityResult")
end

function EntityReplicationService:GetStatus(): any
	local enabledFeatureCount = 0
	for _ in pairs(self._enabledFeatures) do
		enabledFeatureCount += 1
	end

	local registeredEntityCount = 0
	for _ in pairs(self._registeredEntities) do
		registeredEntityCount += 1
	end

	return table.freeze({
		BootCapable = self._clientSignals ~= nil
			and self._replicationRegistry ~= nil
			and self._runtimeParticipation ~= nil
			and self._schemaRegistry ~= nil,
		EnabledFeatureCount = enabledFeatureCount,
		RegisteredEntityCount = registeredEntityCount,
		HasAppliedSharedSchema = self:GetAppliedSharedSchema() ~= nil,
	})
end

function EntityReplicationService:Destroy()
	BaseECSReplicationService.Destroy(self)
	self._enabledFeatures = {}
	self._registeredEntities = {}
end

return EntityReplicationService
