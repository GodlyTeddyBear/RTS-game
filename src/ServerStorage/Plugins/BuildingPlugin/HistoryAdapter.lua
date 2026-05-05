--!strict

local ChangeHistoryService = game:GetService("ChangeHistoryService")

local HistoryAdapter = {}
HistoryAdapter.__index = HistoryAdapter

function HistoryAdapter.new()
	local self = setmetatable({}, HistoryAdapter)
	return self
end

function HistoryAdapter:Run(waypointName: string, callback: () -> ())
	ChangeHistoryService:SetWaypoint(waypointName .. " Before")
	callback()
	ChangeHistoryService:SetWaypoint(waypointName .. " After")
end

return HistoryAdapter
