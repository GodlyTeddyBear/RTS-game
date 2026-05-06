--!strict

local AppAtom = require(script.Parent.Parent.Parent.Parent.App.Infrastructure.AppAtom)
local usePluginServices = require(script.Parent.Parent.Parent.Parent.App.Infrastructure.usePluginServices)
local WaypointsAtom = require(script.Parent.Parent.Parent.Infrastructure.WaypointsAtom)

local function useWaypointsActions()
	local services = usePluginServices()

	local function refreshWaypoints()
		local waypoints = services.Waypoints:GetWaypoints()
		WaypointsAtom.SetWaypoints(waypoints)

		local selectedWaypointName = WaypointsAtom.GetState().SelectedWaypointName
		if selectedWaypointName == nil then
			return
		end

		for _, waypoint in waypoints do
			if waypoint.Name == selectedWaypointName then
				return
			end
		end

		WaypointsAtom.SetSelectedWaypointName(nil)
	end

	local function applyWaypointResult(result)
		AppAtom.SetStatus(result.Message, if result.Success then "Success" else "Error")
	end

	return {
		RefreshWaypoints = refreshWaypoints,
		SetWaypointNameInput = function(waypointNameInput: string)
			WaypointsAtom.SetWaypointNameInput(waypointNameInput)
		end,
		SetSelectedWaypointName = function(selectedWaypointName: string?)
			WaypointsAtom.SetSelectedWaypointName(selectedWaypointName)
		end,
		SaveWaypoint = function()
			local state = WaypointsAtom.GetState()
			local result = services.Waypoints:SaveCameraWaypoint(state.WaypointNameInput)
			applyWaypointResult(result)

			if result.Success then
				WaypointsAtom.SetWaypointNameInput("")
				refreshWaypoints()
				WaypointsAtom.SetSelectedWaypointName(result.SavedWaypointName)
			end
		end,
		GoToSelectedWaypoint = function()
			local selectedWaypointName = WaypointsAtom.GetState().SelectedWaypointName
			if selectedWaypointName == nil then
				AppAtom.SetStatus("Select a waypoint before using Go To Waypoint.", "Error")
				return
			end

			local result = services.Waypoints:GoToWaypoint(selectedWaypointName)
			applyWaypointResult(result)
		end,
	}
end

return useWaypointsActions
