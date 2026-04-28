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
	if atom == nil then
		return ""
	end

	local parts = table.create(#atom.placements)
	for index, record in ipairs(atom.placements) do
		parts[index] = ("%d:%d:%s:%d"):format(record.coord.row, record.coord.col, record.structureType, record.instanceId)
	end

	return table.concat(parts, "|")
end

return BuildPlacementSignatureQuery
