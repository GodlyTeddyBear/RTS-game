--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local AI = require(ServerStorage.Utilities.ContextUtilities.AI)
local Result = require(ReplicatedStorage.Utilities.Result)
local SetupValidationPolicy = require(script.Policies.SetupValidationPolicy)

local Ok = Result.Ok
local Err = Result.Err

export type TBaseAIRuntimeErrors = {
	RUNTIME_ALREADY_STARTED: string,
	RUNTIME_START_FAILED: string,
	RUNTIME_NOT_STARTED: string,
}

export type TBaseAIRuntimeConfig = {
	RuntimeLabel: string,
	ActorRegistryServiceName: string,
	BaseHooks: { any },
	Errors: TBaseAIRuntimeErrors,
	UseDirectCombatHookPath: boolean?,
	UseCachedActiveEntityProvider: boolean?,
	UseRuntimeQueue: boolean?,
	MaxActorsPerTick: number?,
}

export type TBaseAIRuntimeService = typeof(setmetatable({} :: {
	_runtime: any,
	_actorRegistryService: any,
	_runtimeLabel: string,
	_runtimeContextLabel: string,
	_runtimeDisplayName: string,
	_actorRegistryServiceName: string,
	_baseHooks: { any },
	_errors: TBaseAIRuntimeErrors,
	_useDirectCombatHookPath: boolean,
	_useCachedActiveEntityProvider: boolean,
	_useRuntimeQueue: boolean,
	_maxActorsPerTick: number?,
}, {} :: any))

type Result<T> = Result.Result<T>

type TMergedRuntimeInputs = {
	Conditions: { [string]: (any?) -> any },
	Commands: { [string]: (any?) -> any },
	Executors: { [string]: any },
	Hooks: { any },
}

--[=[
	@class BaseAIRuntimeService
	Shared AI runtime helper for context-owned runtime services.
	@server
]=]
local BaseAIRuntimeService = {}
BaseAIRuntimeService.__index = BaseAIRuntimeService

function BaseAIRuntimeService.new(config: TBaseAIRuntimeConfig): TBaseAIRuntimeService
	local contextLabel = config.RuntimeLabel:match("^(.-):") or config.RuntimeLabel
	local self = setmetatable({}, BaseAIRuntimeService)

	if config.UseRuntimeQueue == true then
		assert(
			type(config.MaxActorsPerTick) == "number"
				and config.MaxActorsPerTick > 0
				and math.floor(config.MaxActorsPerTick) == config.MaxActorsPerTick,
			"BaseAIRuntimeService MaxActorsPerTick must be a positive integer when UseRuntimeQueue is enabled"
		)
	end

	self._runtime = nil
	self._actorRegistryService = nil
	self._runtimeLabel = config.RuntimeLabel
	self._runtimeContextLabel = contextLabel
	self._runtimeDisplayName = string.lower(contextLabel)
	self._actorRegistryServiceName = config.ActorRegistryServiceName
	self._baseHooks = table.clone(config.BaseHooks)
	self._errors = config.Errors
	self._useDirectCombatHookPath = config.UseDirectCombatHookPath == true
	self._useCachedActiveEntityProvider = config.UseCachedActiveEntityProvider == true
	self._useRuntimeQueue = config.UseRuntimeQueue == true
	self._maxActorsPerTick = config.MaxActorsPerTick

	return self
end

function BaseAIRuntimeService:Init(registry: any, _name: string)
	self._actorRegistryService = registry:Get(self._actorRegistryServiceName)
end

function BaseAIRuntimeService:StartRuntime(): Result<boolean>
	if self._actorRegistryService:IsRuntimeStarted() then
		return Err("RuntimeAlreadyStarted", self._errors.RUNTIME_ALREADY_STARTED)
	end

	local actorTypePayloads = self._actorRegistryService:GetActorTypePayloads()
	if #actorTypePayloads == 0 then
		return Err("RuntimeStartFailed", self._errors.RUNTIME_START_FAILED, {
			Reason = "NoActorTypesRegistered",
		})
	end

	local actorTypeNames = {}
	for _, actorTypePayload in ipairs(actorTypePayloads) do
		table.insert(actorTypeNames, actorTypePayload.ActorType)
	end

	Result.MentionEvent(self._runtimeLabel, ("Starting %s runtime"):format(self._runtimeDisplayName), {
		ActorTypeCount = #actorTypePayloads,
		ActorTypes = actorTypeNames,
	})

	local buildStage = "BuildRuntimeInputs"
	local didBuild, buildResult = pcall(function()
		buildStage = "BuildRuntimeInputs"
		local mergedInputs = self:_BuildRuntimeInputs()

		buildStage = "CreateRuntime"
		local runtime = AI.CreateRuntime({
			Conditions = mergedInputs.Conditions,
			Commands = mergedInputs.Commands,
			Hooks = mergedInputs.Hooks,
			ErrorSink = self:_BuildErrorSink(),
			UseDirectCombatHookPath = self._useDirectCombatHookPath,
			UseCachedActiveEntityProvider = self._useCachedActiveEntityProvider,
		})

		buildStage = "RegisterExecutors"
		runtime:RegisterActions(mergedInputs.Executors)
		for _, actorTypePayload in ipairs(actorTypePayloads) do
			buildStage = "RegisterActorType:" .. actorTypePayload.ActorType
			runtime:RegisterActorType(actorTypePayload.ActorType, self:_CreateRegistryAdapter(actorTypePayload.ActorType))
		end

		return runtime
	end)

	if not didBuild then
		Result.MentionError(self._runtimeLabel, ("%s runtime build failed"):format(self._runtimeContextLabel), {
			Stage = buildStage,
			ActorTypeCount = #actorTypePayloads,
			ActorTypes = actorTypeNames,
			CauseMessage = buildResult,
		}, "RuntimeStartFailed")
		return Err("RuntimeStartFailed", self._errors.RUNTIME_START_FAILED, {
			Stage = buildStage,
			CauseMessage = buildResult,
		})
	end

	self._runtime = buildResult
	self._actorRegistryService:SetRuntimeStarted(true)

	Result.MentionSuccess(self._runtimeLabel, ("%s runtime started"):format(self._runtimeContextLabel), {
		ActorTypeCount = #actorTypePayloads,
		ActorTypes = actorTypeNames,
	})

	local queueResult = self:_RegisterQueuedActors()
	if not queueResult.success then
		self._runtime = nil
		self._actorRegistryService:SetRuntimeStarted(false)
		return queueResult
	end

	return Ok(true)
end

function BaseAIRuntimeService:StopRuntime(): Result<boolean>
	if not self._actorRegistryService:IsRuntimeStarted() then
		return Ok(false)
	end

	self._runtime = nil
	self._actorRegistryService:SetRuntimeStarted(false)

	return Ok(true)
end

function BaseAIRuntimeService:BuildTree(definition: any): Result<any>
	if self._runtime == nil then
		return Err("RuntimeNotStarted", self._errors.RUNTIME_NOT_STARTED)
	end

	local didBuild, tree = pcall(function()
		return self._runtime:BuildTree(definition)
	end)

	if not didBuild then
		return Err("RuntimeStartFailed", self._errors.RUNTIME_START_FAILED, {
			CauseMessage = tree,
		})
	end

	return Ok(tree)
end

function BaseAIRuntimeService:RunFrame(frameContext: any): any
	if self._runtime == nil then
		return {
			EntityResults = {},
			Defects = {},
			SelectedActorCount = 0,
			ServicedActorCount = 0,
			RemainingSelectedActorCount = 0,
			StopReason = nil,
		}
	end

	local runtimeFrameContext = table.clone(frameContext)
	local baseServices = if type(frameContext.Services) == "table" then table.clone(frameContext.Services) else {}
	runtimeFrameContext.Services = baseServices

	if self._useRuntimeQueue then
		local tickId = frameContext.TickId
		self._actorRegistryService:ResolveSelectedBatchForTick(self._maxActorsPerTick or 0, tickId)
		runtimeFrameContext.OnActorServiced = function(entity: number, _actorType: string)
			self._actorRegistryService:MarkRuntimeIdServiced(entity, tickId)
		end
	end

	return self._runtime:RunFrame(runtimeFrameContext)
end

function BaseAIRuntimeService:CancelActorAction(actorType: string, runtimeId: number, frameContext: any): any
	if self._runtime == nil then
		return nil
	end

	self._actorRegistryService:CancelActor(runtimeId)
	return self._runtime:CancelActorAction(actorType, runtimeId, frameContext)
end

function BaseAIRuntimeService:HandleActorDeath(actorType: string, runtimeId: number, frameContext: any): any
	if self._runtime == nil then
		return nil
	end

	return self._runtime:HandleActorDeath(actorType, runtimeId, frameContext)
end

function BaseAIRuntimeService:GetExecutor(actionId: string)
	if self._runtime == nil then
		return nil
	end

	return self._runtime:GetExecutor(actionId)
end

function BaseAIRuntimeService:HasRuntimeObject(): boolean
	return self._runtime ~= nil
end

function BaseAIRuntimeService:ValidateSetup(expectedActorRegistryService: any): Result<boolean>
	return SetupValidationPolicy.Check(self, expectedActorRegistryService)
end

function BaseAIRuntimeService:_BuildErrorSink(): (payload: any) -> ()
	return function(payload: any)
		local actorType = tostring(payload.ActorType or "UnknownActorType")
		local stage = tostring(payload.Stage or "UnknownStage")
		local errorType = tostring(payload.ErrorType or "UnknownError")
		local causeMessage = tostring(payload.ErrorMessage or "No cause message")
		local actorDescriptor = if payload.ActorLabel ~= nil
			then string.format("%s (%s)", actorType, tostring(payload.ActorLabel))
			else actorType
		local defectMessage = string.format(
			"AI defect [%s] %s [%s]: %s",
			stage,
			actorDescriptor,
			errorType,
			causeMessage
		)

		Result.MentionError(
			self._runtimeLabel,
			defectMessage,
			{
				Summary = defectMessage,
				RuntimeStage = stage,
				Actor = actorDescriptor,
				ActorType = actorType,
				ActorLabel = payload.ActorLabel,
				Entity = payload.Entity,
				ErrorType = errorType,
				CauseMessage = causeMessage,
				DefectDetails = payload.Details,
			},
			payload.ErrorType
		)
	end
end

function BaseAIRuntimeService:_RegisterQueuedActors(): Result<boolean>
	local pendingPayloads = self._actorRegistryService:GetPendingActorPayloads()
	local payloadsByHandle = {}
	local registeredHandles = {}

	for _, payload in ipairs(pendingPayloads) do
		payloadsByHandle[payload.ActorHandle] = payload

		local behaviorTreeResult = self:BuildTree(payload.BehaviorDefinition)
		if not behaviorTreeResult.success then
			Result.MentionError(self._runtimeLabel, "Queued actor behavior tree build failed", {
				Stage = "BuildTree",
				ActorType = payload.ActorType,
				ActorHandle = payload.ActorHandle,
				CauseType = behaviorTreeResult.type,
				CauseMessage = behaviorTreeResult.message,
				Details = behaviorTreeResult.data,
			}, behaviorTreeResult.type)
			self:_RollbackQueuedActorStartup(payloadsByHandle, registeredHandles)
			return behaviorTreeResult
		end

		self._actorRegistryService:RemovePendingActorPayload(payload.ActorHandle)

		local registerResult = self._actorRegistryService:RegisterActor(payload, behaviorTreeResult.value)
		if not registerResult.success then
			self._actorRegistryService:QueueActor(payload)
			Result.MentionError(self._runtimeLabel, "Queued actor registration failed", {
				Stage = "RegisterQueuedActor",
				ActorType = payload.ActorType,
				ActorHandle = payload.ActorHandle,
				CauseType = registerResult.type,
				CauseMessage = registerResult.message,
				Details = registerResult.data,
			}, registerResult.type)
			self:_RollbackQueuedActorStartup(payloadsByHandle, registeredHandles)
			return registerResult
		end

		table.insert(registeredHandles, payload.ActorHandle)
	end

	return Ok(true)
end

function BaseAIRuntimeService:_RollbackQueuedActorStartup(
	payloadsByHandle: { [string]: any },
	registeredHandles: { string }
)
	for _, actorHandle in ipairs(registeredHandles) do
		self._actorRegistryService:DiscardActor(actorHandle)

		local payload = payloadsByHandle[actorHandle]
		if payload ~= nil then
			self._actorRegistryService:QueueActor(payload)
		end
	end
end

function BaseAIRuntimeService:_BuildRuntimeInputs(): TMergedRuntimeInputs
	local mergedInputs: TMergedRuntimeInputs = {
		Conditions = {},
		Commands = {},
		Executors = {},
		Hooks = table.clone(self._baseHooks),
	}

	for _, actorTypePayload in ipairs(self._actorRegistryService:GetActorTypePayloads()) do
		self:_MergeNamedRegistry(mergedInputs.Conditions, actorTypePayload.Conditions, actorTypePayload.ActorType, "Condition")
		self:_MergeNamedRegistry(mergedInputs.Commands, actorTypePayload.Commands, actorTypePayload.ActorType, "Command")
		self:_MergeNamedRegistry(mergedInputs.Executors, actorTypePayload.Executors, actorTypePayload.ActorType, "Executor")
		self:_AppendHooks(mergedInputs.Hooks, actorTypePayload.Hooks)
	end

	return mergedInputs
end

function BaseAIRuntimeService:_MergeNamedRegistry(
	target: { [string]: any },
	source: { [string]: any },
	actorType: string,
	registryLabel: string
)
	for key, value in pairs(source) do
		assert(
			target[key] == nil,
			string.format(
				"%s %s '%s' from actor type '%s' is registered more than once; namespace actor actions by context",
				self._runtimeContextLabel,
				registryLabel,
				key,
				actorType
			)
		)
		target[key] = value
	end
end

function BaseAIRuntimeService:_AppendHooks(target: { any }, hooks: { any }?)
	if hooks == nil then
		return
	end

	for _, hook in ipairs(hooks) do
		table.insert(target, hook)
	end
end

function BaseAIRuntimeService:_CreateRegistryAdapter(actorType: string): any
	local queryActiveEntities = if self._useRuntimeQueue
		then function(frameContext: any): { number }
			return self._actorRegistryService:GetSelectedRuntimeIdsForActorType(
				actorType,
				self._maxActorsPerTick or 0,
				frameContext.TickId
			)
		end
		elseif self._useCachedActiveEntityProvider
		then function(_frameContext: any): { number }
			return self._actorRegistryService:QueryCachedActiveRuntimeIds(actorType)
		end
		else function(_frameContext: any): { number }
			return self._actorRegistryService:QueryActiveRuntimeIds(actorType)
		end

	return AI.CreateAdapter({
		ActorLabel = actorType,
		QueryActiveEntities = queryActiveEntities,
		GetCompiledBehaviorTree = function(runtimeId: number): any?
			return self._actorRegistryService:GetCompiledBehaviorTree(runtimeId)
		end,
		GetActionState = function(runtimeId: number): any?
			return self._actorRegistryService:GetActionState(runtimeId)
		end,
		SetActionState = function(runtimeId: number, actionState: any)
			self._actorRegistryService:SetActionState(runtimeId, actionState)
		end,
		ClearActionState = function(runtimeId: number)
			self._actorRegistryService:ClearActionState(runtimeId)
		end,
		SetPendingAction = function(runtimeId: number, actionId: string, actionData: any?)
			self._actorRegistryService:SetPendingAction(runtimeId, actionId, actionData)
		end,
		UpdateLastTickTime = function(runtimeId: number, currentTime: number)
			self._actorRegistryService:UpdateLastTickTime(runtimeId, currentTime)
		end,
		ShouldEvaluate = function(runtimeId: number, currentTime: number): boolean
			return self._actorRegistryService:ShouldEvaluate(runtimeId, currentTime)
		end,
	})
end

return BaseAIRuntimeService
