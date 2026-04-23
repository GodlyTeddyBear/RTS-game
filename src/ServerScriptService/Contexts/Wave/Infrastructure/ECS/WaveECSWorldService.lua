--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseECSWorldService = require(ReplicatedStorage.Utilities.BaseECSWorldService)

--[=[
	@class WaveECSWorldService
	Owns the isolated JECS world used by WaveContext.
	@server
]=]
local WaveECSWorldService = {}
WaveECSWorldService.__index = WaveECSWorldService
setmetatable(WaveECSWorldService, { __index = BaseECSWorldService })

--[=[
	Creates a new isolated JECS world service.
	@within WaveECSWorldService
	@return WaveECSWorldService -- The new service instance.
]=]
function WaveECSWorldService.new()
	return setmetatable(BaseECSWorldService.new("Wave"), WaveECSWorldService)
end

--[=[
	Initializes the service lifecycle hook.
	@within WaveECSWorldService
	@param registry any -- The dependency registry for this context.
	@param name string -- The registered module name.
]=]
function WaveECSWorldService:Init(registry: any, name: string)
	BaseECSWorldService.Init(self, registry, name)
end

--[=[
	Returns the isolated wave JECS world.
	@within WaveECSWorldService
	@return any -- The authoritative JECS world.
]=]
function WaveECSWorldService:GetWorld()
	return BaseECSWorldService.GetWorld(self)
end

return WaveECSWorldService
