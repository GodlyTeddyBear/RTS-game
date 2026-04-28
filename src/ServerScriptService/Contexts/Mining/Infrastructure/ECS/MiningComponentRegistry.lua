--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseECSComponentRegistry = require(ReplicatedStorage.Utilities.BaseECSComponentRegistry)

--[=[
    @class MiningComponentRegistry
    Registers the mining ECS component and tag identifiers used by extractor and resource-node runtime.
    @server
]=]
local MiningComponentRegistry = {}
MiningComponentRegistry.__index = MiningComponentRegistry
setmetatable(MiningComponentRegistry, { __index = BaseECSComponentRegistry })

-- Creates the registry wrapper for the Mining ECS namespace.
--[=[
    Creates the registry wrapper for the Mining ECS namespace.
    @within MiningComponentRegistry
    @return MiningComponentRegistry -- The new registry instance.
]=]
function MiningComponentRegistry.new()
	return setmetatable(BaseECSComponentRegistry.new("Mining"), MiningComponentRegistry)
end

-- Registers the component and tag ids required by the mining entity factory and mining systems.
function MiningComponentRegistry:_RegisterComponents(_registry: any, _name: string)
	-- [AUTHORITATIVE] player owner that receives extractor production.
	self:RegisterComponent("OwnerComponent", "Mining.Owner", "AUTHORITATIVE")
	-- [AUTHORITATIVE] resource output payload for each extractor.
	self:RegisterComponent("ResourceComponent", "Mining.Resource", "AUTHORITATIVE")
	-- [AUTHORITATIVE] production interval and elapsed accumulator.
	self:RegisterComponent("TimingComponent", "Mining.Timing", "AUTHORITATIVE")
	-- [AUTHORITATIVE] placement runtime instance metadata.
	self:RegisterComponent("InstanceRefComponent", "Mining.InstanceRef", "AUTHORITATIVE")
	-- [AUTHORITATIVE] resource-node identity and resource classification.
	self:RegisterComponent("ResourceNodeComponent", "Mining.ResourceNode", "AUTHORITATIVE")
	-- [AUTHORITATIVE] runtime resource-node instance reference.
	self:RegisterComponent("NodeInstanceComponent", "Mining.NodeInstance", "AUTHORITATIVE")
	self:RegisterTag("ExtractorActiveTag", "Mining.ExtractorActiveTag")
	self:RegisterTag("ResourceNodeTag", "Mining.ResourceNodeTag")
end

return MiningComponentRegistry
