--!strict

--[=[
	@class PlacementTypes
	Defines shared types for placement requests and synchronized structure state.
	@server
	@client
]=]
local PlacementTypes = {}

--[=[
	@type ResourceCostMap table<string, number>
	@within PlacementTypes
	Maps resource names to required placement costs.
]=]
export type ResourceCostMap = { [string]: number }

--[=[
	@interface GridCoord
	@within PlacementTypes
	.row number -- Row index in the placement grid.
	.col number -- Column index in the placement grid.
]=]
export type GridCoord = {
	row: number,
	col: number,
}

--[=[
	@interface StructureRecord
	@within PlacementTypes
	.coord GridCoord -- Grid coordinate where the structure sits.
	.structureType string -- Config key for the structure.
	.instanceId number -- Runtime instance identifier.
	.ownerUserId number? -- Player user id that owns this placement; server-only sync transports may omit it.
	.tier number -- Placement tier used for future upgrade flows.
	.resourceType string? -- Resource metadata for extractor-style structures.
]=]
export type StructureRecord = {
	coord: GridCoord,
	structureType: string,
	instanceId: number,
	ownerUserId: number?,
	tier: number,
	resourceType: string?,
}

--[=[
	@interface PlacementAtom
	@within PlacementTypes
	.placements { StructureRecord } -- Global list of placed structures.
]=]
export type PlacementAtom = {
	placements: { StructureRecord },
}

--[=[
	@interface PlaceRequest
	@within PlacementTypes
	.coord_row number -- Requested row coordinate.
	.coord_col number -- Requested column coordinate.
	.structureType string -- Requested placement key.
]=]
export type PlaceRequest = {
	coord_row: number,
	coord_col: number,
	structureType: string,
}

--[=[
	@interface PlaceResponse
	@within PlacementTypes
	.success boolean -- Whether the placement succeeded.
	.errorMessage string? -- Failure message when `success` is false.
	.instanceId number? -- Spawned instance identifier on success.
]=]
export type PlaceResponse = {
	success: boolean,
	errorMessage: string?,
	instanceId: number?,
}

return table.freeze(PlacementTypes)
