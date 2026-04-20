--!strict

--[=[
	@class GetGoalPointQuery
	Reads the commander goal point from the authoritative world layout service.
	@server
]=]
local GetGoalPointQuery = {}
GetGoalPointQuery.__index = GetGoalPointQuery

--[=[
	Creates a query wrapper around the world layout service.
	@within GetGoalPointQuery
	@param worldLayoutService { GetGoalPoint: (any) -> CFrame } -- Layout service dependency.
	@return GetGoalPointQuery -- The new query instance.
]=]
function GetGoalPointQuery.new(worldLayoutService: { GetGoalPoint: (any) -> CFrame })
	local self = setmetatable({}, GetGoalPointQuery)
	self._worldLayoutService = worldLayoutService
	return self
end

--[=[
	Returns the goal point enemies should path toward.
	@within GetGoalPointQuery
	@return CFrame -- The commander goal point.
]=]
function GetGoalPointQuery:Execute()
	return self._worldLayoutService:GetGoalPoint()
end

return GetGoalPointQuery
