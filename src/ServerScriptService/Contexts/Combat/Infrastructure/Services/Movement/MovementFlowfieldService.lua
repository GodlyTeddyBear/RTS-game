--!strict

local ServerStorage = game:GetService("ServerStorage")

local FastFlowHelper = require(ServerStorage.Utilities.FastFlowHelper)

local MovementFlowfieldService = {}
MovementFlowfieldService.__index = MovementFlowfieldService

function MovementFlowfieldService.new()
	local self = setmetatable({}, MovementFlowfieldService)
	self._gridService = nil
	self._entryByGoalKey = {}
	self._goalKeyByEntity = {}
	return self
end

function MovementFlowfieldService:Init(registry: any, _name: string)
	self._gridService = registry:Get("MovementGridService")
	assert(self._gridService ~= nil, "MovementFlowfieldService missing MovementGridService in Init")
end

function MovementFlowfieldService:GetRuntime(): (any?, any?)
	if self._gridService == nil then
		return nil, nil
	end
	return self._gridService:GetRuntime()
end

function MovementFlowfieldService:Attach(entity: number, goalPosition: Vector3): (any?, string?)
	local pathfinder, mapping = self:GetRuntime()
	if pathfinder == nil or mapping == nil then
		return nil, "FastFlowNotConfigured"
	end

	local goalCell = pathfinder:FindOpenCell(FastFlowHelper.WorldXZToGridCell(goalPosition, mapping))
	if goalCell == nil then
		return nil, "FastFlowGenerateFailed"
	end

	local goalKey = (`{goalCell.X}:{goalCell.Y}`)
	local entry = self._entryByGoalKey[goalKey]
	if self._goalKeyByEntity[entity] == goalKey and entry ~= nil then
		return {
			GoalKey = goalKey,
			GoalWorldSample = entry.GoalWorldSample,
		}, nil
	end
	if entry == nil then
		local goalWorldSample = FastFlowHelper.GridCellToWorldXZ(goalCell, mapping, goalPosition.Y)
		local flowfield = FastFlowHelper.GenerateFlowfieldWorld(pathfinder, goalWorldSample, mapping, nil)
		if flowfield == nil then
			return nil, "FastFlowGenerateFailed"
		end
		entry = {
			Flowfield = flowfield,
			GoalCell = goalCell,
			GoalWorldSample = goalWorldSample,
			RefCount = 0,
		}
		self._entryByGoalKey[goalKey] = entry
	end

	self:Detach(entity)
	entry.RefCount += 1
	self._goalKeyByEntity[entity] = goalKey
	return {
		GoalKey = goalKey,
		GoalWorldSample = entry.GoalWorldSample,
	}, nil
end

function MovementFlowfieldService:Sample(entity: number, position: Vector3): Vector2?
	local _pathfinder, mapping = self:GetRuntime()
	local goalKey = self._goalKeyByEntity[entity]
	local entry = if goalKey ~= nil then self._entryByGoalKey[goalKey] else nil
	if mapping == nil or entry == nil then
		return nil
	end

	local direction = entry.Flowfield:GetDirection(FastFlowHelper.WorldXZToGridCell(position, mapping))
	return if direction ~= nil then Vector2.new(direction.X, direction.Y) else nil
end

function MovementFlowfieldService:SanitizeTarget(targetPosition: Vector3?): Vector3?
	if targetPosition == nil then
		return nil
	end
	local pathfinder, mapping = self:GetRuntime()
	if pathfinder == nil or mapping == nil then
		return targetPosition
	end

	local cellState, cell = FastFlowHelper.ClassifyWorldXZCell(pathfinder, targetPosition, mapping)
	if cellState ~= "Blocked" and cellState ~= "OutOfBounds" then
		return targetPosition
	end
	if cell == nil then
		return nil
	end
	local openCell = FastFlowHelper.FindNearestOpenCellDeep(pathfinder, cell, mapping)
	return if openCell ~= nil then FastFlowHelper.GridCellToWorldXZ(openCell, mapping, targetPosition.Y) else nil
end

function MovementFlowfieldService:Detach(entity: number)
	local goalKey = self._goalKeyByEntity[entity]
	if goalKey == nil then
		return
	end
	self._goalKeyByEntity[entity] = nil
	local entry = self._entryByGoalKey[goalKey]
	if entry ~= nil then
		entry.RefCount -= 1
		if entry.RefCount <= 0 then
			self._entryByGoalKey[goalKey] = nil
		end
	end
end

function MovementFlowfieldService:Reset()
	table.clear(self._entryByGoalKey)
	table.clear(self._goalKeyByEntity)
end

return MovementFlowfieldService
