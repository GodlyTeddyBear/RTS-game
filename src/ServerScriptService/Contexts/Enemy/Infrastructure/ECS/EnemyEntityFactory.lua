--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local EnemyConfig = require(ReplicatedStorage.Contexts.Enemy.Config.EnemyConfig)
local CombatECSEntityFactory = require(ServerStorage.Utilities.ECSUtilities.CombatECSEntityFactory)
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
	self:RegisterUniqueLookupIndex("EnemyId")
end

function EnemyEntityFactory:CreateEnemy(enemyId: string, role: string, spawnCFrame: CFrame, waveNumber: number): number
	self:RequireReady()

	local roleConfig = EnemyConfig.Roles[role]
	assert(roleConfig ~= nil, "Unknown enemy role: " .. tostring(role))
	local components = self:GetComponentsOrThrow()
	local entity = self:_CreateEntity()

	self:_Set(entity, components.HealthComponent, {
		Current = roleConfig.MaxHp,
		Max = roleConfig.MaxHp,
	})
	self:SetTransformCFrame(entity, spawnCFrame)
	self:_Set(entity, components.RoleComponent, {
		Role = role,
		MoveSpeed = roleConfig.MoveSpeed,
		Damage = roleConfig.Damage,
		AttackRange = roleConfig.AttackRange,
		AttackCooldown = roleConfig.AttackCooldown,
		TargetPreference = roleConfig.TargetPreference,
	})
	self:_Set(entity, components.BaseMoveSpeedComponent, {
		Value = roleConfig.MoveSpeed,
	})
	self:_Set(entity, components.CurrentMoveSpeedComponent, {
		Value = roleConfig.MoveSpeed,
	})
	self:_Set(entity, components.PathStateComponent, {
		GoalPosition = nil,
		IsMoving = false,
	})
	self:_Set(entity, components.IdentityComponent, {
		EnemyId = enemyId,
		Role = role,
		WaveNumber = waveNumber,
	})
	self:SetUniqueLookup("EnemyId", enemyId, entity)
	self:_Set(entity, components.CombatActionComponent, self:BuildDefaultCombatAction())
	self:_Set(entity, components.AttackCooldownComponent, {
		Cooldown = roleConfig.AttackCooldown,
		LastAttackTime = 0,
	})
	self:_Set(entity, components.BehaviorConfigComponent, {
		TickInterval = 0.15,
	})
	self:_Set(entity, components.AnimationStateComponent, "Idle")
	self:_Set(entity, components.AnimationLoopingComponent, true)
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
		GoalPosition = goalPosition,
		IsMoving = false,
	})
	self:_Add(entity, self._components.DirtyTag)
end

function EnemyEntityFactory:ClearGoalPosition(entity: number)
	self:RequireReady()
	local state = self:GetPathState(entity)
	if state == nil then
		return
	end

	self:_Set(entity, self._components.PathStateComponent, {
		GoalPosition = nil,
		IsMoving = false,
	})
	self:_Add(entity, self._components.DirtyTag)
end

function EnemyEntityFactory:SetPathMoving(entity: number, isMoving: boolean)
	self:RequireReady()
	local state = self:GetPathState(entity)
	if state == nil then
		return
	end
	if state.IsMoving == isMoving then
		return
	end

	self:_Set(entity, self._components.PathStateComponent, {
		GoalPosition = state.GoalPosition,
		IsMoving = isMoving,
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

	local nextHp = math.max(0, health.Current - amount)
	self:_Set(entity, self._components.HealthComponent, {
		Current = nextHp,
		Max = health.Max,
	})
	self:_Add(entity, self._components.DirtyTag)

	return nextHp <= 0
end

function EnemyEntityFactory:MarkDirty(entity: number)
	self:RequireReady()
	self:_Add(entity, self._components.DirtyTag)
end

function EnemyEntityFactory:IsDirty(entity: number): boolean
	self:RequireReady()
	return self:_Has(entity, self._components.DirtyTag)
end

function EnemyEntityFactory:UpdatePosition(entity: number, cframe: CFrame)
	self:SetTransformCFrame(entity, cframe)
	self:_Add(entity, self._components.DirtyTag)
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

function EnemyEntityFactory:GetBaseMoveSpeed(entity: number): number?
	self:RequireReady()
	local moveSpeed = self:_Get(entity, self._components.BaseMoveSpeedComponent)
	return if moveSpeed ~= nil then moveSpeed.Value else nil
end

function EnemyEntityFactory:GetCurrentMoveSpeed(entity: number): number?
	self:RequireReady()
	local moveSpeed = self:_Get(entity, self._components.CurrentMoveSpeedComponent)
	return if moveSpeed ~= nil then moveSpeed.Value else nil
end

function EnemyEntityFactory:SetCurrentMoveSpeed(entity: number, speed: number)
	self:RequireReady()
	if type(speed) ~= "number" then
		return
	end

	local currentMoveSpeed = self:_Get(entity, self._components.CurrentMoveSpeedComponent)
	if currentMoveSpeed ~= nil and currentMoveSpeed.Value == speed then
		return
	end

	self:_Set(entity, self._components.CurrentMoveSpeedComponent, {
		Value = speed,
	})
	self:_Add(entity, self._components.DirtyTag)
end

function EnemyEntityFactory:GetIdentity(entity: number)
	self:RequireReady()
	return self:_Get(entity, self._components.IdentityComponent)
end

function EnemyEntityFactory:GetAnimationState(entity: number): string?
	self:RequireReady()
	local animationState = self:_Get(entity, self._components.AnimationStateComponent)
	return if type(animationState) == "string" then animationState else nil
end

function EnemyEntityFactory:IsAnimationLooping(entity: number): boolean?
	self:RequireReady()
	local isLooping = self:_Get(entity, self._components.AnimationLoopingComponent)
	return if type(isLooping) == "boolean" then isLooping else nil
end

function EnemyEntityFactory:SetAnimationPresentation(entity: number, animationState: string, isLooping: boolean)
	self:RequireReady()

	local currentAnimationState = self:GetAnimationState(entity)
	local currentLooping = self:IsAnimationLooping(entity)
	if currentAnimationState == animationState and currentLooping == isLooping then
		return
	end

	self:_Set(entity, self._components.AnimationStateComponent, animationState)
	self:_Set(entity, self._components.AnimationLoopingComponent, isLooping)
	self:_Add(entity, self._components.DirtyTag)
end

function EnemyEntityFactory:GetEntityByEnemyId(enemyId: string): number?
	self:RequireReady()
	return self:FindEntityByUniqueLookup("EnemyId", enemyId)
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

function EnemyEntityFactory:GetNearestAliveEnemy(position: Vector3, maxRange: number): { Entity: number, CFrame: CFrame }?
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
		Entity = nearestEntity,
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
	self:ClearUniqueLookup("EnemyId", entity)
	self:MarkForDestruction(entity)
	self:FlushDestructionQueue()
end

return EnemyEntityFactory
