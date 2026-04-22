--!strict

local BaseExecutor = require(script.Parent.Base.BaseExecutor)

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

function StructureAttackExecutor:Start(entity: number, data: any?, services: any): (boolean, string?)
	if not services.StructureEntityFactory:IsActive(entity) then
		return false, "InactiveStructure"
	end

	if type(data) ~= "table" or type(data.TargetEnemyEntity) ~= "number" then
		return false, "MissingTargetEnemy"
	end

	if not services.EnemyEntityFactory:IsAlive(data.TargetEnemyEntity) then
		return false, "InactiveTargetEnemy"
	end

	if not _isTargetInRange(entity, data.TargetEnemyEntity, services) then
		return false, "TargetOutOfRange"
	end

	return true, nil
end

function StructureAttackExecutor:Tick(entity: number, dt: number, services: any): string
	if not services.StructureEntityFactory:IsActive(entity) then
		return "Fail"
	end

	local targetEnemy = _getTargetEnemy(entity, services)
	if targetEnemy == nil or not services.EnemyEntityFactory:IsAlive(targetEnemy) then
		return "Fail"
	end

	if not _isTargetInRange(entity, targetEnemy, services) then
		return "Fail"
	end

	local attackStats = services.StructureEntityFactory:GetAttackStats(entity)
	local cooldown = services.StructureEntityFactory:GetCooldown(entity)
	if attackStats == nil or cooldown == nil then
		return "Fail"
	end

	local elapsed = cooldown.Elapsed + dt
	services.StructureEntityFactory:SetCooldownElapsed(entity, elapsed)
	if elapsed < attackStats.AttackCooldown then
		return "Running"
	end

	services.StructureEntityFactory:SetCooldownElapsed(entity, 0)
	local damageResult = services.EnemyContext:ApplyDamage(targetEnemy, attackStats.AttackDamage)
	if not damageResult.success then
		return "Fail"
	end

	if damageResult.value == true then
		return "Success"
	end

	return "Running"
end

return StructureAttackExecutor
