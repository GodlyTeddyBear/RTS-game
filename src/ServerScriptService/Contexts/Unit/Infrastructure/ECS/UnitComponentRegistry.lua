--!strict

--[=[
    @class UnitComponentRegistry
    Registers the authoritative unit ECS components and tags used by the unit entity factory and sync services.

    @server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseECSComponentRegistry = require(ServerStorage.Utilities.ECSUtilities.BaseECSComponentRegistry)

local UnitComponentRegistry = {}
UnitComponentRegistry.__index = UnitComponentRegistry
setmetatable(UnitComponentRegistry, { __index = BaseECSComponentRegistry })

-- Creates the component registry bound to the Unit namespace.
function UnitComponentRegistry.new()
	return setmetatable(BaseECSComponentRegistry.new("Unit"), UnitComponentRegistry)
end

-- Registers every component and tag required by the unit ECS runtime.
function UnitComponentRegistry:_RegisterComponents(_registry: any, _name: string)
	self:RegisterComponent("IdentityComponent", "Unit.Identity", "AUTHORITATIVE")
	self:RegisterComponent("OwnershipComponent", "Unit.Ownership", "AUTHORITATIVE")
	self:RegisterComponent("TransformComponent", "Unit.Transform", "DERIVED")
	self:RegisterComponent("HealthComponent", "Unit.Health", "AUTHORITATIVE")
	self:RegisterComponent("BaseMoveSpeedComponent", "Unit.BaseMoveSpeed", "AUTHORITATIVE")
	self:RegisterComponent("CurrentMoveSpeedComponent", "Unit.CurrentMoveSpeed", "AUTHORITATIVE")
	self:RegisterComponent("PathStateComponent", "Unit.PathState", "AUTHORITATIVE")
	self:RegisterComponent("AnimationStateComponent", "Unit.AnimationState", "AUTHORITATIVE")
	self:RegisterComponent("AnimationLoopingComponent", "Unit.AnimationLooping", "AUTHORITATIVE")
	self:RegisterComponent("RoleComponent", "Unit.Role", "AUTHORITATIVE")
	self:RegisterComponent("BuilderAssignmentComponent", "Unit.BuilderAssignment", "AUTHORITATIVE")
	self:RegisterComponent("LifetimeComponent", "Unit.Lifetime", "AUTHORITATIVE")
	self:RegisterComponent("ModelRefComponent", "Unit.ModelRef", "AUTHORITATIVE")
	self:RegisterComponent("BehaviorTreeComponent", "Unit.BehaviorTree", "AUTHORITATIVE")
	self:RegisterComponent("CombatActionComponent", "Unit.CombatAction", "AUTHORITATIVE")
	self:RegisterComponent("AttackCooldownComponent", "Unit.AttackCooldown", "AUTHORITATIVE")
	self:RegisterComponent("BehaviorConfigComponent", "Unit.BehaviorConfig", "AUTHORITATIVE")
	self:RegisterComponent("TargetComponent", "Unit.Target", "AUTHORITATIVE")
	self:RegisterComponent("LockOnComponent", "Unit.LockOn", "AUTHORITATIVE")

	self:RegisterTag("ActiveTag", "Unit.ActiveTag")
	self:RegisterTag("DirtyTag", "Unit.DirtyTag")
	self:RegisterTag("GoalReachedTag", "Unit.GoalReachedTag")
end

return UnitComponentRegistry
