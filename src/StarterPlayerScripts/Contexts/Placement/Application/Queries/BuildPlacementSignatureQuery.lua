--!strict

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
		return ""
	end

	local parts = table.create(#atom.placements)
	for index, record in ipairs(atom.placements) do
		parts[index] = ("%d:%d:%s:%d"):format(record.coord.row, record.coord.col, record.structureType, record.instanceId)
	end

	return table.concat(parts, "|")
end

return BuildPlacementSignatureQuery
