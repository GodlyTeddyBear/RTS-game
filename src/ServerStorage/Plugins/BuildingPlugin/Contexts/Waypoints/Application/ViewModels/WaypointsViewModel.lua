--!strict

local PluginTypes = require(script.Parent.Parent.Parent.Parent.Parent.Types.PluginTypes)
local WaypointsAtom = require(script.Parent.Parent.Parent.Infrastructure.WaypointsAtom)

type TPluginWaypoint = PluginTypes.TPluginWaypoint
type TWaypointsState = WaypointsAtom.TWaypointsState

export type TWaypointsViewModel = {
	WaypointNameInput: string,
	WaypointNames: { string },
	SelectedWaypointName: string?,
	Waypoints: { TPluginWaypoint },
}

local WaypointsViewModel = {}

function WaypointsViewModel.FromState(state: TWaypointsState): TWaypointsViewModel
	local waypointNames = {}

	for _, waypoint in state.Waypoints do
		table.insert(waypointNames, waypoint.Name)
	end

	return table.freeze({
		WaypointNameInput = state.WaypointNameInput,
		WaypointNames = waypointNames,
		SelectedWaypointName = state.SelectedWaypointName,
		Waypoints = state.Waypoints,
	})
end

return WaypointsViewModel
