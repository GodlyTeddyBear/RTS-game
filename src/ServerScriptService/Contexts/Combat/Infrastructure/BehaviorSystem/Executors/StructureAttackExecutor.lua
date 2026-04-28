--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseExecutor = require(ReplicatedStorage.Utilities.BaseExecutor)

local ACTIVATION_TIMEOUT_SECONDS = 0.2

type TProjectileActivationResult = {
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
setmetatable(StructureAttackExecutor, BaseExecutor)

function StructureAttackExecutor.new()
	local self = BaseExecutor.new({
		ActionId = "StructureAttack",
		IsCommitted = false,
	})
	return setmetatable(self, StructureAttackExecutor)
end

local function _activationResult(success: boolean, reason: string, source: string): TProjectileActivationResult
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

local function _RecordActivationSource(entity: number, services: any, source: string)
	local modelRef = services.StructureEntityFactory:GetModelRef(entity)
	if modelRef == nil or modelRef.Model == nil or modelRef.Model.Parent == nil then
		return
	end

	modelRef.Model:SetAttribute("LastProjectileActivationSource", source)
	modelRef.Model:SetAttribute("LastProjectileActivatedAt", services.CurrentTime)
end

local function _isTargetInRange(entity: number, targetEnemy: number, services: any): boolean
	local structurePosition = services.StructureEntityFactory:GetPosition(entity)
	local attackStats = services.StructureEntityFactory:GetAttackStats(entity)
	if structurePosition == nil or attackStats == nil then
		return false
	end

	return services.CombatPerceptionService:IsTargetInRange(
		structurePosition,
		attackStats.AttackRange,
		"Enemy",
		targetEnemy
	)
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
	self:SetEntityValue(entity, "ProjectileActivated", false)
	self:SetEntityValue(entity, "ProjectileActivationTimedOut", false)
	self:SetEntityValue(entity, "AttackStartedAt", nil)
	self:SetEntityValue(entity, "ActiveProjectileId", nil)
	self:SetEntityValue(entity, "ProjectileStartedAt", nil)
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
): TProjectileActivationResult
	if self:GetEntityValue(entity, "AwaitingHitboxActivation") ~= true then
		return _activationResult(false, "NotAwaitingActivation", source)
	end

	if self:GetEntityValue(entity, "ProjectileActivated") == true then
		return _activationResult(false, "AlreadyActivated", source)
	end

	local targetEnemy = _getTargetEnemy(entity, services)
	if targetEnemy == nil then
		return _activationResult(false, "MissingTargetEnemy", source)
	end

	local attackStats = services.StructureEntityFactory:GetAttackStats(entity)
	if attackStats == nil then
		return _activationResult(false, "MissingAttackState", source)
	end

	local fireResult = services.ProjectileService:FireStructureBullet({
		StructureEntity = entity,
		TargetEnemyEntity = targetEnemy,
		Damage = attackStats.AttackDamage,
		MaxDistance = attackStats.AttackRange,
	})
	if not fireResult.success or fireResult.projectileId == nil then
		return _activationResult(false, fireResult.reason or "ProjectileFireFailed", source)
	end

	self:SetEntityValue(entity, "ActiveProjectileId", fireResult.projectileId)
	self:SetEntityValue(entity, "ProjectileStartedAt", services.CurrentTime)
	self:SetEntityValue(entity, "ProjectileActivated", true)
	self:SetEntityValue(entity, "ProjectileActivationTimedOut", source == "ServerTimeoutFallback")
	self:SetEntityValue(entity, "AttackStartedAt", nil)
	_RecordActivationSource(entity, services, source)
	services.StructureEntityFactory:PromoteToCommitted(entity)

	return _activationResult(true, "Activated", source)
end

function StructureAttackExecutor:ActivateHitbox(entity: number, services: any): TProjectileActivationResult
	return _activateHitboxInternal(self, entity, services, "AnimationCallback")
end

function StructureAttackExecutor:TryActivateHitboxFromTimeout(entity: number, services: any): TProjectileActivationResult
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
		self:SetEntityValue(entity, "ProjectileActivated", false)
		self:SetEntityValue(entity, "ProjectileActivationTimedOut", false)
		self:SetEntityValue(entity, "AttackStartedAt", services.CurrentTime)
		return self:Running()
	end

	if self:GetEntityValue(entity, "ProjectileActivated") ~= true then
		local startedAt = self:GetEntityValue(entity, "AttackStartedAt")
		if type(startedAt) ~= "number" then
			return self:Fail(entity, "MissingAttackStartTime")
		end

		local timedOut = self:GetEntityValue(entity, "ProjectileActivationTimedOut") == true
		if not timedOut and services.CurrentTime - startedAt >= ACTIVATION_TIMEOUT_SECONDS then
			self:SetEntityValue(entity, "ProjectileActivationTimedOut", true)
			local activation = self:TryActivateHitboxFromTimeout(entity, services)
			if not activation.success then
				return self:Fail(entity, activation.reason)
			end
		end

		return self:Running()
	end

	return self:Success()
end

function StructureAttackExecutor:OnCancel(entity: number, services: any)
	self:ClearEntityValue(entity, "ActiveProjectileId")
	self:ClearEntityValue(entity, "ProjectileStartedAt")
	self:ClearEntityValue(entity, "AwaitingHitboxActivation")
	self:ClearEntityValue(entity, "ProjectileActivated")
	self:ClearEntityValue(entity, "ProjectileActivationTimedOut")
	self:ClearEntityValue(entity, "AttackStartedAt")
	services.StructureEntityFactory:SetTarget(entity, nil)
end

function StructureAttackExecutor:OnComplete(entity: number, services: any)
	self:OnCancel(entity, services)
end

return StructureAttackExecutor
