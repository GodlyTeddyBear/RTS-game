--!strict

local Types = require(script.Parent.Types)

type TCameraApplyRequest = Types.TCameraApplyRequest
type TCameraBounds = Types.TCameraBounds
type TCameraConfig = Types.TCameraConfig
type TCameraPose = Types.TCameraPose
type TCameraPoseUpdate = Types.TCameraPoseUpdate
type TResolvedCameraApplyRequest = Types.TResolvedCameraApplyRequest

local DEFAULT_DISTANCE = 72
local DEFAULT_YAW_DEGREES = 45
local DEFAULT_PITCH_DEGREES = 35
local DEFAULT_FIELD_OF_VIEW = 20
local DEFAULT_DURATION = 0
local DEFAULT_EASING_STYLE = Enum.EasingStyle.Quad
local DEFAULT_EASING_DIRECTION = Enum.EasingDirection.InOut

local Options = {}

local function _ClonePose(pose: TCameraPose): TCameraPose
	return table.freeze({
		FocusPoint = pose.FocusPoint,
		Distance = pose.Distance,
		YawDegrees = pose.YawDegrees,
		PitchDegrees = pose.PitchDegrees,
		FieldOfView = pose.FieldOfView,
	})
end

local function _CloneBounds(bounds: TCameraBounds?): TCameraBounds?
	if bounds == nil then
		return nil
	end

	return table.freeze({
		MinX = bounds.MinX,
		MaxX = bounds.MaxX,
		MinZ = bounds.MinZ,
		MaxZ = bounds.MaxZ,
		MinDistance = bounds.MinDistance,
		MaxDistance = bounds.MaxDistance,
		MinPitch = bounds.MinPitch,
		MaxPitch = bounds.MaxPitch,
		MinFieldOfView = bounds.MinFieldOfView,
		MaxFieldOfView = bounds.MaxFieldOfView,
		YawStepDegrees = bounds.YawStepDegrees,
	})
end

function Options.CreatePose(pose: TCameraPoseUpdate?): TCameraPose
	local focusPoint = if pose ~= nil and pose.FocusPoint ~= nil then pose.FocusPoint else Vector3.zero

	return _ClonePose({
		FocusPoint = focusPoint,
		Distance = if pose ~= nil and pose.Distance ~= nil then pose.Distance else DEFAULT_DISTANCE,
		YawDegrees = if pose ~= nil and pose.YawDegrees ~= nil then pose.YawDegrees else DEFAULT_YAW_DEGREES,
		PitchDegrees = if pose ~= nil and pose.PitchDegrees ~= nil then pose.PitchDegrees else DEFAULT_PITCH_DEGREES,
		FieldOfView = if pose ~= nil and pose.FieldOfView ~= nil then pose.FieldOfView else DEFAULT_FIELD_OF_VIEW,
	})
end

function Options.MergePose(basePose: TCameraPose, overrides: TCameraPoseUpdate?): TCameraPose
	if overrides == nil then
		return _ClonePose(basePose)
	end

	return _ClonePose({
		FocusPoint = if overrides.FocusPoint ~= nil then overrides.FocusPoint else basePose.FocusPoint,
		Distance = if overrides.Distance ~= nil then overrides.Distance else basePose.Distance,
		YawDegrees = if overrides.YawDegrees ~= nil then overrides.YawDegrees else basePose.YawDegrees,
		PitchDegrees = if overrides.PitchDegrees ~= nil then overrides.PitchDegrees else basePose.PitchDegrees,
		FieldOfView = if overrides.FieldOfView ~= nil then overrides.FieldOfView else basePose.FieldOfView,
	})
end

function Options.ClampPose(pose: TCameraPose, bounds: TCameraBounds?): TCameraPose
	if bounds == nil then
		return _ClonePose(pose)
	end

	local clampedYaw = pose.YawDegrees
	if bounds.YawStepDegrees ~= nil and bounds.YawStepDegrees > 0 then
		clampedYaw = math.round(clampedYaw / bounds.YawStepDegrees) * bounds.YawStepDegrees
	end

	return _ClonePose({
		FocusPoint = Vector3.new(
			if bounds.MinX ~= nil or bounds.MaxX ~= nil then math.clamp(pose.FocusPoint.X, bounds.MinX or pose.FocusPoint.X, bounds.MaxX or pose.FocusPoint.X) else pose.FocusPoint.X,
			pose.FocusPoint.Y,
			if bounds.MinZ ~= nil or bounds.MaxZ ~= nil then math.clamp(pose.FocusPoint.Z, bounds.MinZ or pose.FocusPoint.Z, bounds.MaxZ or pose.FocusPoint.Z) else pose.FocusPoint.Z
		),
		Distance = if bounds.MinDistance ~= nil or bounds.MaxDistance ~= nil
			then math.clamp(pose.Distance, bounds.MinDistance or pose.Distance, bounds.MaxDistance or pose.Distance)
			else pose.Distance,
		YawDegrees = clampedYaw,
		PitchDegrees = if bounds.MinPitch ~= nil or bounds.MaxPitch ~= nil
			then math.clamp(pose.PitchDegrees, bounds.MinPitch or pose.PitchDegrees, bounds.MaxPitch or pose.PitchDegrees)
			else pose.PitchDegrees,
		FieldOfView = if bounds.MinFieldOfView ~= nil or bounds.MaxFieldOfView ~= nil
			then math.clamp(
				pose.FieldOfView,
				bounds.MinFieldOfView or pose.FieldOfView,
				bounds.MaxFieldOfView or pose.FieldOfView
			)
			else pose.FieldOfView,
	})
end

function Options.CreateBounds(bounds: TCameraBounds?): TCameraBounds?
	return _CloneBounds(bounds)
end

function Options.CreateApplyRequest(request: TCameraApplyRequest?): TCameraApplyRequest
	if request == nil then
		return {}
	end

	return table.freeze({
		Duration = request.Duration,
		EasingStyle = request.EasingStyle,
		EasingDirection = request.EasingDirection,
		ApplyFieldOfView = request.ApplyFieldOfView,
	})
end

function Options.ResolveApplyRequest(defaultApply: TCameraApplyRequest?, request: TCameraApplyRequest?): TResolvedCameraApplyRequest
	local resolvedDefaults = Options.CreateApplyRequest(defaultApply)
	local resolvedRequest = Options.CreateApplyRequest(request)

	return table.freeze({
		Duration = if resolvedRequest.Duration ~= nil
			then resolvedRequest.Duration
			else if resolvedDefaults.Duration ~= nil then resolvedDefaults.Duration else DEFAULT_DURATION,
		EasingStyle = if resolvedRequest.EasingStyle ~= nil
			then resolvedRequest.EasingStyle
			else if resolvedDefaults.EasingStyle ~= nil then resolvedDefaults.EasingStyle else DEFAULT_EASING_STYLE,
		EasingDirection = if resolvedRequest.EasingDirection ~= nil
			then resolvedRequest.EasingDirection
			else if resolvedDefaults.EasingDirection ~= nil then resolvedDefaults.EasingDirection else DEFAULT_EASING_DIRECTION,
		ApplyFieldOfView = if resolvedRequest.ApplyFieldOfView ~= nil
			then resolvedRequest.ApplyFieldOfView
			else if resolvedDefaults.ApplyFieldOfView ~= nil then resolvedDefaults.ApplyFieldOfView else true,
	})
end

function Options.CreateConfig(config: TCameraConfig): TCameraConfig
	return table.freeze({
		DefaultPose = _ClonePose(config.DefaultPose),
		Bounds = _CloneBounds(config.Bounds),
		CameraProvider = config.CameraProvider,
		DefaultApply = Options.CreateApplyRequest(config.DefaultApply),
	})
end

return table.freeze(Options)
