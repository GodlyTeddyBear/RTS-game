--!strict

--[=[
	@class GetResourceBalanceQuery
	Reads a single resource balance from the economy sync service.
	@server
]=]
local GetResourceBalanceQuery = {}
GetResourceBalanceQuery.__index = GetResourceBalanceQuery

--[=[
	Creates a new balance query.
	@within GetResourceBalanceQuery
	@return GetResourceBalanceQuery -- The new query instance.
]=]
function GetResourceBalanceQuery.new()
	return setmetatable({}, GetResourceBalanceQuery)
end

-- Resolves the sync service once so the query remains a thin read-only wrapper.
--[=[
	Initializes query dependencies.
	@within GetResourceBalanceQuery
	@param registry any -- The registry that owns this query.
	@param _name string -- The registered module name.
]=]
function GetResourceBalanceQuery:Init(registry: any, _name: string)
	self._syncService = registry:Get("ResourceSyncService")
end

--[=[
	Reads a resource balance.
	@within GetResourceBalanceQuery
	@param userId number -- The player user id.
	@param resourceType string -- The resource to read.
	@return number? -- The current balance, or `nil` if uninitialized.
]=]
function GetResourceBalanceQuery:Execute(userId: number, resourceType: string): number?
	return self._syncService:GetBalance(userId, resourceType)
end

return GetResourceBalanceQuery
