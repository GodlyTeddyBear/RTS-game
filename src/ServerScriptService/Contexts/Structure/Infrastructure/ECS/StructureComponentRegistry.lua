--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local JECS = require(ReplicatedStorage.Packages.JECS)

--[=[
	@class StructureComponentRegistry
	Registers structure ECS components and exposes their ids.
	@server
]=]
local StructureComponentRegistry = {}
StructureComponentRegistry.__index = StructureComponentRegistry

--[=[
	Creates a new component registry wrapper.
	@within StructureComponentRegistry
	@return StructureComponentRegistry -- The new registry instance.
]=]
function StructureComponentRegistry.new()
	local self = setmetatable({}, StructureComponentRegistry)
	self._components = nil
	return self
end

local function _nameComponent(world: any, componentId: number, name: string)
	world:set(componentId, JECS.Name, name)
end

--[=[
	Registers the structure ECS components into the shared world.
	@within StructureComponentRegistry
	@param registry any -- The dependency registry for this context.
	@param _name string -- The registered module name.
]=]
function StructureComponentRegistry:Init(registry: any, _name: string)
	-- Create the component ids from the shared structure world.
	local world = registry:Get("World")

	local attackStatsComponent = world:component()
	local attackCooldownComponent = world:component()
	local targetComponent = world:component()
	local instanceRefComponent = world:component()
	local identityComponent = world:component()
	local activeTag = world:entity()

	-- Name each component so debug output and inspector tools stay readable.
	_nameComponent(world, attackStatsComponent, "Structure.AttackStats")
	_nameComponent(world, attackCooldownComponent, "Structure.AttackCooldown")
	_nameComponent(world, targetComponent, "Structure.Target")
	_nameComponent(world, instanceRefComponent, "Structure.InstanceRef")
	_nameComponent(world, identityComponent, "Structure.Identity")
	_nameComponent(world, activeTag, "Structure.Active")

	-- Freeze the lookup table before exposing it to downstream services.
	self._components = table.freeze({
		AttackStatsComponent = attackStatsComponent,
		AttackCooldownComponent = attackCooldownComponent,
		TargetComponent = targetComponent,
		InstanceRefComponent = instanceRefComponent,
		IdentityComponent = identityComponent,
		ActiveTag = activeTag,
	})
end

--[=[
	Returns the frozen component lookup table.
	@within StructureComponentRegistry
	@return table -- The component lookup table.
]=]
function StructureComponentRegistry:GetComponents()
	return self._components
end

return StructureComponentRegistry
