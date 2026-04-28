--!strict

local BaseApplication = require(script.Parent.BaseApplication)

--[=[
    @class BaseQuery
    Base application for queries that resolve dependencies without emitting events.
    @server
]=]

export type TDependencyMap = BaseApplication.TDependencyMap
export type TBaseQuery = BaseApplication.TBaseApplication

local BaseQuery = {}
BaseQuery.__index = BaseQuery
setmetatable(BaseQuery, BaseApplication)

--[=[
    Creates a query base for a context and operation pair.
    @within BaseQuery
    @param contextName string -- Owning context label used in diagnostics.
    @param operationName string -- Operation label used in diagnostics.
    @return TBaseQuery -- Base query instance.
]=]
function BaseQuery.new(contextName: string, operationName: string): TBaseQuery
	local self = BaseApplication.new(contextName, operationName)
	return setmetatable(self, BaseQuery) :: any
end

return BaseQuery
