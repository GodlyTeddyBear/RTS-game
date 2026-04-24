--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseExecutor = require(ReplicatedStorage.Utilities.BaseExecutor)

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

	local elapsed = cooldown.Elapsed + dt
	services.StructureEntityFactory:SetCooldownElapsed(entity, elapsed)
	if elapsed < attackStats.AttackCooldown then
		return self:Running()
	end

	services.StructureEntityFactory:SetCooldownElapsed(entity, 0)
	local damageResult = services.EnemyContext:ApplyDamage(targetEnemy, attackStats.AttackDamage)
	if not damageResult.success then
		return self:Fail(entity, "ApplyDamageFailed")
	end

	if damageResult.value == true then
		return self:Success()
	end

	return self:Running()
end

return StructureAttackExecutor
