--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local PathfindingHelper = require(ServerStorage.Utilities.PathfindingHelper)
local CombatMovementConfig = require(ReplicatedStorage.Contexts.Combat.Config.CombatMovementConfig)
local Result = require(ReplicatedStorage.Utilities.Result)
local UnitConfig = require(ReplicatedStorage.Contexts.Unit.Config.UnitConfig)
local UnitTypes = require(ReplicatedStorage.Contexts.Unit.Types.UnitTypes)
local Errors = require(script.Parent.Parent.Parent.Errors)

type IssueMoveOrderRequest = UnitTypes.IssueMoveOrderRequest

local Ok = Result.Ok
local Try = Result.Try
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

local function _GetAgentRadiusForUnit(unitId: string): number
	local definition = UnitConfig.Definitions[unitId]
	local roleName = if definition ~= nil then definition.Role else nil
	local roleConfig = if roleName ~= nil then CombatMovementConfig.AGENT_PARAMS_BY_UNIT_ROLE[roleName] else nil
	local radius = if roleConfig ~= nil then roleConfig.AgentRadius else nil
	if type(radius) ~= "number" or radius <= 0 then
		radius = CombatMovementConfig.DEFAULT_AGENT_PARAMS.AgentRadius
	end
	return if type(radius) == "number" and radius > 0 then radius else 2
end

local function _BuildFormationOffsets(unitCount: number, spacing: number): { Vector3 }
	if unitCount <= 1 then
		return { Vector3.zero }
	end

	local offsets = table.create(unitCount)
	local columns = math.max(1, math.ceil(math.sqrt(unitCount)))
	local rowCount = math.max(1, math.ceil(unitCount / columns))
	local columnCenter = (columns - 1) * 0.5
	local rowCenter = (rowCount - 1) * 0.5

	for index = 1, unitCount do
		local zeroBasedIndex = index - 1
		local rowIndex = math.floor(zeroBasedIndex / columns)
		local columnIndex = zeroBasedIndex % columns
		offsets[index] = Vector3.new((columnIndex - columnCenter) * spacing, 0, (rowIndex - rowCenter) * spacing)
	end

	return offsets
end

function IssueUnitMoveOrderCommand.new()
	local self = BaseCommand.new("Unit", "IssueUnitMoveOrder")
	return setmetatable(self, IssueUnitMoveOrderCommand)
end

function IssueUnitMoveOrderCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_unitReadService = "UnitEntityReadService",
	})
end

function IssueUnitMoveOrderCommand:Start(registry: any, _name: string)
	self._entityContext = registry:Get("EntityContext")
end

function IssueUnitMoveOrderCommand:Execute(player: Player, request: IssueMoveOrderRequest): Result.Result<number>
	return Result.Catch(function()
		Ensure(type(request) == "table", "InvalidMoveOrderRequest", Errors.INVALID_MOVE_ORDER_REQUEST)
		Ensure(typeof(player) == "Instance" and player:IsA("Player"), "InvalidPlayer", Errors.INVALID_OWNER_ID)
		Ensure(type(request.UnitGuids) == "table" and #request.UnitGuids > 0, "InvalidUnitGuids", Errors.INVALID_UNIT_GUIDS)
		Ensure(typeof(request.Destination) == "Vector3", "InvalidMoveDestination", Errors.INVALID_MOVE_DESTINATION)
		Ensure(_IsValidDestination(request.Destination), "InvalidMoveDestination", Errors.INVALID_MOVE_DESTINATION)

		local normalizedDestination =
			PathfindingHelper.NormalizeGroundTarget(request.Destination, CombatMovementConfig.GOAL_NORMALIZATION)
		Ensure(typeof(normalizedDestination) == "Vector3" and _IsValidDestination(normalizedDestination :: Vector3), "InvalidMoveDestination", Errors.INVALID_MOVE_DESTINATION)

		local ownerId = tostring(player.UserId)
		local orderedEntities = {}
		for _, unitGuid in ipairs(request.UnitGuids) do
			if type(unitGuid) ~= "string" or unitGuid == "" then
				continue
			end

			local entity = self._unitReadService:GetEntityByUnitGuid(unitGuid)
			if entity == nil or not self._unitReadService:IsActive(entity) then
				continue
			end

			local ownership = self._unitReadService:GetOwnership(entity)
			if type(ownership) ~= "table" or ownership.OwnerKind ~= "Player" or ownership.OwnerId ~= ownerId then
				continue
			end

			local role = self._unitReadService:GetRole(entity)
			if type(role) ~= "table" or role.Role ~= "Builder" then
				continue
			end

			table.insert(orderedEntities, {
				Entity = entity,
				UnitGuid = unitGuid,
				AgentRadius = _GetAgentRadiusForUnit(role.UnitId),
			})
		end

		table.sort(orderedEntities, function(a, b)
			return a.UnitGuid < b.UnitGuid
		end)

		if #orderedEntities == 0 then
			return Ok(0)
		end

		local maxAgentRadius = 0
		for _, entry in ipairs(orderedEntities) do
			maxAgentRadius = math.max(maxAgentRadius, entry.AgentRadius)
		end

		local spacing = math.max(4, maxAgentRadius * 3)
		local offsets = _BuildFormationOffsets(#orderedEntities, spacing)
		local issuedCount = 0

		for index, entry in ipairs(orderedEntities) do
			local offsetTarget = (normalizedDestination :: Vector3) + offsets[index]
			local resolvedGoal = if #orderedEntities == 1
				then (normalizedDestination :: Vector3)
				else PathfindingHelper.NormalizeGroundTarget(offsetTarget, CombatMovementConfig.GOAL_NORMALIZATION)
			if typeof(resolvedGoal) ~= "Vector3" or not _IsValidDestination(resolvedGoal :: Vector3) then
				resolvedGoal = normalizedDestination
			end

			local currentState = self._unitReadService:GetPathState(entry.Entity) or {}
			Try(self._entityContext:Set(entry.Entity, "PathState", {
				GoalPosition = resolvedGoal,
				RequestedGoalPosition = request.Destination,
				GoalRevision = (currentState.GoalRevision or 0) + 1,
				FailedGoalRevision = nil,
				IsMoving = false,
			}, "Unit"))
			Try(self._entityContext:Add(entry.Entity, "DirtyTag", "Entity"))
			issuedCount += 1
		end

		return Ok(issuedCount)
	end, self:_Label())
end

return IssueUnitMoveOrderCommand
