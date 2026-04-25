--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseECSWorldService = require(ReplicatedStorage.Utilities.BaseECSWorldService)

local BaseECSWorldServiceImpl = {}
BaseECSWorldServiceImpl.__index = BaseECSWorldServiceImpl
setmetatable(BaseECSWorldServiceImpl, { __index = BaseECSWorldService })

function BaseECSWorldServiceImpl.new()
	return setmetatable(BaseECSWorldService.new("Base"), BaseECSWorldServiceImpl)
end

return BaseECSWorldServiceImpl
