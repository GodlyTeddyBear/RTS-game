--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EnemyConfig = require(ReplicatedStorage.Contexts.Enemy.Config.EnemyConfig)
local CombatECSEntityFactory = require(ReplicatedStorage.Utilities.CombatECSEntityFactory)
local SpatialQuery = require(ReplicatedStorage.Utilities.SpatialQuery)

--[=[
	@class EnemyEntityFactory
	Creates and mutates enemy entities in the EnemyContext ECS world.
	@server
]=]
local EnemyEntityFactory = {}
EnemyEntityFactory.__index = EnemyEntityFactory
setmetatable(EnemyEntityFactory, CombatECSEntityFactory)

function EnemyEntityFactory.new()
	return setmetatable(CombatECSEntityFactory.new("Enemy"), EnemyEntityFactory)
end

function EnemyEntityFactory:_GetComponentRegistryName(): string
	return "EnemyComponentRegistry"
end

function EnemyEntityFactory:_OnInit(_registry: any, _name: string, _componentRegistry: any)
	assert(
		self._components ~= nil
			and self._components.AliveTag ~= nil
			and self._components.TransformComponent ~= nil
			and self._components.TargetComponent ~= nil
			and self._components.LockOnComponent ~= nil,
		"EnemyEntityFactory: missing EnemyComponentRegistry components"
	)
	self:_ConfigureSpatialComponents("ModelRefComponent", "TransformComponent")
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
	self:SetTransformCFrame(entity, spawnCFrame)
	self:_Set(entity, components.RoleComponent, {
		role = role,
		moveSpeed = roleConfig.moveSpeed,
		damage = roleConfig.damage,
		attackRange = roleConfig.attackRange,
		attackCooldown = roleConfig.attackCooldown,
		targetPreference = roleConfig.targetPreference,
	})
	self:_Set(entity, components.PathStateComponent, {
		goalPosition = nil,
		isMoving = false,
	})
	self:_Set(entity, components.IdentityComponent, {
		enemyId = enemyId,
		role = role,
		waveNumber = waveNumber,
	})
	self:_Set(entity, components.CombatActionComponent, self:BuildDefaultCombatAction())
	self:_Set(entity, components.AttackCooldownComponent, {
		Cooldown = roleConfig.attackCooldown,
		LastAttackTime = 0,
	})
	self:_Set(entity, components.BehaviorConfigComponent, {
		TickInterval = 0.15,
	})
	self:_Set(entity, components.TargetComponent, {
		TargetEntity = nil,
		TargetKind = "Structure",
	})
	self:_Set(entity, components.LockOnComponent, {
		Attachment0 = nil,
		Attachment1 = nil,
		Constraint = nil,
	})
	self:_Add(entity, components.AliveTag)

	return entity
end

function EnemyEntityFactory:SetModelRef(entity: number, model: Model)
	CombatECSEntityFactory.SetModelRef(self, entity, model)
	self:_Add(entity, self._components.DirtyTag)
end

function EnemyEntityFactory:SetGoalPosition(entity: number, goalPosition: Vector3)
	self:RequireReady()
	local state = self:GetPathState(entity)
	if state == nil then
		return
	end

	self:_Set(entity, self._components.PathStateComponent, {
		goalPosition = goalPosition,
		isMoving = false,
	})
end

function EnemyEntityFactory:ClearGoalPosition(entity: number)
	self:RequireReady()
	local state = self:GetPathState(entity)
	if state == nil then
		return
	end

	self:_Set(entity, self._components.PathStateComponent, {
		goalPosition = nil,
		isMoving = false,
	})
	self:_Add(entity, self._components.DirtyTag)
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
		goalPosition = state.goalPosition,
		isMoving = isMoving,
	})
	self:_Add(entity, self._components.DirtyTag)
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
	self:SetTransformCFrame(entity, cframe)
end

function EnemyEntityFactory:GetDeathCFrame(entity: number): CFrame?
	return self:GetEntityCFrame(entity)
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

function EnemyEntityFactory:GetEntityByEnemyId(enemyId: string): number?
	self:RequireReady()
	for _, entity in ipairs(self:QueryAliveEntities()) do
		local identity = self:GetIdentity(entity)
		if identity ~= nil and identity.enemyId == enemyId then
			return entity
		end
	end

	return nil
end

function EnemyEntityFactory:GetPathState(entity: number)
	self:RequireReady()
	return self:_Get(entity, self._components.PathStateComponent)
end

function EnemyEntityFactory:SetTarget(entity: number, targetEntity: number?, targetKind: "Structure" | "Enemy" | "Base")
	self:RequireReady()
	self:_Set(entity, self._components.TargetComponent, {
		TargetEntity = targetEntity,
		TargetKind = targetKind,
	})
end

function EnemyEntityFactory:ClearTarget(entity: number)
	self:RequireReady()
	self:_Set(entity, self._components.TargetComponent, {
		TargetEntity = nil,
		TargetKind = "Structure",
	})
end

function EnemyEntityFactory:GetTarget(entity: number)
	self:RequireReady()
	return self:_Get(entity, self._components.TargetComponent)
end

function EnemyEntityFactory:SetLockOn(
	entity: number,
	lockOn: {
		Attachment0: Attachment?,
		Attachment1: Attachment?,
		Constraint: AlignOrientation?,
	}
)
	self:RequireReady()
	self:_Set(entity, self._components.LockOnComponent, {
		Attachment0 = lockOn.Attachment0,
		Attachment1 = lockOn.Attachment1,
		Constraint = lockOn.Constraint,
	})
end

function EnemyEntityFactory:GetLockOn(entity: number)
	self:RequireReady()
	return self:_Get(entity, self._components.LockOnComponent)
end

function EnemyEntityFactory:ClearLockOn(entity: number)
	self:RequireReady()
	self:_Set(entity, self._components.LockOnComponent, {
		Attachment0 = nil,
		Attachment1 = nil,
		Constraint = nil,
	})
end

function EnemyEntityFactory:GetPosition(entity: number)
	return self:GetTransform(entity)
end

function EnemyEntityFactory:GetNearestAliveEnemy(position: Vector3, maxRange: number): { entity: number, CFrame: CFrame }?
	self:RequireReady()

	local nearestEntity = SpatialQuery.FindBestCandidate(
		position,
		self:QueryAliveEntities(),
		function(entity: number): Vector3?
			local entityCFrame = self:GetEntityCFrame(entity)
			if entityCFrame == nil then
				return nil
			end

			return entityCFrame.Position
		end,
		function(_entity: number, distance: number): number?
			return -distance
		end,
		maxRange
	)

	if nearestEntity == nil then
		return nil
	end

	local nearestCFrame = self:GetEntityCFrame(nearestEntity)
	if nearestCFrame == nil then
		return nil
	end

	return {
		entity = nearestEntity,
		CFrame = nearestCFrame,
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
