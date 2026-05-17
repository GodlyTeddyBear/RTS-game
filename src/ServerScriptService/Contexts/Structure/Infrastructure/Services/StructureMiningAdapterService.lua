--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AI = require(ReplicatedStorage.Utilities.AI)
local Result = require(ReplicatedStorage.Utilities.Result)
local StructureConfig = require(ReplicatedStorage.Contexts.Structure.Config.StructureConfig)
local StructureTypes = require(ReplicatedStorage.Contexts.Structure.Types.StructureTypes)
local Nodes = require(script.Parent.Parent.BehaviorSystem.Nodes)
local StructureExtractExecutor = require(script.Parent.Parent.BehaviorSystem.Executors.StructureExtractExecutor)
local StructureRuntimeProfiles = require(script.Parent.Parent.Runtime.Profiles.StructureRuntimeProfiles)
local StructureMiningFactsResolverFactory = require(script.Parent.Parent.Runtime.Resolvers.StructureMiningFactsResolverFactory)
local StructureFactoryProxyResolverFactory = require(script.Parent.Parent.Runtime.Resolvers.StructureFactoryProxyResolverFactory)
local StructureMiningProxyResolverFactory = require(script.Parent.Parent.Runtime.Resolvers.StructureMiningProxyResolverFactory)

type TStructureConfig = StructureTypes.TStructureConfig

local StructureMiningAdapterService = {}
StructureMiningAdapterService.__index = StructureMiningAdapterService

local StructureSemanticRequirements = table.freeze({
	FactsDependOnPolling = false,
	AttributesDependOnProjection = true,
})

local StructureRuntimeBinding = table.freeze({
	ServiceField = "_gameObjectSyncService",
	SyncPhase = "StructureSync",
})

local function _CloneActionState(actionState: any): any
	if type(actionState) ~= "table" then
		return {
			CurrentActionId = nil,
			ActionState = "Idle",
			ActionData = nil,
			PendingActionId = nil,
			PendingActionData = nil,
			StartedAt = nil,
			FinishedAt = nil,
		}
	end

	return {
		CurrentActionId = actionState.CurrentActionId,
		ActionState = actionState.ActionState or "Idle",
		ActionData = actionState.ActionData,
		PendingActionId = actionState.PendingActionId,
		PendingActionData = actionState.PendingActionData,
		StartedAt = actionState.StartedAt,
		FinishedAt = actionState.FinishedAt,
	}
end

function StructureMiningAdapterService.new()
	local self = setmetatable({}, StructureMiningAdapterService)
	self._runtimeOwner = nil
	self._pendingStructureEntitiesByInstanceId = {}
	self._instanceIdsByEntity = {}
	self._registeredActorHandlesByEntity = {}
	self._miningEntityFactory = nil
	self._extractorMiningSystem = nil
	self._miningProxyResolver = nil
	return self
end

function StructureMiningAdapterService:Init(registry: any, _name: string)
	self._entityFactory = registry:Get("StructureEntityFactory")
end

function StructureMiningAdapterService:Start(registry: any, _name: string)
	self._miningContext = registry:Get("MiningContext")
	self._factsResolver = StructureMiningFactsResolverFactory.Create({})
	self._structureFactoryProxyResolver = StructureFactoryProxyResolverFactory.Create({
		StructureEntityFactory = self._entityFactory,
	})
end

function StructureMiningAdapterService:ConfigureRuntimeOwner(runtimeOwner: any)
	self._runtimeOwner = runtimeOwner
end

function StructureMiningAdapterService:RegisterActorType(): Result.Result<boolean>
	return Result.Catch(function()
		AI.ValidateSemanticContract("Structure", StructureSemanticRequirements, StructureRuntimeBinding, {
			RuntimeOwner = self._runtimeOwner,
		})

		return self._miningContext:RegisterActorType({
			ActorType = "StructureExtractor",
			Conditions = Nodes.Conditions,
			Commands = Nodes.Commands,
			Executors = {
				["Structure.Extract"] = table.freeze({
					ActionId = "Structure.Extract",
					CreateExecutor = StructureExtractExecutor.new,
				}),
			},
			SemanticRequirements = StructureSemanticRequirements,
			RuntimeBinding = StructureRuntimeBinding,
			RuntimeOwner = self._runtimeOwner,
		})
	end, "Structure:RegisterMiningActorType")
end

function StructureMiningAdapterService:ShouldRegisterActor(entity: number): boolean
	local identity = self._entityFactory:GetIdentity(entity)
	if identity == nil then
		return false
	end

	local structureConfig = StructureConfig.STRUCTURES[identity.StructureType] :: TStructureConfig?
	if structureConfig == nil then
		return false
	end

	return structureConfig.RuntimeProfileId == "Extract"
end

function StructureMiningAdapterService:RegisterActor(entity: number): Result.Result<string>
	return Result.Catch(function()
		if not self:ShouldRegisterActor(entity) then
			return Result.Ok(self:GetActorHandle(entity))
		end

		local instanceRef = self._entityFactory:GetInstanceRef(entity)
		assert(instanceRef ~= nil, "StructureMiningAdapterService: missing instance ref for extractor actor")

		local runtimeProfile = StructureRuntimeProfiles.GetByVariant("Extract")
		self._entityFactory:SetBehaviorConfig(entity, {
			TickInterval = runtimeProfile.TickInterval,
		})
		self._instanceIdsByEntity[entity] = instanceRef.InstanceId
		self._pendingStructureEntitiesByInstanceId[instanceRef.InstanceId] = entity

		local resolveResult = self:ResolvePendingActor(instanceRef.InstanceId)
		if not resolveResult.success then
			return resolveResult
		end

		return Result.Ok(self:GetActorHandle(entity))
	end, "Structure:RegisterMiningActor")
end

function StructureMiningAdapterService:ResolvePendingActor(instanceId: number): Result.Result<boolean>
	return Result.Catch(function()
		if type(instanceId) ~= "number" then
			return Result.Ok(false)
		end

		local structureEntity = self._pendingStructureEntitiesByInstanceId[instanceId]
			or self._entityFactory:GetEntityByInstanceId(instanceId)
		if type(structureEntity) ~= "number" or not self:_IsStructureEntityActive(structureEntity) then
			return Result.Ok(false)
		end

		if self._registeredActorHandlesByEntity[structureEntity] ~= nil then
			self._pendingStructureEntitiesByInstanceId[instanceId] = nil
			return Result.Ok(true)
		end

		local refreshResult = self:_RefreshMiningDependencies()
		if not refreshResult.success then
			return refreshResult
		end

		if self._miningEntityFactory:FindExtractorByInstanceId(instanceId) == nil then
			self._pendingStructureEntitiesByInstanceId[instanceId] = structureEntity
			return Result.Ok(false)
		end

		local runtimeProfile = StructureRuntimeProfiles.GetByVariant("Extract")
		local actorHandle = self:_BuildActorHandle(structureEntity)
		local registerResult = self._miningContext:RegisterMiningActor({
			ActorType = "StructureExtractor",
			ActorHandle = actorHandle,
			BehaviorDefinition = runtimeProfile.BehaviorDefinition,
			TickInterval = runtimeProfile.TickInterval,
			Adapter = {
				IsActive = function(): boolean
					return self:_IsStructureEntityActive(structureEntity) and self:_IsMiningEntityActive(instanceId)
				end,
				GetActorLabel = function(): string?
					return actorHandle
				end,
				BuildFacts = function(_currentTime: number): { [string]: any }
					return self._factsResolver.BuildFacts(structureEntity)
				end,
				BuildServices = function(currentTime: number, tickId: number?): { [string]: any }
					return self:_BuildServices(structureEntity, instanceId, currentTime, tickId)
				end,
				OnActionStateChanged = function(actionState: any)
					if self:_IsStructureEntityActive(structureEntity) then
						self._entityFactory:SetCombatAction(structureEntity, _CloneActionState(actionState))
					end
				end,
				OnRemoved = function()
					self._registeredActorHandlesByEntity[structureEntity] = nil
					self._instanceIdsByEntity[structureEntity] = nil
					self._pendingStructureEntitiesByInstanceId[instanceId] = nil
					if self:_IsStructureEntityActive(structureEntity) then
						self._entityFactory:ClearAction(structureEntity)
					end
				end,
			},
		})
		if not registerResult.success then
			return registerResult
		end

		self._registeredActorHandlesByEntity[structureEntity] = actorHandle
		self._pendingStructureEntitiesByInstanceId[instanceId] = nil
		return Result.Ok(true)
	end, "Structure:ResolveMiningActor")
end

function StructureMiningAdapterService:UnregisterActor(entity: number): Result.Result<boolean>
	return Result.Catch(function()
		if not self:ShouldRegisterActor(entity) then
			return Result.Ok(false)
		end

		local instanceId = self._instanceIdsByEntity[entity]
		local actorHandle = self._registeredActorHandlesByEntity[entity]
		self._registeredActorHandlesByEntity[entity] = nil
		self._instanceIdsByEntity[entity] = nil

		if type(instanceId) == "number" then
			self._pendingStructureEntitiesByInstanceId[instanceId] = nil
		end

		if actorHandle == nil then
			if self:_IsStructureEntityActive(entity) then
				self._entityFactory:ClearAction(entity)
			end
			return Result.Ok(false)
		end

		return self._miningContext:UnregisterMiningActor(actorHandle)
	end, "Structure:UnregisterMiningActor")
end

function StructureMiningAdapterService:GetActorHandle(entity: number): string
	local actorHandle = self._registeredActorHandlesByEntity[entity]
	if actorHandle ~= nil then
		return actorHandle
	end

	return self:_BuildActorHandle(entity)
end

function StructureMiningAdapterService:_BuildServices(
	entity: number,
	instanceId: number,
	currentTime: number,
	tickId: number?
): { [string]: any }
	local services = {
		StructureEntityFactory = self._structureFactoryProxyResolver.CreateProxy(entity),
		MiningExtractorProxy = self._miningProxyResolver.CreateProxy(instanceId),
		CurrentTime = currentTime,
	}

	if type(tickId) == "number" then
		services.TickId = tickId
	end

	return services
end

function StructureMiningAdapterService:_BuildActorHandle(entity: number): string
	return "StructureExtractorEntity:" .. tostring(entity)
end

function StructureMiningAdapterService:_RefreshMiningDependencies(): Result.Result<boolean>
	if self._miningEntityFactory ~= nil and self._extractorMiningSystem ~= nil and self._miningProxyResolver ~= nil then
		return Result.Ok(true)
	end

	local miningEntityFactoryResult = self._miningContext:GetEntityFactory()
	if not miningEntityFactoryResult.success or miningEntityFactoryResult.value == nil then
		return miningEntityFactoryResult
	end

	local extractorMiningSystemResult = self._miningContext:GetExtractorMiningSystem()
	if not extractorMiningSystemResult.success or extractorMiningSystemResult.value == nil then
		return extractorMiningSystemResult
	end

	self._miningEntityFactory = miningEntityFactoryResult.value
	self._extractorMiningSystem = extractorMiningSystemResult.value
	self._miningProxyResolver = StructureMiningProxyResolverFactory.Create({
		MiningEntityFactory = self._miningEntityFactory,
		ExtractorMiningSystem = self._extractorMiningSystem,
	})

	return Result.Ok(true)
end

function StructureMiningAdapterService:_IsStructureEntityActive(entity: number): boolean
	local didCheck, isActive = pcall(function(): boolean
		return self._entityFactory:IsActive(entity)
	end)

	return didCheck and isActive == true
end

function StructureMiningAdapterService:_IsMiningEntityActive(instanceId: number): boolean
	local refreshResult = self:_RefreshMiningDependencies()
	if not refreshResult.success then
		return false
	end

	local miningEntity = self._miningEntityFactory:FindExtractorByInstanceId(instanceId)
	return self._miningEntityFactory:IsActive(miningEntity)
end

return StructureMiningAdapterService
