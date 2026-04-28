--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseECSWorldService = require(ReplicatedStorage.Utilities.BaseECSWorldService)

--[=[
    @class MiningECSWorldService
    Owns the isolated ECS world used by the Mining context.
    @server
]=]
local MiningECSWorldService = {}
MiningECSWorldService.__index = MiningECSWorldService
setmetatable(MiningECSWorldService, { __index = BaseECSWorldService })

-- Creates the Mining ECS world wrapper with the Mining namespace.
--[=[
    Creates the Mining ECS world wrapper with the Mining namespace.
    @within MiningECSWorldService
    @return MiningECSWorldService -- The new world-service instance.
]=]
function MiningECSWorldService.new()
	return setmetatable(BaseECSWorldService.new("Mining"), MiningECSWorldService)
end

return MiningECSWorldService
