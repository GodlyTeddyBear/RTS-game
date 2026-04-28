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
	return ("%d_%d"):format(coord.row, coord.col)
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
	local worldPos = self._getMouseWorldPositionQuery:Execute(camera)
	if worldPos == nil then
		state._ghost:SetValid(false)
		if state._hoveredKey ~= nil and state._hoveredCoord ~= nil then
			state._highlightPool:SetHovered(state._hoveredCoord.row, state._hoveredCoord.col, false)
			state._hoveredCoord = nil
			state._hoveredKey = nil
			state._isHoveredValid = false
		end
		return
	end

	-- Translate the world position back into a grid tile and compare it to the cached hover key.
	local hoveredCoord = self._gridService.WorldToCoord(worldPos)
	local hoveredKey = _GetCoordKey(hoveredCoord)
	local isHoveredValid = hoveredCoord ~= nil and state._validTileSet[hoveredKey] == true

	-- Update highlight state only when the hovered tile actually changes.
	if hoveredKey ~= state._hoveredKey then
		if state._hoveredCoord ~= nil then
			state._highlightPool:SetHovered(state._hoveredCoord.row, state._hoveredCoord.col, false)
		end

		state._hoveredCoord = hoveredCoord
		state._hoveredKey = hoveredKey

		if hoveredCoord ~= nil then
			state._highlightPool:SetHovered(hoveredCoord.row, hoveredCoord.col, true)
			state._ghost:MoveTo(self._gridService.CoordToWorld(hoveredCoord.row, hoveredCoord.col))
		end
	end

	-- Keep the ghost aligned even when the hovered tile did not change.
	if hoveredCoord ~= nil then
		state._ghost:MoveTo(self._gridService.CoordToWorld(hoveredCoord.row, hoveredCoord.col))
	end

	-- Mirror hover validity to the ghost tint so the preview communicates placement rules.
	state._isHoveredValid = isHoveredValid
	state._ghost:SetValid(isHoveredValid)
end

return UpdateHoverStateCommand
