--!strict

--[=[
    @class BuildPlacementSignatureQuery
    Builds a cheap change token for placement preview invalidation.

    Placement cursor state uses this token to detect placement changes without
    serializing the full atom every render step.
    @client
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlacementTypes = require(ReplicatedStorage.Contexts.Placement.Types.PlacementTypes)

type PlacementAtom = PlacementTypes.PlacementAtom

local BuildPlacementSignatureQuery = {}
BuildPlacementSignatureQuery.__index = BuildPlacementSignatureQuery

function BuildPlacementSignatureQuery.new()
	return setmetatable({}, BuildPlacementSignatureQuery)
end

function BuildPlacementSignatureQuery:Execute(atom: PlacementAtom?): string
	if atom == nil then
		return "0:0:0"
	end

	local revision = if type(atom.Revision) == "number" then atom.Revision else 0
	local placementCount = if type(atom.Placements) == "table" then #atom.Placements else 0
	local footprintCount = if type(atom.FootprintCache) == "table" then #atom.FootprintCache else 0

	return (`{revision}:{placementCount}:{footprintCount}`)
end

return BuildPlacementSignatureQuery
