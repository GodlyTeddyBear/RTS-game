--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseExecutor = require(ReplicatedStorage.Utilities.BaseExecutor)
local HitboxConfig = require(ReplicatedStorage.Contexts.Combat.Config.HitboxConfig)

local ACTIVATION_TIMEOUT_SECONDS = 0.2

type THitboxActivationResult = {
	success: boolean,
	reason: string,
	source: string,
}

--[=[
	@class StructureAttackExecutor
	Resolves structure attacks against alive enemy entities.
	@server
]=]
local StructureAttackExecutor = {}
StructureAttackExecutor.__index = StructureAttackExecutor
setmetatable(StructureAttackExecutor, { __index = BaseExecutor })

function StructureAttackExecutor.new()
	local self = BaseExecutor.new({
		ActionId = "StructureAttack",
		IsCommitted = false,
	})
	return setmetatable(self, StructureAttackExecutor)
end

local function _activationResult(success: boolean, reason: string, source: string): THitboxActivationResult
	return {
		success = success,
		reason = reason,
		source = source,
	}
end

local function _getTargetEnemy(entity: number, services: any): number?
	local action = services.StructureEntityFactory:GetCombatAction(entity)
	local data = action and action.ActionData
	if type(data) ~= "table" or type(data.TargetEnemyEntity) ~= "number" then
		return nil
	end

	return data.TargetEnemyEntity
end

local function _isTargetInRange(entity: number, targetEnemy: number, services: any): boolean
	local structurePosition = services.StructureEntityFactory:GetPosition(entity)
	local enemyPosition = services.EnemyEntityFactory:GetPosition(targetEnemy)
	local attackStats = services.StructureEntityFactory:GetAttackStats(entity)
	if structurePosition == nil or enemyPosition == nil or attackStats == nil then
		return false
	end

	local offset = enemyPosition.cframe.Position - structurePosition
	return offset:Dot(offset) <= attackStats.AttackRange * attackStats.AttackRange
end

local function _validateTargetEnemy(entity: number, targetEnemy: number, services: any): (boolean, string?)
	if not services.EnemyEntityFactory:IsAlive(targetEnemy) then
		return false, "InactiveTargetEnemy"
	end

	if not _isTargetInRange(entity, targetEnemy, services) then
		return false, "TargetOutOfRange"
	end

	return true, nil
end

function StructureAttackExecutor:CanStart(entity: number, data: any?, services: any): (boolean, string?)
	if not services.StructureEntityFactory:IsActive(entity) then
		return false, "InactiveStructure"
	end

	if type(data) ~= "table" or type(data.TargetEnemyEntity) ~= "number" then
		return false, "MissingTargetEnemy"
	end

	return _validateTargetEnemy(entity, data.TargetEnemyEntity, services)
end

function StructureAttackExecutor:OnStart(entity: number, data: any?, services: any)
	local targetEnemy = type(data) == "table" and data.TargetEnemyEntity or nil
	if type(targetEnemy) ~= "number" then
		return
	end

	services.StructureEntityFactory:SetTarget(entity, targetEnemy)
	self:SetEntityValue(entity, "AwaitingHitboxActivation", false)
	self:SetEntityValue(entity, "HitboxActivated", false)
	self:SetEntityValue(entity, "HitboxActivationTimedOut", false)
	self:SetEntityValue(entity, "AttackStartedAt", nil)
	self:SetEntityValue(entity, "HitLanded", false)
	self:SetEntityValue(entity, "ActiveHitboxHandle", nil)
	self:SetEntityValue(entity, "HitboxStartedAt", nil)
end

function StructureAttackExecutor:CanContinue(entity: number, services: any): (boolean, string?)
	local targetEnemy = _getTargetEnemy(entity, services)
	if targetEnemy == nil then
		return false, "MissingTargetEnemy"
	end

	return self:RunGuards(entity, services, {
		{
			Reason = "InactiveStructure",
			Check = function(guardEntity: number, guardServices: any): boolean
				return guardServices.StructureEntityFactory:IsActive(guardEntity)
			end,
		},
		{
			Reason = "InactiveTargetEnemy",
			Check = function(_guardEntity: number, guardServices: any): boolean
				return guardServices.EnemyEntityFactory:IsAlive(targetEnemy)
			end,
		},
		{
			Reason = "TargetOutOfRange",
			Check = function(guardEntity: number, guardServices: any): boolean
				return _isTargetInRange(guardEntity, targetEnemy, guardServices)
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
		return _activationResult(false, "NotAwaitingActivation", source)
	end

	if self:GetEntityValue(entity, "HitboxActivated") == true then
		return _activationResult(false, "AlreadyActivated", source)
	end

	local createResult = services.HitboxService:CreateAttackHitbox(entity, "Structure", HitboxConfig.StructureAttack)
	if not createResult.success or createResult.handle == nil then
		return _activationResult(false, createResult.reason or "HitboxCreateFailed", source)
	end

	self:SetEntityValue(entity, "ActiveHitboxHandle", createResult.handle)
	self:SetEntityValue(entity, "HitboxStartedAt", services.CurrentTime)
	self:SetEntityValue(entity, "HitboxActivated", true)
	services.StructureEntityFactory:PromoteToCommitted(entity)

	return _activationResult(true, "Activated", source)
end

function StructureAttackExecutor:ActivateHitbox(entity: number, services: any): THitboxActivationResult
	return _activateHitboxInternal(self, entity, services, "AnimationCallback")
end

function StructureAttackExecutor:TryActivateHitboxFromTimeout(entity: number, services: any): THitboxActivationResult
	return _activateHitboxInternal(self, entity, services, "ServerTimeoutFallback")
end

function StructureAttackExecutor:OnTick(entity: number, dt: number, services: any): string
	local targetEnemy = _getTargetEnemy(entity, services)
	if targetEnemy == nil then
		return self:Fail(entity, "MissingTargetEnemy")
	end

	local attackStats = services.StructureEntityFactory:GetAttackStats(entity)
	local cooldown = services.StructureEntityFactory:GetCooldown(entity)
	if attackStats == nil or cooldown == nil then
		return self:Fail(entity, "MissingAttackState")
	end

	if self:GetEntityValue(entity, "AwaitingHitboxActivation") ~= true then
		local elapsed = cooldown.Elapsed + dt
		services.StructureEntityFactory:SetCooldownElapsed(entity, elapsed)
		if elapsed < attackStats.AttackCooldown then
			return self:Running()
		end

		services.StructureEntityFactory:SetCooldownElapsed(entity, 0)
		self:SetEntityValue(entity, "AwaitingHitboxActivation", true)
		self:SetEntityValue(entity, "HitboxActivated", false)
		self:SetEntityValue(entity, "HitboxActivationTimedOut", false)
		self:SetEntityValue(entity, "AttackStartedAt", services.CurrentTime)
		self:SetEntityValue(entity, "HitLanded", false)
		return self:Running()
	end

	if self:GetEntityValue(entity, "HitboxActivated") ~= true then
		local startedAt = self:GetEntityValue(entity, "AttackStartedAt")
		if type(startedAt) ~= "number" then
			return self:Fail(entity, "MissingAttackStartTime")
		end

		local timedOut = self:GetEntityValue(entity, "HitboxActivationTimedOut") == true
		if not timedOut and services.CurrentTime - startedAt >= ACTIVATION_TIMEOUT_SECONDS then
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

	if services.HitboxService:DidHitTarget(activeHitboxHandle, targetEnemy, "Enemy") then
		services.HitboxService:DestroyHitbox(activeHitboxHandle)
		self:ClearEntityValue(entity, "ActiveHitboxHandle")
		self:ClearEntityValue(entity, "HitboxStartedAt")
		self:SetEntityValue(entity, "HitLanded", true)

		local damageResult = services.EnemyContext:ApplyDamage(targetEnemy, attackStats.AttackDamage)
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

	if services.CurrentTime - startedAt >= HitboxConfig.StructureAttack.MaxDuration then
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

function StructureAttackExecutor:OnCancel(entity: number, services: any)
	local activeHitboxHandle = self:GetEntityValue(entity, "ActiveHitboxHandle")
	if type(activeHitboxHandle) == "string" then
		services.HitboxService:DestroyHitbox(activeHitboxHandle)
	end

	self:ClearEntityValue(entity, "ActiveHitboxHandle")
	self:ClearEntityValue(entity, "HitboxStartedAt")
	self:ClearEntityValue(entity, "AwaitingHitboxActivation")
	self:ClearEntityValue(entity, "HitboxActivated")
	self:ClearEntityValue(entity, "HitboxActivationTimedOut")
	self:ClearEntityValue(entity, "AttackStartedAt")
	self:ClearEntityValue(entity, "HitLanded")
	services.StructureEntityFactory:SetTarget(entity, nil)
end

function StructureAttackExecutor:OnComplete(entity: number, services: any)
	self:OnCancel(entity, services)
end

return StructureAttackExecutor
