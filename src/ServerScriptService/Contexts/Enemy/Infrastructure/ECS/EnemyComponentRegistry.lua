--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseECSComponentRegistry = require(ReplicatedStorage.Utilities.BaseECSComponentRegistry)

--[=[
	@class EnemyComponentRegistry
	Registers enemy ECS components and exposes ids for other modules.
	@server
]=]
local EnemyComponentRegistry = {}
EnemyComponentRegistry.__index = EnemyComponentRegistry
setmetatable(EnemyComponentRegistry, { __index = BaseECSComponentRegistry })

function EnemyComponentRegistry.new()
	return setmetatable(BaseECSComponentRegistry.new("Enemy"), EnemyComponentRegistry)
end

function EnemyComponentRegistry:Init(registry: any, _name: string)
	BaseECSComponentRegistry.InitBase(self, registry)

	self:RegisterComponent("Health", "Enemy.Health", "AUTHORITATIVE")
	self:RegisterComponent("Position", "Enemy.Position", "AUTHORITATIVE")
	self:RegisterComponent("Role", "Enemy.Role", "AUTHORITATIVE")
	self:RegisterComponent("PathState", "Enemy.PathState", "AUTHORITATIVE")
	self:RegisterComponent("ModelRef", "Enemy.ModelRef", "AUTHORITATIVE")
	self:RegisterComponent("Identity", "Enemy.Identity", "AUTHORITATIVE")
	self:RegisterComponent("BehaviorTree", "Enemy.BehaviorTree", "AUTHORITATIVE")
	self:RegisterComponent("CombatAction", "Enemy.CombatAction", "AUTHORITATIVE")
	self:RegisterComponent("AttackCooldown", "Enemy.AttackCooldown", "AUTHORITATIVE")
	self:RegisterComponent("BehaviorConfig", "Enemy.BehaviorConfig", "AUTHORITATIVE")
	self:RegisterTag("AliveTag", "Enemy.AliveTag")
	self:RegisterTag("DirtyTag", "Enemy.DirtyTag")
	self:RegisterTag("GoalReachedTag", "Enemy.GoalReachedTag")

	self:Finalize()
end

function EnemyComponentRegistry:GetComponents()
	return BaseECSComponentRegistry.GetComponents(self)
end

return EnemyComponentRegistry
