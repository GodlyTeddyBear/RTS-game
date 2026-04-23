--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseECSComponentRegistry = require(ReplicatedStorage.Utilities.BaseECSComponentRegistry)

--[=[
	@class StructureComponentRegistry
	Registers structure ECS components and exposes their ids.
	@server
]=]
local StructureComponentRegistry = {}
StructureComponentRegistry.__index = StructureComponentRegistry
setmetatable(StructureComponentRegistry, { __index = BaseECSComponentRegistry })

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
	-- [AUTHORITATIVE] current enemy target entity id.
	self:RegisterComponent("TargetComponent", "Structure.Target", "AUTHORITATIVE")
	-- [AUTHORITATIVE] assigned combat behavior tree and tick timing.
	self:RegisterComponent("BehaviorTreeComponent", "Structure.BehaviorTree", "AUTHORITATIVE")
	-- [AUTHORITATIVE] current and pending combat executor action.
	self:RegisterComponent("CombatActionComponent", "Structure.CombatAction", "AUTHORITATIVE")
	-- [AUTHORITATIVE] runtime world position and source instance id.
	self:RegisterComponent("InstanceRefComponent", "Structure.InstanceRef", "AUTHORITATIVE")
	-- [AUTHORITATIVE] stable identity metadata.
	self:RegisterComponent("IdentityComponent", "Structure.Identity", "AUTHORITATIVE")
	self:RegisterTag("ActiveTag", "Structure.ActiveTag")
end

return StructureComponentRegistry
