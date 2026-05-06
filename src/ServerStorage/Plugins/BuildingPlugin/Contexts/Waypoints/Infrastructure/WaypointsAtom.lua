--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)
local PluginTypes = require(script.Parent.Parent.Parent.Parent.Types.PluginTypes)

type TPluginWaypoint = PluginTypes.TPluginWaypoint

export type TWaypointsState = {
	WaypointNameInput: string,
	Waypoints: { TPluginWaypoint },
	SelectedWaypointName: string?,
}

local waypointsAtom = Charm.atom({
	WaypointNameInput = "",
	Waypoints = {},
	SelectedWaypointName = nil,
} :: TWaypointsState)

local WaypointsAtom = {}

function WaypointsAtom.GetAtom()
	return waypointsAtom
end

function WaypointsAtom.GetState(): TWaypointsState
	return waypointsAtom()
end

function WaypointsAtom.SetWaypointNameInput(waypointNameInput: string)
	local state = waypointsAtom()
	waypointsAtom({
		WaypointNameInput = waypointNameInput,
		Waypoints = state.Waypoints,
		SelectedWaypointName = state.SelectedWaypointName,
	})
end

function WaypointsAtom.SetWaypoints(waypoints: { TPluginWaypoint })
	local state = waypointsAtom()
	waypointsAtom({
		WaypointNameInput = state.WaypointNameInput,
		Waypoints = waypoints,
		SelectedWaypointName = state.SelectedWaypointName,
	})
end

function WaypointsAtom.SetSelectedWaypointName(selectedWaypointName: string?)
	local state = waypointsAtom()
	waypointsAtom({
		WaypointNameInput = state.WaypointNameInput,
		Waypoints = state.Waypoints,
		SelectedWaypointName = selectedWaypointName,
	})
end

return WaypointsAtom
