--!strict

local Enums = require(script.Enums)
local Manager = require(script.Manager)
local Types = require(script.Types)

export type TClickTarget = Types.TClickTarget
export type TClickAttachOptions = Types.TClickAttachOptions
export type TClickManagerConfig = Types.TClickManagerConfig
export type TClickErrorData = Types.TClickErrorData
export type TClickHandleState = Types.TClickHandleState
export type TClickHandle = Types.TClickHandle
export type TClickService = Types.TClickService

local ClickService = {
	HandleState = Enums.HandleState,
	ErrorKey = Enums.ErrorKey,
}

function ClickService.new(config: TClickManagerConfig?): TClickService
	return Manager.new(config)
end

return table.freeze(ClickService)
