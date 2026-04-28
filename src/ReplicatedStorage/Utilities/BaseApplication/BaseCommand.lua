--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameEvents = require(ReplicatedStorage.Events.GameEvents)
local BaseApplication = require(script.Parent.BaseApplication)

--[=[
    @class BaseCommand
    Base application for commands that emit context and game events.
    @server
]=]

export type TDependencyMap = BaseApplication.TDependencyMap

export type TBaseCommand = BaseApplication.TBaseApplication & {
	_EmitContextEvent: (self: any, eventName: string, ...any) -> (),
	_EmitGameEvent: (self: any, contextName: string, eventName: string, ...any) -> (),
}

local BaseCommand = {}
BaseCommand.__index = BaseCommand
setmetatable(BaseCommand, BaseApplication)

--[=[
    Creates a command base for a context and operation pair.
    @within BaseCommand
    @param contextName string -- Owning context label used in diagnostics.
    @param operationName string -- Operation label used in diagnostics.
    @return TBaseCommand -- Base command instance.
]=]
function BaseCommand.new(contextName: string, operationName: string): TBaseCommand
	local self = BaseApplication.new(contextName, operationName)
	return setmetatable(self, BaseCommand) :: any
end

--[=[
    Emits a context event for the command's own context.
    @within BaseCommand
    @param eventName string -- Event name inside the current context.
]=]
function BaseCommand:_EmitContextEvent(eventName: string, ...: any)
	GameEvents.Bus:Emit(self:_GetGameEvent(self._contextName, eventName), ...)
end

--[=[
    Emits a game event from any registered context.
    @within BaseCommand
    @param contextName string -- Game event context name.
    @param eventName string -- Event name inside the target context.
]=]
function BaseCommand:_EmitGameEvent(contextName: string, eventName: string, ...: any)
	GameEvents.Bus:Emit(self:_GetGameEvent(contextName, eventName), ...)
end

return BaseCommand
