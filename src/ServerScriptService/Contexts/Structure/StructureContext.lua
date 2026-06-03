--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local BaseContext = require(ServerStorage.Utilities.ContextUtilities.BaseContext)
local PlacementTypes = require(ReplicatedStorage.Contexts.Placement.Types.PlacementTypes)
local Result = require(ReplicatedStorage.Utilities.Result)
local StructureTypes = require(ReplicatedStorage.Contexts.Structure.Types.StructureTypes)

local StructureEntityReadService = require(script.Parent.Infrastructure.Entity.StructureEntityReadService)
local StructureEntitySchema = require(script.Parent.Infrastructure.Entity.StructureEntitySchema)
local StructureExtractionSystem = require(script.Parent.Infrastructure.Systems.StructureExtractionSystem)
local RegisterStructurePolicy = require(script.Parent.StructureDomain.Policies.RegisterStructurePolicy)
local StructureAIBehaviors = require(script.Parent.Config.AIBehaviors)
local StructureAIProfiles = require(script.Parent.Config.AIProfiles)
local RegisterStructureCommand = require(script.Parent.Application.Commands.RegisterStructureCommand)
local AdvanceConstructionCommand = require(script.Parent.Application.Commands.AdvanceConstructionCommand)
local ApplyDamageStructureCommand = require(script.Parent.Application.Commands.ApplyDamageStructureCommand)
local CleanupAllCommand = require(script.Parent.Application.Commands.CleanupAllCommand)
local GetActiveStructuresQuery = require(script.Parent.Application.Queries.GetActiveStructuresQuery)
local GetStructureCountQuery = require(script.Parent.Application.Queries.GetStructureCountQuery)

local Catch = Result.Catch
local Ok = Result.Ok

type StructureRecord = PlacementTypes.StructureRecord
type RunState = "Idle" | "Prep" | "Wave" | "Resolution" | "Climax" | "Endless" | "RunEnd"

local function moduleSpec(name: string, module: any, cacheAs: string?): BaseContext.TModuleSpec
	return {
		Name = name,
		Module = module,
		CacheAs = cacheAs,
	}
end

local InfrastructureModules: { BaseContext.TModuleSpec } = {
	{
		Name = "StructureEntityReadService",
		Factory = function(service: any, _baseContext: any)
			return StructureEntityReadService.new(service._entityContext)
		end,
		CacheAs = "_structureReadService",
	},
}

local DomainModules: { BaseContext.TModuleSpec } = {
	moduleSpec("RegisterStructurePolicy", RegisterStructurePolicy),
}

local ApplicationModules: { BaseContext.TModuleSpec } = {
	moduleSpec("RegisterStructureCommand", RegisterStructureCommand, "_registerStructureCommand"),
	moduleSpec("AdvanceConstructionCommand", AdvanceConstructionCommand, "_advanceConstructionCommand"),
	moduleSpec("ApplyDamageStructureCommand", ApplyDamageStructureCommand, "_applyDamageStructureCommand"),
	moduleSpec("CleanupAllCommand", CleanupAllCommand, "_cleanupAllCommand"),
	moduleSpec("GetActiveStructuresQuery", GetActiveStructuresQuery, "_getActiveStructuresQuery"),
	moduleSpec("GetStructureCountQuery", GetStructureCountQuery, "_getStructureCountQuery"),
}

local StructureContext = Knit.CreateService({
	Name = "StructureContext",
	Client = {},
	Modules = {
		Infrastructure = InfrastructureModules,
		Domain = DomainModules,
		Application = ApplicationModules,
	},
	ExternalServices = {
		{ Name = "AIContext", CacheAs = "_aiContext" },
		{ Name = "EntityContext", CacheAs = "_entityContext" },
		{ Name = "EnemyContext", CacheAs = "_enemyContext" },
		{ Name = "CombatContext", CacheAs = "_combatContext" },
		{ Name = "MiningContext", CacheAs = "_miningContext" },
		{ Name = "TeamContext", CacheAs = "_teamContext" },
		{ Name = "RunContext", CacheAs = "_runContext" },
		{ Name = "PlacementContext", CacheAs = "_placementContext" },
	},
	Teardown = {
		Before = "_BeforeDestroy",
		Fields = {
			{ Field = "_structurePlacedConnection", Method = "Disconnect" },
			{ Field = "_runStateChangedConnection", Method = "Disconnect" },
		},
	},
})

local StructureBaseContext = BaseContext.new(StructureContext)

function StructureContext:KnitInit()
	StructureBaseContext:KnitInit()
	self._structurePlacedConnection = nil :: RBXScriptConnection?
	self._runStateChangedConnection = nil :: RBXScriptConnection?
end

function StructureContext:KnitStart()
	StructureBaseContext:KnitStart()

	local entityResult = self:_RegisterEntityInfrastructure()
	if not entityResult.success then
		error(("StructureContext failed to register Entity infrastructure: [%s] %s"):format(
			tostring(entityResult.type),
			tostring(entityResult.message)
		))
	end

	local aiResult = self:_RegisterAIContracts()
	if not aiResult.success then
		error(("StructureContext failed to register AI contracts: [%s] %s"):format(
			tostring(aiResult.type),
			tostring(aiResult.message)
		))
	end

	self._structurePlacedConnection = self._placementContext.StructurePlaced:Connect(function(record: StructureRecord)
		local result = self:RegisterStructure(record)
		if not result.success then
			Result.MentionError("Structure:OnStructurePlaced", "Failed to register structure", {
				CauseType = result.type,
				CauseMessage = result.message,
				InstanceId = record.InstanceId,
				StructureType = record.StructureType,
			}, result.type)
		end
	end)

	self._runStateChangedConnection = self._runContext.StateChanged:Connect(function(newState: RunState, previousState: RunState)
		local isRunEndCleanup = newState == "RunEnd"
		local isFreshRunStartCleanup = previousState == "Idle" and newState == "Prep"
		if not isRunEndCleanup and not isFreshRunStartCleanup then
			return
		end

		local result = self:CleanupAll()
		if not result.success then
			Result.MentionError("Structure:OnRunEnd", "Failed to cleanup structures", {
				CauseType = result.type,
				CauseMessage = result.message,
			}, result.type)
		end
	end)
end

function StructureContext:_RegisterEntityInfrastructure(): Result.Result<boolean>
	return Catch(function()
		local featureResult = self._entityContext:RegisterEntityFeature({
			FeatureName = "Structure",
			Schema = StructureEntitySchema,
		})
		if not featureResult.success then
			return featureResult
		end

		return self._entityContext:RegisterSystem("ActionAdvance", {
			Name = "StructureExtractionSystem",
			Phase = "ActionAdvance",
			Reads = {
				"Structure.ExtractState",
				"Structure.SourcePlacement",
				"Structure.OperationalTag",
				"AI.ActionState",
			},
			Writes = {
				"Structure.AnimationState",
				"Structure.AnimationLooping",
				"Entity.DirtyTag",
			},
			Factory = function(entityFactory: any, _compiledSchemas: any)
				return StructureExtractionSystem.new(entityFactory, {
					MiningContext = self._miningContext,
				})
			end,
		})
	end, "StructureContext:RegisterEntityInfrastructure")
end

function StructureContext:_RegisterAIContracts(): Result.Result<boolean>
	return Catch(function()
		local function acceptDuplicate(result: Result.Result<any>, duplicateType: string): Result.Result<boolean>
			if result.success or result.type == duplicateType then
				return Ok(true)
			end
			return result
		end

		for _, behaviorPayload in pairs(StructureAIBehaviors) do
			local result = acceptDuplicate(self._aiContext:RegisterBehaviorDefinition(behaviorPayload), "DuplicateBehaviorDefinition")
			if not result.success then
				return result
			end
		end

		for _, profilePayload in pairs(StructureAIProfiles) do
			local result = acceptDuplicate(self._aiContext:RegisterProfile(profilePayload), "DuplicateProfile")
			if not result.success then
				return result
			end
		end

		return Ok(true)
	end, "StructureContext:RegisterAIContracts")
end

function StructureContext:RegisterStructure(record: StructureRecord): Result.Result<number>
	return Catch(function()
		return self._registerStructureCommand:Execute(record)
	end, "Structure:RegisterStructure")
end

function StructureContext:ContributeConstruction(
	entity: number,
	workAmount: number,
	_contributorMeta: any?
): Result.Result<StructureTypes.TConstructionContributionResult>
	return Catch(function()
		return self._advanceConstructionCommand:Execute(entity, workAmount)
	end, "Structure:ContributeConstruction")
end

function StructureContext:ApplyDamage(entity: any, amount: number): Result.Result<boolean>
	return Catch(function()
		return self._applyDamageStructureCommand:Execute(entity, amount)
	end, "Structure:ApplyDamage")
end

function StructureContext:CleanupAll(): Result.Result<boolean>
	return Catch(function()
		return self._cleanupAllCommand:Execute()
	end, "Structure:CleanupAll")
end

function StructureContext:GetActiveStructures(): Result.Result<{ number }>
	return Catch(function()
		return Ok(self._getActiveStructuresQuery:Execute())
	end, "Structure:GetActiveStructures")
end

function StructureContext:GetStructureCount(): Result.Result<number>
	return Catch(function()
		return Ok(self._getStructureCountQuery:Execute())
	end, "Structure:GetStructureCount")
end

function StructureContext:GetStructurePosition(entity: number): Result.Result<Vector3?>
	return Ok(self._structureReadService:GetPosition(entity))
end

function StructureContext:IsStructureBuildableForBuilder(
	entity: number,
	ownerUserId: number,
	builderPosition: Vector3?,
	buildRange: number?
): Result.Result<boolean>
	return Catch(function()
		if typeof(builderPosition) ~= "Vector3" or type(buildRange) ~= "number" then
			return Ok(false)
		end
		local structurePosition = self._structureReadService:GetPosition(entity)
		return Ok(
			self._structureReadService:IsPlaced(entity)
				and self._structureReadService:IsUnderConstruction(entity)
				and self._structureReadService:IsOwnedByUser(entity, ownerUserId)
				and structurePosition ~= nil
				and (structurePosition - builderPosition).Magnitude <= buildRange
		)
	end, "Structure:IsStructureBuildableForBuilder")
end

function StructureContext:FindNearestOwnedUnfinishedStructure(
	ownerUserId: number,
	position: Vector3,
	maxRange: number
): Result.Result<number?>
	return Ok(self._structureReadService:FindNearestOwnedUnfinishedStructure(ownerUserId, position, maxRange))
end

function StructureContext:GetSchedulerBindingStatus(targetField: string): Result.Result<any>
	return Ok(StructureBaseContext:GetSchedulerBindingStatus(targetField))
end

function StructureContext:_BeforeDestroy()
	local cleanupResult = self:CleanupAll()
	if not cleanupResult.success then
		Result.MentionError("Structure:Destroy", "Cleanup failed during destroy", {
			CauseType = cleanupResult.type,
			CauseMessage = cleanupResult.message,
		}, cleanupResult.type)
	end
end

function StructureContext:Destroy()
	local destroyResult = StructureBaseContext:Destroy()
	if not destroyResult.success then
		Result.MentionError("Structure:Destroy", "BaseContext teardown failed", {
			CauseType = destroyResult.type,
			CauseMessage = destroyResult.message,
		}, destroyResult.type)
	end
end

return StructureContext
