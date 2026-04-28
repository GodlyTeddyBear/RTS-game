--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)

local Ok = Result.Ok
local Ensure = Result.Ensure
local Try = Result.Try

type THitboxHandle = string
type TEntityKind = "Enemy" | "Structure" | "Base"

type THitEntity = {
	Kind: TEntityKind,
	Entity: number,
}

type TResolveEnemyMeleeHitsSummary = {
	AppliedHits: number,
	HitBase: boolean,
	HitStructures: { number },
}

--[=[
	@class CombatHitResolutionService
	Owns melee hit deduplication and damage routing for combat attack hitboxes.
	@server
]=]
local CombatHitResolutionService = {}
CombatHitResolutionService.__index = CombatHitResolutionService

--[=[
	@within CombatHitResolutionService
	Creates a new resolution service with empty per-hitbox deduplication state.
	@return CombatHitResolutionService -- Service instance used to resolve melee hitboxes.
]=]
function CombatHitResolutionService.new()
	local self = setmetatable({}, CombatHitResolutionService)
	self._resolvedHitKeysByHandle = {} :: { [THitboxHandle]: { [string]: boolean } }
	return self
end

--[=[
	@within CombatHitResolutionService
	Resolves the hitbox service dependency used to read captured hit entities.
	@param registry any -- Registry instance supplied by the context bootstrap.
	@param _name string -- Registry key used to register the service.
]=]
function CombatHitResolutionService:Init(registry: any, _name: string)
	self._hitboxService = registry:Get("HitboxService")
end

--[=[
	@within CombatHitResolutionService
	Resolves the base and structure contexts used to apply combat damage.
	@param registry any -- Registry instance used to resolve dependencies.
	@param _name string -- Registry key used to register the service.
]=]
function CombatHitResolutionService:Start(registry: any, _name: string)
	self._baseContext = registry:Get("BaseContext")
	self._baseEntityFactory = registry:Get("BaseEntityFactory")
	self._structureContext = registry:Get("StructureContext")
	self._structureEntityFactory = registry:Get("StructureEntityFactory")
end

-- Builds a stable deduplication key for one hit target inside a single hitbox handle.
local function _buildResolvedHitKey(kind: TEntityKind, entity: number): string
	return string.format("%s:%d", kind, entity)
end

-- Filters out targets that should not receive melee damage from the attacker.
function CombatHitResolutionService:_IsValidEnemyMeleeTarget(attackerEntity: number, hitEntity: THitEntity): boolean
	if hitEntity.Kind == "Base" then
		return self._baseEntityFactory:IsActive()
	end

	if hitEntity.Kind == "Structure" then
		return self._structureEntityFactory:IsActive(hitEntity.Entity)
	end

	if hitEntity.Kind == "Enemy" then
		return hitEntity.Entity ~= attackerEntity and false
	end

	return false
end

--[=[
	@within CombatHitResolutionService
	Resolves captured hit entities, applies damage once per target, and returns a summary for callers.
	@param handle string -- Hitbox handle to resolve.
	@param attackerEntity number -- Entity id that owns the hitbox.
	@param damage number -- Damage amount to apply per valid target.
	@return Result.Result<TResolveEnemyMeleeHitsSummary> -- Summary payload or a typed combat error.
]=]
function CombatHitResolutionService:ResolveEnemyMeleeHits(
	handle: THitboxHandle,
	attackerEntity: number,
	damage: number
): Result.Result<TResolveEnemyMeleeHitsSummary>
	return Result.Catch(function()
		-- Validate the inbound attack payload before reading any hitbox state.
		Ensure(type(handle) == "string" and handle ~= "", "InvalidHitboxHandle", "Combat hitbox handle must be a non-empty string")
		Ensure(type(attackerEntity) == "number", "InvalidAttackerEntity", "Combat attacker entity must be a number")
		Ensure(type(damage) == "number" and damage > 0, "InvalidDamageAmount", "Combat damage must be a positive number", {
			AttackerEntity = attackerEntity,
			Handle = handle,
			Amount = damage,
		})

		-- Reuse the per-handle dedupe table so repeated callbacks do not double-apply damage.
		local resolvedHitKeys = self._resolvedHitKeysByHandle[handle]
		if resolvedHitKeys == nil then
			resolvedHitKeys = {}
			self._resolvedHitKeysByHandle[handle] = resolvedHitKeys
		end

		-- Read the captured hit entities once, then filter and resolve them against combat ownership rules.
		local hitEntities = self._hitboxService:GetHitEntities(handle)
		local summary: TResolveEnemyMeleeHitsSummary = {
			AppliedHits = 0,
			HitBase = false,
			HitStructures = {},
		}

		for _, hitEntity in ipairs(hitEntities) do
			local resolvedKey = _buildResolvedHitKey(hitEntity.Kind, hitEntity.Entity)
			if resolvedHitKeys[resolvedKey] == true then
				continue
			end

			if not self:_IsValidEnemyMeleeTarget(attackerEntity, hitEntity) then
				continue
			end

			if hitEntity.Kind == "Base" then
				-- Route base hits through the base context so the shared damage pipeline stays authoritative.
				Try(self._baseContext:ApplyDamage(damage))
				summary.HitBase = true
			elseif hitEntity.Kind == "Structure" then
				-- Route structure hits through the structure context so structure HP stays synchronized.
				Try(self._structureContext:ApplyDamage(hitEntity.Entity, damage))
				table.insert(summary.HitStructures, hitEntity.Entity)
			else
				continue
			end

			resolvedHitKeys[resolvedKey] = true
			summary.AppliedHits += 1
		end

		return Ok(summary)
	end, "Combat:ResolveEnemyMeleeHits")
end

--[=[
	@within CombatHitResolutionService
	Clears deduplication state for one hitbox handle after teardown.
	@param handle string -- Hitbox handle to clear.
]=]
function CombatHitResolutionService:ClearResolvedHits(handle: THitboxHandle)
	if type(handle) ~= "string" or handle == "" then
		return
	end

	self._resolvedHitKeysByHandle[handle] = nil
end

--[=[
	@within CombatHitResolutionService
	Clears all deduplication state for combat shutdown.
]=]
function CombatHitResolutionService:CleanupAll()
	table.clear(self._resolvedHitKeysByHandle)
end

return CombatHitResolutionService
