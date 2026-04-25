--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok = Result.Ok
local Ensure = Result.Ensure

local GetBaseTargetCFrameQuery = {}
GetBaseTargetCFrameQuery.__index = GetBaseTargetCFrameQuery

function GetBaseTargetCFrameQuery.new()
	return setmetatable({}, GetBaseTargetCFrameQuery)
end

function GetBaseTargetCFrameQuery:Init(registry: any, _name: string)
	self._entityFactory = registry:Get("BaseEntityFactory")
end

function GetBaseTargetCFrameQuery:Execute(): Result.Result<CFrame>
	local cframe = self._entityFactory:GetTargetCFrame()
	Ensure(cframe ~= nil, "BaseNotFound", Errors.BASE_NOT_FOUND)
	return Ok(cframe)
end

return GetBaseTargetCFrameQuery
