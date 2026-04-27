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

local AttackBaseExecutor = {}
AttackBaseExecutor.__index = AttackBaseExecutor
setmetatable(AttackBaseExecutor, { __index = BaseExecutor })

function AttackBaseExecutor.new()
	local self = BaseExecutor.new({
		ActionId = "AttackBase",
		IsCommitted = false,
	})
	return setmetatable(self, AttackBaseExecutor)
end

local function _activationResult(success: boolean, reason: string, source: string): THitboxActivationResult
	return {
		success = success,
		reason = reason,
		source = source,
	}
end

local function _recordActivationSource(entity: number, services: any, source: string)
	local modelRef = services.EnemyEntityFactory:GetModelRef(entity)
	if modelRef == nil or modelRef.model == nil or modelRef.model.Parent == nil then
		return
	end

	modelRef.model:SetAttribute("LastHitboxActivationSource", source)
	modelRef.model:SetAttribute("LastHitboxActivatedAt", services.CurrentTime)
end

local function _isTargetInRange(entity: number, services: any): boolean
	local enemyPosition = services.EnemyEntityFactory:GetPosition(entity)
	local role = services.EnemyEntityFactory:GetRole(entity)
	if enemyPosition == nil or role == nil then
		return false
	end

	local attackRange = role.attackRange
	if type(attackRange) ~= "number" then
		return false
	end

	return services.CombatPerceptionService:IsTargetInRange(enemyPosition.cframe.Position, attackRange, "Base", nil)
end

function AttackBaseExecutor:CanStart(entity: number, _data: any?, services: any): (boolean, string?)
	if not services.BaseEntityFactory:IsActive() then
		return false, "InactiveBase"
	end

	if not _isTargetInRange(entity, services) then
		return false, "BaseOutOfRange"
	end

	return true, nil
end

function AttackBaseExecutor:OnStart(entity: number, _data: any?, services: any)
	services.EnemyEntityFactory:SetTarget(entity, nil, "Base")
	self:SetEntityValue(entity, "AwaitingHitboxActivation", false)
	self:SetEntityValue(entity, "HitboxActivated", false)
	self:SetEntityValue(entity, "HitboxActivationTimedOut", false)
	self:SetEntityValue(entity, "AttackStartedAt", nil)
	self:SetEntityValue(entity, "HitLanded", false)
	self:SetEntityValue(entity, "ActiveHitboxHandle", nil)
	self:SetEntityValue(entity, "HitboxStartedAt", nil)
	self:SetEntityValue(entity, "PendingHitboxActivation", false)
end

function AttackBaseExecutor:CanContinue(entity: number, services: any): (boolean, string?)
	if self:GetEntityValue(entity, "HitboxActivated") == true then
		return true, nil
	end

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
				return _isTargetInRange(guardEntity, guardServices)
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
	if self:GetEntityValue(entity, "AwaitingHitboxActivation") ~= true then
		self:SetEntityValue(entity, "PendingHitboxActivation", true)
		return _activationResult(true, "QueuedBeforeActivationWindow", source)
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
	self:SetEntityValue(entity, "HitboxActivationTimedOut", source == "ServerTimeoutFallback")
	self:SetEntityValue(entity, "AwaitingHitboxActivation", false)
	self:SetEntityValue(entity, "AttackStartedAt", nil)
	self:SetEntityValue(entity, "PendingHitboxActivation", false)
	services.EnemyEntityFactory:SetLastAttackTime(entity, services.CurrentTime)
	services.EnemyEntityFactory:PromoteToCommitted(entity)
	_recordActivationSource(entity, services, source)

	return _activationResult(true, "Activated", source)
end

function AttackBaseExecutor:TryActivateHitboxFromTimeout(entity: number, services: any): THitboxActivationResult
	return _activateHitboxInternal(self, entity, services, "ServerTimeoutFallback")
end

function AttackBaseExecutor:ActivateHitbox(entity: number, services: any): THitboxActivationResult
	return _activateHitboxInternal(self, entity, services, "AnimationCallback")
end

function AttackBaseExecutor:OnTick(entity: number, _dt: number, services: any): string
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
		if self:GetEntityValue(entity, "AwaitingHitboxActivation") ~= true then
			if services.CurrentTime - cooldown.LastAttackTime < cooldown.Cooldown then
				return self:Running()
			end

			self:SetEntityValue(entity, "AwaitingHitboxActivation", true)
			self:SetEntityValue(entity, "HitboxActivationTimedOut", false)
			self:SetEntityValue(entity, "AttackStartedAt", services.CurrentTime)

			if self:GetEntityValue(entity, "PendingHitboxActivation") == true then
				local activation = self:ActivateHitbox(entity, services)
				if not activation.success then
					return self:Fail(entity, activation.reason)
				end
			end

			return self:Running()
		end

		local activationWindowStartedAt = self:GetEntityValue(entity, "AttackStartedAt")
		if type(activationWindowStartedAt) ~= "number" then
			return self:Fail(entity, "MissingAttackStartTime")
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

	local resolutionResult = services.CombatHitResolutionService:ResolveEnemyMeleeHits(activeHitboxHandle, entity, damage)
	if not resolutionResult.success then
		return self:Fail(entity, "ApplyDamageFailed")
	end
	if resolutionResult.value.AppliedHits > 0 then
		self:SetEntityValue(entity, "HitLanded", true)
	end

	local startedAt = self:GetEntityValue(entity, "HitboxStartedAt")
	if type(startedAt) ~= "number" then
		return self:Fail(entity, "MissingHitboxStartTime")
	end

	if services.CurrentTime - startedAt >= HitboxConfig.AttackStructure.MaxDuration then
		services.HitboxService:DestroyHitbox(activeHitboxHandle)
		services.CombatHitResolutionService:ClearResolvedHits(activeHitboxHandle)
		self:ClearEntityValue(entity, "ActiveHitboxHandle")
		self:ClearEntityValue(entity, "HitboxStartedAt")
		if self:GetEntityValue(entity, "HitLanded") == true then
			return self:Success()
		end
		return self:Fail(entity, "HitboxExpired")
	end

	return self:Running()
end

function AttackBaseExecutor:OnCancel(entity: number, services: any)
	local activeHitboxHandle = self:GetEntityValue(entity, "ActiveHitboxHandle")
	if type(activeHitboxHandle) == "string" then
		services.HitboxService:DestroyHitbox(activeHitboxHandle)
		services.CombatHitResolutionService:ClearResolvedHits(activeHitboxHandle)
	end

	self:ClearEntityValue(entity, "ActiveHitboxHandle")
	self:ClearEntityValue(entity, "HitboxStartedAt")
	self:ClearEntityValue(entity, "AwaitingHitboxActivation")
	self:ClearEntityValue(entity, "HitboxActivated")
	self:ClearEntityValue(entity, "HitboxActivationTimedOut")
	self:ClearEntityValue(entity, "AttackStartedAt")
	self:ClearEntityValue(entity, "HitLanded")
	self:ClearEntityValue(entity, "PendingHitboxActivation")
	services.EnemyEntityFactory:ClearTarget(entity)
end

function AttackBaseExecutor:OnComplete(entity: number, services: any)
	self:OnCancel(entity, services)
end

return AttackBaseExecutor
