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

local EnemyAttackBaseExecutor = {}
EnemyAttackBaseExecutor.__index = EnemyAttackBaseExecutor
setmetatable(EnemyAttackBaseExecutor, { __index = BaseExecutor })

function EnemyAttackBaseExecutor.new()
	local self = BaseExecutor.new({
		ActionId = "AttackBase",
		IsCommitted = false,
	})
	return setmetatable(self, EnemyAttackBaseExecutor)
end

local function _activationResult(success: boolean, reason: string, source: string): THitboxActivationResult
	return {
		success = success,
		reason = reason,
		source = source,
	}
end

local function _isBaseInRange(entity: number, services: any): boolean
	local enemyPosition = services.EnemyEntityFactory:GetPosition(entity)
	local role = services.EnemyEntityFactory:GetRole(entity)
	local baseCFrame = services.BaseEntityFactory:GetTargetCFrame()
	if enemyPosition == nil or role == nil or baseCFrame == nil then
		return false
	end

	local attackRange = role.attackRange
	if type(attackRange) ~= "number" then
		return false
	end

	local offset = baseCFrame.Position - enemyPosition.cframe.Position
	return offset:Dot(offset) <= attackRange * attackRange
end

function EnemyAttackBaseExecutor:CanStart(entity: number, _data: any?, services: any): (boolean, string?)
	if not services.BaseEntityFactory:IsActive() then
		return false, "InactiveBase"
	end

	if not _isBaseInRange(entity, services) then
		return false, "BaseOutOfRange"
	end

	return true, nil
end

function EnemyAttackBaseExecutor:OnStart(entity: number, _data: any?, services: any)
	services.EnemyEntityFactory:SetTarget(entity, nil, "Base")
	self:SetEntityValue(entity, "HitboxActivated", false)
	self:SetEntityValue(entity, "HitboxActivationTimedOut", false)
	self:SetEntityValue(entity, "ActivationWindowStartedAt", nil)
	self:SetEntityValue(entity, "HitLanded", false)
	self:SetEntityValue(entity, "ActiveHitboxHandle", nil)
	self:SetEntityValue(entity, "HitboxStartedAt", nil)
end

function EnemyAttackBaseExecutor:CanContinue(entity: number, services: any): (boolean, string?)
	return self:RunGuards(entity, services, {
		{
			Reason = "InactiveBase",
			Check = function(_guardEntity: number, guardServices: any): boolean
				return guardServices.BaseEntityFactory:IsActive()
			end,
		},
		{
			Reason = "BaseOutOfRange",
			Check = function(guardEntity: number, guardServices: any): boolean
				return _isBaseInRange(guardEntity, guardServices)
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

	local activatedHitbox = services.HitboxService:CreateAttackHitbox(entity, "Enemy", HitboxConfig.AttackStructure)
	if not activatedHitbox.success or activatedHitbox.handle == nil then
		return _activationResult(false, activatedHitbox.reason or "HitboxCreateFailed", source)
	end

	self:SetEntityValue(entity, "ActiveHitboxHandle", activatedHitbox.handle)
	self:SetEntityValue(entity, "HitboxStartedAt", services.CurrentTime)
	self:SetEntityValue(entity, "HitboxActivated", true)
	self:SetEntityValue(entity, "ActivationWindowStartedAt", nil)
	services.EnemyEntityFactory:SetLastAttackTime(entity, services.CurrentTime)
	services.EnemyEntityFactory:PromoteToCommitted(entity)

	return _activationResult(true, "Activated", source)
end

function EnemyAttackBaseExecutor:TryActivateHitboxFromTimeout(entity: number, services: any): THitboxActivationResult
	return _activateHitboxInternal(self, entity, services, "ServerTimeoutFallback")
end

function EnemyAttackBaseExecutor:OnTick(entity: number, _dt: number, services: any): string
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

	if services.HitboxService:DidHitBase(activeHitboxHandle) then
		services.HitboxService:DestroyHitbox(activeHitboxHandle)
		self:ClearEntityValue(entity, "ActiveHitboxHandle")
		self:ClearEntityValue(entity, "HitboxStartedAt")
		self:SetEntityValue(entity, "HitLanded", true)

		local damageResult = services.BaseContext:ApplyDamage(damage)
		if not damageResult.success then
			return self:Fail(entity, "ApplyDamageFailed")
		end

		return self:Success()
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

function EnemyAttackBaseExecutor:OnCancel(entity: number, services: any)
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

function EnemyAttackBaseExecutor:OnComplete(entity: number, services: any)
	self:OnCancel(entity, services)
end

return EnemyAttackBaseExecutor
