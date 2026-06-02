--!strict

--[=[
    @class MiningContext
    Owns the server-authoritative mining runtime for extractors, resource-node registration, and manual gather wiring.

    `PlacementContext` notifies this context when extractor structures are placed.
    `RunContext` drives cleanup and resource-node reattachment at run transitions.
    `MiningTick` advances extractor production while gather interactions remain owned by the mining services.
    Owns mining orchestration only; Economy owns balances and Placement owns structure spawning.
    @server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local BaseContext = require(ServerStorage.Utilities.ContextUtilities.BaseContext)
local Result = require(ReplicatedStorage.Utilities.Result)
local MiningTypes = require(ReplicatedStorage.Contexts.Mining.Types.MiningTypes)
local PlacementTypes = require(ReplicatedStorage.Contexts.Placement.Types.PlacementTypes)

local MiningECSWorldService = require(script.Parent.Infrastructure.ECS.MiningECSWorldService)
local MiningComponentRegistry = require(script.Parent.Infrastructure.ECS.MiningComponentRegistry)
local MiningEntityFactory = require(script.Parent.Infrastructure.ECS.MiningEntityFactory)
local MiningActorRegistryService = require(script.Parent.Infrastructure.Services.MiningActorRegistryService)
local MiningBehaviorRuntimeService = require(script.Parent.Infrastructure.Services.MiningBehaviorRuntimeService)
local ExtractorMiningSystem = require(script.Parent.Infrastructure.Systems.ExtractorMiningSystem)
local MiningInstanceFactory = require(script.Parent.Infrastructure.ECS.MiningInstanceFactory)
local ResourceNodeRegistryService = require(script.Parent.Infrastructure.Services.ResourceNodeRegistryService)
local ResourceGatherInteractionService = require(script.Parent.Infrastructure.Services.ResourceGatherInteractionService)
local RegisterExtractorCommand = require(script.Parent.Application.Commands.RegisterExtractorCommand)
local CleanupAllExtractorsCommand = require(script.Parent.Application.Commands.CleanupAllExtractorsCommand)
local GatherResourceCommand = require(script.Parent.Application.Commands.GatherResourceCommand)

local Catch = Result.Catch

type StructureRecord = PlacementTypes.StructureRecord
type RunState = "Idle" | "Prep" | "Wave" | "Resolution" | "Climax" | "Endless" | "RunEnd"
type TMiningActorTypePayload = MiningTypes.TMiningActorTypePayload
type TMiningActorPayload = MiningTypes.TMiningActorPayload
type TMiningActionState = MiningTypes.TMiningActionState

-- â”€â”€ Constants â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

local InfrastructureModules: { BaseContext.TModuleSpec } = {
	{
		Name = "MiningComponentRegistry",
		Module = MiningComponentRegistry,
	},
	{
		Name = "MiningEntityFactory",
		Module = MiningEntityFactory,
		CacheAs = "_entityFactory",
	},
	{
		Name = "MiningInstanceFactory",
		Module = MiningInstanceFactory,
		CacheAs = "_instanceFactory",
	},
	{
		Name = "MiningActorRegistryService",
		Module = MiningActorRegistryService,
		CacheAs = "_actorRegistryService",
	},
	{
		Name = "MiningBehaviorRuntimeService",
		Module = MiningBehaviorRuntimeService,
		CacheAs = "_behaviorRuntimeService",
	},
	{
		Name = "ExtractorMiningSystem",
		Module = ExtractorMiningSystem,
		CacheAs = "_extractorMiningSystem",
	},
	{
		Name = "ResourceNodeRegistryService",
		Module = ResourceNodeRegistryService,
		CacheAs = "_resourceNodeRegistryService",
	},
	{
		Name = "ResourceGatherInteractionService",
		Module = ResourceGatherInteractionService,
		CacheAs = "_resourceGatherInteractionService",
	},
}

local ApplicationModules: { BaseContext.TModuleSpec } = {
	{
		Name = "RegisterExtractorCommand",
		Module = RegisterExtractorCommand,
		CacheAs = "_registerExtractorCommand",
	},
	{
		Name = "CleanupAllExtractorsCommand",
		Module = CleanupAllExtractorsCommand,
		CacheAs = "_cleanupAllExtractorsCommand",
	},
	{
		Name = "GatherResourceCommand",
		Module = GatherResourceCommand,
		CacheAs = "_gatherResourceCommand",
	},
}

local MiningModules: BaseContext.TModuleLayers = {
	Infrastructure = InfrastructureModules,
	Application = ApplicationModules,
}

-- â”€â”€ Initialization â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

local MiningContext = Knit.CreateService({
	Name = "MiningContext",
	Client = {},
	WorldService = {
		Name = "MiningECSWorldService",
		Module = MiningECSWorldService,
	},
	Modules = MiningModules,
	ExternalServices = {
		{ Name = "MapContext", CacheAs = "_mapContext" },
		{ Name = "PlacementContext", CacheAs = "_placementContext" },
		{ Name = "RunContext", CacheAs = "_runContext" },
		{ Name = "EconomyContext", CacheAs = "_economyContext" },
		{ Name = "StructureContext", CacheAs = "_structureContext" },
	},
	AIRuntimeContext = {
		RuntimeServiceField = "_behaviorRuntimeService",
		ActorRegistryServiceField = "_actorRegistryService",
	},
	Teardown = {
		Before = "_BeforeDestroy",
		Fields = {
			{ Field = "_structurePlacedConnection", Method = "Disconnect" },
			{ Field = "_runStateChangedConnection", Method = "Disconnect" },
			{ Field = "_resourceNodeClickedConnection", Method = "Disconnect" },
			{ Field = "_instanceFactory", Method = "Destroy" },
			{ Field = "_resourceGatherInteractionService", Method = "Destroy" },
		},
	},
})

local MiningBaseContext = BaseContext.new(MiningContext)

-- â”€â”€ Public â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

--[=[
    Resets the wrapped `BaseContext` and clears cached connection handles before startup.
    @within MiningContext
]=]
function MiningContext:KnitInit()
	MiningBaseContext:KnitInit()
	self._structurePlacedConnection = nil :: RBXScriptConnection?
	self._runStateChangedConnection = nil :: RBXScriptConnection?
	self._resourceNodeClickedConnection = nil :: RBXScriptConnection?
	self._behaviorTickId = 0
	self._extractorEntitiesByInstanceId = {} :: { [number]: number }
end

--[=[
    Wires the mining runtime to placement, run-state, gather, and combat-tick events.
    @within MiningContext
]=]
function MiningContext:KnitStart()
	MiningBaseContext:KnitStart()

	-- Register extractors when placement produces a new structure record.
	self._structurePlacedConnection = self._placementContext.StructurePlaced:Connect(function(record: StructureRecord)
		local result = self:_RegisterExtractor(record)
		if not result.success then
			Result.MentionError("Mining:OnStructurePlaced", "Failed to register extractor", {
				CauseType = result.type,
				CauseMessage = result.message,
				InstanceId = record.InstanceId,
				StructureType = record.StructureType,
			}, result.type)
		end
	end)

	-- Reset mining runtime state when a new run begins or the current run ends.
	self._runStateChangedConnection = self._runContext.StateChanged:Connect(
		function(newState: RunState, previousState: RunState)
			-- Only the run-end cleanup and fresh-run prep transitions need mining teardown.
			local isRunEndCleanup = newState == "RunEnd"
			local isFreshRunStartCleanup = previousState == "Idle" and newState == "Prep"
			if not isRunEndCleanup and not isFreshRunStartCleanup then
				return
			end

			-- Clear any active gather wiring before tearing down runtime entities.
			self._resourceGatherInteractionService:Cleanup()

			-- Remove all mining entities so the next phase starts from a clean world state.
			local result = self:_CleanupAll()
			if not result.success then
				Result.MentionError("Mining:RunCleanup", "Failed to cleanup mining entities", {
					CauseType = result.type,
					CauseMessage = result.message,
				}, result.type)
				return
			end

			if isFreshRunStartCleanup then
				-- Rebuild resource-node entities from the active map zone for the new run.
				local registerNodesResult = self:_RegisterResourceNodes()
				if not registerNodesResult.success then
					Result.MentionError("Mining:OnRunPrep", "Failed to register resource nodes", {
						CauseType = registerNodesResult.type,
						CauseMessage = registerNodesResult.message,
					}, registerNodesResult.type)
					return
				end

				-- Reattach gather interactions after the node registry has been rebuilt.
				local attachResult = self:_AttachResourceGatherInteractions()
				if not attachResult.success then
					Result.MentionError("Mining:OnRunPrep", "Failed to attach resource gather interactions", {
						CauseType = attachResult.type,
						CauseMessage = attachResult.message,
					}, attachResult.type)
				end
			end
		end
	)

	-- Forward manual resource clicks into the gather command and report failures.
	self._resourceNodeClickedConnection = self._resourceGatherInteractionService.ResourceNodeClicked:Connect(
		function(player: Player, resourcePart: BasePart)
			local result = self:_GatherResourceFromNode(player, resourcePart)
			if result.success then
				return
			end

			Result.MentionError("Mining:ManualGather", "Failed to gather resource", {
				CauseType = result.type,
				CauseMessage = result.message,
				PlayerUserId = player.UserId,
				PartName = resourcePart.Name,
				PartPath = resourcePart:GetFullName(),
			}, result.type)
		end
	)

	-- Advance extractor AI and flush deferred entity deletes afterward.
	MiningBaseContext:RegisterSchedulerSystem("MiningTick", function()
		self:_RunBehaviorFrame(MiningBaseContext:GetSchedulerDeltaTime())
		self._entityFactory:FlushPendingDeletes()
	end)
end

-- â”€â”€ Private â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

function MiningContext:_RegisterResourceNodes(): Result.Result<number>
	return Catch(function()
		return self._resourceNodeRegistryService:RegisterNodesFromMapZone()
	end, "Mining:RegisterResourceNodes")
end

function MiningContext:_AttachResourceGatherInteractions(): Result.Result<number>
	return Catch(function()
		return self._resourceGatherInteractionService:AttachToRegisteredNodes()
	end, "Mining:AttachResourceGatherInteractions")
end

function MiningContext:_GatherResourceFromNode(player: Player, resourcePart: BasePart): Result.Result<nil>
	return Catch(function()
		return self._gatherResourceCommand:Execute(player, resourcePart)
	end, "Mining:GatherResourceFromNode")
end

function MiningContext:_RegisterExtractor(record: StructureRecord): Result.Result<number?>
	return Catch(function()
		local registerResult = self._registerExtractorCommand:Execute(record)
		if not registerResult.success or registerResult.value == nil then
			return registerResult
		end

		self._extractorEntitiesByInstanceId[record.InstanceId] = registerResult.value

		return registerResult
	end, "Mining:RegisterExtractor")
end

function MiningContext:_CleanupAll(): Result.Result<boolean>
	return Catch(function()
		table.clear(self._extractorEntitiesByInstanceId)
		return self._cleanupAllExtractorsCommand:Execute()
	end, "Mining:CleanupAll")
end

function MiningContext:_RunBehaviorFrame(dt: number)
	self._behaviorTickId += 1
	local frameResult = self._behaviorRuntimeService:RunFrame({
		CurrentTime = os.clock(),
		TickId = self._behaviorTickId,
		DeltaTime = dt,
		Services = {
			MiningActorRegistryService = self._actorRegistryService,
		},
	})

	for _, entityResult in ipairs(frameResult.EntityResults) do
		self._actorRegistryService:NotifyActionResult(entityResult.Entity, entityResult)
	end
end

-- Cleans up gather wiring before the wrapped BaseContext tears down shared services.
function MiningContext:_BeforeDestroy()
	self._resourceGatherInteractionService:Cleanup()

	local cleanupResult = self:_CleanupAll()
	if not cleanupResult.success then
		Result.MentionError("Mining:Destroy", "Cleanup failed during destroy", {
			CauseType = cleanupResult.type,
			CauseMessage = cleanupResult.message,
		}, cleanupResult.type)
	end

	local stopRuntimeResult = self._behaviorRuntimeService:StopRuntime()
	if not stopRuntimeResult.success then
		Result.MentionError("Mining:Destroy", "Failed to stop mining runtime", {
			CauseType = stopRuntimeResult.type,
			CauseMessage = stopRuntimeResult.message,
		}, stopRuntimeResult.type)
	end
end

-- â”€â”€ Public â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

--[=[
    Shuts down the wrapped `BaseContext` and reports teardown failures.
    @within MiningContext
]=]
function MiningContext:Destroy()
	local destroyResult = MiningBaseContext:Destroy()
	if destroyResult.success then
		return
	end

	Result.MentionError("Mining:Destroy", "BaseContext teardown failed", {
		CauseType = destroyResult.type,
		CauseMessage = destroyResult.message,
	}, destroyResult.type)
end

function MiningContext:GetEntityFactory(): Result.Result<any>
	return Result.Ok(self._entityFactory)
end

function MiningContext:GetInstanceFactory(): Result.Result<any>
	return Result.Ok(self._instanceFactory)
end

function MiningContext:GetExtractorEntityByInstanceId(instanceId: number): Result.Result<number?>
	return Result.Ok(self._extractorEntitiesByInstanceId[instanceId])
end

function MiningContext:GetExtractorMiningSystem(): Result.Result<any>
	return Result.Ok(self._extractorMiningSystem)
end

function MiningContext:GetMiningActorActionState(actorHandle: string): Result.Result<TMiningActionState?>
	return Result.Ok(self._actorRegistryService:GetActionStateByHandle(actorHandle))
end

function MiningContext:RegisterActorType(payload: TMiningActorTypePayload): Result.Result<boolean>
	return Catch(function()
		return self._actorRegistryService:RegisterActorType(payload)
	end, "Mining:RegisterActorType")
end

function MiningContext:RegisterMiningActor(payload: TMiningActorPayload): Result.Result<string>
	return Catch(function()
		if not self._actorRegistryService:IsRuntimeStarted() then
			local queueResult = self._actorRegistryService:QueueActor(payload)
			if not queueResult.success then
				return queueResult
			end

			local startRuntimeResult = self._behaviorRuntimeService:StartRuntime()
			if not startRuntimeResult.success then
				return startRuntimeResult
			end

			return queueResult
		end

		local behaviorTreeResult = self._behaviorRuntimeService:BuildTree(payload.BehaviorDefinition)
		if not behaviorTreeResult.success then
			return behaviorTreeResult
		end

		return self._actorRegistryService:RegisterActor(payload, behaviorTreeResult.value)
	end, "Mining:RegisterMiningActor")
end

function MiningContext:UnregisterMiningActor(actorHandle: string): Result.Result<boolean>
	return Catch(function()
		local record = self._actorRegistryService:GetRecordByHandle(actorHandle)
		if record ~= nil then
			self._behaviorRuntimeService:CancelActorAction(record.ActorType, record.RuntimeId, {
				CurrentTime = os.clock(),
				TickId = self._behaviorTickId,
				DeltaTime = 0,
				Services = {
					MiningActorRegistryService = self._actorRegistryService,
				},
				ActorTypes = {
					record.ActorType,
				},
			})
		end

		return self._actorRegistryService:UnregisterActor(actorHandle)
	end, "Mining:UnregisterMiningActor")
end

return MiningContext
