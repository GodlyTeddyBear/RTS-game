--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)
local UnitTypes = require(ReplicatedStorage.Contexts.Unit.Types.UnitTypes)
local Errors = require(script.Parent.Parent.Parent.Errors)

type IssueMoveOrderRequest = UnitTypes.IssueMoveOrderRequest

local Ok = Result.Ok
local Ensure = Result.Ensure

local IssueUnitMoveOrderCommand = {}
IssueUnitMoveOrderCommand.__index = IssueUnitMoveOrderCommand
setmetatable(IssueUnitMoveOrderCommand, BaseCommand)

local function _IsFiniteNumber(value: number): boolean
	return value == value and value ~= math.huge and value ~= -math.huge
end

local function _IsValidDestination(destination: Vector3): boolean
	return _IsFiniteNumber(destination.X) and _IsFiniteNumber(destination.Y) and _IsFiniteNumber(destination.Z)
end

function IssueUnitMoveOrderCommand.new()
	local self = BaseCommand.new("Unit", "IssueUnitMoveOrder")
	return setmetatable(self, IssueUnitMoveOrderCommand)
end

function IssueUnitMoveOrderCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_entityFactory = "UnitEntityFactory",
	})
end

function IssueUnitMoveOrderCommand:Execute(player: Player, request: IssueMoveOrderRequest): Result.Result<number>
	return Result.Catch(function()
		Ensure(type(request) == "table", "InvalidMoveOrderRequest", Errors.INVALID_MOVE_ORDER_REQUEST)
		Ensure(typeof(player) == "Instance" and player:IsA("Player"), "InvalidPlayer", Errors.INVALID_OWNER_ID)
		Ensure(type(request.UnitGuids) == "table" and #request.UnitGuids > 0, "InvalidUnitGuids", Errors.INVALID_UNIT_GUIDS)
		Ensure(typeof(request.Destination) == "Vector3", "InvalidMoveDestination", Errors.INVALID_MOVE_DESTINATION)
		Ensure(_IsValidDestination(request.Destination), "InvalidMoveDestination", Errors.INVALID_MOVE_DESTINATION)

		local ownerId = tostring(player.UserId)
		local issuedCount = 0

		for _, unitGuid in ipairs(request.UnitGuids) do
			if type(unitGuid) ~= "string" or unitGuid == "" then
				continue
			end

			local entity = self._entityFactory:GetEntityByUnitGuid(unitGuid)
			if entity == nil or not self._entityFactory:IsActive(entity) then
				continue
			end

			local ownership = self._entityFactory:GetOwnership(entity)
			if ownership == nil or ownership.OwnerKind ~= "Player" or ownership.OwnerId ~= ownerId then
				continue
			end

			local role = self._entityFactory:GetRole(entity)
			if role == nil or role.Role ~= "Builder" then
				continue
			end

			self._entityFactory:SetGoalPosition(entity, request.Destination)
			issuedCount += 1
		end

		return Ok(issuedCount)
	end, self:_Label())
end

return IssueUnitMoveOrderCommand
