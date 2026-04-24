--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EnemyConfig = require(ReplicatedStorage.Contexts.Enemy.Config.EnemyConfig)
local BaseECSEntityFactory = require(ReplicatedStorage.Utilities.BaseECSEntityFactory)

type TCombatActionState = "Idle" | "Running" | "Committed"

type TCombatAction = {
	CurrentActionId: string?,
	ActionState: TCombatActionState,
	ActionData: any?,
	PendingActionId: string?,
	PendingActionData: any?,
	StartedAt: number?,
	FinishedAt: number?,
}

--[=[
	@class EnemyEntityFactory
	Creates and mutates enemy entities in the EnemyContext ECS world.
	@server
]=]
local EnemyEntityFactory = {}
EnemyEntityFactory.__index = EnemyEntityFactory
setmetatable(EnemyEntityFactory, { __index = BaseECSEntityFactory })

function EnemyEntityFactory.new()
	return setmetatable(BaseECSEntityFactory.new("Enemy"), EnemyEntityFactory)
end

local function _buildDefaultAction(): TCombatAction
	return {
		CurrentActionId = nil,
		ActionState = "Idle",
		ActionData = nil,
		PendingActionId = nil,
		PendingActionData = nil,
		StartedAt = nil,
		FinishedAt = nil,
	}
end

function EnemyEntityFactory:_GetComponentRegistryName(): string
	return "EnemyComponentRegistry"
end

function EnemyEntityFactory:_OnInit(_registry: any, _name: string, _componentRegistry: any)
	assert(self._components ~= nil and self._components.AliveTag ~= nil, "EnemyEntityFactory: missing EnemyComponentRegistry components")
end

function EnemyEntityFactory:CreateEnemy(enemyId: string, role: string, spawnCFrame: CFrame, waveNumber: number): number
	self:RequireReady()

	local roleConfig = EnemyConfig.ROLES[role]
	assert(roleConfig ~= nil, "Unknown enemy role: " .. tostring(role))
	local components = self:GetComponentsOrThrow()
	local entity = self:_CreateEntity()

	self:_Set(entity, components.HealthComponent, {
		current = roleConfig.maxHp,
		max = roleConfig.maxHp,
	})
	self:_Set(entity, components.PositionComponent, {
		cframe = spawnCFrame,
	})
	self:_Set(entity, components.RoleComponent, {
		role = role,
		moveSpeed = roleConfig.moveSpeed,
		damage = roleConfig.damage,
		attackRange = roleConfig.attackRange,
		attackCooldown = roleConfig.attackCooldown,
		targetPreference = roleConfig.targetPreference,
	})
	self:_Set(entity, components.PathStateComponent, {
		waypointIndex = 1,
		waypoints = {},
		isMoving = false,
	})
	self:_Set(entity, components.IdentityComponent, {
		enemyId = enemyId,
		role = role,
		waveNumber = waveNumber,
	})
	self:_Set(entity, components.CombatActionComponent, _buildDefaultAction())
	self:_Set(entity, components.AttackCooldownComponent, {
		Cooldown = roleConfig.attackCooldown,
		LastAttackTime = 0,
	})
	self:_Set(entity, components.BehaviorConfigComponent, {
		TickInterval = 0.15,
	})
	self:_Add(entity, components.AliveTag)

	return entity
end

function EnemyEntityFactory:SetModelRef(entity: number, model: Model)
	self:RequireReady()
	self:_Set(entity, self._components.ModelRefComponent, { model = model })
	self:_Add(entity, self._components.DirtyTag)
end

function EnemyEntityFactory:SetWaypoints(entity: number, waypoints: { Vector3 })
	self:RequireReady()
	local state = self:GetPathState(entity)
	if state == nil then
		return
	end

	self:_Set(entity, self._components.PathStateComponent, {
		waypointIndex = 1,
		waypoints = table.clone(waypoints),
		isMoving = false,
	})
end

function EnemyEntityFactory:SetPathMoving(entity: number, isMoving: boolean)
	self:RequireReady()
	local state = self:GetPathState(entity)
	if state == nil then
		return
	end
	if state.isMoving == isMoving then
		return
	end

	self:_Set(entity, self._components.PathStateComponent, {
		waypointIndex = state.waypointIndex,
		waypoints = state.waypoints,
		isMoving = isMoving,
	})
	self:_Add(entity, self._components.DirtyTag)
end

function EnemyEntityFactory:SetWaypointIndex(entity: number, waypointIndex: number)
	self:RequireReady()
	local state = self:GetPathState(entity)
	if state == nil then
		return
	end

	self:_Set(entity, self._components.PathStateComponent, {
		waypointIndex = waypointIndex,
		waypoints = state.waypoints,
		isMoving = state.isMoving,
	})
end

function EnemyEntityFactory:SetBehaviorTree(entity: number, treeInstance: any, tickInterval: number)
	self:RequireReady()
	self:_Set(entity, self._components.BehaviorTreeComponent, {
		TreeInstance = treeInstance,
		TickInterval = tickInterval,
		LastTickTime = 0,
	})
end

function EnemyEntityFactory:GetBehaviorTree(entity: number)
	self:RequireReady()
	return self:_Get(entity, self._components.BehaviorTreeComponent)
end

function EnemyEntityFactory:UpdateBTLastTickTime(entity: number, currentTime: number)
	self:RequireReady()
	local behaviorTree = self:GetBehaviorTree(entity)
	if behaviorTree == nil then
		return
	end

	self:_Set(entity, self._components.BehaviorTreeComponent, {
		TreeInstance = behaviorTree.TreeInstance,
		TickInterval = behaviorTree.TickInterval,
		LastTickTime = currentTime,
	})
end

function EnemyEntityFactory:GetCombatAction(entity: number)
	self:RequireReady()
	return self:_Get(entity, self._components.CombatActionComponent)
end

function EnemyEntityFactory:SetCombatAction(entity: number, action: TCombatAction)
	self:RequireReady()
	self:_Set(entity, self._components.CombatActionComponent, {
		CurrentActionId = action.CurrentActionId,
		ActionState = action.ActionState,
		ActionData = action.ActionData,
		PendingActionId = action.PendingActionId,
		PendingActionData = action.PendingActionData,
		StartedAt = action.StartedAt,
		FinishedAt = action.FinishedAt,
	})
end

function EnemyEntityFactory:SetPendingAction(entity: number, actionId: string, actionData: any?)
	self:RequireReady()
	local action = self:GetCombatAction(entity) or _buildDefaultAction()
	self:SetCombatAction(entity, {
		CurrentActionId = action.CurrentActionId,
		ActionState = action.ActionState,
		ActionData = action.ActionData,
		PendingActionId = actionId,
		PendingActionData = actionData,
		StartedAt = action.StartedAt,
		FinishedAt = action.FinishedAt,
	})
end

function EnemyEntityFactory:ClearPendingAction(entity: number)
	self:RequireReady()
	local action = self:GetCombatAction(entity) or _buildDefaultAction()
	self:SetCombatAction(entity, {
		CurrentActionId = action.CurrentActionId,
		ActionState = action.ActionState,
		ActionData = action.ActionData,
		PendingActionId = nil,
		PendingActionData = nil,
		StartedAt = action.StartedAt,
		FinishedAt = action.FinishedAt,
	})
end

function EnemyEntityFactory:StartAction(entity: number, actionId: string, actionData: any?, currentTime: number)
	self:RequireReady()
	self:SetCombatAction(entity, {
		CurrentActionId = actionId,
		ActionState = "Running",
		ActionData = actionData,
		PendingActionId = nil,
		PendingActionData = nil,
		StartedAt = currentTime,
		FinishedAt = nil,
	})
end

function EnemyEntityFactory:ClearAction(entity: number)
	self:RequireReady()
	self:SetCombatAction(entity, _buildDefaultAction())
end

function EnemyEntityFactory:ResetActionState(entity: number)
	self:RequireReady()
	self:SetCombatAction(entity, _buildDefaultAction())
end

function EnemyEntityFactory:GetBehaviorConfig(entity: number)
	self:RequireReady()
	return self:_Get(entity, self._components.BehaviorConfigComponent)
end

function EnemyEntityFactory:GetAttackCooldown(entity: number)
	self:RequireReady()
	return self:_Get(entity, self._components.AttackCooldownComponent)
end

function EnemyEntityFactory:SetLastAttackTime(entity: number, lastAttackTime: number)
	self:RequireReady()
	local attackCooldown = self:GetAttackCooldown(entity)
	if attackCooldown == nil then
		return
	end

	self:_Set(entity, self._components.AttackCooldownComponent, {
		Cooldown = attackCooldown.Cooldown,
		LastAttackTime = lastAttackTime,
	})
end

function EnemyEntityFactory:SetBehaviorConfig(entity: number, config: { TickInterval: number })
	self:RequireReady()
	self:_Set(entity, self._components.BehaviorConfigComponent, {
		TickInterval = config.TickInterval,
	})

	local behaviorTree = self:GetBehaviorTree(entity)
	if behaviorTree ~= nil then
		self:_Set(entity, self._components.BehaviorTreeComponent, {
			TreeInstance = behaviorTree.TreeInstance,
			TickInterval = config.TickInterval,
			LastTickTime = behaviorTree.LastTickTime,
		})
	end
end

function EnemyEntityFactory:MarkGoalReached(entity: number)
	self:RequireReady()
	self:_Remove(entity, self._components.AliveTag)
	self:_Add(entity, self._components.GoalReachedTag)
	self:_Add(entity, self._components.DirtyTag)
end

function EnemyEntityFactory:ClearGoalReached(entity: number)
	self:RequireReady()
	self:_Remove(entity, self._components.GoalReachedTag)
	self:_Add(entity, self._components.DirtyTag)
end

function EnemyEntityFactory:ApplyDamage(entity: number, amount: number): boolean
	self:RequireReady()
	local health = self:GetHealth(entity)
	if health == nil then
		return false
	end

	local nextHp = math.max(0, health.current - amount)
	self:_Set(entity, self._components.HealthComponent, {
		current = nextHp,
		max = health.max,
	})
	self:_Add(entity, self._components.DirtyTag)

	return nextHp <= 0
end

function EnemyEntityFactory:UpdatePosition(entity: number, cframe: CFrame)
	self:RequireReady()
	self:_Set(entity, self._components.PositionComponent, { cframe = cframe })
end

function EnemyEntityFactory:GetDeathCFrame(entity: number): CFrame?
	self:RequireReady()
	local modelRef = self:GetModelRef(entity)
	if modelRef ~= nil then
		return modelRef.model:GetPivot()
	end

	local position = self:GetPosition(entity)
	if position ~= nil then
		return position.cframe
	end

	return nil
end

function EnemyEntityFactory:IsAlive(entity: number): boolean
	self:RequireReady()
	return self:_Has(entity, self._components.AliveTag)
end

function EnemyEntityFactory:GetHealth(entity: number)
	self:RequireReady()
	return self:_Get(entity, self._components.HealthComponent)
end

function EnemyEntityFactory:GetRole(entity: number)
	self:RequireReady()
	return self:_Get(entity, self._components.RoleComponent)
end

function EnemyEntityFactory:GetIdentity(entity: number)
	self:RequireReady()
	return self:_Get(entity, self._components.IdentityComponent)
end

function EnemyEntityFactory:GetPathState(entity: number)
	self:RequireReady()
	return self:_Get(entity, self._components.PathStateComponent)
end

function EnemyEntityFactory:GetModelRef(entity: number)
	self:RequireReady()
	return self:_Get(entity, self._components.ModelRefComponent)
end

function EnemyEntityFactory:GetPosition(entity: number)
	self:RequireReady()
	return self:_Get(entity, self._components.PositionComponent)
end

function EnemyEntityFactory:GetEntityCFrame(entity: number): CFrame?
	self:RequireReady()
	local modelRef = self:GetModelRef(entity)
	if modelRef ~= nil and modelRef.model ~= nil then
		return modelRef.model:GetPivot()
	end

	local position = self:GetPosition(entity)
	if position == nil then
		return nil
	end

	return position.cframe
end

function EnemyEntityFactory:GetNearestAliveEnemy(position: Vector3, maxRange: number): { entity: number, cframe: CFrame }?
	self:RequireReady()

	local nearestEntity = nil :: number?
	local nearestCFrame = nil :: CFrame?
	local nearestDistanceSquared = math.huge
	local maxRangeSquared = maxRange * maxRange

	for _, entity in ipairs(self:QueryAliveEntities()) do
		local entityCFrame = self:GetEntityCFrame(entity)
		if entityCFrame == nil then
			continue
		end

		local delta = entityCFrame.Position - position
		local distanceSquared = delta.X * delta.X + delta.Y * delta.Y + delta.Z * delta.Z
		if distanceSquared <= maxRangeSquared and distanceSquared < nearestDistanceSquared then
			nearestDistanceSquared = distanceSquared
			nearestEntity = entity
			nearestCFrame = entityCFrame
		end
	end

	if nearestEntity == nil or nearestCFrame == nil then
		return nil
	end

	return {
		entity = nearestEntity,
		cframe = nearestCFrame,
	}
end

function EnemyEntityFactory:QueryAliveEntities(): { number }
	self:RequireReady()
	return self:CollectQuery(self._components.AliveTag)
end

function EnemyEntityFactory:QueryGoalReachedEntities(): { number }
	self:RequireReady()
	return self:CollectQuery(self._components.GoalReachedTag)
end

function EnemyEntityFactory:DeleteEntity(entity: number)
	self:RequireReady()
	self:MarkForDestruction(entity)
	self:FlushDestructionQueue()
end

return EnemyEntityFactory
