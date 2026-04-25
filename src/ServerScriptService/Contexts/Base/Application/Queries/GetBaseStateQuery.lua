--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local BaseTypes = require(ReplicatedStorage.Contexts.Base.Types.BaseTypes)

local Ok = Result.Ok

type BaseState = BaseTypes.BaseState

local GetBaseStateQuery = {}
GetBaseStateQuery.__index = GetBaseStateQuery

function GetBaseStateQuery.new()
	return setmetatable({}, GetBaseStateQuery)
end

function GetBaseStateQuery:Init(registry: any, _name: string)
	self._syncService = registry:Get("BaseSyncService")
end

function GetBaseStateQuery:Execute(): Result.Result<BaseState?>
	return Ok(self._syncService:GetStateReadOnly())
end

return GetBaseStateQuery
