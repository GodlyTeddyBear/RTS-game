--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local BaseECSComponentRegistry = require(ServerStorage.Utilities.ECSUtilities.BaseECSComponentRegistry)

--[=[
	@class StructureComponentRegistry
	Registers structure ECS components and exposes their ids.
	@server
]=]
local StructureComponentRegistry = {}
StructureComponentRegistry.__index = StructureComponentRegistry
setmetatable(StructureComponentRegistry, BaseECSComponentRegistry)

--[=[
	Creates a new component registry wrapper.
	@within StructureComponentRegistry
	@return StructureComponentRegistry -- The new registry instance.
]=]
function StructureComponentRegistry.new()
	return setmetatable(BaseECSComponentRegistry.new("Structure"), StructureComponentRegistry)
end

--[=[
	Registers the structure ECS components into the shared world.
	@within StructureComponentRegistry
	@param registry any -- The dependency registry for this context.
	@param _name string -- The registered module name.
]=]
function StructureComponentRegistry:_RegisterComponents(_registry: any, _name: string)
	-- [AUTHORITATIVE] static combat stats for each structure.
	self:RegisterComponent("AttackStatsComponent", "Structure.AttackStats", "AUTHORITATIVE")
	-- [AUTHORITATIVE] runtime cooldown accumulator.
	self:RegisterComponent("AttackCooldownComponent", "Structure.AttackCooldown", "AUTHORITATIVE")
	-- [AUTHORITATIVE] runtime health for destructible structures.
	self:RegisterComponent("HealthComponent", "Structure.Health", "AUTHORITATIVE")
	-- [AUTHORITATIVE] construction work progress before the structure becomes operational.
	self:RegisterComponent("ConstructionProgressComponent", "Structure.ConstructionProgress", "AUTHORITATIVE")
	-- [AUTHORITATIVE] current enemy target entity id.
	self:RegisterComponent("TargetComponent", "Structure.Target", "AUTHORITATIVE")
	-- [AUTHORITATIVE] assigned combat behavior tree and tick timing.
	self:RegisterComponent("BehaviorTreeComponent", "Structure.BehaviorTree", "AUTHORITATIVE")
	-- [AUTHORITATIVE] current and pending combat executor action.
	self:RegisterComponent("CombatActionComponent", "Structure.CombatAction", "AUTHORITATIVE")
	-- [AUTHORITATIVE] runtime world position and source instance id.
	self:RegisterComponent("InstanceRefComponent", "Structure.InstanceRef", "AUTHORITATIVE")
	-- [AUTHORITATIVE] runtime model reference for collision and orientation services.
	self:RegisterComponent("ModelRefComponent", "Structure.ModelRef", "AUTHORITATIVE")
	-- [AUTHORITATIVE] runtime world transform for targeting and range checks.
	self:RegisterComponent("TransformComponent", "Structure.Transform", "AUTHORITATIVE")
	-- [AUTHORITATIVE] stable identity metadata.
	self:RegisterComponent("IdentityComponent", "Structure.Identity", "AUTHORITATIVE")
	-- [DERIVED] client-facing animation state resolved from the runtime profile.
	self:RegisterComponent("AnimationStateComponent", "Structure.AnimationState", "DERIVED")
	-- [DERIVED] client-facing animation looping flag for the active animation state.
	self:RegisterComponent("AnimationLoopingComponent", "Structure.AnimationLooping", "DERIVED")
	-- [DERIVED] replicated enemy id used by the client aim layer.
	self:RegisterComponent("TargetEnemyIdComponent", "Structure.TargetEnemyId", "DERIVED")
	self:RegisterTag("PlacedTag", "Structure.PlacedTag")
	self:RegisterTag("UnderConstructionTag", "Structure.UnderConstructionTag")
	self:RegisterTag("ActiveTag", "Structure.ActiveTag")
	self:RegisterTag("DirtyTag", "Structure.DirtyTag")
end

return StructureComponentRegistry
