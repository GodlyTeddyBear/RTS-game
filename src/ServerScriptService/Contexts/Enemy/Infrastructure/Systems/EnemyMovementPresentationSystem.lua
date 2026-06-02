--!strict

local EnemyMovementPresentationSystem = {}
EnemyMovementPresentationSystem.__index = EnemyMovementPresentationSystem

function EnemyMovementPresentationSystem.new(entityFactory: any)
	return setmetatable({ _entityFactory = entityFactory }, EnemyMovementPresentationSystem)
end

function EnemyMovementPresentationSystem:Run()
	-- READS: Movement.MoveIntent [AUTHORITATIVE], Movement.ApplyResult [AUTHORITATIVE]
	-- WRITES: Enemy.PathState [AUTHORITATIVE], Enemy.CurrentMoveSpeed [DERIVED], Enemy.AnimationState [DERIVED], Enemy.AnimationLooping [DERIVED]
	local result = self._entityFactory:Query({ FeatureName = "Enemy", Keys = { "AliveTag", "PathState" } })
	if not result.success then return end
	for _, entity in ipairs(result.value) do
		local actionState = self:_Get(entity, "ActionState", "AI")
		local attackState = self:_Get(entity, "AttackState", "Combat")
		local intent = self:_Get(entity, "MoveIntent", "Movement")
		local applyResult = self:_Get(entity, "ApplyResult", "Movement")
		local speed = self:_Get(entity, "SpeedState", "Movement")
		local isMoving = type(applyResult) == "table" and applyResult.IsMoving == true
		if type(actionState) == "table" and actionState.ActionId == "Attack" and type(attackState) == "table" then
			self._entityFactory:Set(entity, "PathState", { GoalPosition = attackState.TargetPosition, IsMoving = false }, "Enemy")
			self._entityFactory:Set(entity, "CurrentMoveSpeed", { Value = 0 }, "Enemy")
			self._entityFactory:Set(entity, "Target", { TargetEntity = attackState.TargetEntity, TargetKind = attackState.TargetKind }, "Entity")
			self._entityFactory:Set(entity, "AnimationState", "Attack", "Enemy")
			self._entityFactory:Set(entity, "AnimationLooping", false, "Enemy")
			continue
		end
		self._entityFactory:Set(entity, "PathState", {
			GoalPosition = if type(intent) == "table" then intent.GoalPosition else nil,
			IsMoving = isMoving,
		}, "Enemy")
		self._entityFactory:Set(entity, "CurrentMoveSpeed", {
			Value = if isMoving and type(speed) == "table" then speed.CurrentSpeed or 0 else 0,
		}, "Enemy")
		self._entityFactory:Set(entity, "AnimationState", if isMoving then "Walk" else "Idle", "Enemy")
		self._entityFactory:Set(entity, "AnimationLooping", true, "Enemy")
	end
end

function EnemyMovementPresentationSystem:_Get(entity: number, key: string, featureName: string): any
	local result = self._entityFactory:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

return EnemyMovementPresentationSystem
