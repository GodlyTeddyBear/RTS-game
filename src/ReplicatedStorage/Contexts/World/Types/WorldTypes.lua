--!strict

--[[
    Module: WorldTypes
    Purpose: Defines the shared world-grid type contracts used by server and client world consumers.
    Used In System: Imported by world layout services, placement helpers, and any code that exchanges world tile data.
    Boundaries: Owns type shape only; does not own runtime grid state, configuration values, or conversion logic.
]]

--[=[
	@class WorldTypes
	Defines the shared world grid types used by the world context.
]=]
local WorldTypes = {}

-- [Types]

--[=[
	@type ZoneType "lane" | "side_pocket" | "blocked"
	@within WorldTypes
	The allowed tile zone categories.
]=]
export type ZoneType = "lane" | "side_pocket" | "blocked"

--[=[
	@type ResourceType string
	@within WorldTypes
	Placeholder union for world resource names.
]=]
export type ResourceType = string

--[=[
	@interface GridCoord
	@within WorldTypes
	.row number -- Row index in the grid.
	.col number -- Column index in the grid.
]=]
export type GridCoord = {
	row: number,
	col: number,
}

--[=[
	@interface TileDescriptor
	@within WorldTypes
	.zone ZoneType -- Tile zone classification.
	.resourceType ResourceType? -- Resource assigned to side-pocket tiles.
]=]
export type TileDescriptor = {
	zone: ZoneType,
	resourceType: ResourceType?,
}

--[=[
	@interface GridSpec
	@within WorldTypes
	.gridCFrame CFrame -- World transform for the authoritative grid part.
	.gridSize Vector3 -- Physical size of the authoritative grid part.
	.tileSize number -- Tile size in studs.
	.gridRows number -- Derived row count from part Z size.
	.gridCols number -- Derived column count from part X size.
	.laneRow number -- Center lane row used for lane zoning.
	.sidePocketRows { number } -- Rows adjacent to lane that may host side pockets.
]=]
export type GridSpec = {
	gridCFrame: CFrame,
	gridSize: Vector3,
	tileSize: number,
	gridRows: number,
	gridCols: number,
	laneRow: number,
	sidePocketRows: { number },
}

--[=[
	@interface Tile
	@within WorldTypes
	.coord GridCoord -- Grid coordinate for the tile.
	.worldPos Vector3 -- World-space center position.
	.zone ZoneType -- Tile zone classification.
	.occupied boolean -- Whether the tile is reserved.
	.resourceType ResourceType? -- Resource assigned to side-pocket tiles.
]=]
export type Tile = {
	coord: GridCoord,
	worldPos: Vector3,
	zone: ZoneType,
	occupied: boolean,
	resourceType: ResourceType?,
}

--[=[
	@type TileGrid { [number]: Tile }
	@within WorldTypes
	A flat row-major tile array.
]=]
export type TileGrid = { [number]: Tile }

--[=[
	@type ZoneRow { [number]: TileDescriptor }
	@within WorldTypes
	A single row of tile descriptors.
]=]
export type ZoneRow = { [number]: TileDescriptor }

--[=[
	@type ZoneLayout { [number]: ZoneRow }
	@within WorldTypes
	The full row-major zone layout.
]=]
export type ZoneLayout = { [number]: ZoneRow }

return table.freeze(WorldTypes)
