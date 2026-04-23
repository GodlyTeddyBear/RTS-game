--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseECSComponentRegistry = require(ReplicatedStorage.Utilities.BaseECSComponentRegistry)

--[=[
	@class WaveComponentRegistry
	Registers wave ECS components and exposes their ids.
	@server
]=]
local WaveComponentRegistry = {}
WaveComponentRegistry.__index = WaveComponentRegistry
setmetatable(WaveComponentRegistry, { __index = BaseECSComponentRegistry })

--[=[
	Creates a new component registry wrapper.
	@within WaveComponentRegistry
	@return WaveComponentRegistry -- The new registry instance.
]=]
function WaveComponentRegistry.new()
	return setmetatable(BaseECSComponentRegistry.new("Wave"), WaveComponentRegistry)
end

--[=[
	Registers the wave ECS components into the shared world.
	@within WaveComponentRegistry
	@param registry any -- The dependency registry for this context.
	@param name string -- The registered module name.
]=]
function WaveComponentRegistry:Init(registry: any, _name: string)
	BaseECSComponentRegistry.InitBase(self, registry)

	-- [AUTHORITATIVE] canonical runtime counters and lifecycle flags for the active wave session.
	self:RegisterComponent("RuntimeStateComponent", "Wave.RuntimeState", "AUTHORITATIVE")
	self:RegisterTag("SessionTag", "Wave.SessionTag")

	self:Finalize()
end

--[=[
	Returns the frozen component lookup table.
	@within WaveComponentRegistry
	@return table -- The component lookup table.
]=]
function WaveComponentRegistry:GetComponents()
	return BaseECSComponentRegistry.GetComponents(self)
end

return WaveComponentRegistry
