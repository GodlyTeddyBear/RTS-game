--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local BaseCommand = require(ReplicatedStorage.Utilities.BaseApplication.BaseCommand)
local PlacementTypes = require(ReplicatedStorage.Contexts.Placement.Types.PlacementTypes)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok = Result.Ok
local Err = Result.Err
local Try = Result.Try

type GridCoord = PlacementTypes.GridCoord
type StructureRecord = PlacementTypes.StructureRecord
type ResourceCostMap = PlacementTypes.ResourceCostMap

--[=[
	@class PlaceStructureCommand
	Executes the placement workflow with rollback on downstream failures.
	@server
]=]
local PlaceStructureCommand = {}
PlaceStructureCommand.__index = PlaceStructureCommand
setmetatable(PlaceStructureCommand, BaseCommand)

--[=[
	Creates a new placement command wrapper.
	@within PlaceStructureCommand
	@return PlaceStructureCommand -- The new command instance.
]=]
-- The command is composed from injected collaborators; no constructor arguments are needed.
function PlaceStructureCommand.new()
	local self = BaseCommand.new("Placement", "PlaceStructure")
	return setmetatable(self, PlaceStructureCommand)
end

--[=[
	Initializes the placement policy, sync, and cross-context dependencies.
	@within PlaceStructureCommand
	@param registry any -- The dependency registry for this context.
	@param _name string -- The registered module name.
]=]
-- Resolve the policy, write services, and cross-context dependencies once.
function PlaceStructureCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_policy = "PlaceStructurePolicy",
		_placementService = "PlacementService",
		_syncService = "PlacementSyncService"
	})
end

function PlaceStructureCommand:Start(registry: any, _name: string)
	self._worldContext = registry:Get("WorldContext")
	self._economyContext = registry:Get("EconomyContext")
end

-- Refund every resource spend if a downstream write fails after the deduction already happened.
function PlaceStructureCommand:_RefundResources(player: Player, costMap: ResourceCostMap, reason: string): Result.Result<nil>
	for resourceType, amount in costMap do
		local refundResult = self._economyContext:AddResource(player, resourceType, amount)
		if refundResult.success then
			continue
		end

		return Err("RefundFailed", Errors.REFUND_FAILED, {
			resourceType = resourceType,
			amount = amount,
			reason = reason,
			refundErrorType = refundResult.type,
			refundErrorMessage = refundResult.message,
		})
	end

	return Ok(nil)
end

--[=[
	Executes a structure placement and returns the spawned instance id.
	@within PlaceStructureCommand
	@param player Player -- The player requesting placement.
	@param coord GridCoord -- The requested grid coordinate.
	@param structureType string -- The placement key.
	@return Result.Result<{ InstanceId: number }> -- The spawned instance id on success.
]=]
-- Validate first, then spend, then spawn, then occupy, then sync.
function PlaceStructureCommand:Execute(
	player: Player,
	coord: GridCoord,
	structureType: string,
	rotationQuarterTurns: number
): Result.Result<{ InstanceId: number, Record: StructureRecord }>
	-- Policy resolves the live tile and all gate conditions before any mutation occurs.
	local decision = Try(self._policy:Check(coord, structureType, rotationQuarterTurns))
	local costMap = decision.CostMap
	local resolvedFootprint = decision.ResolvedFootprint
	local resourceType = nil :: string?
	for _, tile in ipairs(decision.Tiles) do
		if tile.ResourceType ~= nil then
			resourceType = tile.ResourceType
			break
		end
	end

	-- Fail before any wallet mutation if the configured runtime template is missing.
	Try(self._placementService:ValidateTemplate(structureType))

	-- Resource spend happens after all read-only checks so malformed requests never mutate the wallet.
	Try(self._economyContext:SpendResources(player, costMap))

	-- Spawn the physical structure only after the purchase succeeds.
	local groundPointResult = self._placementService:ResolveGroundPointFromFootprint(
		resolvedFootprint.AnchorCoord,
		resolvedFootprint.WidthTiles,
		resolvedFootprint.DepthTiles
	)
	if not groundPointResult.success then
		Try(self:_RefundResources(player, costMap, "GroundResolveFailed"))
		return groundPointResult
	end

	local groundPoint = groundPointResult.value
	local spawnResult = self._placementService:SpawnStructure(structureType, groundPoint, rotationQuarterTurns)
	if not spawnResult.success then
		Try(self:_RefundResources(player, costMap, "SpawnFailed"))
		return spawnResult
	end

	local instanceId = spawnResult.value

	-- Occupancy is authoritative in WorldContext, so restore the model if this write fails.
	local occupancyResult = self._worldContext:SetTilesOccupied(resolvedFootprint.OccupiedCoords, true)
	if not occupancyResult.success or occupancyResult.value ~= true then
		self._placementService:DestroyStructure(instanceId)
		Try(self:_RefundResources(player, costMap, "OccupancyFailed"))

		if not occupancyResult.success then
			return occupancyResult
		end

		return Err("OccupancyUpdateFailed", Errors.OCCUPANCY_UPDATE_FAILED, {
			GridId = resolvedFootprint.AnchorCoord.GridId,
			Row = resolvedFootprint.AnchorCoord.Row,
			Col = resolvedFootprint.AnchorCoord.Col,
		})
	end

	-- Record the placement after all writes succeed so the atom only reflects committed state.
	local record: StructureRecord = {
		AnchorCoord = resolvedFootprint.AnchorCoord,
		OccupiedCoords = resolvedFootprint.OccupiedCoords,
		RotationQuarterTurns = resolvedFootprint.RotationQuarterTurns,
		FootprintWidthTiles = resolvedFootprint.WidthTiles,
		FootprintDepthTiles = resolvedFootprint.DepthTiles,
		StructureType = structureType,
		InstanceId = instanceId,
		OwnerUserId = player.UserId,
		Tier = 1,
		ResourceType = resourceType,
		GroundPosX = groundPoint.X,
		GroundPosY = groundPoint.Y,
		GroundPosZ = groundPoint.Z,
	}

	self._syncService:AddPlacement(record)

	-- Emit a success milestone for telemetry and debugging visibility.
	Result.MentionSuccess("PlacementContext:PlaceStructureCommand", "Structure placed", {
		UserId = player.UserId,
		StructureType = structureType,
		GridId = resolvedFootprint.AnchorCoord.GridId,
		Row = resolvedFootprint.AnchorCoord.Row,
		Col = resolvedFootprint.AnchorCoord.Col,
		InstanceId = instanceId,
	})

	return Ok({
		InstanceId = instanceId,
		Record = record,
	})
end

return PlaceStructureCommand


