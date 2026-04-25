--!strict

--[[
	Module: MiningContext
	Purpose: Owns server-authoritative extractor production for resource-tile placements.
	Used In System: Listens to PlacementContext structure placements and grants run-only resources through EconomyContext.
	Boundaries: Owns extractor runtime ECS and scheduling only; Economy owns wallet balances and Placement owns structure spawning.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local BaseContext = require(ReplicatedStorage.Utilities.BaseContext)
local Result = require(ReplicatedStorage.Utilities.Result)
local PlacementTypes = require(ReplicatedStorage.Contexts.Placement.Types.PlacementTypes)

local MiningECSWorldService = require(script.Parent.Infrastructure.ECS.MiningECSWorldService)
local MiningComponentRegistry = require(script.Parent.Infrastructure.ECS.MiningComponentRegistry)
local MiningEntityFactory = require(script.Parent.Infrastructure.ECS.MiningEntityFactory)
local ExtractorMiningSystem = require(script.Parent.Infrastructure.Services.ExtractorMiningSystem)
local ResourceNodeRegistryService = require(script.Parent.Infrastructure.Services.ResourceNodeRegistryService)
local RegisterExtractorCommand = require(script.Parent.Application.Commands.RegisterExtractorCommand)
local CleanupAllExtractorsCommand = require(script.Parent.Application.Commands.CleanupAllExtractorsCommand)

local Catch = Result.Catch

type StructureRecord = PlacementTypes.StructureRecord
type RunState = "Idle" | "Prep" | "Wave" | "Resolution" | "Climax" | "Endless" | "RunEnd"

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
		Name = "ExtractorMiningSystem",
		Module = ExtractorMiningSystem,
		CacheAs = "_extractorMiningSystem",
	},
	{
		Name = "ResourceNodeRegistryService",
		Module = ResourceNodeRegistryService,
		CacheAs = "_resourceNodeRegistryService",
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
}

local MiningModules: BaseContext.TModuleLayers = {
	Infrastructure = InfrastructureModules,
	Application = ApplicationModules,
}

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
	},
	Teardown = {
		Before = "_BeforeDestroy",
		Fields = {
			{ Field = "_structurePlacedConnection", Method = "Disconnect" },
			{ Field = "_runStateChangedConnection", Method = "Disconnect" },
		},
	},
})

local MiningBaseContext = BaseContext.new(MiningContext)

function MiningContext:KnitInit()
	MiningBaseContext:KnitInit()
	self._structurePlacedConnection = nil :: RBXScriptConnection?
	self._runStateChangedConnection = nil :: RBXScriptConnection?
end

function MiningContext:KnitStart()
	MiningBaseContext:KnitStart()

	self._structurePlacedConnection = self._placementContext.StructurePlaced:Connect(function(record: StructureRecord)
		local result = self:_RegisterExtractor(record)
		if not result.success then
			Result.MentionError("Mining:OnStructurePlaced", "Failed to register extractor", {
				CauseType = result.type,
				CauseMessage = result.message,
				InstanceId = record.instanceId,
				StructureType = record.structureType,
			}, result.type)
		end
	end)

	self._runStateChangedConnection = self._runContext.StateChanged:Connect(
		function(newState: RunState, previousState: RunState)
			local isRunEndCleanup = newState == "RunEnd"
			local isFreshRunStartCleanup = previousState == "Idle" and newState == "Prep"
			if not isRunEndCleanup and not isFreshRunStartCleanup then
				return
			end

			local result = self:_CleanupAll()
			if not result.success then
				Result.MentionError("Mining:RunCleanup", "Failed to cleanup mining entities", {
					CauseType = result.type,
					CauseMessage = result.message,
				}, result.type)
				return
			end

			if isFreshRunStartCleanup then
				local registerNodesResult = self:_RegisterResourceNodes()
				if not registerNodesResult.success then
					Result.MentionError("Mining:OnRunPrep", "Failed to register resource nodes", {
						CauseType = registerNodesResult.type,
						CauseMessage = registerNodesResult.message,
					}, registerNodesResult.type)
				end
			end
		end
	)

	MiningBaseContext:RegisterSchedulerSystem("CombatTick", function()
		self._extractorMiningSystem:Tick(MiningBaseContext:GetSchedulerDeltaTime())
		self._entityFactory:FlushPendingDeletes()
	end)
end

function MiningContext:_RegisterResourceNodes(): Result.Result<number>
	return Catch(function()
		return self._resourceNodeRegistryService:RegisterNodesFromMapZone()
	end, "Mining:RegisterResourceNodes")
end

function MiningContext:_RegisterExtractor(record: StructureRecord): Result.Result<number?>
	return Catch(function()
		return self._registerExtractorCommand:Execute(record)
	end, "Mining:RegisterExtractor")
end

function MiningContext:_CleanupAll(): Result.Result<boolean>
	return Catch(function()
		return self._cleanupAllExtractorsCommand:Execute()
	end, "Mining:CleanupAll")
end

function MiningContext:_BeforeDestroy()
	local cleanupResult = self:_CleanupAll()
	if cleanupResult.success then
		return
	end

	Result.MentionError("Mining:Destroy", "Cleanup failed during destroy", {
		CauseType = cleanupResult.type,
		CauseMessage = cleanupResult.message,
	}, cleanupResult.type)
end

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

return MiningContext
