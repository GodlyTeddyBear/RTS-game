--!strict

local StructureAttackPresentationSystem = {}
StructureAttackPresentationSystem.__index = StructureAttackPresentationSystem

function StructureAttackPresentationSystem.new(entityFactory: any, dependencies: any)
	local self = setmetatable({}, StructureAttackPresentationSystem)
	self._entityFactory = entityFactory
	self._entityContext = dependencies.EntityContext
	return self
end

function StructureAttackPresentationSystem:Run()
	-- READS: Combat.AttackState [AUTHORITATIVE], Structure.OperationalTag, Entity.Identity [AUTHORITATIVE]
	-- WRITES: Entity.Target [AUTHORITATIVE], Structure.AnimationState [DERIVED], Structure.AnimationLooping [DERIVED], Structure.TargetEnemyId [DERIVED], Entity.DirtyTag
	local queryResult = self._entityFactory:Query({
		Keys = {
			{ Key = "OperationalTag", FeatureName = "Structure" },
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

		local targetEntity = if type(attackState.TargetEntity) == "number" then attackState.TargetEntity else nil
		self._entityFactory:Set(entity, "Target", {
			TargetEntity = targetEntity,
			TargetKind = if targetEntity ~= nil then "Enemy" else nil,
		}, "Entity")
		self._entityFactory:Set(entity, "AnimationState", "Attack", "Structure")
		self._entityFactory:Set(entity, "AnimationLooping", false, "Structure")
		self._entityFactory:Set(entity, "TargetEnemyId", self:_ResolveTargetEntityId(targetEntity), "Structure")
		self._entityFactory:Add(entity, "DirtyTag", "Entity")
	end
end

function StructureAttackPresentationSystem:_ResolveTargetEntityId(targetEntity: number?): string?
	if type(targetEntity) ~= "number" then
		return nil
	end

	local identityResult = self._entityContext:Get(targetEntity, "Identity", "Entity")
	local identity = if identityResult.success then identityResult.value else nil
	return if type(identity) == "table" and type(identity.EntityId) == "string" then identity.EntityId else nil
end

function StructureAttackPresentationSystem:_Get(entity: number, key: string, featureName: string): any
	local result = self._entityFactory:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

return StructureAttackPresentationSystem
