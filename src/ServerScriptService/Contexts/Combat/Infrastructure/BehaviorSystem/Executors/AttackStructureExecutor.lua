--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseExecutor = require(ReplicatedStorage.Utilities.BaseExecutor)
local HitboxConfig = require(ReplicatedStorage.Contexts.Combat.Config.HitboxConfig)

local ACTIVATION_TIMEOUT_SECONDS = 0.35

type THitboxActivationResult = {
	success: boolean,
	reason: string,
	source: string,
}

--[=[
	@class AttackStructureExecutor
	Resolves enemy melee attacks against active structure entities.
	@server
]=]
local AttackStructureExecutor = {}
AttackStructureExecutor.__index = AttackStructureExecutor
setmetatable(AttackStructureExecutor, { __index = BaseExecutor })

function AttackStructureExecutor.new()
	local self = BaseExecutor.new({
		ActionId = "AttackStructure",
		IsCommitted = false,
	})
	return setmetatable(self, AttackStructureExecutor)
end

local function _activationResult(success: boolean, reason: string, source: string): THitboxActivationResult
	return {
		success = success,
		reason = reason,
		source = source,
	}
end

local function _getTargetStructure(entity: number, services: any): number?
	local action = services.EnemyEntityFactory:GetCombatAction(entity)
	local data = action and action.ActionData
	if type(data) ~= "table" or type(data.TargetStructureEntity) ~= "number" then
		return nil
	end

	return data.TargetStructureEntity
end

local function _isTargetInRange(entity: number, targetStructure: number, services: any): boolean
	local enemyPosition = services.EnemyEntityFactory:GetPosition(entity)
	local structurePosition = services.StructureEntityFactory:GetPosition(targetStructure)
	local role = services.EnemyEntityFactory:GetRole(entity)
	if enemyPosition == nil or structurePosition == nil or role == nil then
		return false
	end

	local attackRange = role.attackRange
	if type(attackRange) ~= "number" then
		return false
	end

	local offset = structurePosition - enemyPosition.cframe.Position
	return offset:Dot(offset) <= attackRange * attackRange
end

local function _validateTargetStructure(entity: number, targetStructure: number, services: any): (boolean, string?)
	if not services.StructureEntityFactory:IsActive(targetStructure) then
		return false, "InactiveTargetStructure"
	end

	if not _isTargetInRange(entity, targetStructure, services) then
		return false, "TargetOutOfRange"
	end

	return true, nil
end

function AttackStructureExecutor:CanStart(entity: number, data: any?, services: any): (boolean, string?)
	if type(data) ~= "table" or type(data.TargetStructureEntity) ~= "number" then
		return false, "MissingTargetStructure"
	end

	return _validateTargetStructure(entity, data.TargetStructureEntity, services)
end

function AttackStructureExecutor:OnStart(entity: number, data: any?, services: any)
	local targetStructure = type(data) == "table" and data.TargetStructureEntity or nil
	if type(targetStructure) ~= "number" then
		return
	end

	services.EnemyEntityFactory:SetTarget(entity, targetStructure, "Structure")
	self:SetEntityValue(entity, "HitboxActivated", false)
	self:SetEntityValue(entity, "HitboxActivationTimedOut", false)
	self:SetEntityValue(entity, "ActivationWindowStartedAt", nil)
	self:SetEntityValue(entity, "HitLanded", false)
	self:SetEntityValue(entity, "ActiveHitboxHandle", nil)
	self:SetEntityValue(entity, "HitboxStartedAt", nil)
end

function AttackStructureExecutor:CanContinue(entity: number, services: any): (boolean, string?)
	local targetStructure = _getTargetStructure(entity, services)
	if targetStructure == nil then
		return false, "MissingTargetStructure"
	end

	return self:RunGuards(entity, services, {
		{
			Reason = "InactiveTargetStructure",
			Check = function(_guardEntity: number, guardServices: any): boolean
				return guardServices.StructureEntityFactory:IsActive(targetStructure)
			end,
		},
		{
			Reason = "TargetOutOfRange",
			Check = function(guardEntity: number, guardServices: any): boolean
				return _isTargetInRange(guardEntity, targetStructure, guardServices)
			end,
		},
	})
end

local function _activateHitboxInternal(
	self: any,
	entity: number,
	services: any,
	source: string
): THitboxActivationResult
	local cooldown = services.EnemyEntityFactory:GetAttackCooldown(entity)
	if cooldown == nil then
		return _activationResult(false, "MissingAttackState", source)
	end
	if services.CurrentTime - cooldown.LastAttackTime < cooldown.Cooldown then
		return _activationResult(false, "CooldownNotReady", source)
	end

	local activated = self:GetEntityValue(entity, "HitboxActivated")
	if activated == true then
		return _activationResult(false, "AlreadyActivated", source)
	end

	local createResult = services.HitboxService:CreateAttackHitbox(entity, "Enemy", HitboxConfig.AttackStructure)
	if not createResult.success or createResult.handle == nil then
		return _activationResult(false, createResult.reason or "HitboxCreateFailed", source)
	end

	self:SetEntityValue(entity, "ActiveHitboxHandle", createResult.handle)
	self:SetEntityValue(entity, "HitboxStartedAt", services.CurrentTime)
	self:SetEntityValue(entity, "HitboxActivated", true)
	self:SetEntityValue(entity, "ActivationWindowStartedAt", nil)
	services.EnemyEntityFactory:SetLastAttackTime(entity, services.CurrentTime)
	services.EnemyEntityFactory:PromoteToCommitted(entity)

	return _activationResult(true, "Activated", source)
end

function AttackStructureExecutor:ActivateHitbox(entity: number, services: any): THitboxActivationResult
	return _activateHitboxInternal(self, entity, services, "AnimationCallback")
end

function AttackStructureExecutor:TryActivateHitboxFromTimeout(entity: number, services: any): THitboxActivationResult
	return _activateHitboxInternal(self, entity, services, "ServerTimeoutFallback")
end

function AttackStructureExecutor:OnTick(entity: number, _dt: number, services: any): string
	local targetStructure = _getTargetStructure(entity, services)
	if targetStructure == nil then
		return self:Fail(entity, "MissingTargetStructure")
	end

	local role = services.EnemyEntityFactory:GetRole(entity)
	local cooldown = services.EnemyEntityFactory:GetAttackCooldown(entity)
	if role == nil or cooldown == nil then
		return self:Fail(entity, "MissingAttackState")
	end

	local damage = role.damage
	if type(damage) ~= "number" or damage <= 0 then
		return self:Fail(entity, "InvalidAttackDamage")
	end

	local activated = self:GetEntityValue(entity, "HitboxActivated") == true
	if not activated then
		if services.CurrentTime - cooldown.LastAttackTime < cooldown.Cooldown then
			return self:Running()
		end

		local activationWindowStartedAt = self:GetEntityValue(entity, "ActivationWindowStartedAt")
		if type(activationWindowStartedAt) ~= "number" then
			self:SetEntityValue(entity, "ActivationWindowStartedAt", services.CurrentTime)
			return self:Running()
		end

		local timedOut = self:GetEntityValue(entity, "HitboxActivationTimedOut") == true
		if not timedOut and services.CurrentTime - activationWindowStartedAt >= ACTIVATION_TIMEOUT_SECONDS then
			self:SetEntityValue(entity, "HitboxActivationTimedOut", true)
			local activation = self:TryActivateHitboxFromTimeout(entity, services)
			if not activation.success then
				return self:Fail(entity, activation.reason)
			end
		end

		return self:Running()
	end

	local activeHitboxHandle = self:GetEntityValue(entity, "ActiveHitboxHandle")
	if type(activeHitboxHandle) ~= "string" then
		return self:Fail(entity, "MissingHitboxHandle")
	end

	if services.HitboxService:DidHitTarget(activeHitboxHandle, targetStructure, "Structure") then
		services.HitboxService:DestroyHitbox(activeHitboxHandle)
		self:ClearEntityValue(entity, "ActiveHitboxHandle")
		self:ClearEntityValue(entity, "HitboxStartedAt")
		self:SetEntityValue(entity, "HitLanded", true)

		local damageResult = services.StructureContext:ApplyDamage(targetStructure, damage)
		if not damageResult.success then
			return self:Fail(entity, "ApplyDamageFailed")
		end

		if damageResult.value == true then
			return self:Success()
		end
		return self:Running()
	end

	local startedAt = self:GetEntityValue(entity, "HitboxStartedAt")
	if type(startedAt) ~= "number" then
		return self:Fail(entity, "MissingHitboxStartTime")
	end

	if services.CurrentTime - startedAt >= HitboxConfig.AttackStructure.MaxDuration then
		services.HitboxService:DestroyHitbox(activeHitboxHandle)
		self:ClearEntityValue(entity, "ActiveHitboxHandle")
		self:ClearEntityValue(entity, "HitboxStartedAt")
		if self:GetEntityValue(entity, "HitLanded") == true then
			return self:Success()
		end
		return self:Fail(entity, "HitboxExpired")
	end

	return self:Running()
end

function AttackStructureExecutor:OnCancel(entity: number, services: any)
	local activeHitboxHandle = self:GetEntityValue(entity, "ActiveHitboxHandle")
	if type(activeHitboxHandle) == "string" then
		services.HitboxService:DestroyHitbox(activeHitboxHandle)
	end

	self:ClearEntityValue(entity, "ActiveHitboxHandle")
	self:ClearEntityValue(entity, "HitboxStartedAt")
	self:ClearEntityValue(entity, "HitboxActivated")
	self:ClearEntityValue(entity, "HitboxActivationTimedOut")
	self:ClearEntityValue(entity, "ActivationWindowStartedAt")
	self:ClearEntityValue(entity, "HitLanded")
	services.EnemyEntityFactory:ClearTarget(entity)
end

function AttackStructureExecutor:OnComplete(entity: number, services: any)
	self:OnCancel(entity, services)
end

return AttackStructureExecutor
