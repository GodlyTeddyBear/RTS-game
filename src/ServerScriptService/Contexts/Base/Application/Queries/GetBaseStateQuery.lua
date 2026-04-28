--!strict

--[=[
    @class GetBaseStateQuery
    Reads the base state snapshot from the sync service.
    @server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local BaseQuery = require(ReplicatedStorage.Utilities.BaseApplication.BaseQuery)
local BaseTypes = require(ReplicatedStorage.Contexts.Base.Types.BaseTypes)

local Ok = Result.Ok

type BaseState = BaseTypes.BaseState

local GetBaseStateQuery = {}
GetBaseStateQuery.__index = GetBaseStateQuery
setmetatable(GetBaseStateQuery, BaseQuery)

--[=[
    Create a new base-state query.
    @within GetBaseStateQuery
    @return GetBaseStateQuery -- Query instance.
]=]
function GetBaseStateQuery.new()
	local self = BaseQuery.new("Base", "GetBaseStateQuery")
	return setmetatable(self, GetBaseStateQuery)
end

--[=[
    Bind the base sync service dependency.
    @within GetBaseStateQuery
    @param registry any -- Registry that provides dependencies.
    @param _name string -- Module name supplied by the BaseContext framework.
]=]
function GetBaseStateQuery:Init(registry: any, _name: string)
	self:_RequireDependency(registry, "_syncService", "BaseSyncService")
end

--[=[
    Read the current base state snapshot.
    @within GetBaseStateQuery
    @return Result.Result<BaseState?> -- Read-only base state snapshot when the base exists.
]=]
function GetBaseStateQuery:Execute(): Result.Result<BaseState?>
	return Ok(self._syncService:GetStateReadOnly())
end

return GetBaseStateQuery
