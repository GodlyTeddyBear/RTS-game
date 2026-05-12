--!strict

--[=[
    @class BuildPlacementSignatureQuery
    Serializes the client placement atom into a stable comparison signature.

    Placement cursor state uses this signature to detect when placement records change
    and the valid tile cache needs to be refreshed.
    @client
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlacementTypes = require(ReplicatedStorage.Contexts.Placement.Types.PlacementTypes)

type PlacementAtom = PlacementTypes.PlacementAtom

local BuildPlacementSignatureQuery = {}
BuildPlacementSignatureQuery.__index = BuildPlacementSignatureQuery

--[=[
    Creates a new placement signature query.
    @within BuildPlacementSignatureQuery
    @return BuildPlacementSignatureQuery -- The query instance.
]=]
function BuildPlacementSignatureQuery.new()
	return setmetatable({}, BuildPlacementSignatureQuery)
end

--[=[
    Converts the placement atom into a stable comparison signature.
    @within BuildPlacementSignatureQuery
    @param atom PlacementAtom? -- The placement atom snapshot to serialize.
    @return string -- A stable signature string for change detection.
]=]
function BuildPlacementSignatureQuery:Execute(atom: PlacementAtom?): string
	if atom == nil or type(atom.Placements) ~= "table" then
		return ""
	end

	local parts = table.create(#atom.Placements)
	local cacheParts = table.create(#atom.FootprintCache)

	for index, entry in ipairs(atom.FootprintCache) do
		cacheParts[index] = ("%s:%d:%d:%d:%s"):format(
			entry.StructureType,
			entry.RotationQuarterTurns,
			entry.WidthTiles,
			entry.DepthTiles,
			entry.SpecialTileRequirementMode
		)
	end

	for index, record in ipairs(atom.Placements) do
		local occupiedParts = table.create(#record.OccupiedCoords)
		for occupiedIndex, occupiedCoord in ipairs(record.OccupiedCoords) do
			occupiedParts[occupiedIndex] = ("%s:%d:%d"):format(
				occupiedCoord.GridId,
				occupiedCoord.Row,
				occupiedCoord.Col
			)
		end

		parts[index] = ("%s:%d:%d:%s:%d:%d:%s"):format(
			record.AnchorCoord.GridId,
			record.AnchorCoord.Row,
			record.AnchorCoord.Col,
			record.StructureType,
			record.InstanceId,
			record.RotationQuarterTurns,
			table.concat(occupiedParts, ",")
		)
	end

	return table.concat(cacheParts, "|") .. "#" .. table.concat(parts, "|")
end

return BuildPlacementSignatureQuery
