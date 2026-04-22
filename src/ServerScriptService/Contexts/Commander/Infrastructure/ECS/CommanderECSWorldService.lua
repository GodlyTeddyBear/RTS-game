--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseECSWorldService = require(ReplicatedStorage.Utilities.BaseECSWorldService)

--[=[
	@class CommanderECSWorldService
	Owns the isolated JECS world used by CommanderContext.
	@server
]=]
local CommanderECSWorldService = {}
CommanderECSWorldService.__index = CommanderECSWorldService
setmetatable(CommanderECSWorldService, BaseECSWorldService)

function CommanderECSWorldService.new()
	return setmetatable(BaseECSWorldService._new("Commander"), CommanderECSWorldService)
end

function CommanderECSWorldService:Init(registry: any, name: string)
	BaseECSWorldService.Init(self, registry, name)
end

function CommanderECSWorldService:GetWorld()
	return BaseECSWorldService.GetWorld(self)
end

return CommanderECSWorldService

