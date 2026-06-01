--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local AISharedContract = require(ReplicatedStorage.Contexts.AI.AISharedContract)
local Orient = require(ReplicatedStorage.Utilities.Orient)
local ServerScheduler = require(ServerScriptService.Scheduler.ServerScheduler)
local SpatialQuery = require(ReplicatedStorage.Utilities.SpatialQuery)

local SummonEngagementSystem = {}
SummonEngagementSystem.__index = SummonEngagementSystem

local ACTION_ENGAGE_ENEMY = "EngageEnemy"

function SummonEngagementSystem.new(entityFactory: any, entityContext: any)
	local self = setmetatable({}, SummonEngagementSystem)
	self._entityFactory = entityFactory
	self._entityContext = entityContext
	return self
end

function SummonEngagementSystem:Run()
	-- READS: Summon.EngageState [AUTHORITATIVE], Summon.CombatProfile [AUTHORITATIVE], Summon.AttackCooldown [AUTHORITATIVE], Entity.Transform [AUTHORITATIVE], AI.ActionState [AUTHORITATIVE]
	-- WRITES: Entity.Transform [AUTHORITATIVE], Entity.DirtyTag, Summon.AttackCooldown [AUTHORITATIVE], Summon.TargetEnemyId [DERIVED], Combat.DamageRequest [AUTHORITATIVE], Combat.RequestTag
	local queryResult = self._entityFactory:Query({
		FeatureName = "Summon",
		Keys = { "DroneTag", "EngageState", "CombatProfile", "AttackCooldown" },
	})
	if not queryResult.success then
		return
	end

	local now = os.clock()
	local deltaTime = ServerScheduler:GetDeltaTime()
	for _, entity in ipairs(queryResult.value) do
		self:_RunEntity(entity, now, deltaTime)
	end
end

function SummonEngagementSystem:_RunEntity(entity: number, now: number, deltaTime: number)
	local actionState = self:_Get(entity, AISharedContract.Components.ActionState, AISharedContract.FeatureName)
	if type(actionState) ~= "table" or actionState.ActionId ~= ACTION_ENGAGE_ENEMY then
		self:_SetTargetEnemyId(entity, nil)
		return
	end

	local engageState = self:_Get(entity, "EngageState", "Summon")
	local combatProfile = self:_Get(entity, "CombatProfile", "Summon")
	local transform = self:_Get(entity, "Transform", "Entity")
	local targetEntity = if type(engageState) == "table" then engageState.TargetEntity else nil
	local targetPosition = if type(engageState) == "table" then engageState.TargetPosition else nil
	if
		type(combatProfile) ~= "table"
		or type(transform) ~= "table"
		or typeof(transform.CFrame) ~= "CFrame"
		or type(targetEntity) ~= "number"
		or typeof(targetPosition) ~= "Vector3"
	then
		self:_SetTargetEnemyId(entity, nil)
		return
	end

	local nextPosition = transform.CFrame.Position
	if not SpatialQuery.IsWithinRange(nextPosition, targetPosition, combatProfile.AttackRange or 0) then
		nextPosition = Orient.MoveTowards(nextPosition, targetPosition, (combatProfile.MoveSpeed or 0) * deltaTime)
	end

	local nextCFrame = Orient.BuildLookAt(nextPosition, targetPosition) or Orient.BuildAtPosition(transform.CFrame, nextPosition)
	self._entityFactory:Set(entity, "Transform", {
		CFrame = nextCFrame,
	}, "Entity")
	self:_MarkDirty(entity)
	self:_SetTargetEnemyId(entity, self:_ResolveEnemyId(targetEntity))

	if SpatialQuery.IsWithinRange(nextPosition, targetPosition, combatProfile.AttackRange or 0) then
		self:_TryAttack(entity, targetEntity, combatProfile, now)
	end
end

function SummonEngagementSystem:_TryAttack(entity: number, targetEntity: number, combatProfile: any, now: number)
	local cooldown = self:_Get(entity, "AttackCooldown", "Summon") or {}
	local lastAttackAt = if type(cooldown.LastAttackAt) == "number" then cooldown.LastAttackAt else 0
	local attackInterval = if type(combatProfile.AttackInterval) == "number" then combatProfile.AttackInterval else math.huge
	if (now - lastAttackAt) < attackInterval then
		return
	end

	local damage = combatProfile.DamagePerHit
	if type(damage) ~= "number" or damage <= 0 then
		return
	end

	local createResult = self._entityFactory:CreateFromArchetype("Combat.DamageRequest", {
		DamageRequest = {
			ActionId = ACTION_ENGAGE_ENEMY,
			AbilityId = "SummonEngageEnemy",
			AttackerEntity = entity,
			VictimEntity = targetEntity,
			VictimKind = "Enemy",
			Amount = damage,
			CreatedAt = now,
			Reason = "SummonEngageState",
		},
	})
	if createResult.success then
		self._entityFactory:Set(entity, "AttackCooldown", {
			LastAttackAt = now,
		}, "Summon")
		self:_MarkDirty(entity)
	end
end

function SummonEngagementSystem:_ResolveEnemyId(enemyEntity: number): string?
	local identityResult = self._entityContext:Get(enemyEntity, "Identity", "Entity")
	local identity = if identityResult.success then identityResult.value else nil
	return if type(identity) == "table" and type(identity.EntityId) == "string" then identity.EntityId else nil
end

function SummonEngagementSystem:_SetTargetEnemyId(entity: number, enemyId: string?)
	self._entityFactory:Set(entity, "TargetEnemyId", enemyId, "Summon")
	self:_MarkDirty(entity)
end

function SummonEngagementSystem:_Get(entity: number, key: string, featureName: string): any
	local result = self._entityFactory:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

function SummonEngagementSystem:_MarkDirty(entity: number)
	self._entityFactory:Add(entity, "DirtyTag", "Entity")
end

return SummonEngagementSystem
