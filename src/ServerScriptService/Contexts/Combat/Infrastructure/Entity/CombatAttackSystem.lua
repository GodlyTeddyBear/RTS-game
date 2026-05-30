--!strict

local CombatAttackSystem = {}
CombatAttackSystem.__index = CombatAttackSystem

local PHASE_STARTUP = "Startup"
local PHASE_ACTIVE = "Active"
local PHASE_COMPLETED = "Completed"
local PHASE_FAILED = "Failed"

function CombatAttackSystem.new(entityFactory: any)
	local self = setmetatable({}, CombatAttackSystem)
	self._entityFactory = entityFactory
	return self
end

function CombatAttackSystem:Run()
	-- READS: Combat.AttackState [AUTHORITATIVE]
	-- WRITES: Combat.AttackState [AUTHORITATIVE], Combat.DamageRequest [AUTHORITATIVE], Combat.RequestTag
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
	local damage = attackState.Damage
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
		self:_CreateDamageRequest(entity, attackState, targetEntity, damage, now)
	end

	self:_SetAttackState(entity, attackState, {
		Phase = if phase == PHASE_ACTIVE then PHASE_COMPLETED else phase,
		UpdatedAt = now,
		HasEmittedRequest = true,
	})
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
			AttackerEntity = entity,
			VictimEntity = targetEntity,
			Amount = damage,
			CreatedAt = now,
			Reason = "AttackState",
		},
	})
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
