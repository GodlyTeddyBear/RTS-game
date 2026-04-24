--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseExecutor = require(ReplicatedStorage.Utilities.BaseExecutor)

--[=[
	@class EnemyAttackStructureExecutor
	Resolves enemy melee attacks against active structure entities.
	@server
]=]
local EnemyAttackStructureExecutor = {}
EnemyAttackStructureExecutor.__index = EnemyAttackStructureExecutor
setmetatable(EnemyAttackStructureExecutor, { __index = BaseExecutor })

function EnemyAttackStructureExecutor.new()
	local self = BaseExecutor.new({
		ActionId = "AttackStructure",
		IsCommitted = false,
	})
	return setmetatable(self, EnemyAttackStructureExecutor)
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

function EnemyAttackStructureExecutor:CanStart(entity: number, data: any?, services: any): (boolean, string?)
	if type(data) ~= "table" or type(data.TargetStructureEntity) ~= "number" then
		return false, "MissingTargetStructure"
	end

	return _validateTargetStructure(entity, data.TargetStructureEntity, services)
end

function EnemyAttackStructureExecutor:CanContinue(entity: number, services: any): (boolean, string?)
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

function EnemyAttackStructureExecutor:OnTick(entity: number, _dt: number, services: any): string
	local targetStructure = _getTargetStructure(entity, services)
	if targetStructure == nil then
		return self:Fail(entity, "MissingTargetStructure")
	end

	local role = services.EnemyEntityFactory:GetRole(entity)
	local cooldown = services.EnemyEntityFactory:GetAttackCooldown(entity)
	if role == nil or cooldown == nil then
		return self:Fail(entity, "MissingAttackState")
	end

	if services.CurrentTime - cooldown.LastAttackTime < cooldown.Cooldown then
		return self:Running()
	end

	local damage = role.damage
	if type(damage) ~= "number" or damage <= 0 then
		return self:Fail(entity, "InvalidAttackDamage")
	end

	local damageResult = services.StructureContext:ApplyDamage(targetStructure, damage)
	if not damageResult.success then
		return self:Fail(entity, "ApplyDamageFailed")
	end

	services.EnemyEntityFactory:SetLastAttackTime(entity, services.CurrentTime)
	if damageResult.value == true then
		return self:Success()
	end

	return self:Running()
end

return EnemyAttackStructureExecutor
