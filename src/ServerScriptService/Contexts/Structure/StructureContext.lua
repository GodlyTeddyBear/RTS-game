--!strict

--[[
	Module: StructureContext
	Purpose: Owns server-authoritative structure registration, cleanup, and combat scheduling.
	Used In System: Started by Knit on the server and invoked by placement and run-lifecycle callbacks.
	High-Level Flow: Register infrastructure -> initialize ECS and commands -> bridge placement and run events -> schedule targeting and attacks.
	Boundaries: Owns structure orchestration only; does not own placement validation, enemy selection, or client presentation.
]]

-- [Dependencies]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local BaseContext = require(ReplicatedStorage.Utilities.BaseContext)
local Result = require(ReplicatedStorage.Utilities.Result)
local PlacementTypes = require(ReplicatedStorage.Contexts.Placement.Types.PlacementTypes)
local StructureTypes = require(ReplicatedStorage.Contexts.Structure.Types.StructureTypes)

local StructureECSWorldService = require(script.Parent.Infrastructure.ECS.StructureECSWorldService)
local StructureComponentRegistry = require(script.Parent.Infrastructure.ECS.StructureComponentRegistry)
local StructureEntityFactory = require(script.Parent.Infrastructure.ECS.StructureEntityFactory)
local StructureGameObjectSyncService = require(script.Parent.Infrastructure.Services.StructureGameObjectSyncService)
local RegisterStructurePolicy = require(script.Parent.StructureDomain.Policies.RegisterStructurePolicy)
local RegisterStructureCommand = require(script.Parent.Application.Commands.RegisterStructureCommand)
local ApplyDamageStructureCommand = require(script.Parent.Application.Commands.ApplyDamageStructureCommand)
local CleanupAllCommand = require(script.Parent.Application.Commands.CleanupAllCommand)
local GetActiveStructuresQuery = require(script.Parent.Application.Queries.GetActiveStructuresQuery)
local GetStructureCountQuery = require(script.Parent.Application.Queries.GetStructureCountQuery)

local Catch = Result.Catch
local Ok = Result.Ok

type StructureRecord = PlacementTypes.StructureRecord
type StructureAttackPayload = StructureTypes.StructureAttackPayload
type RunState = "Idle" | "Prep" | "Wave" | "Resolution" | "Climax" | "Endless" | "RunEnd"

local InfrastructureModules: { BaseContext.TModuleSpec } = {
	{
		Name = "StructureComponentRegistry",
		Module = StructureComponentRegistry,
	},
	{
		Name = "StructureEntityFactory",
		Module = StructureEntityFactory,
		CacheAs = "_entityFactory",
	},
	{
		Name = "StructureGameObjectSyncService",
		Module = StructureGameObjectSyncService,
		CacheAs = "_gameObjectSyncService",
	},
	{
		Name = "OnStructureAttacked",
		Factory = function(service: any, _baseContext: any)
			service._structureAttackedSignal = Instance.new("BindableEvent")
			service.StructureAttacked = service._structureAttackedSignal.Event
			return function(payload: StructureAttackPayload)
				service._structureAttackedSignal:Fire(payload)
			end
		end,
	},
}

local DomainModules: { BaseContext.TModuleSpec } = {
	{
		Name = "RegisterStructurePolicy",
		Module = RegisterStructurePolicy,
	},
}

local ApplicationModules: { BaseContext.TModuleSpec } = {
	{
		Name = "RegisterStructureCommand",
		Module = RegisterStructureCommand,
		CacheAs = "_registerStructureCommand",
	},
	{
		Name = "ApplyDamageStructureCommand",
		Module = ApplyDamageStructureCommand,
		CacheAs = "_applyDamageStructureCommand",
	},
	{
		Name = "CleanupAllCommand",
		Module = CleanupAllCommand,
		CacheAs = "_cleanupAllCommand",
	},
	{
		Name = "GetActiveStructuresQuery",
		Module = GetActiveStructuresQuery,
		CacheAs = "_getActiveStructuresQuery",
	},
	{
		Name = "GetStructureCountQuery",
		Module = GetStructureCountQuery,
		CacheAs = "_getStructureCountQuery",
	},
}

local StructureModules: BaseContext.TModuleLayers = {
	Infrastructure = InfrastructureModules,
	Domain = DomainModules,
	Application = ApplicationModules,
}

-- [Public API]

--[=[
	@class StructureContext
	Owns the server-authoritative structure combat layer and ECS lifecycle.
	@server
]=]
local StructureContext = Knit.CreateService({
	Name = "StructureContext",
	Client = {},
	WorldService = {
		Name = "StructureECSWorldService",
		Module = StructureECSWorldService,
	},
	Modules = StructureModules,
	ExternalServices = {
		{ Name = "WorldContext" },
		{ Name = "EnemyContext" },
		{ Name = "RunContext", CacheAs = "_runContext" },
		{ Name = "PlacementContext", CacheAs = "_placementContext" },
	},
	Teardown = {
		Before = "_BeforeDestroy",
		Fields = {
			{ Field = "_structurePlacedConnection", Method = "Disconnect" },
			{ Field = "_runStateChangedConnection", Method = "Disconnect" },
			{ Field = "_structureAttackedSignal", Method = "Destroy" },
		},
	},
})

local StructureBaseContext = BaseContext.new(StructureContext)

--[=[
	@prop StructureAttacked RBXScriptSignal
	@within StructureContext
	Fires when a structure schedules an attack for CombatContext to resolve.
]=]
StructureContext.StructureAttacked = nil

--[=[
	Initializes the structure registry, commands, ECS world, and attack signal.
	@within StructureContext
]=]
function StructureContext:KnitInit()
	StructureBaseContext:KnitInit()
	self._structurePlacedConnection = nil :: RBXScriptConnection?
	self._runStateChangedConnection = nil :: RBXScriptConnection?
end

--[=[
	Wires the placement bridge, run cleanup hook, and Heartbeat systems.
	@within StructureContext
]=]
function StructureContext:KnitStart()
	StructureBaseContext:KnitStart()

	-- Register new placements as ECS entities as soon as PlacementContext announces them.
	self._structurePlacedConnection = self._placementContext.StructurePlaced:Connect(function(record: StructureRecord)
		local result = self:_RegisterStructure(record)
		if not result.success then
			Result.MentionError("Structure:OnStructurePlaced", "Failed to register structure", {
				CauseType = result.type,
				CauseMessage = result.message,
				InstanceId = record.instanceId,
				StructureType = record.structureType,
			}, result.type)
		end
	end)

	-- Tear down all structures when the run ends so the next session starts clean.
	self._runStateChangedConnection = self._runContext.StateChanged:Connect(function(newState: RunState, _previousState: RunState)
		if newState ~= "RunEnd" then
			return
		end

		local result = self:_CleanupAll()
		if not result.success then
			Result.MentionError("Structure:OnRunEnd", "Failed to cleanup structures", {
				CauseType = result.type,
				CauseMessage = result.message,
			}, result.type)
		end
	end)

	StructureBaseContext:RegisterMethodSystem("CombatTick", "_entityFactory", "FlushPendingDeletes")
	StructureBaseContext:RegisterMethodSystem("CombatTick", "_gameObjectSyncService", "SyncAll")
end

-- [Private Helpers]

-- Registers a structure record with the ECS world through the application command stack.
function StructureContext:_RegisterStructure(record: StructureRecord): Result.Result<number?>
	return Catch(function()
		return self._registerStructureCommand:Execute(record)
	end, "Structure:RegisterStructure")
end

-- Clears every active structure entity from the isolated world.
function StructureContext:_CleanupAll(): Result.Result<boolean>
	return Catch(function()
		return self._cleanupAllCommand:Execute()
	end, "Structure:CleanupAll")
end

-- [Public API]

--[=[
	Returns the active structure entities.
	@within StructureContext
	@return Result.Result<{ number }> -- The active structure entity ids.
]=]
function StructureContext:GetActiveStructures(): Result.Result<{ number }>
	return Catch(function()
		return Ok(self._getActiveStructuresQuery:Execute())
	end, "Structure:GetActiveStructures")
end

--[=[
	Returns the current active structure count.
	@within StructureContext
	@return Result.Result<number> -- The active structure count.
]=]
function StructureContext:GetStructureCount(): Result.Result<number>
	return Catch(function()
		return Ok(self._getStructureCountQuery:Execute())
	end, "Structure:GetStructureCount")
end

--[=[
	Applies damage to a structure entity and disables it if it dies.
	@within StructureContext
	@param entity any -- Structure entity id.
	@param amount number -- Positive damage amount.
	@return Result.Result<boolean> -- Whether the damage killed the structure.
]=]
function StructureContext:ApplyDamage(entity: any, amount: number): Result.Result<boolean>
	return Catch(function()
		return self._applyDamageStructureCommand:Execute(entity, amount)
	end, "Structure:ApplyDamage")
end

--[=[
	Returns the structure entity factory for server-side bridge consumers.
	@within StructureContext
	@return Result.Result<any> -- Structure entity factory.
]=]
function StructureContext:GetEntityFactory(): Result.Result<any>
	return Ok(self._entityFactory)
end

--[=[
	Returns the structure model sync service for cross-context runtime cleanup.
	@within StructureContext
	@return Result.Result<any> -- Structure game object sync service.
]=]
function StructureContext:GetGameObjectSyncService(): Result.Result<any>
	return Ok(self._gameObjectSyncService)
end

function StructureContext:_BeforeDestroy()
	-- Run cleanup first so entity deletion still has access to live collaborators.
	local cleanupResult = self:_CleanupAll()
	if not cleanupResult.success then
		Result.MentionError("Structure:Destroy", "Cleanup failed during destroy", {
			CauseType = cleanupResult.type,
			CauseMessage = cleanupResult.message,
		}, cleanupResult.type)
	end
end

--[=[
	Disconnects listeners and cleans up the isolated world.
	@within StructureContext
]=]
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
