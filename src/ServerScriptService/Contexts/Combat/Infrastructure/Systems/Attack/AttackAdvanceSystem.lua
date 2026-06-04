--!strict

local AttackAdvanceSystem = {}
AttackAdvanceSystem.__index = AttackAdvanceSystem

function AttackAdvanceSystem.new(entityFactory: any, dependencies: any)
	local self = setmetatable({}, AttackAdvanceSystem)
	self._entityFactory = entityFactory
	self._abilityRegistry = dependencies.AbilityRegistry
	self._requestFactory = dependencies.RequestFactory
	return self
end

function AttackAdvanceSystem:Run()
	local result = self._entityFactory:Query({ FeatureName = "Combat", Keys = { "AttackState" } })
	if not result.success then
		return
	end
	local now = os.clock()
	for _, entity in ipairs(result.value) do
		self:_Advance(entity, now)
	end
end

function AttackAdvanceSystem:_Advance(entity: number, now: number)
	local state = self:_Get(entity, "AttackState", "Combat")
	if type(state) ~= "table" or state.Phase == "Completed" or state.Phase == "Failed" then
		return
	end
	local ability = self._abilityRegistry:GetAbility(state.AbilityId)
	if ability == nil then
		self:_Patch(entity, state, { Phase = "Failed", ErrorCode = "UnknownCombatAbility", UpdatedAt = now })
		return
	end
	local damage = self:_Number(state.Damage, ability.Damage, 0)
	if damage <= 0 then
		self:_Patch(entity, state, { Phase = "Failed", ErrorCode = "InvalidAttackDamage", UpdatedAt = now })
		return
	end

	local elapsed = now - (state.StartedAt or now)
	local startup = self:_Number(nil, ability.Startup, 0)
	local active = self:_Number(nil, ability.Active, 0)
	local recovery = self:_Number(nil, ability.Recovery, 0)
	local patch = { Elapsed = elapsed, UpdatedAt = now }
	if elapsed < startup then
		patch.Phase = "Startup"
	elseif state.HasEmittedRequest ~= true then
		patch.Phase = "Active"
		patch.HasEmittedRequest = true
		self:_EmitMechanicRequest(entity, state, ability, damage, now)
	elseif elapsed < startup + active + recovery then
		patch.Phase = "Recovery"
	else
		patch.Phase = "Completed"
	end
	self:_Patch(entity, state, patch)
end

function AttackAdvanceSystem:_EmitMechanicRequest(entity: number, state: any, ability: any, damage: number, now: number)
	local common = {
		ActionId = state.ActionId,
		AbilityId = state.AbilityId,
		SourceEntity = entity,
		TargetEntity = state.TargetEntity,
		Damage = damage,
		Range = self:_Number(state.Range, ability.Range, 0),
		CreatedAt = now,
		ExpiresAt = now + 1,
	}
	if ability.Mechanic == "Projectile" then
		common.ProjectileId = ability.ProjectileId
		self._requestFactory:Create(self._entityFactory, "Combat.ProjectileSpawnRequest", "ProjectileSpawnRequest", common)
	elseif ability.Mechanic == "Hitbox" then
		common.Hitbox = ability.Hitbox
		self._requestFactory:Create(self._entityFactory, "Combat.HitboxSpawnRequest", "HitboxSpawnRequest", common)
	elseif ability.Mechanic == "DirectDamage" then
		if type(state.TargetEntity) ~= "number" then
			local errorCode = if state.TargetKind == "Base" then "MissingActiveBase" else "MissingAttackTarget"
			self:_Patch(entity, state, { Phase = "Failed", ErrorCode = errorCode, UpdatedAt = now })
			return
		end
		self._requestFactory:Create(self._entityFactory, "Combat.HealthChangeRequest", "HealthChangeRequest", {
			ActionId = state.ActionId,
			AbilityId = state.AbilityId,
			SourceEntity = entity,
			TargetEntity = state.TargetEntity,
			TargetKind = state.TargetKind,
			Amount = damage,
			ChangeType = "Damage",
			CreatedAt = now,
			ExpiresAt = now + 1,
			Reason = "AttackState",
		})
	else
		self:_Patch(entity, state, { Phase = "Failed", ErrorCode = "UnsupportedCombatMechanic", UpdatedAt = now })
	end
end

function AttackAdvanceSystem:_Number(primary: any, fallback: any, defaultValue: number): number
	if type(primary) == "number" then return primary end
	if type(fallback) == "number" then return fallback end
	return defaultValue
end

function AttackAdvanceSystem:_Patch(entity: number, current: any, patch: any)
	local nextState = table.clone(current)
	for key, value in pairs(patch) do nextState[key] = value end
	self._entityFactory:Set(entity, "AttackState", nextState, "Combat")
end

function AttackAdvanceSystem:_Get(entity: number, key: string, featureName: string): any
	local result = self._entityFactory:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

return AttackAdvanceSystem
