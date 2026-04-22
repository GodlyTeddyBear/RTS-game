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
local ServerScriptService = game:GetService("ServerScriptService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Registry = require(ReplicatedStorage.Utilities.Registry)
local Result = require(ReplicatedStorage.Utilities.Result)
local WrapContext = require(ReplicatedStorage.Utilities.WrapContext)
local PlacementTypes = require(ReplicatedStorage.Contexts.Placement.Types.PlacementTypes)
local StructureTypes = require(ReplicatedStorage.Contexts.Structure.Types.StructureTypes)

local ServerScheduler = require(ServerScriptService.Scheduler.ServerScheduler)

local StructureECSWorldService = require(script.Parent.Infrastructure.ECS.StructureECSWorldService)
local StructureComponentRegistry = require(script.Parent.Infrastructure.ECS.StructureComponentRegistry)
local StructureEntityFactory = require(script.Parent.Infrastructure.ECS.StructureEntityFactory)
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

-- [Public API]

--[=[
	@class StructureContext
	Owns the server-authoritative structure combat layer and ECS lifecycle.
	@server
]=]
local StructureContext = Knit.CreateService({
	Name = "StructureContext",
	Client = {},
})

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
	local registry = Registry.new("Server")
	local worldService = StructureECSWorldService.new()

	-- Register the isolated ECS world and all structure-specific services first.
	registry:Register("StructureECSWorldService", worldService, "Infrastructure")
	worldService:Init(registry, "StructureECSWorldService")
	registry:Register("World", worldService:GetWorld())
	registry:Register("StructureComponentRegistry", StructureComponentRegistry.new(), "Infrastructure")
	registry:Register("StructureEntityFactory", StructureEntityFactory.new(), "Infrastructure")
	registry:Register("RegisterStructurePolicy", RegisterStructurePolicy.new(), "Domain")
	registry:Register("RegisterStructureCommand", RegisterStructureCommand.new(), "Application")
	registry:Register("ApplyDamageStructureCommand", ApplyDamageStructureCommand.new(), "Application")
	registry:Register("CleanupAllCommand", CleanupAllCommand.new(), "Application")
	registry:Register("GetActiveStructuresQuery", GetActiveStructuresQuery.new(), "Application")
	registry:Register("GetStructureCountQuery", GetStructureCountQuery.new(), "Application")

	-- Expose a server-only signal so CombatContext can subscribe without a remote.
	self._structureAttackedSignal = Instance.new("BindableEvent")
	self.StructureAttacked = self._structureAttackedSignal.Event
	registry:Register("OnStructureAttacked", function(payload: StructureAttackPayload)
		self._structureAttackedSignal:Fire(payload)
	end)

	-- Finish module initialization after every dependency has been registered.
	registry:InitAll()

	-- Cache the resolved services and public helpers used by the runtime hooks.
	self._registry = registry
	self._registerStructureCommand = registry:Get("RegisterStructureCommand")
	self._applyDamageStructureCommand = registry:Get("ApplyDamageStructureCommand")
	self._cleanupAllCommand = registry:Get("CleanupAllCommand")
	self._getActiveStructuresQuery = registry:Get("GetActiveStructuresQuery")
	self._getStructureCountQuery = registry:Get("GetStructureCountQuery")
	self._entityFactory = registry:Get("StructureEntityFactory")
	self._structurePlacedConnection = nil :: RBXScriptConnection?
	self._runStateChangedConnection = nil :: RBXScriptConnection?
end

--[=[
	Wires the placement bridge, run cleanup hook, and Heartbeat systems.
	@within StructureContext
]=]
function StructureContext:KnitStart()
	-- Resolve the other server contexts that drive structure placement and run lifecycle.
	local worldContext = Knit.GetService("WorldContext")
	local enemyContext = Knit.GetService("EnemyContext")
	local runContext = Knit.GetService("RunContext")
	local placementContext = Knit.GetService("PlacementContext")

	-- Register the sibling contexts before the system modules start so their dependencies are available.
	self._registry:Register("WorldContext", worldContext)
	self._registry:Register("EnemyContext", enemyContext)
	self._registry:Register("RunContext", runContext)
	self._registry:Register("PlacementContext", placementContext)
	self._registry:StartOrdered({ "Domain", "Infrastructure", "Application" })

	-- Register new placements as ECS entities as soon as PlacementContext announces them.
	self._structurePlacedConnection = placementContext.StructurePlaced:Connect(function(record: StructureRecord)
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
	self._runStateChangedConnection = runContext.StateChanged:Connect(function(newState: RunState, _previousState: RunState)
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

	ServerScheduler:RegisterSystem(function()
		self._entityFactory:FlushPendingDeletes()
	end, "CombatTick")
end

-- [Private Helpers]

-- Registers a structure record with the ECS world through the application command stack.
function StructureContext:_RegisterStructure(record: StructureRecord): Result.Result<number>
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
	Disconnects listeners and cleans up the isolated world.
	@within StructureContext
]=]
function StructureContext:Destroy()
	-- Run cleanup first so entity deletion still has access to live collaborators.
	local cleanupResult = self:_CleanupAll()
	if not cleanupResult.success then
		Result.MentionError("Structure:Destroy", "Cleanup failed during destroy", {
			CauseType = cleanupResult.type,
			CauseMessage = cleanupResult.message,
		}, cleanupResult.type)
	end

	-- Disconnect the placement bridge before destroying the signal object.
	if self._structurePlacedConnection then
		self._structurePlacedConnection:Disconnect()
	end

	-- Disconnect the run-end listener once teardown begins.
	if self._runStateChangedConnection then
		self._runStateChangedConnection:Disconnect()
	end

	-- Destroy the BindableEvent so no stale server listeners remain attached.
	if self._structureAttackedSignal then
		self._structureAttackedSignal:Destroy()
	end
end

WrapContext(StructureContext, "Structure")

return StructureContext
