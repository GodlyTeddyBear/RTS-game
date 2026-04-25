--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseECSWorldService = require(ReplicatedStorage.Utilities.BaseECSWorldService)

local MiningECSWorldService = {}
MiningECSWorldService.__index = MiningECSWorldService
setmetatable(MiningECSWorldService, { __index = BaseECSWorldService })

function MiningECSWorldService.new()
	return setmetatable(BaseECSWorldService.new("Mining"), MiningECSWorldService)
end

return MiningECSWorldService
