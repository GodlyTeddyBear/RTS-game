--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)
local EntityProofRuntimeConfig = require(script.Parent.Parent.Parent.Config.EntityProofRuntimeConfig)
local EntityOperationSupport = require(script.Parent.Parent.Support.EntityOperationSupport)
local Errors = require(script.Parent.Parent.Parent.Errors)

local RunOperationalProofCommand = {}
RunOperationalProofCommand.__index = RunOperationalProofCommand
setmetatable(RunOperationalProofCommand, BaseCommand)

function RunOperationalProofCommand.new()
	local self = BaseCommand.new("Entity", "RunOperationalProof")
	return setmetatable(self, RunOperationalProofCommand)
end

function RunOperationalProofCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_lifecycle = "EntityLifecycleStateMachine",
		_validationService = "EntityValidationService",
		_readinessPolicy = "EntityReadinessPolicy",
		_startupState = "EntityStartupStateService",
		_runtimeScheduler = "EntityRuntimeSchedulerService",
		_schemaRegistry = "EntitySchemaRegistry",
		_systemRegistry = "EntitySystemRegistry",
		_instanceBindingRegistry = "EntityInstanceBindingRegistry",
		_syncContributorRegistry = "EntitySyncContributorRegistry",
		_replicationRegistry = "EntityReplicationRegistry",
		_replicationService = "EntityReplicationService",
		_instanceBindingService = "EntityInstanceBindingService",
		_runtimeParticipation = "EntityRuntimeParticipationService",
		_createEntityCommand = "CreateEntityCommand",
		_destroyEntityCommand = "DestroyEntityCommand",
		_registerRuntimeEntityCommand = "RegisterRuntimeEntityCommand",
		_bindEntityInstanceCommand = "BindEntityInstanceCommand",
		_hydrateEntityReplicationCommand = "HydrateEntityReplicationCommand",
		_completeEntityReplicationBootstrapCommand = "CompleteEntityReplicationBootstrapCommand",
	})
end

function RunOperationalProofCommand:Execute(): Result.Result<any>
	return Result.Catch(function()
		local lifecycleResult = EntityOperationSupport.RequireLifecycleStates(self._validationService, "RunOperationalProof", self._lifecycle:GetState(), {
			"Running",
		})
		if not lifecycleResult.success then
			return lifecycleResult
		end

		local proofResult = {
			Lifecycle = { InitPassed = true, StartPassed = self._lifecycle:GetState() == "Running", ShutdownPassed = false },
			Runtime = { BindPassed = false, ReplicationBootstrapPassed = false, CleanupPassed = false },
			Acceptance = { Passed = false, BlockingGaps = {} },
		}

		local proofEntity = nil
		local runtimeRegistered = false
		local bindResult = Result.Ok(nil)
		local registerRuntimeResult = Result.Ok(false)

		local function readiness()
			return EntityOperationSupport.BuildReadinessStatus(self)
		end

		local function finalizeAndReturn()
			local readinessStatus = readiness()
			local cleanupPassed = readinessStatus.Runtime.PendingBindCount == 0
				and readinessStatus.Runtime.BoundEntityCount == 0
				and readinessStatus.Runtime.RuntimeEntityCount == 0
			proofResult.Runtime.CleanupPassed = cleanupPassed
			proofResult.Lifecycle.ShutdownPassed = cleanupPassed
			if not cleanupPassed then
				table.insert(proofResult.Acceptance.BlockingGaps, {
					Code = "OperationalProofCleanupFailed",
					Message = Errors.OPERATIONAL_PROOF_FAILED,
					Details = readinessStatus,
				})
			end
			proofResult.Acceptance.Passed = cleanupPassed and #proofResult.Acceptance.BlockingGaps == 0
			return proofResult
		end

		local function cleanupProofState()
			if proofEntity == nil then
				return
			end
			self._destroyEntityCommand:Execute(proofEntity)
			runtimeRegistered = false
			proofEntity = nil
		end

		local createResult = self._createEntityCommand:Execute(EntityProofRuntimeConfig.ArchetypeName, {
			Identity = {
				EntityId = "EntityProof.OperationalProof",
				EntityKind = EntityProofRuntimeConfig.FeatureName,
				DefinitionId = "OperationalProof",
			},
			Health = { Current = 1, Max = 1 },
		})
		if not createResult.success then
			table.insert(proofResult.Acceptance.BlockingGaps, {
				Code = "OperationalProofCreateFailed",
				Message = createResult.message,
				Details = createResult.data,
			})
			return Result.Ok(finalizeAndReturn())
		end
		proofEntity = createResult.value

		registerRuntimeResult = self._registerRuntimeEntityCommand:Execute(proofEntity)
		runtimeRegistered = registerRuntimeResult.success

		bindResult = self._bindEntityInstanceCommand:Execute(proofEntity)
		proofResult.Runtime.BindPassed = bindResult.success and bindResult.value ~= nil

		local primaryPlayer = Players:GetPlayers()[1]
		if primaryPlayer ~= nil then
			local hydrateResult = self._hydrateEntityReplicationCommand:Execute(primaryPlayer)
			local completeResult = self._completeEntityReplicationBootstrapCommand:Execute(primaryPlayer)
			proofResult.Runtime.ReplicationBootstrapPassed = hydrateResult.success and completeResult.success
		else
			proofResult.Runtime.ReplicationBootstrapPassed = self._replicationService:GetStatus().BootCapable
		end

		cleanupProofState()

		if not proofResult.Runtime.BindPassed and bindResult.message ~= nil then
			table.insert(proofResult.Acceptance.BlockingGaps, { Code = "OperationalProofBindFailed", Message = bindResult.message, Details = bindResult.data })
		end
		if not runtimeRegistered and registerRuntimeResult.message ~= nil then
			table.insert(proofResult.Acceptance.BlockingGaps, { Code = "OperationalProofRuntimeRegistrationFailed", Message = registerRuntimeResult.message, Details = registerRuntimeResult.data })
		end
		if not proofResult.Runtime.ReplicationBootstrapPassed then
			table.insert(proofResult.Acceptance.BlockingGaps, {
				Code = "OperationalProofReplicationUnavailable",
				Message = Errors.OPERATIONAL_PROOF_FAILED,
				Details = { Reason = "ReplicationBootstrapUnavailable" },
			})
		end

		return Result.Ok(finalizeAndReturn())
	end, self:_Label())
end

return RunOperationalProofCommand
