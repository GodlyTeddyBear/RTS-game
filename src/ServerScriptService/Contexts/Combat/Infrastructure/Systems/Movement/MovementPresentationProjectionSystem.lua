--!strict

local MovementPresentationProjectionSystem = {}
MovementPresentationProjectionSystem.__index = MovementPresentationProjectionSystem

function MovementPresentationProjectionSystem.new(entityFactory: any, ruleRegistry: any)
	return setmetatable({ _entityFactory = entityFactory, _ruleRegistry = ruleRegistry }, MovementPresentationProjectionSystem)
end

function MovementPresentationProjectionSystem:Run()
	-- READS: Movement.MoveIntent [AUTHORITATIVE], Movement.ApplyResult [AUTHORITATIVE], Movement.SpeedState [AUTHORITATIVE], Combat.AttackState [AUTHORITATIVE], AI.ActionState [AUTHORITATIVE]
	-- WRITES: configured feature presentation components [DERIVED], configured Entity.Target [AUTHORITATIVE], Entity.DirtyTag
	for _, rule in ipairs(self._ruleRegistry:GetMovementPresentationRules()) do
		self:_RunRule(rule)
	end
end

function MovementPresentationProjectionSystem:_RunRule(rule: any)
	local query = rule.Query
	if type(query) ~= "table" then
		return
	end

	local result = self._entityFactory:Query(query)
	if not result.success then
		return
	end

	for _, entity in ipairs(result.value) do
		self:_ProjectEntity(rule, entity)
	end
end

function MovementPresentationProjectionSystem:_ProjectEntity(rule: any, entity: number)
	local intent = self:_Get(entity, "MoveIntent", "Movement")
	local applyResult = self:_Get(entity, "ApplyResult", "Movement")
	local speed = self:_Get(entity, "SpeedState", "Movement")
	local actionState = self:_Get(entity, "ActionState", "AI")
	local attackState = self:_Get(entity, "AttackState", "Combat")
	local isMoving = type(applyResult) == "table" and applyResult.IsMoving == true
	local isAttacking = type(actionState) == "table" and actionState.ActionId == "Attack"
		and type(attackState) == "table"
		and attackState.ActionId == "Attack"

	if isAttacking and type(rule.Attack) == "table" then
		self:_ApplyAttackProjection(rule, entity, attackState)
		return
	end

	if type(actionState) == "table" and type(rule.ActionPresentation) == "table" then
		local actionProjection = rule.ActionPresentation[actionState.ActionId]
		if type(actionProjection) == "table" and self:_CanApplyActionProjection(actionProjection, isMoving) then
			self:_ApplyActionProjection(rule, entity, actionProjection)
			return
		end
	end

	self:_ApplyMovementProjection(rule, entity, intent, speed, isMoving)
end

function MovementPresentationProjectionSystem:_CanApplyActionProjection(actionProjection: any, isMoving: boolean): boolean
	if actionProjection.WhenNotMoving == true and isMoving then
		return false
	end
	return true
end

function MovementPresentationProjectionSystem:_ApplyActionProjection(rule: any, entity: number, actionProjection: any)
	if type(actionProjection.Animation) == "table" then
		self:_SetAnimation(
			entity,
			actionProjection.Animation,
			actionProjection.Animation.State or "Idle",
			actionProjection.Animation.Looping == true
		)
	end
	if type(actionProjection.TargetEntityId) == "table" then
		self:_SetTargetEntityId(entity, actionProjection.TargetEntityId, actionProjection.TargetEntity)
	end
	self:_MarkDirty(entity, rule)
end

function MovementPresentationProjectionSystem:_ApplyAttackProjection(rule: any, entity: number, attackState: any)
	local attack = rule.Attack
	if type(attack.Target) == "table" then
		self._entityFactory:Set(entity, "Target", {
			TargetEntity = attackState.TargetEntity,
			TargetKind = attackState.TargetKind or attack.Target.TargetKind,
		}, "Entity")
	end
	if type(attack.PathState) == "table" then
		self._entityFactory:Set(entity, attack.PathState.Key, {
			GoalPosition = attackState.TargetPosition,
			IsMoving = false,
		}, attack.PathState.FeatureName)
	end
	if type(attack.Speed) == "table" then
		self._entityFactory:Set(entity, attack.Speed.Key, { Value = 0 }, attack.Speed.FeatureName)
	end
	if type(attack.Animation) == "table" then
		self:_SetAnimation(entity, attack.Animation, attack.Animation.State or "Attack", attack.Animation.Looping == true)
	end
	if type(attack.TargetEntityId) == "table" then
		self:_SetTargetEntityId(entity, attack.TargetEntityId, attackState.TargetEntity)
	end
	self:_MarkDirty(entity, rule)
end

function MovementPresentationProjectionSystem:_ApplyMovementProjection(rule: any, entity: number, intent: any, speed: any, isMoving: boolean)
	if type(rule.PathState) == "table" then
		local previous = self:_Get(entity, rule.PathState.Key, rule.PathState.FeatureName)
		local nextState = {
			GoalPosition = if type(intent) == "table" then intent.GoalPosition else if type(previous) == "table" then previous.GoalPosition else nil,
			IsMoving = isMoving,
		}
		if type(rule.PathState.PreserveKeys) == "table" and type(previous) == "table" then
			for _, key in ipairs(rule.PathState.PreserveKeys) do
				nextState[key] = previous[key]
			end
		end
		self._entityFactory:Set(entity, rule.PathState.Key, nextState, rule.PathState.FeatureName)
	end
	if type(rule.Speed) == "table" then
		self._entityFactory:Set(entity, rule.Speed.Key, {
			Value = if isMoving and type(speed) == "table" then speed.CurrentSpeed or 0 else 0,
		}, rule.Speed.FeatureName)
	end
	if type(rule.Animation) == "table" then
		self:_SetAnimation(entity, rule.Animation, if isMoving then rule.Animation.MovingState or "Walk" else rule.Animation.IdleState or "Idle", true)
	end
	if type(rule.TargetEntityId) == "table" then
		local targetEntity = if type(intent) == "table" then intent.TargetEntity else nil
		self:_SetTargetEntityId(entity, rule.TargetEntityId, targetEntity)
	end
	self:_MarkDirty(entity, rule)
end

function MovementPresentationProjectionSystem:_SetAnimation(entity: number, animation: any, state: string, looping: boolean)
	self._entityFactory:Set(entity, animation.StateKey, state, animation.FeatureName)
	self._entityFactory:Set(entity, animation.LoopingKey, looping, animation.FeatureName)
end

function MovementPresentationProjectionSystem:_SetTargetEntityId(entity: number, targetConfig: any, targetEntity: any)
	local identity = if type(targetEntity) == "number" then self:_Get(targetEntity, "Identity", "Entity") else nil
	local entityId = if type(identity) == "table" and type(identity.EntityId) == "string" then identity.EntityId else nil
	self._entityFactory:Set(entity, targetConfig.Key, entityId, targetConfig.FeatureName)
end

function MovementPresentationProjectionSystem:_MarkDirty(entity: number, rule: any)
	if rule.MarkDirty ~= false then
		self._entityFactory:Add(entity, "DirtyTag", "Entity")
	end
end

function MovementPresentationProjectionSystem:_Get(entity: number, key: string, featureName: string): any
	local result = self._entityFactory:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

return MovementPresentationProjectionSystem
