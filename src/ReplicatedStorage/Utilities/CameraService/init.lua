--!strict

local CameraService = require(script.src)
local Types = require(script.src.Types)

export type TCameraProvider = Types.TCameraProvider
export type TCameraPose = Types.TCameraPose
export type TCameraPoseUpdate = Types.TCameraPoseUpdate
export type TCameraBounds = Types.TCameraBounds
export type TCameraApplyRequest = Types.TCameraApplyRequest
export type TResolvedCameraApplyRequest = Types.TResolvedCameraApplyRequest
export type TCameraConfig = Types.TCameraConfig
export type TCameraSnapshot = Types.TCameraSnapshot
export type TCameraService = Types.TCameraService

return CameraService
