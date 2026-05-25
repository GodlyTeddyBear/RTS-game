--!strict

--[=[
    @class IssueUnitMoveOrderCommand
    Validates a manual move-order request and applies the destination to each eligible unit entity.

    @server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local PathfindingHelper = require(ServerStorage.Utilities.PathfindingHelper)
local CombatMovementConfig = require(ReplicatedStorage.Contexts.Combat.Config.CombatMovementConfig)
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

-- Resolves the entity factory used to look up and mutate the targeted unit entities.
function IssueUnitMoveOrderCommand.new()
	local self = BaseCommand.new("Unit", "IssueUnitMoveOrder")
	return setmetatable(self, IssueUnitMoveOrderCommand)
end

-- Binds the entity factory dependency required to inspect active units and update path goals.
function IssueUnitMoveOrderCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_entityFactory = "UnitEntityFactory",
	})
end

-- Validates the request and assigns the requested destination to every eligible owned builder unit.
function IssueUnitMoveOrderCommand:Execute(player: Player, request: IssueMoveOrderRequest): Result.Result<number>
	return Result.Catch(function()
		-- Validate the outer request shape before reading fields from it.
		Ensure(type(request) == "table", "InvalidMoveOrderRequest", Errors.INVALID_MOVE_ORDER_REQUEST)
		Ensure(typeof(player) == "Instance" and player:IsA("Player"), "InvalidPlayer", Errors.INVALID_OWNER_ID)
		Ensure(type(request.UnitGuids) == "table" and #request.UnitGuids > 0, "InvalidUnitGuids", Errors.INVALID_UNIT_GUIDS)
		Ensure(typeof(request.Destination) == "Vector3", "InvalidMoveDestination", Errors.INVALID_MOVE_DESTINATION)
		Ensure(_IsValidDestination(request.Destination), "InvalidMoveDestination", Errors.INVALID_MOVE_DESTINATION)
		local normalizedDestination =
			PathfindingHelper.NormalizeGroundTarget(request.Destination, CombatMovementConfig.GOAL_NORMALIZATION)
		Ensure(
			typeof(normalizedDestination) == "Vector3" and _IsValidDestination(normalizedDestination :: Vector3),
			"InvalidMoveDestination",
			Errors.INVALID_MOVE_DESTINATION
		)

		local ownerId = tostring(player.UserId)
		local issuedCount = 0

		-- Visit each candidate unit and only issue orders to live, owned builder entities.
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

			self._entityFactory:SetGoalPosition(entity, normalizedDestination :: Vector3, request.Destination)
			issuedCount += 1
		end

		return Ok(issuedCount)
	end, self:_Label())
end

return IssueUnitMoveOrderCommand
