--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseECSWorldService = require(ReplicatedStorage.Utilities.BaseECSWorldService)

--[=[
	@class MapECSWorldService
	Owns the isolated JECS world used by MapContext.
	@server
]=]
local MapECSWorldService = {}
MapECSWorldService.__index = MapECSWorldService
setmetatable(MapECSWorldService, { __index = BaseECSWorldService })

--[=[
	Creates the Map ECS world service wrapper.
	@within MapECSWorldService
	@return MapECSWorldService -- The new world service instance.
]=]
function MapECSWorldService.new()
	return setmetatable(BaseECSWorldService.new("Map"), MapECSWorldService)
end

return MapECSWorldService
