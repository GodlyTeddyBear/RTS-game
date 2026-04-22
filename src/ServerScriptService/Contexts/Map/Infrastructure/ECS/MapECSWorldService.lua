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

function MapECSWorldService.new()
	return setmetatable(BaseECSWorldService.new("Map"), MapECSWorldService)
end

function MapECSWorldService:Init(_registry: any, _name: string)
	BaseECSWorldService.Init(self, _registry, _name)
end

function MapECSWorldService:GetWorld()
	return BaseECSWorldService.GetWorld(self)
end

return MapECSWorldService
