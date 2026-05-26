--!strict

local ServerStorage = game:GetService("ServerStorage")

local BaseECSWorldService = require(ServerStorage.Utilities.ECSUtilities.BaseECSWorldService)

local EntityECSWorldService = {}
EntityECSWorldService.__index = EntityECSWorldService
setmetatable(EntityECSWorldService, { __index = BaseECSWorldService })

function EntityECSWorldService.new()
	return setmetatable(BaseECSWorldService.new("Entity"), EntityECSWorldService)
end

return EntityECSWorldService
