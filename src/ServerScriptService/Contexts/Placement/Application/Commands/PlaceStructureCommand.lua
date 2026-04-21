--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local PlacementTypes = require(ReplicatedStorage.Contexts.Placement.Types.PlacementTypes)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok = Result.Ok
local Err = Result.Err
local Try = Result.Try

type GridCoord = PlacementTypes.GridCoord
type StructureRecord = PlacementTypes.StructureRecord

--[=[
	@class PlaceStructureCommand
	Executes the placement workflow with rollback on downstream failures.
	@server
]=]
local PlaceStructureCommand = {}
PlaceStructureCommand.__index = PlaceStructureCommand

--[=[
	Creates a new placement command wrapper.
	@within PlaceStructureCommand
	@return PlaceStructureCommand -- The new command instance.
]=]
-- The command is composed from injected collaborators; no constructor arguments are needed.
function PlaceStructureCommand.new()
	return setmetatable({}, PlaceStructureCommand)
end

--[=[
	Initializes the placement policy, sync, and cross-context dependencies.
	@within PlaceStructureCommand
	@param registry any -- The dependency registry for this context.
	@param _name string -- The registered module name.
]=]
-- Resolve the policy, write services, and cross-context dependencies once.
function PlaceStructureCommand:Init(registry: any, _name: string)
	self._policy = registry:Get("PlaceStructurePolicy")
	self._placementService = registry:Get("PlacementService")
	self._syncService = registry:Get("PlacementSyncService")
end

function PlaceStructureCommand:Start(registry: any, _name: string)
	self._worldContext = registry:Get("WorldContext")
	self._economyContext = registry:Get("EconomyContext")
end

-- Refund the energy spend if a downstream write fails after the deduction already happened.
function PlaceStructureCommand:_RefundEnergy(player: Player, cost: number, reason: string): Result.Result<nil>
	local refundResult = self._economyContext:AddResource(player, "Energy", cost)
	if refundResult.success then
		return Ok(nil)
	end

	return Err("RefundFailed", Errors.REFUND_FAILED, {
		cost = cost,
		reason = reason,
		refundErrorType = refundResult.type,
		refundErrorMessage = refundResult.message,
	})
end

--[=[
	Executes a structure placement and returns the spawned instance id.
	@within PlaceStructureCommand
	@param player Player -- The player requesting placement.
	@param coord GridCoord -- The requested grid coordinate.
	@param structureType string -- The placement key.
	@return Result.Result<{ instanceId: number }> -- The spawned instance id on success.
]=]
-- Validate first, then spend, then spawn, then occupy, then sync.
function PlaceStructureCommand:Execute(player: Player, coord: GridCoord, structureType: string): Result.Result<{ instanceId: number, record: StructureRecord }>
	-- Policy resolves the live tile and all gate conditions before any mutation occurs.
	local decision = Try(self._policy:Check(coord, structureType))
	local cost = decision.cost
	local tile = decision.tile

	-- Energy spend happens after all read-only checks so a failure never needs rollback.
	Try(self._economyContext:SpendEnergy(player, cost))

	-- Spawn the physical structure only after the purchase succeeds.
	local spawnResult = self._placementService:SpawnStructure(structureType, tile.worldPos)
	if not spawnResult.success then
		Try(self:_RefundEnergy(player, cost, "SpawnFailed"))
		return spawnResult
	end

	local instanceId = spawnResult.value

	-- Occupancy is authoritative in WorldContext, so restore the model if this write fails.
	local occupancyResult = self._worldContext:SetTileOccupied(coord, true)
	if not occupancyResult.success or occupancyResult.value ~= true then
		self._placementService:DestroyStructure(instanceId)
		Try(self:_RefundEnergy(player, cost, "OccupancyFailed"))

		if not occupancyResult.success then
			return occupancyResult
		end

		return Err("OccupancyUpdateFailed", Errors.OCCUPANCY_UPDATE_FAILED, {
			row = coord.row,
			col = coord.col,
		})
	end

	-- Record the placement after all writes succeed so the atom only reflects committed state.
	local record: StructureRecord = {
		coord = {
			row = coord.row,
			col = coord.col,
		},
		structureType = structureType,
		instanceId = instanceId,
		tier = 1,
		resourceType = tile.resourceType,
	}

	self._syncService:AddPlacement(record)

	-- Emit a success milestone for telemetry and debugging visibility.
	Result.MentionSuccess("PlacementContext:PlaceStructureCommand", "Structure placed", {
		userId = player.UserId,
		structureType = structureType,
		row = coord.row,
		col = coord.col,
		instanceId = instanceId,
	})

	return Ok({
		instanceId = instanceId,
		record = record,
	})
end

return PlaceStructureCommand
