--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local JECS = require(ReplicatedStorage.Packages.JECS)

--[=[
	@class MapECSWorldService
	Owns the isolated JECS world used by MapContext.
	@server
]=]
local MapECSWorldService = {}
MapECSWorldService.__index = MapECSWorldService

function MapECSWorldService.new()
	local self = setmetatable({}, MapECSWorldService)
	self._world = JECS.World.new()
	return self
end

function MapECSWorldService:Init(_registry: any, _name: string)
end

function MapECSWorldService:GetWorld()
	return self._world
end

return MapECSWorldService

