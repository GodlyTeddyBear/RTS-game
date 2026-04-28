--!strict

--[=[
    @class BaseComponentRegistry
    Registers the Base context's ECS components and active tag.
    @server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseECSComponentRegistry = require(ReplicatedStorage.Utilities.BaseECSComponentRegistry)
local BaseTypes = require(ReplicatedStorage.Contexts.Base.Types.BaseTypes)

export type HealthComponent = BaseTypes.HealthComponent
export type InstanceRefComponent = BaseTypes.InstanceRefComponent
export type IdentityComponent = BaseTypes.IdentityComponent
export type ActiveTag = BaseTypes.ActiveTag

local BaseComponentRegistry = {}
BaseComponentRegistry.__index = BaseComponentRegistry
setmetatable(BaseComponentRegistry, { __index = BaseECSComponentRegistry })

--[=[
    Create a new base component registry.
    @within BaseComponentRegistry
    @return BaseComponentRegistry -- Registry instance.
]=]
function BaseComponentRegistry.new()
	return setmetatable(BaseECSComponentRegistry.new("Base"), BaseComponentRegistry)
end

-- Registers the Base ECS component and tag names during initialization.
function BaseComponentRegistry:_RegisterComponents(_registry: any, _name: string)
	self:RegisterComponent("HealthComponent", "Base.Health", "AUTHORITATIVE")
	self:RegisterComponent("InstanceRefComponent", "Base.InstanceRef", "AUTHORITATIVE")
	self:RegisterComponent("IdentityComponent", "Base.Identity", "AUTHORITATIVE")
	self:RegisterTag("ActiveTag", "Base.ActiveTag")
end

return BaseComponentRegistry
