--!strict

local EnemyAttackPresentationSystem = {}
EnemyAttackPresentationSystem.__index = EnemyAttackPresentationSystem

function EnemyAttackPresentationSystem.new(entityFactory: any)
	local self = setmetatable({}, EnemyAttackPresentationSystem)
	self._entityFactory = entityFactory
	return self
end

function EnemyAttackPresentationSystem:Run()
	-- READS: Combat.AttackState [AUTHORITATIVE], Enemy.AliveTag, Enemy.Role [AUTHORITATIVE]
	-- WRITES: Entity.Target [AUTHORITATIVE], Enemy.CurrentMoveSpeed [AUTHORITATIVE], Enemy.PathState [AUTHORITATIVE], Enemy.AnimationState [DERIVED], Enemy.AnimationLooping [DERIVED]
	local queryResult = self._entityFactory:Query({
		Keys = {
			{ Key = "AliveTag", FeatureName = "Enemy" },
			{ Key = "Role", FeatureName = "Enemy" },
			{ Key = "AttackState", FeatureName = "Combat" },
			{ Key = "ActionState", FeatureName = "AI" },
		},
	})
	if not queryResult.success then
		return
	end

	for _, entity in ipairs(queryResult.value) do
		local actionState = self:_Get(entity, "ActionState", "AI")
		if type(actionState) ~= "table" or actionState.ActionId ~= "Attack" then
			continue
		end

		local attackState = self:_Get(entity, "AttackState", "Combat")
		if type(attackState) ~= "table" or attackState.ActionId ~= "Attack" then
			continue
		end

		self._entityFactory:Set(entity, "CurrentMoveSpeed", {
			Value = 0,
		}, "Enemy")
		self._entityFactory:Set(entity, "PathState", {
			GoalPosition = attackState.TargetPosition,
			IsMoving = false,
		}, "Enemy")
		self._entityFactory:Set(entity, "Target", {
			TargetEntity = attackState.TargetEntity,
			TargetKind = attackState.TargetKind,
		}, "Entity")
		self._entityFactory:Set(entity, "AnimationState", "Attack", "Enemy")
		self._entityFactory:Set(entity, "AnimationLooping", false, "Enemy")
	end
end

function EnemyAttackPresentationSystem:_Get(entity: number, key: string, featureName: string): any
	local result = self._entityFactory:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

return EnemyAttackPresentationSystem
