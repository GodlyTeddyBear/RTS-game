--!strict

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlacementConfig = require(ReplicatedStorage.Contexts.Placement.Config.PlacementConfig)
local PlacementTypes = require(ReplicatedStorage.Contexts.Placement.Types.PlacementTypes)

type PlacementAtom = PlacementTypes.PlacementAtom

local BuildOccupiedSetQuery = {}
BuildOccupiedSetQuery.__index = BuildOccupiedSetQuery

local function _GetCoordKey(row: number, col: number): string
	return ("%d_%d"):format(row, col)
end

function BuildOccupiedSetQuery.new()
	return setmetatable({}, BuildOccupiedSetQuery)
end

function BuildOccupiedSetQuery:Execute(atom: PlacementAtom?): { [string]: boolean }
	local occupiedSet = {}
	if atom == nil then
		return occupiedSet
	end

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

	for _, record in ipairs(atom.placements) do
		if liveInstanceIds[record.instanceId] ~= true then
			continue
		end

		occupiedSet[_GetCoordKey(record.coord.row, record.coord.col)] = true
	end

	return occupiedSet
end

return BuildOccupiedSetQuery
