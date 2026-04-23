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

return WaveECSWorldService
