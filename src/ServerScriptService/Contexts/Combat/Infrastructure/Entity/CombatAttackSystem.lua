--!strict

local CombatAttackSystem = {}
CombatAttackSystem.__index = CombatAttackSystem

local PHASE_STARTUP = "Startup"
local PHASE_ACTIVE = "Active"
local PHASE_COMPLETED = "Completed"
local PHASE_FAILED = "Failed"
local MECHANIC_DIRECT_DAMAGE = "DirectDamage"
local MECHANIC_HITBOX = "Hitbox"
local MECHANIC_PROJECTILE = "Projectile"

function CombatAttackSystem.new(entityFactory: any, abilityRegistry: any)
	local self = setmetatable({}, CombatAttackSystem)
	self._entityFactory = entityFactory
	self._abilityRegistry = abilityRegistry
	return self
end

function CombatAttackSystem:Run()
	-- READS: Combat.AttackState [AUTHORITATIVE]
	-- WRITES: Combat.AttackState [AUTHORITATIVE], Combat.DamageRequest [AUTHORITATIVE], Combat.HitboxRequest [AUTHORITATIVE], Combat.ProjectileRequest [AUTHORITATIVE], Combat.RequestTag
	local queryResult = self._entityFactory:Query({
		FeatureName = "Combat",
		Keys = { "AttackState" },
	})
	if not queryResult.success then
		return
	end

	local now = os.clock()
	for _, entity in ipairs(queryResult.value) do
		self:_RunEntity(entity, now)
	end
end

function CombatAttackSystem:_RunEntity(entity: number, now: number)
	local attackState = self:_Get(entity, "AttackState", "Combat")
	if type(attackState) ~= "table" then
		return
	end
	if attackState.Phase == PHASE_COMPLETED or attackState.Phase == PHASE_FAILED then
		return
	end

	local targetEntity = attackState.TargetEntity
	local ability = self:_ResolveAbility(attackState)
	if ability == nil then
		self:_SetAttackState(entity, attackState, {
			Phase = PHASE_FAILED,
			UpdatedAt = now,
			ErrorCode = "UnknownCombatAbility",
		})
		return
	end

	local damage = self:_ResolveNumber(attackState.Damage, ability.Damage, 0)
	if type(targetEntity) ~= "number" or not self._entityFactory:Exists(targetEntity) then
		self:_SetAttackState(entity, attackState, {
			Phase = PHASE_FAILED,
			UpdatedAt = now,
			ErrorCode = "MissingAttackTarget",
		})
		return
	end
	if type(damage) ~= "number" or damage <= 0 then
		self:_SetAttackState(entity, attackState, {
			Phase = PHASE_FAILED,
			UpdatedAt = now,
			ErrorCode = "InvalidAttackDamage",
		})
		return
	end

	local phase = if attackState.Phase == PHASE_STARTUP then PHASE_ACTIVE else attackState.Phase
	if attackState.HasEmittedRequest ~= true then
		self:_CreateMechanicRequest(entity, attackState, ability, targetEntity, damage, now)
	end

	self:_SetAttackState(entity, attackState, {
		Phase = if phase == PHASE_ACTIVE then PHASE_COMPLETED else phase,
		UpdatedAt = now,
		HasEmittedRequest = true,
		Mechanic = ability.Mechanic,
		Cooldown = self:_ResolveNumber(attackState.Cooldown, ability.Cooldown, 0),
	})
end

function CombatAttackSystem:_ResolveAbility(attackState: any): any?
	local abilityId = attackState.AbilityId
	if type(abilityId) ~= "string" or abilityId == "" then
		return nil
	end

	return self._abilityRegistry:GetAbility(abilityId)
end

function CombatAttackSystem:_CreateMechanicRequest(
	entity: number,
	attackState: any,
	ability: any,
	targetEntity: number,
	damage: number,
	now: number
)
	if ability.Mechanic == MECHANIC_PROJECTILE then
		self:_CreateProjectileRequest(entity, attackState, ability, targetEntity, damage, now)
	elseif ability.Mechanic == MECHANIC_HITBOX then
		self:_CreateHitboxRequest(entity, attackState, ability, targetEntity, damage, now)
	elseif ability.Mechanic == MECHANIC_DIRECT_DAMAGE then
		self:_CreateDamageRequest(entity, attackState, targetEntity, damage, now)
	end
end

function CombatAttackSystem:_CreateDamageRequest(
	entity: number,
	attackState: any,
	targetEntity: number,
	damage: number,
	now: number
)
	self._entityFactory:CreateFromArchetype("Combat.DamageRequest", {
		DamageRequest = {
			ActionId = attackState.ActionId,
			AbilityId = attackState.AbilityId,
			AttackerEntity = entity,
			VictimEntity = targetEntity,
			Amount = damage,
			CreatedAt = now,
			Reason = "AttackState",
		},
	})
end

function CombatAttackSystem:_CreateHitboxRequest(
	entity: number,
	attackState: any,
	ability: any,
	targetEntity: number,
	damage: number,
	now: number
)
	self._entityFactory:CreateFromArchetype("Combat.HitboxRequest", {
		HitboxRequest = {
			ActionId = attackState.ActionId,
			AbilityId = attackState.AbilityId,
			SourceEntity = entity,
			TargetEntity = targetEntity,
			Damage = damage,
			Range = self:_ResolveNumber(attackState.Range, ability.Range, 0),
			CreatedAt = now,
			ExpiresAt = nil,
		},
	})
end

function CombatAttackSystem:_CreateProjectileRequest(
	entity: number,
	attackState: any,
	ability: any,
	targetEntity: number,
	damage: number,
	now: number
)
	self._entityFactory:CreateFromArchetype("Combat.ProjectileRequest", {
		ProjectileRequest = {
			ActionId = attackState.ActionId,
			AbilityId = attackState.AbilityId,
			ProjectileId = if type(ability.ProjectileId) == "string" then ability.ProjectileId else "",
			SourceEntity = entity,
			TargetEntity = targetEntity,
			Damage = damage,
			Range = self:_ResolveNumber(attackState.Range, ability.Range, 0),
			CreatedAt = now,
			ExpiresAt = nil,
		},
	})
end

function CombatAttackSystem:_ResolveNumber(primary: any, fallback: any, defaultValue: number): number
	if type(primary) == "number" and primary > 0 then
		return primary
	end
	if type(fallback) == "number" then
		return fallback
	end
	return defaultValue
end

function CombatAttackSystem:_SetAttackState(entity: number, current: any, patch: any)
	local nextState = table.clone(current)
	for key, value in pairs(patch) do
		nextState[key] = value
	end
	self._entityFactory:Set(entity, "AttackState", nextState, "Combat")
end

function CombatAttackSystem:_Get(entity: number, key: string, featureName: string): any
	local result = self._entityFactory:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

return CombatAttackSystem
