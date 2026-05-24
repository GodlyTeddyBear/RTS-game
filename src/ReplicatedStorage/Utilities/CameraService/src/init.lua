--!strict

local Manager = require(script.Manager)
local Resolver = require(script.Resolver)
local Types = require(script.Types)

export type TCameraProvider = Types.TCameraProvider
export type TCameraPose = Types.TCameraPose
export type TCameraPoseUpdate = Types.TCameraPoseUpdate
export type TCameraBounds = Types.TCameraBounds
export type TCameraApplyRequest = Types.TCameraApplyRequest
export type TResolvedCameraApplyRequest = Types.TResolvedCameraApplyRequest
export type TCameraConfig = Types.TCameraConfig
export type TCameraSnapshot = Types.TCameraSnapshot
export type TCameraService = Types.TCameraService

local CameraService = {}

function CameraService.new(config: Types.TCameraConfig): Types.TCameraService
	return Manager.new(config)
end

function CameraService.ResolveCameraCFrame(pose: Types.TCameraPose): CFrame
	return Resolver.ResolveCameraCFrame(pose)
end

return table.freeze(CameraService)
