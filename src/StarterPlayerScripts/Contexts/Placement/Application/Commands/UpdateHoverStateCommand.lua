--!strict

--[=[
    @class UpdateHoverStateCommand
    Synchronizes the placement ghost and hover highlight with the current mouse position.

    The placement cursor controller calls this command on render steps so the ghost stays
    aligned with the cursor and validity changes update immediately.
    @client
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlacementTypes = require(ReplicatedStorage.Contexts.Placement.Types.PlacementTypes)

type GridCoord = PlacementTypes.GridCoord

-- Builds a stable key for a coordinate so hover state can compare tiles cheaply.
local function _GetCoordKey(coord: GridCoord?): string?
	if coord == nil then
		return nil
	end
	return (`{coord.GridId}:{coord.Row}:{coord.Col}`)
end

local UpdateHoverStateCommand = {}
UpdateHoverStateCommand.__index = UpdateHoverStateCommand

--[=[
    Creates a new hover-state command.
    @within UpdateHoverStateCommand
    @param getMouseWorldPositionQuery any -- Query used to resolve the cursor world point.
    @param gridService any -- Placement grid service used for coordinate conversion.
    @return UpdateHoverStateCommand -- The command instance.
]=]
function UpdateHoverStateCommand.new(getMouseWorldPositionQuery: any, gridService: any)
	local self = setmetatable({}, UpdateHoverStateCommand)
	self._getMouseWorldPositionQuery = getMouseWorldPositionQuery
	self._gridService = gridService
	return self
end

--[=[
    Updates ghost placement and hover highlights for the current mouse position.
    @within UpdateHoverStateCommand
    @param state any -- Placement controller session state.
    @param deps any -- Controller dependencies and runtime adapters.
]=]
function UpdateHoverStateCommand:Execute(state: any, deps: any)
	-- Only active placement sessions with a ghost can process hover updates.
	if state._state ~= "Active" or state._ghost == nil or state._confirming then
		return
	end

	-- The ghost cannot update without a camera to project the cursor ray.
	local camera = deps.workspace.CurrentCamera
	if camera == nil then
		return
	end

	-- Resolve the cursor onto the grid plane and clear hover state when that fails.
	local worldPos = self._getMouseWorldPositionQuery:Execute(
		camera,
		self._gridService:GetCursorRaycastExcludeInstances(state._placementFolder)
	)
	if worldPos == nil then
		state._ghost:SetValid(false)
		if state._hoveredKey ~= nil and state._hoveredCoord ~= nil then
			state._highlightPool:SetHovered(state._hoveredCoord, false)
			state._highlightPool:ShowHoveredFootprint(table.freeze({}), false)
			state._hoveredCoord = nil
			state._hoveredKey = nil
			state._hoveredFootprintCoords = table.freeze({})
			state._isHoveredValid = false
		end
		return
	end

	-- Translate the world position back into a grid tile and compare it to the cached hover key.
	local hoveredCoord = self._gridService.WorldToCoord(worldPos)
	local hoveredKey = _GetCoordKey(hoveredCoord)
	local hoveredGroundWorldPos = nil :: Vector3?
	local hoveredFootprintCoords = table.freeze({})
	if hoveredCoord ~= nil then
		local footprint = self._gridService.GetFootprintForAnchor(
			state._footprintCacheLookup,
			state._structureType,
			hoveredCoord,
			state._rotationQuarterTurns
		)
		if footprint ~= nil then
			hoveredFootprintCoords = footprint.OccupiedCoords
			hoveredGroundWorldPos = self._gridService:ResolveGroundWorldPositionForFootprint(
				state._footprintCacheLookup,
				hoveredCoord,
				state._structureType,
				state._rotationQuarterTurns,
				state._placementFolder
			)
		end
	end

	local isHoveredValid = hoveredCoord ~= nil and hoveredGroundWorldPos ~= nil and state._validTileSet[hoveredKey] == true

	-- Update highlight state only when the hovered tile actually changes.
	if hoveredKey ~= state._hoveredKey then
		if state._hoveredCoord ~= nil then
			state._highlightPool:SetHovered(state._hoveredCoord, false)
		end

		state._hoveredCoord = hoveredCoord
		state._hoveredKey = hoveredKey
		state._hoveredFootprintCoords = hoveredFootprintCoords

		if hoveredCoord ~= nil then
			state._highlightPool:ShowHoveredFootprint(hoveredFootprintCoords, isHoveredValid)
			if hoveredGroundWorldPos ~= nil then
				state._ghost:SetRotationQuarterTurns(state._rotationQuarterTurns)
				state._ghost:MoveTo(hoveredGroundWorldPos)
			end
		else
			state._highlightPool:ShowHoveredFootprint(table.freeze({}), false)
		end
	end

	if hoveredKey == state._hoveredKey then
		state._hoveredFootprintCoords = hoveredFootprintCoords
		state._highlightPool:ShowHoveredFootprint(hoveredFootprintCoords, isHoveredValid)
	end

	-- Keep the ghost aligned even when the hovered tile did not change.
	if hoveredGroundWorldPos ~= nil then
		state._ghost:SetRotationQuarterTurns(state._rotationQuarterTurns)
		state._ghost:MoveTo(hoveredGroundWorldPos)
	end

	-- Mirror hover validity to the ghost tint so the preview communicates placement rules.
	state._isHoveredValid = isHoveredValid
	state._ghost:SetValid(isHoveredValid)
end

return UpdateHoverStateCommand
