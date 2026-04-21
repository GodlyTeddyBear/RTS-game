--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Knit = require(ReplicatedStorage.Packages.Knit)

type TPlacementCursorController = {
	EnterPlacementMode: (self: TPlacementCursorController, structureType: string) -> (),
	ExitPlacementMode: (self: TPlacementCursorController) -> (),
	TogglePlacementMode: (self: TPlacementCursorController, structureType: string) -> (),
	PlacementCancelled: RBXScriptSignal,
}

type TPlacementCursorActions = {
	enterPlacementMode: (structureType: string) -> (),
	exitPlacementMode: () -> (),
	togglePlacementMode: (structureType: string) -> (),
	onCancelled: ((() -> ()) -> RBXScriptConnection),
}

local placementCursorController: TPlacementCursorController? = nil

local function _GetPlacementCursorController(): TPlacementCursorController
	if placementCursorController == nil then
		placementCursorController = Knit.GetController("PlacementCursorController") :: TPlacementCursorController
	end
	return placementCursorController
end

local function usePlacementCursorActions(): TPlacementCursorActions
	local controller = _GetPlacementCursorController()

	return React.useMemo(function()
		return table.freeze({
			enterPlacementMode = function(structureType: string)
				controller:EnterPlacementMode(structureType)
			end,
			exitPlacementMode = function()
				controller:ExitPlacementMode()
			end,
			togglePlacementMode = function(structureType: string)
				controller:TogglePlacementMode(structureType)
			end,
			onCancelled = function(callback: () -> ())
				return controller.PlacementCancelled:Connect(callback)
			end,
		} :: TPlacementCursorActions)
	end, {})
end

return usePlacementCursorActions
