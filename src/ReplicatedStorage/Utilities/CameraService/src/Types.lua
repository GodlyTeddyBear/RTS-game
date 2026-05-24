--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)

export type TCameraProvider = () -> Camera?

export type TCameraPose = {
	FocusPoint: Vector3,
	Distance: number,
	YawDegrees: number,
	PitchDegrees: number,
	FieldOfView: number,
}

export type TCameraPoseUpdate = {
	FocusPoint: Vector3?,
	Distance: number?,
	YawDegrees: number?,
	PitchDegrees: number?,
	FieldOfView: number?,
}

export type TCameraBounds = {
	MinX: number?,
	MaxX: number?,
	MinZ: number?,
	MaxZ: number?,
	MinDistance: number?,
	MaxDistance: number?,
	MinPitch: number?,
	MaxPitch: number?,
	MinFieldOfView: number?,
	MaxFieldOfView: number?,
	YawStepDegrees: number?,
}

export type TCameraApplyRequest = {
	Duration: number?,
	EasingStyle: Enum.EasingStyle?,
	EasingDirection: Enum.EasingDirection?,
	ApplyFieldOfView: boolean?,
}

export type TResolvedCameraApplyRequest = {
	Duration: number,
	EasingStyle: Enum.EasingStyle,
	EasingDirection: Enum.EasingDirection,
	ApplyFieldOfView: boolean,
}

export type TCameraConfig = {
	DefaultPose: TCameraPose,
	Bounds: TCameraBounds?,
	CameraProvider: TCameraProvider?,
	DefaultApply: TCameraApplyRequest?,
}

export type TCameraSnapshot = {
	Pose: TCameraPose,
	CameraCFrame: CFrame,
	FieldOfView: number,
	Camera: Camera?,
}

export type TCameraSignal = {
	Connect: (self: TCameraSignal, callback: (snapshot: TCameraSnapshot, previousSnapshot: TCameraSnapshot?) -> ()) -> any,
	Once: (self: TCameraSignal, callback: (snapshot: TCameraSnapshot, previousSnapshot: TCameraSnapshot?) -> ()) -> any,
	Fire: (self: TCameraSignal, snapshot: TCameraSnapshot, previousSnapshot: TCameraSnapshot?) -> (),
	Wait: (self: TCameraSignal) -> (TCameraSnapshot, TCameraSnapshot?),
	DisconnectAll: (self: TCameraSignal) -> (),
}

export type TCameraService = {
	Changed: TCameraSignal,
	BindCamera: (self: TCameraService, camera: Camera?) -> Result.Result<Camera>,
	GetCamera: (self: TCameraService) -> Camera?,
	GetPose: (self: TCameraService) -> TCameraPose,
	GetBounds: (self: TCameraService) -> TCameraBounds?,
	SetBounds: (self: TCameraService, bounds: TCameraBounds?) -> (),
	GetCameraCFrame: (self: TCameraService) -> Result.Result<CFrame>,
	GetSnapshot: (self: TCameraService) -> Result.Result<TCameraSnapshot>,
	ApplyDefault: (self: TCameraService, applyRequest: TCameraApplyRequest?) -> Result.Result<TCameraSnapshot>,
	SetPose: (self: TCameraService, pose: TCameraPoseUpdate, applyRequest: TCameraApplyRequest?) -> Result.Result<TCameraSnapshot>,
	SetFocusPoint: (self: TCameraService, focusPoint: Vector3, applyRequest: TCameraApplyRequest?) -> Result.Result<TCameraSnapshot>,
	FocusOnPart: (self: TCameraService, part: BasePart, applyRequest: TCameraApplyRequest?) -> Result.Result<TCameraSnapshot>,
	FocusOnModel: (self: TCameraService, model: Model, applyRequest: TCameraApplyRequest?) -> Result.Result<TCameraSnapshot>,
	PanBy: (self: TCameraService, worldDelta: Vector3, applyRequest: TCameraApplyRequest?) -> Result.Result<TCameraSnapshot>,
	ZoomBy: (self: TCameraService, delta: number, applyRequest: TCameraApplyRequest?) -> Result.Result<TCameraSnapshot>,
	SetZoom: (self: TCameraService, distance: number, applyRequest: TCameraApplyRequest?) -> Result.Result<TCameraSnapshot>,
	RotateBy: (self: TCameraService, yawDeltaDegrees: number, applyRequest: TCameraApplyRequest?) -> Result.Result<TCameraSnapshot>,
	SetYaw: (self: TCameraService, yawDegrees: number, applyRequest: TCameraApplyRequest?) -> Result.Result<TCameraSnapshot>,
	SetPitch: (self: TCameraService, pitchDegrees: number, applyRequest: TCameraApplyRequest?) -> Result.Result<TCameraSnapshot>,
	SetFieldOfView: (self: TCameraService, fieldOfView: number, applyRequest: TCameraApplyRequest?) -> Result.Result<TCameraSnapshot>,
	Apply: (self: TCameraService, applyRequest: TCameraApplyRequest?) -> Result.Result<TCameraSnapshot>,
	Reset: (self: TCameraService, applyRequest: TCameraApplyRequest?) -> Result.Result<TCameraSnapshot>,
	Destroy: (self: TCameraService) -> (),
}

local Types = {}

return Types
