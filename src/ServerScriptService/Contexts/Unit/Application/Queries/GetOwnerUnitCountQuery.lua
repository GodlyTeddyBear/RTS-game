--!strict

--[=[
    @class GetOwnerUnitCountQuery
    Returns the number of active units owned by the requested owner bucket.

    @server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseQuery = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseQuery)
local Result = require(ReplicatedStorage.Utilities.Result)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok = Result.Ok
local Ensure = Result.Ensure

local GetOwnerUnitCountQuery = {}
GetOwnerUnitCountQuery.__index = GetOwnerUnitCountQuery
setmetatable(GetOwnerUnitCountQuery, BaseQuery)

function GetOwnerUnitCountQuery.new()
	local self = BaseQuery.new("Unit", "GetOwnerUnitCount")
	return setmetatable(self, GetOwnerUnitCountQuery)
end

-- Resolves the entity factory used to count owner-scoped unit entities.
function GetOwnerUnitCountQuery:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_entityFactory = "UnitEntityFactory",
	})
end

-- Validates the owner identity and returns the current unit count for that owner bucket.
function GetOwnerUnitCountQuery:Execute(ownerKind: string, ownerId: string): Result.Result<number>
	return Result.Catch(function()
		Ensure(type(ownerKind) == "string" and ownerKind ~= "", "InvalidOwnerKind", Errors.INVALID_OWNER_KIND)
		Ensure(type(ownerId) == "string" and ownerId ~= "", "InvalidOwnerId", Errors.INVALID_OWNER_ID)
		return Ok(self._entityFactory:GetOwnerUnitCount(ownerKind, ownerId))
	end, self:_Label())
end

return GetOwnerUnitCountQuery
