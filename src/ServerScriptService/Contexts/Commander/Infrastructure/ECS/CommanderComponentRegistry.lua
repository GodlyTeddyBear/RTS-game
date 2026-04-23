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
setmetatable(CommanderComponentRegistry, { __index = BaseECSComponentRegistry })

function CommanderComponentRegistry.new()
	return setmetatable(BaseECSComponentRegistry.new("Commander"), CommanderComponentRegistry)
end

function CommanderComponentRegistry:_RegisterComponents(_registry: any, _name: string)
	self:RegisterComponent("IdentityComponent", "Commander.Identity", "AUTHORITATIVE")
	self:RegisterComponent("HealthComponent", "Commander.Health", "AUTHORITATIVE")
	self:RegisterComponent("CooldownsComponent", "Commander.Cooldowns", "AUTHORITATIVE")
	self:RegisterTag("ActiveTag", "Commander.ActiveTag")
end

return CommanderComponentRegistry
