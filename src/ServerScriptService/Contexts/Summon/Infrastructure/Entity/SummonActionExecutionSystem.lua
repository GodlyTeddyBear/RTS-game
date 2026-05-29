--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local AISharedContract = require(ReplicatedStorage.Contexts.AI.AISharedContract)
local Orient = require(ReplicatedStorage.Utilities.Orient)
local ServerScheduler = require(ServerScriptService.Scheduler.ServerScheduler)
local SpatialQuery = require(ReplicatedStorage.Utilities.SpatialQuery)

local SummonActionExecutionSystem = {}
SummonActionExecutionSystem.__index = SummonActionExecutionSystem

local ACTION_ENGAGE_ENEMY = "EngageEnemy"
local RUNNING_STATUSES = {
	[AISharedContract.ActionStatus.Requested] = true,
	[AISharedContract.ActionStatus.Running] = true,
}

function SummonActionExecutionSystem.new(entityFactory: any, dependencies: any)
	local self = setmetatable({}, SummonActionExecutionSystem)
	self._entityFactory = entityFactory
	self._entityContext = dependencies.EntityContext
	self._enemyContext = dependencies.EnemyContext
	self._summonReadService = dependencies.SummonReadService
	return self
end

function SummonActionExecutionSystem:Run()
	-- READS: Summon.CombatProfile, Summon.AttackCooldown, Entity.Transform, Entity.Lifetime, AI.ActionIntent, AI.ActionState
	-- WRITES: Entity.Transform, Entity.DirtyTag, Summon.AttackCooldown, Summon.TargetEnemyId
	local queryResult = self._entityFactory:Query({
		FeatureName = "Summon",
		Keys = {
			{ Key = "ActiveTag", FeatureName = "Entity" },
			{ Key = "DroneTag", FeatureName = "Summon" },
		},
	})
	if not queryResult.success then
		return
	end

	local now = os.clock()
	local deltaTime = ServerScheduler:GetDeltaTime()
	for _, entity in ipairs(queryResult.value) do
		self:_RunDrone(entity, now, deltaTime)
	end
end

function SummonActionExecutionSystem:_RunDrone(entity: number, now: number, deltaTime: number)
	local lifetime = self._summonReadService:GetLifetime(entity)
	if type(lifetime) ~= "table" or type(lifetime.ExpiresAt) ~= "number" or now >= lifetime.ExpiresAt then
		self._entityContext:DestroyEntity(entity)
		return
	end

	local actionState = self:_Get(entity, AISharedContract.Components.ActionState, AISharedContract.FeatureName)
	local actionIntent = self:_Get(entity, AISharedContract.Components.ActionIntent, AISharedContract.FeatureName)
	if
		type(actionState) ~= "table"
		or RUNNING_STATUSES[actionState.Status] ~= true
		or type(actionIntent) ~= "table"
		or actionIntent.ActionId ~= ACTION_ENGAGE_ENEMY
	then
		self:_SetTargetEnemyId(entity, nil)
		return
	end

	self:_EngageEnemy(entity, actionIntent, now, deltaTime)
end

function SummonActionExecutionSystem:_EngageEnemy(entity: number, actionIntent: any, now: number, deltaTime: number)
	local combatProfile = self._summonReadService:GetCombatProfile(entity)
	local currentCFrame = self._summonReadService:GetCFrame(entity)
	local targetEntity = actionIntent.TargetEntity
	local targetPosition = if type(actionIntent.Data) == "table" then actionIntent.Data.TargetPosition else nil
	if
		type(combatProfile) ~= "table"
		or currentCFrame == nil
		or type(targetEntity) ~= "number"
		or typeof(targetPosition) ~= "Vector3"
	then
		self:_SetTargetEnemyId(entity, nil)
		return
	end

	local nextPosition = currentCFrame.Position
	if not SpatialQuery.IsWithinRange(nextPosition, targetPosition, combatProfile.AttackRange or 0) then
		nextPosition = Orient.MoveTowards(nextPosition, targetPosition, (combatProfile.MoveSpeed or 0) * deltaTime)
	end

	local nextCFrame = Orient.BuildLookAt(nextPosition, targetPosition) or Orient.BuildAtPosition(currentCFrame, nextPosition)
	self:_SetTransform(entity, nextCFrame)
	self:_SetTargetEnemyId(entity, self:_ResolveEnemyId(targetEntity))

	if SpatialQuery.IsWithinRange(nextPosition, targetPosition, combatProfile.AttackRange or 0) then
		self:_TryAttack(entity, targetEntity, combatProfile, now)
	end
end

function SummonActionExecutionSystem:_TryAttack(entity: number, targetEntity: number, combatProfile: any, now: number)
	local cooldown = self._summonReadService:GetAttackCooldown(entity) or {}
	local lastAttackAt = if type(cooldown.LastAttackAt) == "number" then cooldown.LastAttackAt else 0
	local attackInterval = if type(combatProfile.AttackInterval) == "number" then combatProfile.AttackInterval else math.huge
	if (now - lastAttackAt) < attackInterval then
		return
	end

	local damage = combatProfile.DamagePerHit
	if type(damage) ~= "number" or damage <= 0 then
		return
	end

	local damageResult = self._enemyContext:ApplyDamage(targetEntity, damage)
	if damageResult.success then
		self._entityFactory:Set(entity, "AttackCooldown", {
			LastAttackAt = now,
		}, "Summon")
		self:_MarkDirty(entity)
	end
end

function SummonActionExecutionSystem:_ResolveEnemyId(enemyEntity: number): string?
	local identityResult = self._entityContext:Get(enemyEntity, "Identity", "Entity")
	local identity = if identityResult.success then identityResult.value else nil
	return if type(identity) == "table" and type(identity.EntityId) == "string" then identity.EntityId else nil
end

function SummonActionExecutionSystem:_SetTransform(entity: number, cframe: CFrame)
	self._entityFactory:Set(entity, "Transform", {
		CFrame = cframe,
	}, "Entity")
	self:_MarkDirty(entity)
end

function SummonActionExecutionSystem:_SetTargetEnemyId(entity: number, enemyId: string?)
	self._entityFactory:Set(entity, "TargetEnemyId", enemyId, "Summon")
	self:_MarkDirty(entity)
end

function SummonActionExecutionSystem:_Get(entity: number, key: string, featureName: string): any
	local result = self._entityFactory:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

function SummonActionExecutionSystem:_MarkDirty(entity: number)
	self._entityFactory:Add(entity, "DirtyTag", "Entity")
end

return SummonActionExecutionSystem
