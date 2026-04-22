--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseECSComponentRegistry = require(ReplicatedStorage.Utilities.BaseECSComponentRegistry)

--[=[
	@class CommanderComponentRegistry
	Registers commander ECS components and exposes ids for other commander modules.
	@server
]=]
local CommanderComponentRegistry = {}
CommanderComponentRegistry.__index = CommanderComponentRegistry
setmetatable(CommanderComponentRegistry, BaseECSComponentRegistry)

function CommanderComponentRegistry.new()
	return setmetatable(BaseECSComponentRegistry.new("Commander"), CommanderComponentRegistry)
end

function CommanderComponentRegistry:Init(registry: any, _name: string)
	BaseECSComponentRegistry.InitBase(self, registry)

	self:RegisterComponent("IdentityComponent", "Commander.Identity", "AUTHORITATIVE")
	self:RegisterComponent("HealthComponent", "Commander.Health", "AUTHORITATIVE")
	self:RegisterComponent("CooldownsComponent", "Commander.Cooldowns", "AUTHORITATIVE")
	self:RegisterTag("ActiveTag", "Commander.ActiveTag")

	self:Finalize()
end

function CommanderComponentRegistry:GetComponents()
	return BaseECSComponentRegistry.GetComponents(self)
end

return CommanderComponentRegistry
