--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseECSComponentRegistry = require(ServerStorage.Utilities.ECSUtilities.BaseECSComponentRegistry)

local UnitComponentRegistry = {}
UnitComponentRegistry.__index = UnitComponentRegistry
setmetatable(UnitComponentRegistry, { __index = BaseECSComponentRegistry })

function UnitComponentRegistry.new()
	return setmetatable(BaseECSComponentRegistry.new("Unit"), UnitComponentRegistry)
end

function UnitComponentRegistry:_RegisterComponents(_registry: any, _name: string)
	self:RegisterComponent("IdentityComponent", "Unit.Identity", "AUTHORITATIVE")
	self:RegisterComponent("OwnershipComponent", "Unit.Ownership", "AUTHORITATIVE")
	self:RegisterComponent("TransformComponent", "Unit.Transform", "AUTHORITATIVE")
	self:RegisterComponent("HealthComponent", "Unit.Health", "AUTHORITATIVE")
	self:RegisterComponent("AnimationStateComponent", "Unit.AnimationState", "AUTHORITATIVE")
	self:RegisterComponent("AnimationLoopingComponent", "Unit.AnimationLooping", "AUTHORITATIVE")
	self:RegisterComponent("RoleComponent", "Unit.Role", "AUTHORITATIVE")
	self:RegisterComponent("LifetimeComponent", "Unit.Lifetime", "AUTHORITATIVE")
	self:RegisterComponent("ModelRefComponent", "Unit.ModelRef", "AUTHORITATIVE")

	self:RegisterTag("ActiveTag", "Unit.ActiveTag")
	self:RegisterTag("DirtyTag", "Unit.DirtyTag")
end

return UnitComponentRegistry
