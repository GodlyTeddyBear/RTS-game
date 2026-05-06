--!strict

-- Services
local Workspace = game:GetService("Workspace")

-- Modules
local Constants = require(script.Parent.Parent.Parent.Parent.Parent.Constants)
local PluginTypes = require(script.Parent.Parent.Parent.Parent.Parent.Types.PluginTypes)

type TPluginWaypoint = PluginTypes.TPluginWaypoint
type TWaypointActionResult = PluginTypes.TWaypointActionResult

local WaypointService = {}
WaypointService.__index = WaypointService

function WaypointService.new(settingsService)
	local self = setmetatable({}, WaypointService)
	self.Settings = settingsService
	return self
end

function WaypointService:GetWaypoints(): { TPluginWaypoint }
	return self.Settings:GetWaypoints()
end

function WaypointService:SaveCameraWaypoint(rawWaypointName: string): TWaypointActionResult
	local waypointName = string.gsub(rawWaypointName, "^%s*(.-)%s*$", "%1")
	if waypointName == "" then
		return {
			Success = false,
			Message = "Enter a waypoint name before saving.",
			SavedWaypointName = nil,
		}
	end

	local currentCamera = Workspace.CurrentCamera
	if currentCamera == nil then
		return {
			Success = false,
			Message = "Cannot save waypoint because no current camera is available.",
			SavedWaypointName = nil,
		}
	end

	local componentsTuple = table.pack(currentCamera.CFrame:GetComponents())
	if componentsTuple.n ~= 12 then
		return {
			Success = false,
			Message = "Cannot save waypoint because camera transform data is invalid.",
			SavedWaypointName = nil,
		}
	end

	local components = {}
	for index = 1, 12 do
		components[index] = componentsTuple[index]
	end

	local waypoints = self.Settings:GetWaypoints()
	local nextWaypointName = self:_CreateUniqueWaypointName(waypointName, waypoints)
	table.insert(waypoints, {
		Name = nextWaypointName,
		CameraCFrameComponents = components,
	})

	while #waypoints > Constants.MaxWaypoints do
		table.remove(waypoints, 1)
	end

	self.Settings:SetWaypoints(waypoints)

	return {
		Success = true,
		Message = "Saved waypoint \"" .. nextWaypointName .. "\".",
		SavedWaypointName = nextWaypointName,
	}
end

function WaypointService:GoToWaypoint(waypointName: string): TWaypointActionResult
	local currentCamera = Workspace.CurrentCamera
	if currentCamera == nil then
		return {
			Success = false,
			Message = "Cannot go to waypoint because no current camera is available.",
			SavedWaypointName = nil,
		}
	end

	local targetWaypoint = nil
	for _, waypoint in self.Settings:GetWaypoints() do
		if waypoint.Name == waypointName then
			targetWaypoint = waypoint
			break
		end
	end

	if targetWaypoint == nil then
		return {
			Success = false,
			Message = "Selected waypoint no longer exists.",
			SavedWaypointName = nil,
		}
	end

	local components = targetWaypoint.CameraCFrameComponents
	if #components ~= 12 then
		return {
			Success = false,
			Message = "Waypoint data is invalid and cannot be applied.",
			SavedWaypointName = nil,
		}
	end

	for index = 1, 12 do
		if type(components[index]) ~= "number" then
			return {
				Success = false,
				Message = "Waypoint data is invalid and cannot be applied.",
				SavedWaypointName = nil,
			}
		end
	end

	currentCamera.CFrame = CFrame.new(
		components[1],
		components[2],
		components[3],
		components[4],
		components[5],
		components[6],
		components[7],
		components[8],
		components[9],
		components[10],
		components[11],
		components[12]
	)

	return {
		Success = true,
		Message = "Moved camera to waypoint \"" .. targetWaypoint.Name .. "\".",
		SavedWaypointName = targetWaypoint.Name,
	}
end

function WaypointService:_CreateUniqueWaypointName(baseName: string, waypoints: { TPluginWaypoint }): string
	local nameSet = {}
	for _, waypoint in waypoints do
		nameSet[waypoint.Name] = true
	end

	if not nameSet[baseName] then
		return baseName
	end

	local suffix = 2
	while true do
		local nextName = string.format("%s (%d)", baseName, suffix)
		if not nameSet[nextName] then
			return nextName
		end
		suffix += 1
	end
end

return WaypointService
