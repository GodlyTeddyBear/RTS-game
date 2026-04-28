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

function EnemyComponentRegistry:_RegisterComponents(_registry: any, _name: string)
	self:RegisterComponent("HealthComponent", "Enemy.Health", "AUTHORITATIVE")
	self:RegisterComponent("TransformComponent", "Enemy.Transform", "DERIVED")
	self:RegisterComponent("RoleComponent", "Enemy.Role", "AUTHORITATIVE")
	self:RegisterComponent("PathStateComponent", "Enemy.PathState", "AUTHORITATIVE")
	self:RegisterComponent("ModelRefComponent", "Enemy.ModelRef", "AUTHORITATIVE")
	self:RegisterComponent("IdentityComponent", "Enemy.Identity", "AUTHORITATIVE")
	self:RegisterComponent("BehaviorTreeComponent", "Enemy.BehaviorTree", "AUTHORITATIVE")
	self:RegisterComponent("CombatActionComponent", "Enemy.CombatAction", "AUTHORITATIVE")
	self:RegisterComponent("AttackCooldownComponent", "Enemy.AttackCooldown", "AUTHORITATIVE")
	self:RegisterComponent("BehaviorConfigComponent", "Enemy.BehaviorConfig", "AUTHORITATIVE")
	self:RegisterComponent("TargetComponent", "Enemy.Target", "AUTHORITATIVE")
	self:RegisterComponent("LockOnComponent", "Enemy.LockOn", "AUTHORITATIVE")
	self:RegisterTag("AliveTag", "Enemy.AliveTag")
	self:RegisterTag("DirtyTag", "Enemy.DirtyTag")
	self:RegisterTag("GoalReachedTag", "Enemy.GoalReachedTag")
end

return EnemyComponentRegistry
