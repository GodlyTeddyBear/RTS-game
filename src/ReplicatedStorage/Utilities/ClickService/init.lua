--!strict

local ClickService = require(script.src)
local Types = require(script.src.Types)

export type TClickTarget = Types.TClickTarget
export type TClickAttachOptions = Types.TClickAttachOptions
export type TClickManagerConfig = Types.TClickManagerConfig
export type TClickErrorData = Types.TClickErrorData
export type TClickHandleState = Types.TClickHandleState
export type TClickHandle = Types.TClickHandle
export type TClickService = Types.TClickService

return ClickService
