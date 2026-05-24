--!strict

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)

local Types = require(script.Parent.Types)

type TCameraApplyRequest = Types.TCameraApplyRequest
type TCameraBounds = Types.TCameraBounds
type TCameraConfig = Types.TCameraConfig
type TCameraPose = Types.TCameraPose

local Policies = {}

local function _BuildErr(errorType: string, message: string, data: { [string]: any }?): Result.Err
	return Result.Err(errorType, message, data)
end

local function _IsNumber(value: any): boolean
	return type(value) == "number" and value == value
end

local function _Assert(condition: boolean, message: string)
	assert(condition, message)
end

local function _ValidateBounds(bounds: TCameraBounds?)
	if bounds == nil then
		return
	end

	_Assert(bounds.MinDistance == nil or _IsNumber(bounds.MinDistance), "CameraService bounds MinDistance must be a number")
	_Assert(bounds.MaxDistance == nil or _IsNumber(bounds.MaxDistance), "CameraService bounds MaxDistance must be a number")
	_Assert(bounds.MinPitch == nil or _IsNumber(bounds.MinPitch), "CameraService bounds MinPitch must be a number")
	_Assert(bounds.MaxPitch == nil or _IsNumber(bounds.MaxPitch), "CameraService bounds MaxPitch must be a number")
	_Assert(bounds.MinFieldOfView == nil or _IsNumber(bounds.MinFieldOfView), "CameraService bounds MinFieldOfView must be a number")
	_Assert(bounds.MaxFieldOfView == nil or _IsNumber(bounds.MaxFieldOfView), "CameraService bounds MaxFieldOfView must be a number")
	_Assert(bounds.MinX == nil or _IsNumber(bounds.MinX), "CameraService bounds MinX must be a number")
	_Assert(bounds.MaxX == nil or _IsNumber(bounds.MaxX), "CameraService bounds MaxX must be a number")
	_Assert(bounds.MinZ == nil or _IsNumber(bounds.MinZ), "CameraService bounds MinZ must be a number")
	_Assert(bounds.MaxZ == nil or _IsNumber(bounds.MaxZ), "CameraService bounds MaxZ must be a number")
	_Assert(bounds.YawStepDegrees == nil or _IsNumber(bounds.YawStepDegrees), "CameraService bounds YawStepDegrees must be a number")

	if bounds.MinDistance ~= nil and bounds.MaxDistance ~= nil then
		_Assert(bounds.MinDistance <= bounds.MaxDistance, "CameraService MinDistance must be <= MaxDistance")
	end
	if bounds.MinPitch ~= nil and bounds.MaxPitch ~= nil then
		_Assert(bounds.MinPitch <= bounds.MaxPitch, "CameraService MinPitch must be <= MaxPitch")
	end
	if bounds.MinFieldOfView ~= nil and bounds.MaxFieldOfView ~= nil then
		_Assert(bounds.MinFieldOfView <= bounds.MaxFieldOfView, "CameraService MinFieldOfView must be <= MaxFieldOfView")
	end
	if bounds.MinX ~= nil and bounds.MaxX ~= nil then
		_Assert(bounds.MinX <= bounds.MaxX, "CameraService MinX must be <= MaxX")
	end
	if bounds.MinZ ~= nil and bounds.MaxZ ~= nil then
		_Assert(bounds.MinZ <= bounds.MaxZ, "CameraService MinZ must be <= MaxZ")
	end
	if bounds.YawStepDegrees ~= nil then
		_Assert(bounds.YawStepDegrees > 0, "CameraService YawStepDegrees must be positive")
	end
end

local function _ValidatePose(pose: TCameraPose)
	_Assert(typeof(pose.FocusPoint) == "Vector3", "CameraService pose FocusPoint must be a Vector3")
	_Assert(_IsNumber(pose.Distance), "CameraService pose Distance must be a number")
	_Assert(_IsNumber(pose.YawDegrees), "CameraService pose YawDegrees must be a number")
	_Assert(_IsNumber(pose.PitchDegrees), "CameraService pose PitchDegrees must be a number")
	_Assert(_IsNumber(pose.FieldOfView), "CameraService pose FieldOfView must be a number")
	_Assert(pose.Distance > 0, "CameraService pose Distance must be greater than 0")
	_Assert(pose.FieldOfView > 0, "CameraService pose FieldOfView must be greater than 0")
end

function Policies.CheckManagerConfig(config: TCameraConfig)
	_Assert(type(config) == "table", "CameraService.new requires a config table")
	_Assert(type(config.DefaultPose) == "table", "CameraService config must include DefaultPose")
	_ValidatePose(config.DefaultPose)
	_ValidateBounds(config.Bounds)

	if config.CameraProvider ~= nil then
		_Assert(type(config.CameraProvider) == "function", "CameraService CameraProvider must be a function")
	end

	if config.DefaultApply ~= nil then
		Policies.AssertApplyRequest(config.DefaultApply)
	end
end

function Policies.AssertBounds(bounds: TCameraBounds?)
	_ValidateBounds(bounds)
end

function Policies.AssertPose(pose: TCameraPose)
	_ValidatePose(pose)
end

function Policies.AssertApplyRequest(request: TCameraApplyRequest)
	_Assert(type(request) == "table", "CameraService apply request must be a table")
	if request.Duration ~= nil then
		_Assert(_IsNumber(request.Duration), "CameraService apply Duration must be a number")
		_Assert(request.Duration >= 0, "CameraService apply Duration must be >= 0")
	end
	if request.EasingStyle ~= nil then
		_Assert(typeof(request.EasingStyle) == "EnumItem", "CameraService apply EasingStyle must be an EnumItem")
	end
	if request.EasingDirection ~= nil then
		_Assert(typeof(request.EasingDirection) == "EnumItem", "CameraService apply EasingDirection must be an EnumItem")
	end
	if request.ApplyFieldOfView ~= nil then
		_Assert(type(request.ApplyFieldOfView) == "boolean", "CameraService apply ApplyFieldOfView must be a boolean")
	end
end

function Policies.CheckClientRuntime(): Result.Result<boolean>
	if RunService:IsClient() then
		return Result.Ok(true)
	end

	return _BuildErr("UnsupportedRuntime", "CameraService only supports client runtime.", nil)
end

function Policies.CheckCamera(camera: Camera?): Result.Result<Camera>
	if camera ~= nil and camera:IsA("Camera") then
		return Result.Ok(camera)
	end

	return _BuildErr("MissingCamera", "CameraService could not resolve an active camera.", {
		CurrentCamera = Workspace.CurrentCamera,
	})
end

function Policies.CheckPoseUpdateValue(fieldName: string, value: any): Result.Result<boolean>
	if fieldName == "FocusPoint" then
		if typeof(value) == "Vector3" then
			return Result.Ok(true)
		end
	elseif _IsNumber(value) then
		return Result.Ok(true)
	end

	return _BuildErr("InvalidPoseUpdate", string.format("CameraService received an invalid %s value.", fieldName), {
		Field = fieldName,
		Value = value,
	})
end

function Policies.CheckVector3(name: string, value: any): Result.Result<Vector3>
	if typeof(value) == "Vector3" then
		return Result.Ok(value)
	end

	return _BuildErr("InvalidVector3", string.format("CameraService expected %s to be a Vector3.", name), {
		Field = name,
		Value = value,
	})
end

function Policies.CheckNumber(name: string, value: any): Result.Result<number>
	if _IsNumber(value) then
		return Result.Ok(value)
	end

	return _BuildErr("InvalidNumber", string.format("CameraService expected %s to be a number.", name), {
		Field = name,
		Value = value,
	})
end

function Policies.CheckBasePart(part: any): Result.Result<BasePart>
	if typeof(part) == "Instance" and part:IsA("BasePart") then
		return Result.Ok(part)
	end

	return _BuildErr("InvalidPart", "CameraService expected a BasePart target.", {
		Target = part,
	})
end

function Policies.CheckModel(model: any): Result.Result<Model>
	if typeof(model) == "Instance" and model:IsA("Model") then
		return Result.Ok(model)
	end

	return _BuildErr("InvalidModel", "CameraService expected a Model target.", {
		Target = model,
	})
end

function Policies.CheckServiceAlive(service: any): Result.Result<boolean>
	if service._isDestroyed ~= true then
		return Result.Ok(true)
	end

	return _BuildErr("DestroyedService", "CameraService has already been destroyed.", nil)
end

return table.freeze(Policies)
