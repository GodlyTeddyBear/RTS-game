--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AISharedContract = require(ReplicatedStorage.Contexts.AI.AISharedContract)

local CombatStatusAuraSystem = {}
CombatStatusAuraSystem.__index = CombatStatusAuraSystem

local ACTION_STASIS = "Stasis"

function CombatStatusAuraSystem.new(entityFactory: any, statusService: any)
	local self = setmetatable({}, CombatStatusAuraSystem)
	self._entityFactory = entityFactory
	self._statusService = statusService
	return self
end

function CombatStatusAuraSystem:Run()
	-- READS: Combat.StatusAuraState [AUTHORITATIVE], Structure.Stats [AUTHORITATIVE], Entity.Transform [AUTHORITATIVE], Entity.Identity [AUTHORITATIVE], AI.ActionState [AUTHORITATIVE]
	-- WRITES: Structure.AnimationState [DERIVED], Structure.AnimationLooping [DERIVED], Structure.TargetEnemyId [DERIVED], Entity.DirtyTag
	local queryResult = self._entityFactory:Query({
		FeatureName = "Combat",
		Keys = { "StatusAuraState" },
	})
	if not queryResult.success then
		return
	end

	for _, entity in ipairs(queryResult.value) do
		self:_RunEntity(entity)
	end
end

function CombatStatusAuraSystem:_RunEntity(entity: number)
	local auraState = self:_Get(entity, "StatusAuraState", "Combat")
	if type(auraState) ~= "table" then
		return
	end

	local actionState = self:_Get(entity, AISharedContract.Components.ActionState, AISharedContract.FeatureName)
	local handle = self:_BuildStructureHandle(entity)
	if type(actionState) ~= "table" or actionState.ActionId ~= ACTION_STASIS then
		if self._statusService ~= nil then
			self._statusService:RemoveAuraSource(handle)
		end
		if type(actionState) == "table" and actionState.ActionId == "Idle" then
			self._entityFactory:Set(entity, "AnimationState", "Idle", "Structure")
			self._entityFactory:Set(entity, "AnimationLooping", true, "Structure")
			self._entityFactory:Set(entity, "TargetEnemyId", nil, "Structure")
			self._entityFactory:Add(entity, "DirtyTag", "Entity")
		end
		return
	end

	local stats = self:_Get(entity, "Stats", "Structure")
	local transform = self:_Get(entity, "Transform", "Entity")
	if self._statusService == nil or type(stats) ~= "table" or type(transform) ~= "table" or typeof(transform.CFrame) ~= "CFrame" then
		return
	end

	self._statusService:UpsertAuraSource(handle, {
		SourceType = "StasisField",
		Position = transform.CFrame.Position,
		Radius = stats.StasisRadius or 0,
		MoveSpeedMultiplier = stats.MoveSpeedMultiplier or 1,
		IsActive = true,
	})
	self._entityFactory:Set(entity, "AnimationState", "Stasis", "Structure")
	self._entityFactory:Set(entity, "AnimationLooping", true, "Structure")
	self._entityFactory:Set(entity, "TargetEnemyId", nil, "Structure")
	self._entityFactory:Add(entity, "DirtyTag", "Entity")
end

function CombatStatusAuraSystem:_BuildStructureHandle(entity: number): string
	local identity = self:_Get(entity, "Identity", "Entity")
	if type(identity) == "table" and type(identity.EntityId) == "string" then
		return "Structure:" .. identity.EntityId
	end
	return "Structure:" .. tostring(entity)
end

function CombatStatusAuraSystem:_Get(entity: number, key: string, featureName: string): any
	local result = self._entityFactory:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

return CombatStatusAuraSystem
