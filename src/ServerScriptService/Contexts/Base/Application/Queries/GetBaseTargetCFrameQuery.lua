--!strict

--[=[
    @class GetBaseTargetCFrameQuery
    Reads the current base target CFrame from the entity factory.
    @server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local BaseQuery = require(ReplicatedStorage.Utilities.BaseApplication.BaseQuery)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok = Result.Ok
local Ensure = Result.Ensure

local GetBaseTargetCFrameQuery = {}
GetBaseTargetCFrameQuery.__index = GetBaseTargetCFrameQuery
setmetatable(GetBaseTargetCFrameQuery, BaseQuery)

--[=[
    Create a new base-target query.
    @within GetBaseTargetCFrameQuery
    @return GetBaseTargetCFrameQuery -- Query instance.
]=]
function GetBaseTargetCFrameQuery.new()
	local self = BaseQuery.new("Base", "GetBaseTargetCFrameQuery")
	return setmetatable(self, GetBaseTargetCFrameQuery)
end

--[=[
    Bind the base entity factory dependency.
    @within GetBaseTargetCFrameQuery
    @param registry any -- Registry that provides dependencies.
    @param _name string -- Module name supplied by the BaseContext framework.
]=]
function GetBaseTargetCFrameQuery:Init(registry: any, _name: string)
	self:_RequireDependency(registry, "_entityFactory", "BaseEntityFactory")
end

--[=[
    Read the target CFrame for the active base.
    @within GetBaseTargetCFrameQuery
    @return Result.Result<CFrame> -- Target CFrame for the active base.
]=]
function GetBaseTargetCFrameQuery:Execute(): Result.Result<CFrame>
	local cframe = self._entityFactory:GetTargetCFrame()
	Ensure(cframe ~= nil, "BaseNotFound", Errors.BASE_NOT_FOUND)
	return Ok(cframe)
end

return GetBaseTargetCFrameQuery
