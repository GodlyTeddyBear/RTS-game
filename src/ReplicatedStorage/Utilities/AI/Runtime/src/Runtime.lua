--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BehaviorSystem = require(ReplicatedStorage.Utilities.AI.Behavior)
local DebugConfig = require(ReplicatedStorage.Config.DebugConfig)
local DebugPlus = require(ReplicatedStorage.Utilities.DebugPlus)

local HookRunner = require(script.Parent.HookRunner)
local RuntimeEnums = require(script.Parent.RuntimeEnums)
local Types = require(script.Parent.Types)
local Validation = require(script.Parent.Validation)

type TConfig = Types.TConfig
type TActionDefinition = Types.TActionDefinition
type TActionState = Types.TActionState
type TCompiledBehaviorTree = Types.TCompiledBehaviorTree
type TActorAdapter = Types.TActorAdapter
type TFrameContext = Types.TFrameContext
type TRunFrameEntityResult = Types.TRunFrameEntityResult
type TRunFrameResult = Types.TRunFrameResult
type TErrorSinkPayload = Types.TErrorSinkPayload
type TCleanupKind = Types.TCleanupKind
type TCleanupResult = Types.TCleanupResult
type TCleanupBatchResult = Types.TCleanupBatchResult

type THookOutcome = HookRunner.THookOutcome

type TEntityFrameState = {
	Entity: number,
	ActorType: string,
	Adapter: TActorAdapter,
	WorkingActionState: TActionState,
	Result: TRunFrameEntityResult,
	HookOutcome: THookOutcome,
	BehaviorTree: TCompiledBehaviorTree?,
	ShouldEvaluateTree: boolean,
	NeedsTransitionPhase: boolean,
	NeedsActionPhase: boolean,
	NeedsFacts: boolean,
	SkipAllPhases: boolean,
	TreeTouchedActionState: boolean,
	NeedsAdapterRefreshAfterTree: boolean,
}

type TRuntimeFrameProfile = {
	FrameStartedAt: number,
	ActorEnumerationMilliseconds: number,
	BuildEntityStateMilliseconds: number,
	InitialActionStateMilliseconds: number,
	RefreshActionStateMilliseconds: number,
	HookMilliseconds: number,
	FactBuildMilliseconds: number,
	ServiceBuildMilliseconds: number,
	TreeMilliseconds: number,
	TransitionMilliseconds: number,
	ActionMilliseconds: number,
	ActorCount: number,
	FullSkipCount: number,
	ActionOnlyCount: number,
	TreeEvaluatedCount: number,
	FactBuildCount: number,
	ServiceBuildCount: number,
}

local _ResolveActorTypes
local _BuildTreeContext
local _CloneActionState
local _GetActorLabel
local _BuildCleanupResult
local _CreateRuntimeFrameProfile
local _CaptureMilliseconds
local _BuildDirectCombatHookOutcome
local _ShouldStopForTimeBudget
local _BuildServiceTickDeadline

local runFrameActorTypesProfileTag = "AI.Runtime.RunFrame.ActorTypes"
local runFrameResolveActorTypesProfileTag = "AI.Runtime.RunFrame.ResolveActorTypes"
local runFrameActorTypesIterateProfileTag = "AI.Runtime.RunFrame.ActorTypes.Iterate"
local runFrameActorTypesTreePhaseProfileTag = "AI.Runtime.RunFrame.ActorTypes.TreePhase"
local runFrameActorTypesTransitionPhaseProfileTag = "AI.Runtime.RunFrame.ActorTypes.TransitionPhase"
local runFrameActorTypesActionPhaseProfileTag = "AI.Runtime.RunFrame.ActorTypes.ActionPhase"
local runFrameActionPhaseTickCurrentActionProfileTag = "ActionPhase.TickCurrentAction"
local runFrameActionPhaseResolveFinishedActionProfileTag = "ActionPhase.ResolveFinishedAction"
local runFrameBuildEntityStatesIterateProfileTag = "AI.Runtime.RunFrame.BuildEntityStates.IterateEntities"
local runFrameBuildEntityStatesReadEntitySnapshotProfileTag =
	"AI.Runtime.RunFrame.BuildEntityStates.IterateEntities.ReadEntitySnapshot"
local runFrameBuildEntityStatesBuildHookOutcomeProfileTag =
	"AI.Runtime.RunFrame.BuildEntityStates.IterateEntities.BuildHookOutcome"
local runFrameBuildHookOutcomeDirectPathProfileTag = "AI.Runtime.BuildHookOutcome.DirectPath"
local runFrameBuildHookOutcomeBuildContextProfileTag = "AI.Runtime.BuildHookOutcome.BuildContext"
local runFrameBuildHookOutcomeRunHooksProfileTag = "AI.Runtime.BuildHookOutcome.RunHooks"
local runFrameBuildHookOutcomeFinalizeProfileTag = "AI.Runtime.BuildHookOutcome.Finalize"
local runFrameBuildDirectCombatHookOutcomeBuildServicesProfileTag =
	"AI.Runtime.BuildHookOutcome.DirectPath.BuildServices"
local runFrameBuildDirectCombatHookOutcomeBuildFactsProfileTag = "AI.Runtime.BuildHookOutcome.DirectPath.BuildFacts"
local runFrameBuildDirectCombatHookOutcomeBuildFactsPrecheckProfileTag =
	"AI.Runtime.BuildHookOutcome.DirectPath.BuildFacts.Precheck"
local runFrameBuildDirectCombatHookOutcomeBuildFactsGateProfileTag =
	"AI.Runtime.BuildHookOutcome.DirectPath.BuildFacts.Gate"
local runFrameProfilingEnabled = DebugConfig.AI_RUNTIME_FRAME_PROFILING

local EMPTY_HOOK_OUTCOME: THookOutcome = table.freeze({
	Facts = table.freeze({}),
	BehaviorContext = table.freeze({}),
	Services = table.freeze({}),
})

--[=[
	@class AiRuntimeService
	Runs the shared AI frame loop while keeping actor state and cleanup ownership in the caller's context.
	@server
	@client
]=]

local Runtime = {}
Runtime.__index = Runtime

--[=[
	Creates one AI runtime service from condition, command, hook, and error-sink registries.
	@within AiRuntimeService
	@param config TConfig
	@return any
]=]
function Runtime.new(config: TConfig)
	Validation.ValidateConfig(config)

	-- The shared BehaviorSystem handles tree compilation while this runtime keeps orchestration and adapter state.
	local self = setmetatable({}, Runtime)
	self._runtime = BehaviorSystem.new({
		Conditions = config.Conditions,
		Commands = config.Commands,
	})
	self._hooks = config.Hooks
	self._errorSink = config.ErrorSink
	self._actorAdapters = {}
	self._actorOrder = {}
	self._lastFrameTime = nil
	self._lastProfileLogAt = 0
	self._useDirectCombatHookPath = config.UseDirectCombatHookPath == true

	return self
end

--[=[
	Registers action definitions on the shared BehaviorSystem runtime.
	@within AiRuntimeService
	@param definitions { [any]: TActionDefinition }
]=]
function Runtime:RegisterActions(definitions: { [any]: TActionDefinition })
	self._runtime:RegisterActions(definitions)
end

--[=[
	Registers one actor adapter under one actor type.
	@within AiRuntimeService
	@param actorType string
	@param adapter TActorAdapter
]=]
function Runtime:RegisterActorType(actorType: string, adapter: TActorAdapter)
	Validation.ValidateActorType(actorType)
	Validation.ValidateActorAdapter(actorType, adapter)
	assert(self._actorAdapters[actorType] == nil, ("AiRuntime actor type '%s' is already registered"):format(actorType))

	self._actorAdapters[actorType] = adapter
	table.insert(self._actorOrder, actorType)
end

--[=[
	Compiles one behavior-tree definition through the shared BehaviorSystem runtime.
	@within AiRuntimeService
	@param definition any
	@return any
]=]
function Runtime:BuildTree(definition: any)
	return self._runtime:BuildTree(definition)
end

--[=[
	Returns one registered executor by action id.
	@within AiRuntimeService
	@param actionId string
	@return any
]=]
function Runtime:GetExecutor(actionId: string)
	return self._runtime:GetExecutor(actionId)
end

--[=[
	Cancels one actor's current action through the cleanup boundary.
	@within AiRuntimeService
	@param actorType string
	@param entity number
	@param frameContext TFrameContext
	@return TCleanupResult
]=]
function Runtime:CancelActorAction(actorType: string, entity: number, frameContext: TFrameContext): TCleanupResult
	return self:_CleanupActorAction(RuntimeEnums.CleanupKind.Cancel.Name, actorType, entity, frameContext)
end

--[=[
	Handles one actor death through the cleanup boundary.
	@within AiRuntimeService
	@param actorType string
	@param entity number
	@param frameContext TFrameContext
	@return TCleanupResult
]=]
function Runtime:HandleActorDeath(actorType: string, entity: number, frameContext: TFrameContext): TCleanupResult
	return self:_CleanupActorAction(RuntimeEnums.CleanupKind.Death.Name, actorType, entity, frameContext)
end

--[=[
	Cancels many actor actions in order.
	@within AiRuntimeService
	@param actorType string
	@param entities { number }
	@param frameContext TFrameContext
	@return TCleanupBatchResult
]=]
function Runtime:CancelActorActions(
	actorType: string,
	entities: { number },
	frameContext: TFrameContext
): TCleanupBatchResult
	Validation.ValidateActorType(actorType)
	assert(type(entities) == "table", "AiRuntime CancelActorActions entities must be an array")
	Validation.ValidateFrameContext(frameContext)

	local cleanupResults = {}
	for _, entity in ipairs(entities) do
		table.insert(cleanupResults, self:CancelActorAction(actorType, entity, frameContext))
	end

	return table.freeze(cleanupResults)
end

--[=[
	Handles many actor deaths in order.
	@within AiRuntimeService
	@param actorType string
	@param entities { number }
	@param frameContext TFrameContext
	@return TCleanupBatchResult
]=]
function Runtime:HandleActorDeaths(
	actorType: string,
	entities: { number },
	frameContext: TFrameContext
): TCleanupBatchResult
	Validation.ValidateActorType(actorType)
	assert(type(entities) == "table", "AiRuntime HandleActorDeaths entities must be an array")
	Validation.ValidateFrameContext(frameContext)

	local cleanupResults = {}
	for _, entity in ipairs(entities) do
		table.insert(cleanupResults, self:HandleActorDeath(actorType, entity, frameContext))
	end

	return table.freeze(cleanupResults)
end

--[=[
	Runs one AI frame across all registered actor types.
	@within AiRuntimeService
	@param frameContext TFrameContext
	@return TRunFrameResult
]=]
function Runtime:RunFrame(frameContext: TFrameContext): TRunFrameResult
	Validation.ValidateFrameContext(frameContext)
	Validation.ValidateMonotonicFrameTime(frameContext.CurrentTime, self._lastFrameTime)

	-- Frame execution is deliberately staged so defects can be attributed to the exact phase that failed.
	local defects = {}
	local entityResults = {}
	local frameProfile = _CreateRuntimeFrameProfile()
	local selectedEntitiesByActorType = {}
	local selectedActorCount = 0
	local servicedActorCount = 0
	local serviceTickDeadline = nil
	local stopReason = nil
	local actorTypes = DebugPlus.profile(runFrameResolveActorTypesProfileTag, function()
		return _ResolveActorTypes(frameContext, self._actorAdapters, self._actorOrder)
	end, runFrameProfilingEnabled)

	DebugPlus.profile(runFrameActorTypesProfileTag, function()
		DebugPlus.profile(runFrameActorTypesIterateProfileTag, function()
			for _, actorType in ipairs(actorTypes) do
				local adapter = self._actorAdapters[actorType]
				local enumerationStartedAt = if frameProfile ~= nil then os.clock() else nil
				local entities = adapter:QueryActiveEntities(frameContext)
				Validation.ValidateQueryActiveEntitiesResult(actorType, entities)
				if frameProfile ~= nil then
					frameProfile.ActorEnumerationMilliseconds += _CaptureMilliseconds(enumerationStartedAt)
				end

				selectedEntitiesByActorType[actorType] = entities
				selectedActorCount += #entities
			end

			serviceTickDeadline = _BuildServiceTickDeadline(frameContext)
			local s = os.clock()
			for _, actorType in ipairs(actorTypes) do
				local adapter = self._actorAdapters[actorType]
				local entities = selectedEntitiesByActorType[actorType]
				if entities == nil then
					continue
				end

				for _, entity in ipairs(entities) do
					if servicedActorCount > 0 and _ShouldStopForTimeBudget(serviceTickDeadline) then
						stopReason = "TimeBudgetExceeded"
						print(((os.clock() - s) * 10 ^ 3) .. " MS for actors:", servicedActorCount)
						return
					end

					local entityState = self:_BuildEntityState(
						actorType,
						adapter,
						entity,
						frameContext,
						defects,
						entityResults,
						frameProfile
					)
					local singleEntityStates = { entityState }

					DebugPlus.profile(runFrameActorTypesTreePhaseProfileTag, function()
						self:_RunTreePhase(singleEntityStates, frameContext, defects, frameProfile)
					end, runFrameProfilingEnabled)
					DebugPlus.profile(runFrameActorTypesTransitionPhaseProfileTag, function()
						self:_RunTransitionPhase(singleEntityStates, frameContext, defects, frameProfile)
					end, runFrameProfilingEnabled)
					DebugPlus.profile(runFrameActorTypesActionPhaseProfileTag, function()
						self:_RunActionPhase(singleEntityStates, frameContext, defects, frameProfile)
					end, runFrameProfilingEnabled)

					servicedActorCount += 1

					local onActorServiced = frameContext.OnActorServiced
					if type(onActorServiced) == "function" then
						onActorServiced(entityState.Entity, actorType)
					end
				end
			end
		end, runFrameProfilingEnabled)
	end, runFrameProfilingEnabled)

	self._lastFrameTime = frameContext.CurrentTime
	self:_EmitFrameProfile(frameProfile)

	return table.freeze({
		EntityResults = entityResults,
		Defects = defects,
		SelectedActorCount = selectedActorCount,
		ServicedActorCount = servicedActorCount,
		RemainingSelectedActorCount = math.max(selectedActorCount - servicedActorCount, 0),
		StopReason = stopReason,
	})
end

--[=[
	@private
	Builds the per-entity snapshots used by the tree, transition, and action phases.
	@within AiRuntimeService
	@param actorType string
	@param adapter TActorAdapter
	@param frameContext TFrameContext
	@param defects { TErrorSinkPayload }
	@param entityResults { TRunFrameEntityResult }
	@return { any }
]=]
function Runtime:_BuildEntityStates(
	actorType: string,
	adapter: TActorAdapter,
	frameContext: TFrameContext,
	defects: { TErrorSinkPayload },
	entityResults: { TRunFrameEntityResult },
	frameProfile: TRuntimeFrameProfile?
): { TEntityFrameState }
	-- Entity state snapshots let the three runtime phases share the same per-entity inputs without repeated adapter calls.
	local entityStates = {}
	local enumerationStartedAt = if frameProfile ~= nil then os.clock() else nil
	local entities = adapter:QueryActiveEntities(frameContext)
	Validation.ValidateQueryActiveEntitiesResult(actorType, entities)
	if frameProfile ~= nil then
		frameProfile.ActorEnumerationMilliseconds += _CaptureMilliseconds(enumerationStartedAt)
	end

	local buildEntityStateStartedAt = if frameProfile ~= nil then os.clock() else nil

	DebugPlus.profile(runFrameBuildEntityStatesIterateProfileTag, function()
		for _, entity in ipairs(entities) do
			table.insert(
				entityStates,
				self:_BuildEntityState(actorType, adapter, entity, frameContext, defects, entityResults, frameProfile)
			)
		end
	end, runFrameProfilingEnabled)

	if frameProfile ~= nil then
		frameProfile.BuildEntityStateMilliseconds += _CaptureMilliseconds(buildEntityStateStartedAt)
	end

	return entityStates
end

function Runtime:_BuildEntityState(
	actorType: string,
	adapter: TActorAdapter,
	entity: number,
	frameContext: TFrameContext,
	defects: { TErrorSinkPayload },
	entityResults: { TRunFrameEntityResult },
	frameProfile: TRuntimeFrameProfile?
): TEntityFrameState
	local buildEntityStateStartedAt = if frameProfile ~= nil then os.clock() else nil
	Validation.ValidateEntityId(actorType, entity, "QueryActiveEntities")
	if frameProfile ~= nil then
		frameProfile.ActorCount += 1
	end

	local result = {
		ActorType = actorType,
		Entity = entity,
		TreeStatus = RuntimeEnums.TreeStatus.SkippedNoTree.Name,
		StartStatus = nil,
		CommitStatus = nil,
		TickActionId = nil,
		TickStatus = nil,
		ResolveStatus = nil,
	}
	table.insert(entityResults, result)

	local actionStateStartedAt = if frameProfile ~= nil then os.clock() else nil
	local workingActionState = nil :: TActionState?
	local behaviorTree = nil :: TCompiledBehaviorTree?
	local hasCurrentAction = false
	local hasPendingAction = false
	local shouldEvaluateTree = false
	DebugPlus.profile(runFrameBuildEntityStatesReadEntitySnapshotProfileTag, function()
		local actionStateSnapshot = adapter:GetActionState(entity)
		Validation.ValidateActionState(actionStateSnapshot, "AiRuntime BuildEntityStates GetActionState")
		workingActionState = _CloneActionState(actionStateSnapshot)
		if frameProfile ~= nil then
			frameProfile.InitialActionStateMilliseconds += _CaptureMilliseconds(actionStateStartedAt)
		end
		behaviorTree = adapter:GetCompiledBehaviorTree(entity)
		Validation.ValidateBehaviorTree(actorType, entity, behaviorTree)
		hasCurrentAction = type((workingActionState :: TActionState).CurrentActionId) == "string"
		hasPendingAction = type((workingActionState :: TActionState).PendingActionId) == "string"
		if behaviorTree ~= nil then
			shouldEvaluateTree = adapter:ShouldEvaluate(entity, frameContext.CurrentTime)
			Validation.ValidateShouldEvaluateResult(actorType, entity, shouldEvaluateTree)
		end
	end, runFrameProfilingEnabled)
	local resolvedWorkingActionState = workingActionState :: TActionState

	if behaviorTree == nil then
		result.TreeStatus = RuntimeEnums.TreeStatus.SkippedNoTree.Name
	elseif not shouldEvaluateTree then
		result.TreeStatus = RuntimeEnums.TreeStatus.SkippedNotReady.Name
	end

	local skipAllPhases = not hasCurrentAction and not hasPendingAction and not shouldEvaluateTree
	local needsTransitionPhase = hasPendingAction or shouldEvaluateTree
	local needsActionPhase = hasCurrentAction or hasPendingAction or shouldEvaluateTree
	local needsFacts = shouldEvaluateTree
	local hookOutcome = EMPTY_HOOK_OUTCOME

	if frameProfile ~= nil then
		if skipAllPhases then
			frameProfile.FullSkipCount += 1
		elseif shouldEvaluateTree then
			frameProfile.TreeEvaluatedCount += 1
		else
			frameProfile.ActionOnlyCount += 1
		end
	end

	if not skipAllPhases then
		hookOutcome = DebugPlus.profile(runFrameBuildEntityStatesBuildHookOutcomeProfileTag, function()
			return self:_BuildHookOutcome(
				actorType,
				entity,
				adapter,
				resolvedWorkingActionState,
				frameContext,
				defects,
				needsFacts,
				shouldEvaluateTree,
				hasCurrentAction or hasPendingAction or shouldEvaluateTree,
				frameProfile
			)
		end, runFrameProfilingEnabled)
	end

	if frameProfile ~= nil then
		frameProfile.BuildEntityStateMilliseconds += _CaptureMilliseconds(buildEntityStateStartedAt)
	end

	return {
		Entity = entity,
		ActorType = actorType,
		Adapter = adapter,
		WorkingActionState = resolvedWorkingActionState,
		Result = result,
		HookOutcome = hookOutcome,
		BehaviorTree = behaviorTree,
		ShouldEvaluateTree = shouldEvaluateTree,
		NeedsTransitionPhase = needsTransitionPhase,
		NeedsActionPhase = needsActionPhase,
		NeedsFacts = needsFacts,
		SkipAllPhases = skipAllPhases,
		TreeTouchedActionState = false,
		NeedsAdapterRefreshAfterTree = shouldEvaluateTree,
	}
end

--[=[
	@private
	Runs the cleanup boundary for one actor and clears action state after the shared runtime call.
	@within AiRuntimeService
	@param cleanupKind TCleanupKind
	@param actorType string
	@param entity number
	@param frameContext TFrameContext
	@return TCleanupResult
]=]
function Runtime:_CleanupActorAction(
	cleanupKind: TCleanupKind,
	actorType: string,
	entity: number,
	frameContext: TFrameContext
): TCleanupResult
	Validation.ValidateActorType(actorType)
	Validation.ValidateFrameContext(frameContext)

	local adapter = self:_RequireActorAdapter(actorType)
	if adapter == nil then
		-- Return a structured invalid-type result instead of throwing so cleanup can stay caller-safe.
		return _BuildCleanupResult(
			actorType,
			entity,
			cleanupKind,
			RuntimeEnums.CleanupStatus.InvalidActorType.Name,
			nil
		)
	end

	local defects = {}
	local actionStateSnapshot = adapter:GetActionState(entity)
	Validation.ValidateActionState(actionStateSnapshot, "AiRuntime Cleanup GetActionState")
	local workingActionState = _CloneActionState(actionStateSnapshot)
	-- Reuse the normal hook merge path so cleanup sees the same service bag as frame execution.
	local hookOutcome = self:_BuildHookOutcome(
		actorType,
		entity,
		adapter,
		workingActionState,
		frameContext,
		defects,
		false,
		false,
		true,
		nil
	)
	local runtimeContext = {
		DeltaTime = frameContext.DeltaTime,
		Services = hookOutcome.Services,
	}

	-- Cleanup uses the same runtime boundary as frame execution so cancellation and death stay behavior-system aware.
	local cleanupResult = if cleanupKind == RuntimeEnums.CleanupKind.Cancel.Name
		then self._runtime:CancelCurrentAction(entity, workingActionState, runtimeContext)
		else self._runtime:HandleCurrentActionDeath(entity, workingActionState, runtimeContext)

	if not cleanupResult.success then
		-- Cleanup failures still clear the adapter state so stale actions do not linger after the defect.
		local defect = {
			Stage = if cleanupKind == RuntimeEnums.CleanupKind.Cancel.Name
				then "CancelActorAction"
				else "HandleActorDeath",
			ActorType = actorType,
			Entity = entity,
			ActorLabel = _GetActorLabel(adapter),
			ErrorType = cleanupResult.type,
			ErrorMessage = cleanupResult.message,
			Details = nil,
		}
		self:_PushDefect(defects, defect)
		adapter:ClearActionState(entity)

		return _BuildCleanupResult(
			actorType,
			entity,
			cleanupKind,
			RuntimeEnums.CleanupStatus.ClearedAfterFailure.Name,
			defect
		)
	end

	adapter:ClearActionState(entity)

	if
		cleanupResult.value.Status == RuntimeEnums.CancelStatus.NoCurrentAction.Name
		or cleanupResult.value.Status == RuntimeEnums.DeathStatus.NoCurrentAction.Name
	then
		-- A no-op cleanup still returns a distinct status for callers that care about the empty-path case.
		return _BuildCleanupResult(actorType, entity, cleanupKind, RuntimeEnums.CleanupStatus.NoCurrentAction.Name, nil)
	end

	return _BuildCleanupResult(actorType, entity, cleanupKind, RuntimeEnums.CleanupStatus.Handled.Name, nil)
end

--[=[
	@private
	Returns the registered adapter for one actor type, if present.
	@within AiRuntimeService
	@param actorType string
	@return TActorAdapter?
]=]
function Runtime:_RequireActorAdapter(actorType: string): TActorAdapter?
	return self._actorAdapters[actorType]
end

--[=[
	@private
	Builds the hook context and runs the ordered hook chain for one entity.
	@within AiRuntimeService
	@param actorType string
	@param entity number
	@param adapter TActorAdapter
	@param actionState TActionState
	@param frameContext TFrameContext
	@param defects { TErrorSinkPayload }
	@return THookOutcome
]=]
function Runtime:_BuildHookOutcome(
	actorType: string,
	entity: number,
	adapter: TActorAdapter,
	actionState: TActionState,
	frameContext: TFrameContext,
	defects: { TErrorSinkPayload },
	needsFacts: boolean,
	needsBehaviorContext: boolean,
	needsServices: boolean,
	frameProfile: TRuntimeFrameProfile?
): THookOutcome
	local hookStartedAt = if frameProfile ~= nil then os.clock() else nil
	if self._useDirectCombatHookPath then
		local directCombatHookOutcome = DebugPlus.profile(runFrameBuildHookOutcomeDirectPathProfileTag, function()
			return _BuildDirectCombatHookOutcome(actionState, frameContext, {
				Entity = entity,
				NeedsFacts = needsFacts,
				NeedsServices = needsServices,
				RuntimeProfile = frameProfile,
			})
		end, runFrameProfilingEnabled)
		if directCombatHookOutcome ~= nil then
			if frameProfile ~= nil then
				frameProfile.HookMilliseconds += _CaptureMilliseconds(hookStartedAt)
			end
			return directCombatHookOutcome
		end
	end

	local hookContext = nil :: Types.THookContext?
	DebugPlus.profile(runFrameBuildHookOutcomeBuildContextProfileTag, function()
		local baseServices = if frameContext.Services ~= nil then frameContext.Services else {}
		hookContext = {
			Entity = entity,
			ActorType = actorType,
			ActionState = actionState,
			FrameContext = frameContext,
			Services = baseServices,
			Adapter = adapter,
			NeedsFacts = needsFacts,
			NeedsBehaviorContext = needsBehaviorContext,
			NeedsServices = needsServices,
			RuntimeProfile = frameProfile,
		}
	end, runFrameProfilingEnabled)

	local resolvedHookContext = hookContext :: Types.THookContext
	local hookOutcome = DebugPlus.profile(runFrameBuildHookOutcomeRunHooksProfileTag, function()
		return self:_RunHooks(entity, actorType, adapter, resolvedHookContext, defects)
	end, runFrameProfilingEnabled)
	DebugPlus.profile(runFrameBuildHookOutcomeFinalizeProfileTag, function()
		-- Keep a dedicated finalize span so post-hook bookkeeping stays visible in traces.
	end, runFrameProfilingEnabled)
	if frameProfile ~= nil then
		frameProfile.HookMilliseconds += _CaptureMilliseconds(hookStartedAt)
	end
	return hookOutcome
end

--[=[
	@private
	Runs the tree-evaluation phase for one batch of entity snapshots.
	@within AiRuntimeService
	@param entityStates { TEntityFrameState }
	@param frameContext TFrameContext
	@param defects { TErrorSinkPayload }
]=]
function Runtime:_RunTreePhase(
	entityStates: { TEntityFrameState },
	frameContext: TFrameContext,
	defects: { TErrorSinkPayload },
	frameProfile: TRuntimeFrameProfile?
)
	local treePhaseStartedAt = if frameProfile ~= nil then os.clock() else nil
	for _, entityState in ipairs(entityStates) do
		if not entityState.ShouldEvaluateTree then
			continue
		end

		if entityState.BehaviorTree == nil then
			-- No tree means there is nothing to evaluate for this entity.
			entityState.Result.TreeStatus = RuntimeEnums.TreeStatus.SkippedNoTree.Name
			continue
		end

		local treeContext =
			_BuildTreeContext(entityState.Entity, entityState.ActorType, entityState.Adapter, entityState.HookOutcome)
		local didRun, runError = pcall(function()
			entityState.BehaviorTree:run(treeContext)
		end)

		if not didRun then
			-- Tree execution defects stay isolated to the tree phase and do not stop later entities.
			entityState.Result.TreeStatus = RuntimeEnums.TreeStatus.TreeDefect.Name
			self:_PushDefect(defects, {
				Stage = "TreeRun",
				ActorType = entityState.ActorType,
				Entity = entityState.Entity,
				ActorLabel = _GetActorLabel(entityState.Adapter),
				ErrorType = "TreeRunFailed",
				ErrorMessage = tostring(runError),
				Details = nil,
			})
			continue
		end

		entityState.Result.TreeStatus = RuntimeEnums.TreeStatus.Ran.Name
		entityState.TreeTouchedActionState = true
		-- The tree advanced successfully, so the adapter records the new tick time for the next frame.
		entityState.Adapter:UpdateLastTickTime(entityState.Entity, frameContext.CurrentTime)

		if entityState.NeedsAdapterRefreshAfterTree then
			local refreshActionStateStartedAt = if frameProfile ~= nil then os.clock() else nil
			local refreshedActionState = entityState.Adapter:GetActionState(entityState.Entity)
			Validation.ValidateActionState(refreshedActionState, "AiRuntime TreeRun RefreshActionState")
			entityState.WorkingActionState = _CloneActionState(refreshedActionState)
			if frameProfile ~= nil then
				frameProfile.RefreshActionStateMilliseconds += _CaptureMilliseconds(refreshActionStateStartedAt)
			end
		end

		local hasCurrentAction = type(entityState.WorkingActionState.CurrentActionId) == "string"
		local hasPendingAction = type(entityState.WorkingActionState.PendingActionId) == "string"
		entityState.NeedsTransitionPhase = hasPendingAction
		entityState.NeedsActionPhase = hasCurrentAction or hasPendingAction
	end

	if frameProfile ~= nil then
		frameProfile.TreeMilliseconds += _CaptureMilliseconds(treePhaseStartedAt)
	end
end

--[=[
	@private
	Runs the pending-action transition phase for one batch of entity snapshots.
	@within AiRuntimeService
	@param entityStates { TEntityFrameState }
	@param frameContext TFrameContext
	@param defects { TErrorSinkPayload }
]=]
function Runtime:_RunTransitionPhase(
	entityStates: { TEntityFrameState },
	frameContext: TFrameContext,
	defects: { TErrorSinkPayload },
	frameProfile: TRuntimeFrameProfile?
)
	local transitionPhaseStartedAt = if frameProfile ~= nil then os.clock() else nil
	for _, entityState in ipairs(entityStates) do
		if not entityState.NeedsTransitionPhase then
			continue
		end

		local workingActionState = entityState.WorkingActionState
		local runtimeContext = {
			DeltaTime = frameContext.DeltaTime,
			Services = entityState.HookOutcome.Services,
		}
		local startResult = self._runtime:StartPendingAction(entityState.Entity, workingActionState, runtimeContext)

		if not startResult.success then
			-- Failed starts clear the action state so the next frame can retry from a clean boundary.
			self:_PushRuntimeFailure(
				defects,
				"StartPendingAction",
				entityState,
				startResult.type,
				startResult.message,
				nil
			)
			entityState.WorkingActionState = _CloneActionState(nil)
			entityState.Adapter:ClearActionState(entityState.Entity)
			continue
		end

		local startStatus = startResult.value.Status
		entityState.Result.StartStatus = startStatus

		if
			startStatus == RuntimeEnums.StartStatus.NoAction.Name
			or startStatus == RuntimeEnums.StartStatus.Blocked.Name
		then
			-- These statuses intentionally leave the action state unchanged.
			local hasCurrentAction = type(workingActionState.CurrentActionId) == "string"
			entityState.NeedsActionPhase = hasCurrentAction
			continue
		end

		if startStatus == RuntimeEnums.StartStatus.NoChange.Name then
			-- No-change means the pending action should be dropped but the current action should stay intact.
			workingActionState.PendingActionId = nil
			workingActionState.PendingActionData = nil
			entityState.WorkingActionState = workingActionState
			entityState.Adapter:SetActionState(entityState.Entity, workingActionState)
			entityState.NeedsActionPhase = type(workingActionState.CurrentActionId) == "string"
			continue
		end

		if
			startStatus == RuntimeEnums.StartStatus.MissingAction.Name
			or startStatus == RuntimeEnums.StartStatus.FailedToStart.Name
		then
			-- Missing or failed starts reset the adapter state so the entity does not retain a bad pending action.
			entityState.WorkingActionState = _CloneActionState(nil)
			entityState.Adapter:ClearActionState(entityState.Entity)
			entityState.NeedsActionPhase = false
			continue
		end

		local commitResult =
			self._runtime:CommitStartedAction(workingActionState, startResult.value, frameContext.CurrentTime)
		entityState.Result.CommitStatus = commitResult.Status

		if commitResult.Status == RuntimeEnums.CommitStatus.Committed.Name then
			-- A successful commit writes the updated action state back to the adapter.
			entityState.WorkingActionState = workingActionState
			entityState.Adapter:SetActionState(entityState.Entity, workingActionState)
			entityState.NeedsActionPhase = true
			continue
		end

		-- Invalid transitions are reported as defects because the runtime should only see valid commit outcomes.
		self:_PushDefect(defects, {
			Stage = "CommitStartedAction",
			ActorType = entityState.ActorType,
			Entity = entityState.Entity,
			ActorLabel = _GetActorLabel(entityState.Adapter),
			ErrorType = "InvalidCommitTransition",
			ErrorMessage = "AiRuntime received an invalid commit transition",
			Details = {
				StartStatus = startStatus,
				CommitStatus = commitResult.Status,
			},
		})
		entityState.WorkingActionState = _CloneActionState(nil)
		entityState.Adapter:ClearActionState(entityState.Entity)
		entityState.NeedsActionPhase = false
	end

	if frameProfile ~= nil then
		frameProfile.TransitionMilliseconds += _CaptureMilliseconds(transitionPhaseStartedAt)
	end
end

--[=[
	@private
	Runs the current-action tick and resolve phase for one batch of entity snapshots.
	@within AiRuntimeService
	@param entityStates { TEntityFrameState }
	@param frameContext TFrameContext
	@param defects { TErrorSinkPayload }
]=]
function Runtime:_RunActionPhase(
	entityStates: { TEntityFrameState },
	frameContext: TFrameContext,
	defects: { TErrorSinkPayload },
	frameProfile: TRuntimeFrameProfile?
)
	local actionPhaseStartedAt = if frameProfile ~= nil then os.clock() else nil
	for _, entityState in ipairs(entityStates) do
		if not entityState.NeedsActionPhase then
			continue
		end

		local workingActionState = entityState.WorkingActionState
		entityState.HookOutcome.Services.ActionState = workingActionState
		local runtimeContext = {
			DeltaTime = frameContext.DeltaTime,
			Services = entityState.HookOutcome.Services,
		}
		local closeTickCurrentActionProfile =
			DebugPlus.begin(runFrameActionPhaseTickCurrentActionProfileTag, runFrameProfilingEnabled)
		local tickResult = self._runtime:TickCurrentAction(entityState.Entity, workingActionState, runtimeContext)
		closeTickCurrentActionProfile()

		if not tickResult.success then
			-- Tick failures clear the action state so the runtime can recover on the next frame.
			self:_PushRuntimeFailure(
				defects,
				"TickCurrentAction",
				entityState,
				tickResult.type,
				tickResult.message,
				nil
			)
			entityState.WorkingActionState = _CloneActionState(nil)
			entityState.Adapter:ClearActionState(entityState.Entity)
			continue
		end

		local tickStatus = tickResult.value.Status
		entityState.Result.TickActionId = tickResult.value.ActionId
		entityState.Result.TickStatus = tickStatus

		local closeResolveFinishedActionProfile =
			DebugPlus.begin(runFrameActionPhaseResolveFinishedActionProfileTag, runFrameProfilingEnabled)
		local resolveResult =
			self._runtime:ResolveFinishedAction(workingActionState, tickResult.value, frameContext.CurrentTime)
		closeResolveFinishedActionProfile()
		entityState.Result.ResolveStatus = resolveResult.Status

		if resolveResult.Status == RuntimeEnums.ResolveStatus.Resolved.Name then
			-- Resolved actions keep the updated state because the action may have advanced into a new terminal status.
			entityState.WorkingActionState = workingActionState
			entityState.Adapter:SetActionState(entityState.Entity, workingActionState)
			continue
		end

		if resolveResult.Status == RuntimeEnums.ResolveStatus.InvalidResult.Name then
			-- Invalid resolve transitions are defects because the shared runtime rejected the terminal status.
			self:_PushDefect(defects, {
				Stage = "ResolveFinishedAction",
				ActorType = entityState.ActorType,
				Entity = entityState.Entity,
				ActorLabel = _GetActorLabel(entityState.Adapter),
				ErrorType = "InvalidResolveTransition",
				ErrorMessage = "AiRuntime received an invalid resolve transition",
				Details = {
					TickStatus = tickStatus,
					ActionId = tickResult.value.ActionId,
				},
			})
			entityState.WorkingActionState = _CloneActionState(nil)
			entityState.Adapter:ClearActionState(entityState.Entity)
		end
	end

	if frameProfile ~= nil then
		frameProfile.ActionMilliseconds += _CaptureMilliseconds(actionPhaseStartedAt)
	end
end

--[=[
	@private
	Runs the hook chain for one entity through the shared hook boundary.
	@within AiRuntimeService
	@param entity number
	@param actorType string
	@param adapter TActorAdapter
	@param hookContext Types.THookContext
	@param defects { TErrorSinkPayload }
	@return THookOutcome
]=]
function Runtime:_RunHooks(
	entity: number,
	_actorType: string,
	_adapter: TActorAdapter,
	hookContext: Types.THookContext,
	_defects: { TErrorSinkPayload }
): THookOutcome
	return HookRunner.Run(self._hooks, entity, hookContext)
end

--[=[
	@private
	Pushes a runtime failure into the defect list and optional error sink.
	@within AiRuntimeService
	@param defects { TErrorSinkPayload }
	@param stage string
	@param entityState TEntityFrameState
	@param errorType string
	@param errorMessage string
	@param details { [string]: any }?
]=]
function Runtime:_PushRuntimeFailure(
	defects: { TErrorSinkPayload },
	stage: string,
	entityState: TEntityFrameState,
	errorType: string,
	errorMessage: string,
	details: { [string]: any }?
)
	self:_PushDefect(defects, {
		Stage = stage,
		ActorType = entityState.ActorType,
		Entity = entityState.Entity,
		ActorLabel = _GetActorLabel(entityState.Adapter),
		ErrorType = errorType,
		ErrorMessage = errorMessage,
		Details = details,
	})
end

--[=[
	@private
	Pushes one defect payload and forwards it to the optional error sink.
	@within AiRuntimeService
	@param defects { TErrorSinkPayload }
	@param payload TErrorSinkPayload
]=]
function Runtime:_PushDefect(defects: { TErrorSinkPayload }, payload: TErrorSinkPayload)
	table.insert(defects, payload)

	if self._errorSink ~= nil then
		self._errorSink(payload)
	end
end

function Runtime:_EmitFrameProfile(frameProfile: TRuntimeFrameProfile?)
	if frameProfile == nil or DebugConfig.ENABLED ~= true then
		return
	end

	local logInterval = DebugConfig.AI_RUNTIME_PROFILING_LOG_INTERVAL_SECONDS
	if type(logInterval) ~= "number" then
		logInterval = 1
	end
	logInterval = math.max(0.25, logInterval)

	local now = os.clock()
	if now - self._lastProfileLogAt < logInterval then
		return
	end

	self._lastProfileLogAt = now
	local totalMilliseconds = _CaptureMilliseconds(frameProfile.FrameStartedAt)
	warn(
		string.format(
			"AiRuntime profile | totalMs=%.3f actors=%d fullSkip=%d actionOnly=%d treeActors=%d enumMs=%.3f buildMs=%.3f actionReadMs=%.3f actionRefreshMs=%.3f hookMs=%.3f factsMs=%.3f facts=%d servicesMs=%.3f services=%d treeMs=%.3f transitionMs=%.3f actionMs=%.3f",
			totalMilliseconds,
			frameProfile.ActorCount,
			frameProfile.FullSkipCount,
			frameProfile.ActionOnlyCount,
			frameProfile.TreeEvaluatedCount,
			frameProfile.ActorEnumerationMilliseconds,
			frameProfile.BuildEntityStateMilliseconds,
			frameProfile.InitialActionStateMilliseconds,
			frameProfile.RefreshActionStateMilliseconds,
			frameProfile.HookMilliseconds,
			frameProfile.FactBuildMilliseconds,
			frameProfile.FactBuildCount,
			frameProfile.ServiceBuildMilliseconds,
			frameProfile.ServiceBuildCount,
			frameProfile.TreeMilliseconds,
			frameProfile.TransitionMilliseconds,
			frameProfile.ActionMilliseconds
		)
	)
end

--[=[
	@private
	Selects the actor types for one frame from the optional frame filter or registration order.
	@within AiRuntimeService
	@param frameContext TFrameContext
	@param actorAdapters { [string]: TActorAdapter }
	@param actorOrder { string }
	@return { string }
]=]
function _ResolveActorTypes(
	frameContext: TFrameContext,
	actorAdapters: { [string]: TActorAdapter },
	actorOrder: { string }
): { string }
	-- An explicit frame filter wins over registration order when the caller only wants a subset of actor types.
	if frameContext.ActorTypes == nil then
		return actorOrder
	end

	for _, actorType in ipairs(frameContext.ActorTypes) do
		-- Validate every requested actor type before the frame starts, so missing adapters fail fast.
		assert(actorAdapters[actorType] ~= nil, ("AiRuntime frame requested unknown actor type '%s'"):format(actorType))
	end

	return frameContext.ActorTypes
end

function _CreateRuntimeFrameProfile(): TRuntimeFrameProfile?
	if DebugConfig.ENABLED ~= true or DebugConfig.AI_RUNTIME_PROFILING ~= true then
		return nil
	end

	return {
		FrameStartedAt = os.clock(),
		ActorEnumerationMilliseconds = 0,
		BuildEntityStateMilliseconds = 0,
		InitialActionStateMilliseconds = 0,
		RefreshActionStateMilliseconds = 0,
		HookMilliseconds = 0,
		FactBuildMilliseconds = 0,
		ServiceBuildMilliseconds = 0,
		TreeMilliseconds = 0,
		TransitionMilliseconds = 0,
		ActionMilliseconds = 0,
		ActorCount = 0,
		FullSkipCount = 0,
		ActionOnlyCount = 0,
		TreeEvaluatedCount = 0,
		FactBuildCount = 0,
		ServiceBuildCount = 0,
	}
end

function _CaptureMilliseconds(startedAt: number?): number
	if startedAt == nil then
		return 0
	end

	return (os.clock() - startedAt) * 1000
end

function _BuildServiceTickDeadline(frameContext: TFrameContext): number?
	local tickBudgetSeconds = frameContext.TickBudgetSeconds
	if type(tickBudgetSeconds) ~= "number" or tickBudgetSeconds <= 0 then
		return nil
	end

	return os.clock() + tickBudgetSeconds
end

function _ShouldStopForTimeBudget(tickDeadline: number?): boolean
	return type(tickDeadline) == "number" and os.clock() >= tickDeadline
end

function _BuildDirectCombatHookOutcome(
	actionState: TActionState,
	frameContext: TFrameContext,
	options: {
		Entity: number,
		NeedsFacts: boolean,
		NeedsServices: boolean,
		RuntimeProfile: TRuntimeFrameProfile?,
	}
): THookOutcome?
	local baseServices = nil
	local registryService = nil
	local precheckPassed = DebugPlus.profile(
		runFrameBuildDirectCombatHookOutcomeBuildFactsPrecheckProfileTag,
		function()
			baseServices = frameContext.Services
			if type(baseServices) ~= "table" then
				return false
			end

			registryService = baseServices.CombatActorRegistryService
			if registryService == nil then
				return false
			end

			return true
		end,
		runFrameProfilingEnabled
	)
	if not precheckPassed then
		return nil
	end

	local currentTime = frameContext.CurrentTime
	local runtimeProfile = options.RuntimeProfile
	local services = if options.NeedsServices then table.clone(baseServices) else nil
	if services ~= nil then
		DebugPlus.profile(runFrameBuildDirectCombatHookOutcomeBuildServicesProfileTag, function()
			local serviceBuildStartedAt = if runtimeProfile ~= nil then os.clock() else nil
			local builtServices = registryService:BuildServices(options.Entity, currentTime, frameContext.TickId)
			for key, value in pairs(builtServices) do
				services[key] = value
			end
			services.ActionState = actionState
			if runtimeProfile ~= nil then
				runtimeProfile.ServiceBuildCount += 1
				runtimeProfile.ServiceBuildMilliseconds += _CaptureMilliseconds(serviceBuildStartedAt)
			end
		end, runFrameProfilingEnabled)
	end

	local facts = nil
	local shouldBuildFacts = DebugPlus.profile(runFrameBuildDirectCombatHookOutcomeBuildFactsGateProfileTag, function()
		return options.NeedsFacts == true
	end, runFrameProfilingEnabled)
	if shouldBuildFacts then
		DebugPlus.profile(runFrameBuildDirectCombatHookOutcomeBuildFactsProfileTag, function()
			local factBuildStartedAt = if runtimeProfile ~= nil then os.clock() else nil
			facts = registryService:BuildFacts(options.Entity, currentTime)
			if runtimeProfile ~= nil then
				runtimeProfile.FactBuildCount += 1
				runtimeProfile.FactBuildMilliseconds += _CaptureMilliseconds(factBuildStartedAt)
			end
		end, runFrameProfilingEnabled)
	end

	return {
		Facts = if facts ~= nil then facts else EMPTY_HOOK_OUTCOME.Facts,
		BehaviorContext = EMPTY_HOOK_OUTCOME.BehaviorContext,
		Services = if services ~= nil then services else EMPTY_HOOK_OUTCOME.Services,
	}
end

--[=[
	@private
	Builds the behavior-tree execution context from hook output and adapter state.
	@within AiRuntimeService
	@param entity number
	@param actorType string
	@param adapter TActorAdapter
	@param hookOutcome THookOutcome
	@return { [string]: any }
]=]
function _BuildTreeContext(
	entity: number,
	actorType: string,
	adapter: TActorAdapter,
	hookOutcome: THookOutcome
): { [string]: any }
	local treeContext = {
		Entity = entity,
		ActorType = actorType,
		Facts = hookOutcome.Facts,
		ActionFactory = adapter,
	}

	for key, value in pairs(hookOutcome.BehaviorContext) do
		if key ~= "Entity" and key ~= "ActorType" and key ~= "Facts" and key ~= "ActionFactory" then
			-- Keep hook-provided fields, but never let them overwrite the reserved tree keys.
			treeContext[key] = value
		end
	end

	return treeContext
end

--[=[
	@private
	Normalizes an adapter action-state snapshot into the shape expected by the shared BehaviorSystem boundary.
	@within AiRuntimeService
	@param actionState TActionState?
	@return TActionState
]=]
function _CloneActionState(actionState: TActionState?): TActionState
	if actionState == nil then
		-- A missing state is normalized to the idle shape expected by the shared BehaviorSystem boundary.
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

	-- Clone the known fields so later runtime phases mutate a local copy instead of the adapter payload.
	return {
		CurrentActionId = actionState.CurrentActionId,
		ActionState = actionState.ActionState or "Idle",
		ActionData = actionState.ActionData,
		PendingActionId = actionState.PendingActionId,
		PendingActionData = actionState.PendingActionData,
		StartedAt = (actionState :: any).StartedAt or (actionState :: any).ActionStartedAt,
		FinishedAt = (actionState :: any).FinishedAt,
	}
end

--[=[
	@private
	Returns the optional adapter label used in defect payloads.
	@within AiRuntimeService
	@param adapter TActorAdapter
	@return string?
]=]
function _GetActorLabel(adapter: TActorAdapter): string?
	if adapter.GetActorLabel == nil then
		return nil
	end

	local actorLabel = adapter:GetActorLabel()
	Validation.ValidateActorLabel("unknown", actorLabel)
	return actorLabel
end

--[=[
	@private
	Builds one immutable cleanup result payload.
	@within AiRuntimeService
	@param actorType string
	@param entity number
	@param cleanupKind TCleanupKind
	@param status string
	@param defect TErrorSinkPayload?
	@return TCleanupResult
]=]
function _BuildCleanupResult(
	actorType: string,
	entity: number,
	cleanupKind: TCleanupKind,
	status: string,
	defect: TErrorSinkPayload?
): TCleanupResult
	return {
		ActorType = actorType,
		Entity = entity,
		CleanupKind = cleanupKind,
		Status = status,
		Defect = defect,
	}
end

return table.freeze(Runtime)
