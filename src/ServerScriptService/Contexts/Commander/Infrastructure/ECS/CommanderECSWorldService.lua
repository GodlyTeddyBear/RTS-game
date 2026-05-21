--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local BaseECSWorldService = require(ServerStorage.Utilities.ECSUtilities.BaseECSWorldService)

--[=[
	@class CommanderECSWorldService
	Owns the isolated JECS world used by CommanderContext.
	@server
]=]
local CommanderECSWorldService = {}
CommanderECSWorldService.__index = CommanderECSWorldService
setmetatable(CommanderECSWorldService, { __index = BaseECSWorldService })

function CommanderECSWorldService.new()
	return setmetatable(BaseECSWorldService.new("Commander"), CommanderECSWorldService)
end

return CommanderECSWorldService
