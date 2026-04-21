--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local PlacementTypes = require(ReplicatedStorage.Contexts.Placement.Types.PlacementTypes)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok = Result.Ok
local Ensure = Result.Ensure

type GridCoord = PlacementTypes.GridCoord

export type PlacementRequest = {
	coord: GridCoord,
	structureType: string,
}

--[=[
	@class PlacementValidator
	Validates placement request input shape.
	@server
]=]
local PlacementValidator = {}
PlacementValidator.__index = PlacementValidator

--[=[
	Creates a new placement validator.
	@within PlacementValidator
	@return PlacementValidator -- The new validator instance.
]=]
-- The validator is stateless, so construction just returns the table wrapper.
function PlacementValidator.new()
	return setmetatable({}, PlacementValidator)
end

--[=[
	Validates the raw placement request payload.
	@within PlacementValidator
	@param coordRow any -- The requested row value.
	@param coordCol any -- The requested column value.
	@param structureType any -- The requested structure key.
	@return Result.Result<PlacementRequest> -- The sanitized request payload.
]=]
-- Validate the request shape before the policy touches any live game state.
function PlacementValidator:ValidateRequest(coordRow: any, coordCol: any, structureType: any): Result.Result<PlacementRequest>
	Ensure(type(coordRow) == "number", "InvalidRequestCoord", Errors.INVALID_REQUEST_COORD)
	Ensure(type(coordCol) == "number", "InvalidRequestCoord", Errors.INVALID_REQUEST_COORD)
	Ensure(math.floor(coordRow) == coordRow, "InvalidRequestCoord", Errors.INVALID_REQUEST_COORD)
	Ensure(math.floor(coordCol) == coordCol, "InvalidRequestCoord", Errors.INVALID_REQUEST_COORD)
	Ensure(coordRow >= 1 and coordCol >= 1, "InvalidRequestCoord", Errors.INVALID_REQUEST_COORD)
	Ensure(type(structureType) == "string", "InvalidRequestStructureType", Errors.INVALID_REQUEST_STRUCTURE_TYPE)
	Ensure(#structureType > 0, "InvalidRequestStructureType", Errors.INVALID_REQUEST_STRUCTURE_TYPE)

	return Ok({
		coord = {
			row = coordRow,
			col = coordCol,
		},
		structureType = structureType,
	})
end

return PlacementValidator
