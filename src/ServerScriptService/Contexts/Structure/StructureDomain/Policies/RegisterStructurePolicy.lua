--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local PlacementTypes = require(ReplicatedStorage.Contexts.Placement.Types.PlacementTypes)
local StructureTypes = require(ReplicatedStorage.Contexts.Structure.Types.StructureTypes)
local StructureSpecs = require(script.Parent.Parent.Specs.StructureSpecs)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok = Result.Ok
local Try = Result.Try
local Ensure = Result.Ensure

type GridCoord = PlacementTypes.GridCoord
type StructureRecord = PlacementTypes.StructureRecord
type StructureType = StructureTypes.StructureType
type ResolvedStructureRecord = StructureTypes.ResolvedStructureRecord

--[=[
	@class RegisterStructurePolicy
	Validates placed structures and resolves their live world position.
	@server
]=]
local RegisterStructurePolicy = {}
RegisterStructurePolicy.__index = RegisterStructurePolicy

--[=[
	Creates a new registration policy wrapper.
	@within RegisterStructurePolicy
	@return RegisterStructurePolicy -- The new policy instance.
]=]
function RegisterStructurePolicy.new()
	return setmetatable({}, RegisterStructurePolicy)
end

--[=[
	Resolves the world context used to translate placement records into live ECS state.
	@within RegisterStructurePolicy
	@param registry any -- The dependency registry for this context.
	@param _name string -- The registered module name.
]=]
function RegisterStructurePolicy:Init(_registry: any, _name: string)
end

function RegisterStructurePolicy:Start(registry: any, _name: string)
	self._worldContext = registry:Get("WorldContext")
end

-- Checks the record shape before attempting any world lookup.
local function _isValidCoord(coord: GridCoord?): boolean
	if coord == nil then
		return false
	end

	return type(coord.GridId) == "string" and type(coord.Row) == "number" and type(coord.Col) == "number"
end

local function _ExtractGroundWorldPos(record: StructureRecord): Vector3?
	if type(record.GroundPosX) ~= "number" then
		return nil
	end
	if type(record.GroundPosY) ~= "number" then
		return nil
	end
	if type(record.GroundPosZ) ~= "number" then
		return nil
	end

	return Vector3.new(record.GroundPosX, record.GroundPosY, record.GroundPosZ)
end

--[=[
	Validates a placement record and resolves the canonical structure data.
	@within RegisterStructurePolicy
	@param record StructureRecord -- The placement record to validate.
	@return Result.Result<ResolvedStructureRecord> -- The resolved structure payload.
	@error Result.Err -- Thrown when the record is malformed or cannot be resolved.
]=]
function RegisterStructurePolicy:Check(record: StructureRecord): Result.Result<ResolvedStructureRecord>
	-- Validate the record shape first so later field access is safe.
	Ensure(type(record) == "table", "InvalidPlacementRecord", Errors.INVALID_PLACEMENT_RECORD)
	Ensure(StructureSpecs.IsValidStructureType(record.StructureType), "UnknownStructureType", Errors.UNKNOWN_STRUCTURE_TYPE, {
		StructureType = record.StructureType,
	})
	Ensure(StructureSpecs.HasValidInstanceId(record.InstanceId), "InvalidPlacementRecord", Errors.INVALID_PLACEMENT_RECORD, {
		InstanceId = record.InstanceId,
	})
	Ensure(_isValidCoord(record.AnchorCoord), "InvalidPlacementRecord", Errors.INVALID_PLACEMENT_RECORD)

	local worldPos = _ExtractGroundWorldPos(record)
	if worldPos == nil then
		Result.MentionError("Structure:RegisterStructurePolicy", "Placement record missing persisted ground point; falling back to tile world position", {
			GridId = record.AnchorCoord.GridId,
			Row = record.AnchorCoord.Row,
			Col = record.AnchorCoord.Col,
			InstanceId = record.InstanceId,
		}, "MissingPlacementGroundPoint")

		local tile = Try(self._worldContext:GetTile(record.AnchorCoord))
		Ensure(tile ~= nil, "InvalidPlacementRecord", Errors.INVALID_PLACEMENT_RECORD, {
			GridId = record.AnchorCoord.GridId,
			Row = record.AnchorCoord.Row,
			Col = record.AnchorCoord.Col,
		})
		Ensure(typeof(tile.WorldPos) == "Vector3", "InvalidPlacementRecord", Errors.INVALID_PLACEMENT_RECORD)
		worldPos = tile.WorldPos
	end
	Ensure(typeof(worldPos) == "Vector3", "InvalidPlacementRecord", Errors.INVALID_PLACEMENT_RECORD)

	-- Normalize the structure key to the canonical combat type after all guards pass.
	local resolvedType = StructureSpecs.ResolveStructureType(record.StructureType)
	Ensure(resolvedType ~= nil, "UnknownStructureType", Errors.UNKNOWN_STRUCTURE_TYPE, {
		StructureType = record.StructureType,
	})

	return Ok({
		StructureType = resolvedType :: StructureType,
		InstanceId = record.InstanceId,
		WorldPos = worldPos :: Vector3,
		RotationQuarterTurns = record.RotationQuarterTurns,
	})
end

return RegisterStructurePolicy
