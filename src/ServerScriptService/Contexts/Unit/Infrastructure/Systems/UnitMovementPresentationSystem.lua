--!strict

local UnitMovementPresentationSystem = {}
UnitMovementPresentationSystem.__index = UnitMovementPresentationSystem

function UnitMovementPresentationSystem.new(entityFactory: any)
	return setmetatable({ _entityFactory = entityFactory }, UnitMovementPresentationSystem)
end

function UnitMovementPresentationSystem:Run()
	-- READS: Movement.ApplyResult [AUTHORITATIVE], Movement.MoveIntent [AUTHORITATIVE], Unit.PathState [AUTHORITATIVE]
	-- WRITES: Unit.PathState [AUTHORITATIVE], Unit.AnimationState [DERIVED], Unit.AnimationLooping [DERIVED]
	local result = self._entityFactory:Query({ FeatureName = "Unit", Keys = { "PathState" } })
	if not result.success then return end
	for _, entity in ipairs(result.value) do
		local intent = self:_Get(entity, "MoveIntent", "Movement")
		local applyResult = self:_Get(entity, "ApplyResult", "Movement")
		local state = self:_Get(entity, "PathState", "Unit") or {}
		local isMoving = type(applyResult) == "table" and applyResult.IsMoving == true
		self._entityFactory:Set(entity, "PathState", {
			GoalPosition = if type(intent) == "table" then intent.GoalPosition else state.GoalPosition,
			RequestedGoalPosition = state.RequestedGoalPosition,
			GoalRevision = state.GoalRevision or 0,
			FailedGoalRevision = state.FailedGoalRevision,
			IsMoving = isMoving,
		}, "Unit")
		self._entityFactory:Set(entity, "AnimationState", if isMoving then "Walk" else "Idle", "Unit")
		self._entityFactory:Set(entity, "AnimationLooping", true, "Unit")
		self._entityFactory:Add(entity, "DirtyTag", "Entity")
	end
end

function UnitMovementPresentationSystem:_Get(entity: number, key: string, featureName: string): any
	local result = self._entityFactory:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

return UnitMovementPresentationSystem
