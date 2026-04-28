--!strict

--[=[
    @class BaseECSWorldService
    Creates the isolated ECS world used by the Base context.
    @server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseECSWorldService = require(ReplicatedStorage.Utilities.BaseECSWorldService)

local BaseECSWorldServiceImpl = {}
BaseECSWorldServiceImpl.__index = BaseECSWorldServiceImpl
setmetatable(BaseECSWorldServiceImpl, { __index = BaseECSWorldService })

--[=[
    Create a new base ECS world service.
    @within BaseECSWorldService
    @return BaseECSWorldService -- World service instance.
]=]
function BaseECSWorldServiceImpl.new()
	return setmetatable(BaseECSWorldService.new("Base"), BaseECSWorldServiceImpl)
end

return BaseECSWorldServiceImpl
