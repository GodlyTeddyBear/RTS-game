--!strict

-- Services
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local ChangeHistoryAdapter = {}

function ChangeHistoryAdapter:Run(waypointName: string, callback: () -> ())
	ChangeHistoryService:SetWaypoint(waypointName .. " Before")
	callback()
	ChangeHistoryService:SetWaypoint(waypointName .. " After")
end

return ChangeHistoryAdapter
