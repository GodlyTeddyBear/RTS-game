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

local CombatHitResolutionService = {}
CombatHitResolutionService.__index = CombatHitResolutionService

function CombatHitResolutionService.new()
	local self = setmetatable({}, CombatHitResolutionService)
	self._resolvedHitKeysByHandle = {} :: { [THitboxHandle]: { [string]: boolean } }
	return self
end

function CombatHitResolutionService:Init(registry: any, _name: string)
	self._hitboxService = registry:Get("HitboxService")
end

function CombatHitResolutionService:Start(registry: any, _name: string)
	self._baseContext = registry:Get("BaseContext")
	self._baseEntityFactory = registry:Get("BaseEntityFactory")
	self._structureContext = registry:Get("StructureContext")
	self._structureEntityFactory = registry:Get("StructureEntityFactory")
end

local function _buildResolvedHitKey(kind: TEntityKind, entity: number): string
	return string.format("%s:%d", kind, entity)
end

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

function CombatHitResolutionService:ResolveEnemyMeleeHits(
	handle: THitboxHandle,
	attackerEntity: number,
	damage: number
): Result.Result<TResolveEnemyMeleeHitsSummary>
	return Result.Catch(function()
		Ensure(type(handle) == "string" and handle ~= "", "InvalidHitboxHandle", "Combat hitbox handle must be a non-empty string")
		Ensure(type(attackerEntity) == "number", "InvalidAttackerEntity", "Combat attacker entity must be a number")
		Ensure(type(damage) == "number" and damage > 0, "InvalidDamageAmount", "Combat damage must be a positive number", {
			AttackerEntity = attackerEntity,
			Handle = handle,
			Amount = damage,
		})

		local resolvedHitKeys = self._resolvedHitKeysByHandle[handle]
		if resolvedHitKeys == nil then
			resolvedHitKeys = {}
			self._resolvedHitKeysByHandle[handle] = resolvedHitKeys
		end

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
				Try(self._baseContext:ApplyDamage(damage))
				summary.HitBase = true
			elseif hitEntity.Kind == "Structure" then
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

function CombatHitResolutionService:ClearResolvedHits(handle: THitboxHandle)
	if type(handle) ~= "string" or handle == "" then
		return
	end

	self._resolvedHitKeysByHandle[handle] = nil
end

function CombatHitResolutionService:CleanupAll()
	table.clear(self._resolvedHitKeysByHandle)
end

return CombatHitResolutionService
