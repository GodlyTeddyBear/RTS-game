--!strict

--[=[
    @class BuildOccupiedSetQuery
    Builds a client-side lookup of occupied placement coordinates from synced placement data.

    Placement commands use this query to filter out tiles that are already occupied by
    live placement instances in Workspace.
    @client
]=]

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlacementConfig = require(ReplicatedStorage.Contexts.Placement.Config.PlacementConfig)
local PlacementTypes = require(ReplicatedStorage.Contexts.Placement.Types.PlacementTypes)

type PlacementAtom = PlacementTypes.PlacementAtom

local BuildOccupiedSetQuery = {}
BuildOccupiedSetQuery.__index = BuildOccupiedSetQuery

-- Builds a stable key for a coordinate so the occupied lookup can use string tables.
local function _GetCoordKey(row: number, col: number): string
	return ("%d_%d"):format(row, col)
end

--[=[
    Creates a new occupied-set query.
    @within BuildOccupiedSetQuery
    @return BuildOccupiedSetQuery -- The query instance.
]=]
function BuildOccupiedSetQuery.new()
	return setmetatable({}, BuildOccupiedSetQuery)
end

--[=[
    Builds the occupied coordinate lookup for the current placement atom.
    @within BuildOccupiedSetQuery
    @param atom PlacementAtom? -- The placement atom snapshot to inspect.
    @return { [string]: boolean } -- A lookup keyed by "row_col" coordinate strings.
]=]
function BuildOccupiedSetQuery:Execute(atom: PlacementAtom?): { [string]: boolean }
	-- Return an empty lookup when no placement atom is available.
	local occupiedSet = {}
	if atom == nil then
		return occupiedSet
	end

	-- Resolve live placement instances so stale atom records do not block valid tiles.
	local liveInstanceIds = {} :: { [number]: boolean }
	local placementFolder = Workspace:FindFirstChild(PlacementConfig.PLACEMENT_FOLDER_NAME)
	if placementFolder ~= nil then
		for _, instance in ipairs(placementFolder:GetChildren()) do
			local placementInstanceId = instance:GetAttribute("PlacementInstanceId")
			if type(placementInstanceId) == "number" then
				liveInstanceIds[placementInstanceId] = true
			end
		end
	end

	-- Keep only records whose instance still exists in Workspace.
	for _, record in ipairs(atom.placements) do
		if liveInstanceIds[record.instanceId] ~= true then
			continue
		end

		occupiedSet[_GetCoordKey(record.coord.row, record.coord.col)] = true
	end

	return occupiedSet
end

return BuildOccupiedSetQuery
