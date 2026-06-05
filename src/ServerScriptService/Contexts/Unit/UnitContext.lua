--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local BaseContext = require(ServerStorage.Utilities.ContextUtilities.BaseContext)
local Result = require(ReplicatedStorage.Utilities.Result)
local UnitTypes = require(ReplicatedStorage.Contexts.Unit.Types.UnitTypes)

local UnitEntityReadService = require(script.Parent.Infrastructure.Entity.UnitEntityReadService)
local UnitEntitySchema = require(script.Parent.Infrastructure.Entity.UnitEntitySchema)
local UnitAIBehaviors = require(script.Parent.Config.AIBehaviors)
local UnitAIProfiles = require(script.Parent.Config.AIProfiles)
local UnitCombatRules = require(script.Parent.Config.CombatRules)
local UnitSpawnPolicy = require(script.Parent.UnitDomain.Policies.UnitSpawnPolicy)
local UnitBuilderConstructionSystem = require(script.Parent.Infrastructure.Systems.UnitBuilderConstructionSystem)

local SpawnUnitCommand = require(script.Parent.Application.Commands.SpawnUnitCommand)
local DespawnUnitCommand = require(script.Parent.Application.Commands.DespawnUnitCommand)
local CleanupUnitsCommand = require(script.Parent.Application.Commands.CleanupUnitsCommand)
local IssueUnitMoveOrderCommand = require(script.Parent.Application.Commands.IssueUnitMoveOrderCommand)
local GetActiveUnitsQuery = require(script.Parent.Application.Queries.GetActiveUnitsQuery)
local GetOwnerUnitCountQuery = require(script.Parent.Application.Queries.GetOwnerUnitCountQuery)

type SpawnUnitRequest = UnitTypes.SpawnUnitRequest
type SpawnUnitResult = UnitTypes.SpawnUnitResult

local Catch = Result.Catch
local Ok = Result.Ok

local function moduleSpec(name: string, module: any, cacheAs: string?): BaseContext.TModuleSpec
	return {
		Name = name,
		Module = module,
		CacheAs = cacheAs,
	}
end

local InfrastructureModules: { BaseContext.TModuleSpec } = {
	{
		Name = "UnitEntityReadService",
		Factory = function(service: any, _baseContext: any)
			return UnitEntityReadService.new()
		end,
		CacheAs = "_unitReadService",
	},
}

local DomainModules: { BaseContext.TModuleSpec } = {
	moduleSpec("UnitSpawnPolicy", UnitSpawnPolicy),
}

local ApplicationModules: { BaseContext.TModuleSpec } = {
	moduleSpec("SpawnUnitCommand", SpawnUnitCommand, "_spawnUnitCommand"),
	moduleSpec("DespawnUnitCommand", DespawnUnitCommand, "_despawnUnitCommand"),
	moduleSpec("CleanupUnitsCommand", CleanupUnitsCommand, "_cleanupUnitsCommand"),
	moduleSpec("IssueUnitMoveOrderCommand", IssueUnitMoveOrderCommand, "_issueUnitMoveOrderCommand"),
	moduleSpec("GetActiveUnitsQuery", GetActiveUnitsQuery, "_getActiveUnitsQuery"),
	moduleSpec("GetOwnerUnitCountQuery", GetOwnerUnitCountQuery, "_getOwnerUnitCountQuery"),
}

local UnitContext = Knit.CreateService({
	Name = "UnitContext",
	Client = {},
	Modules = {
		Infrastructure = InfrastructureModules,
		Domain = DomainModules,
		Application = ApplicationModules,
	},
	ExternalServices = {
		{ Name = "AIContext", CacheAs = "_aiContext" },
		{ Name = "CombatContext", CacheAs = "_combatContext" },
		{ Name = "EntityContext", CacheAs = "_entityContext" },
		{ Name = "StructureContext", CacheAs = "_structureContext" },
		{ Name = "TeamContext", CacheAs = "_teamContext" },
		{ Name = "WorldContext", CacheAs = "_worldContext" },
	},
	Teardown = {
		Before = "_BeforeDestroy",
		Fields = {
			{ Field = "_runEndedConnection", Method = "Disconnect" },
			{ Field = "_playerRemovingConnection", Method = "Disconnect" },
		},
	},
})

local UnitBaseContext = BaseContext.new(UnitContext)

function UnitContext:KnitInit()
	UnitBaseContext:KnitInit()
	self._runEndedConnection = nil :: any
	self._playerRemovingConnection = nil :: any
end

function UnitContext:KnitStart()
	UnitBaseContext:KnitStart()

	local entityResult = self:_RegisterEntityInfrastructure()
	if not entityResult.success then
		error(("UnitContext failed to register Entity infrastructure: [%s] %s"):format(
			tostring(entityResult.type),
			tostring(entityResult.message)
		))
	end

	local aiResult = self:_RegisterAIContracts()
	if not aiResult.success then
		error(("UnitContext failed to register AI contracts: [%s] %s"):format(
			tostring(aiResult.type),
			tostring(aiResult.message)
		))
	end

	local combatRuleResult = self:_RegisterCombatRules()
	if not combatRuleResult.success then
		error(("UnitContext failed to register Combat rules: [%s] %s"):format(
			tostring(combatRuleResult.type),
			tostring(combatRuleResult.message)
		))
	end

	UnitBaseContext:OnContextEvent("Run", "RunEnded", function()
		self:_OnRunEnded()
	end, "_runEndedConnection")

	UnitBaseContext:OnPlayerRemoving(function(player: Player)
		self:CleanupOwner("Player", tostring(player.UserId))
	end, "_playerRemovingConnection")
end

function UnitContext:_RegisterEntityInfrastructure(): Result.Result<boolean>
	return Catch(function()
		local featureResult = self._entityContext:RegisterEntityFeature({
			FeatureName = "Unit",
			Schema = UnitEntitySchema,
		})
		if not featureResult.success then
			return featureResult
		end

		return self._entityContext:RegisterSystem("ActionAdvance", {
			Name = "UnitBuilderConstructionSystem",
			Phase = "ActionAdvance",
			Reads = {
				"Structure.BuildContributionState",
				"Unit.BuilderAssignment",
				"Entity.Ownership",
				"AI.ActionState",
			},
			Writes = {
				"Unit.BuilderAssignment",
				"Movement.MoveIntent",
				"Entity.DirtyTag",
			},
			Factory = function(entityFactory: any, _compiledSchemas: any)
				return UnitBuilderConstructionSystem.new(entityFactory, {
					StructureContext = self._structureContext,
					UnitReadService = self._unitReadService,
				})
			end,
		})
	end, "UnitContext:RegisterEntityInfrastructure")
end

function UnitContext:_RegisterAIContracts(): Result.Result<boolean>
	return Catch(function()
		local function acceptDuplicate(result: Result.Result<any>, duplicateType: string): Result.Result<boolean>
			if result.success or result.type == duplicateType then
				return Ok(true)
			end
			return result
		end

		for _, behaviorPayload in pairs(UnitAIBehaviors) do
			local behaviorResult =
				acceptDuplicate(self._aiContext:RegisterBehaviorDefinition(behaviorPayload), "DuplicateBehaviorDefinition")
			if not behaviorResult.success then
				return behaviorResult
			end
		end

		for _, profilePayload in pairs(UnitAIProfiles) do
			local profileResult = acceptDuplicate(self._aiContext:RegisterProfile(profilePayload), "DuplicateProfile")
			if not profileResult.success then
				return profileResult
			end
		end

		return Ok(true)
	end, "UnitContext:RegisterAIContracts")
end

function UnitContext:_RegisterCombatRules(): Result.Result<boolean>
	return Catch(function()
		for _, payload in ipairs(UnitCombatRules.MovementPresentation or {}) do
			local result = self._combatContext:RegisterMovementPresentationRule(payload)
			if not result.success then
				return result
			end
		end
		return Ok(true)
	end, "UnitContext:RegisterCombatRules")
end

function UnitContext:SpawnUnit(request: SpawnUnitRequest): Result.Result<SpawnUnitResult>
	return Catch(function()
		return self._spawnUnitCommand:Execute(request)
	end, "Unit:SpawnUnit")
end

function UnitContext:DespawnUnit(entity: number): Result.Result<boolean>
	return Catch(function()
		return self._despawnUnitCommand:Execute(entity)
	end, "Unit:DespawnUnit")
end

function UnitContext:CleanupOwner(ownerKind: string, ownerId: string): Result.Result<boolean>
	return Catch(function()
		return self._cleanupUnitsCommand:Execute(ownerKind, ownerId)
	end, "Unit:CleanupOwner")
end

function UnitContext:CleanupAll(): Result.Result<boolean>
	return Catch(function()
		return self._cleanupUnitsCommand:Execute(nil, nil)
	end, "Unit:CleanupAll")
end

function UnitContext:IssueMoveOrder(player: Player, request: UnitTypes.IssueMoveOrderRequest): Result.Result<number>
	return Catch(function()
		return self._issueUnitMoveOrderCommand:Execute(player, request)
	end, "Unit:IssueMoveOrder")
end

function UnitContext:GetActiveUnits(): Result.Result<{ number }>
	return Catch(function()
		return self._getActiveUnitsQuery:Execute()
	end, "Unit:GetActiveUnits")
end

function UnitContext:GetOwnerUnitCount(ownerKind: string, ownerId: string): Result.Result<number>
	return Catch(function()
		return self._getOwnerUnitCountQuery:Execute(ownerKind, ownerId)
	end, "Unit:GetOwnerUnitCount")
end

function UnitContext:WarmFastFlowForRun(): Result.Result<boolean>
	return self._combatContext:WarmMovementRuntime()
end

function UnitContext:GetSchedulerBindingStatus(targetField: string): Result.Result<any>
	return Ok(UnitBaseContext:GetSchedulerBindingStatus(targetField))
end

function UnitContext:_OnRunEnded()
	local result = self:CleanupAll()
	if not result.success then
		Result.MentionError("Unit:RunEnded", "Failed to cleanup units after run ended", {
			CauseType = result.type,
			CauseMessage = result.message,
		}, result.type)
	end
end

function UnitContext:_BeforeDestroy()
	local result = self:CleanupAll()
	if not result.success then
		Result.MentionError("Unit:Destroy", "Cleanup failed during destroy", {
			CauseType = result.type,
			CauseMessage = result.message,
		}, result.type)
	end
end

function UnitContext:Destroy()
	local destroyResult = UnitBaseContext:Destroy()
	if not destroyResult.success then
		Result.MentionError("Unit:Destroy", "BaseContext teardown failed", {
			CauseType = destroyResult.type,
			CauseMessage = destroyResult.message,
		}, destroyResult.type)
	end
end

function UnitContext.Client:IssueMoveOrder(player: Player, request: UnitTypes.IssueMoveOrderRequest): boolean
	local result = self.Server:IssueMoveOrder(player, request)
	return result.success and result.value > 0
end

return UnitContext
