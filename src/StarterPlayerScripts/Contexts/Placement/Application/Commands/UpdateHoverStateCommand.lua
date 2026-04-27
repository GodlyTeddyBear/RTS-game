--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlacementTypes = require(ReplicatedStorage.Contexts.Placement.Types.PlacementTypes)

type GridCoord = PlacementTypes.GridCoord

local function _GetCoordKey(coord: GridCoord?): string?
	if coord == nil then
		return nil
	end
	return ("%d_%d"):format(coord.row, coord.col)
end

local UpdateHoverStateCommand = {}
UpdateHoverStateCommand.__index = UpdateHoverStateCommand

function UpdateHoverStateCommand.new(getMouseWorldPositionQuery: any, gridService: any)
	local self = setmetatable({}, UpdateHoverStateCommand)
	self._getMouseWorldPositionQuery = getMouseWorldPositionQuery
	self._gridService = gridService
	return self
end

function UpdateHoverStateCommand:Execute(state: any, deps: any)
	if state._state ~= "Active" or state._ghost == nil or state._confirming then
		return
	end

	local camera = deps.workspace.CurrentCamera
	if camera == nil then
		return
	end

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

	local hoveredCoord = self._gridService.WorldToCoord(worldPos)
	local hoveredKey = _GetCoordKey(hoveredCoord)
	local isHoveredValid = hoveredCoord ~= nil and state._validTileSet[hoveredKey] == true

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

	if hoveredCoord ~= nil then
		state._ghost:MoveTo(self._gridService.CoordToWorld(hoveredCoord.row, hoveredCoord.col))
	end

	state._isHoveredValid = isHoveredValid
	state._ghost:SetValid(isHoveredValid)
end

return UpdateHoverStateCommand
