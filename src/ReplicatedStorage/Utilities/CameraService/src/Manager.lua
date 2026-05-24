--!strict

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GoodSignal = require(ReplicatedStorage.Packages.Goodsignal)
local CameraUtil = require(ReplicatedStorage.Utilities.CameraUtil)
local ModelPlus = require(ReplicatedStorage.Utilities.ModelPlus)
local Result = require(ReplicatedStorage.Utilities.Result)
local StashPlus = require(ReplicatedStorage.Utilities.StashPlus)

local Options = require(script.Parent.Options)
local Policies = require(script.Parent.Policies)
local Resolver = require(script.Parent.Resolver)
local Types = require(script.Parent.Types)

type TCameraApplyRequest = Types.TCameraApplyRequest
type TCameraBounds = Types.TCameraBounds
type TCameraConfig = Types.TCameraConfig
type TCameraPose = Types.TCameraPose
type TCameraPoseUpdate = Types.TCameraPoseUpdate
type TCameraService = Types.TCameraService
type TCameraSnapshot = Types.TCameraSnapshot

local CAMERA_INVALIDATION_KEY = "CurrentCameraInvalidation"
local CHANGED_SIGNAL_KEY = "ChangedSignal"

local Manager = {}
Manager.__index = Manager

function Manager.new(config: TCameraConfig): TCameraService
	local runtimeResult = Policies.CheckClientRuntime()
	if not runtimeResult.success then
		error(runtimeResult.message, 2)
	end

	Policies.CheckManagerConfig(config)

	local resolvedConfig = Options.CreateConfig(config)
	local resolvedPose = Options.ClampPose(resolvedConfig.DefaultPose, resolvedConfig.Bounds)
	local self = setmetatable({}, Manager) :: any
	self._config = resolvedConfig
	self._defaultPose = resolvedPose
	self._pose = resolvedPose
	self._bounds = resolvedConfig.Bounds
	self._cameraOverride = nil :: Camera?
	self._camera = nil :: Camera?
	self._cameraHandle = nil
	self._stash = StashPlus.new()
	self._isDestroyed = false
	self.Changed = GoodSignal.new()

	self._stash:Add(self.Changed, {
		CleanupMethod = "DisconnectAll",
		Key = CHANGED_SIGNAL_KEY,
		Label = CHANGED_SIGNAL_KEY,
	})
	self._stash:AddConnection(Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		if self._cameraOverride == nil then
			self:_InvalidateCamera()
		end
	end), {
		Key = CAMERA_INVALIDATION_KEY,
		Label = CAMERA_INVALIDATION_KEY,
	})

	return self
end

function Manager:BindCamera(camera: Camera?): Result.Result<Camera>
	local aliveResult = Policies.CheckServiceAlive(self)
	if not aliveResult.success then
		return aliveResult
	end

	self._cameraOverride = camera
	return self:_ResolveCamera()
end

function Manager:GetCamera(): Camera?
	local cameraCandidate = self:_PeekResolvedCamera()
	if cameraCandidate == nil or not cameraCandidate:IsA("Camera") then
		return nil
	end

	return cameraCandidate
end

function Manager:GetPose(): TCameraPose
	return Options.CreatePose(self._pose)
end

function Manager:GetBounds(): TCameraBounds?
	return Options.CreateBounds(self._bounds)
end

function Manager:SetBounds(bounds: TCameraBounds?)
	local aliveResult = Policies.CheckServiceAlive(self)
	if not aliveResult.success then
		return
	end

	Policies.AssertBounds(bounds)
	self._bounds = Options.CreateBounds(bounds)
	self._pose = Options.ClampPose(self._pose, self._bounds)
end

function Manager:GetCameraCFrame(): Result.Result<CFrame>
	local aliveResult = Policies.CheckServiceAlive(self)
	if not aliveResult.success then
		return aliveResult
	end

	return Result.Ok(Resolver.ResolveCameraCFrame(self._pose))
end

function Manager:GetSnapshot(): Result.Result<TCameraSnapshot>
	local aliveResult = Policies.CheckServiceAlive(self)
	if not aliveResult.success then
		return aliveResult
	end

	return Result.Ok(self:_BuildSnapshot(self:GetCamera()))
end

function Manager:ApplyDefault(applyRequest: TCameraApplyRequest?): Result.Result<TCameraSnapshot>
	return self:_SetResolvedPose(self._defaultPose, applyRequest)
end

function Manager:SetPose(pose: TCameraPoseUpdate, applyRequest: TCameraApplyRequest?): Result.Result<TCameraSnapshot>
	local aliveResult = Policies.CheckServiceAlive(self)
	if not aliveResult.success then
		return aliveResult
	end

	for fieldName, value in pairs(pose) do
		local valueResult = Policies.CheckPoseUpdateValue(fieldName, value)
		if not valueResult.success then
			return valueResult
		end
	end

	local nextPose = Options.ClampPose(Options.MergePose(self._pose, pose), self._bounds)
	return self:_SetResolvedPose(nextPose, applyRequest)
end

function Manager:SetFocusPoint(focusPoint: Vector3, applyRequest: TCameraApplyRequest?): Result.Result<TCameraSnapshot>
	local focusResult = Policies.CheckVector3("FocusPoint", focusPoint)
	if not focusResult.success then
		return focusResult
	end

	return self:SetPose({
		FocusPoint = focusResult.value,
	}, applyRequest)
end

function Manager:FocusOnPart(part: BasePart, applyRequest: TCameraApplyRequest?): Result.Result<TCameraSnapshot>
	local partResult = Policies.CheckBasePart(part)
	if not partResult.success then
		return partResult
	end

	return self:SetFocusPoint(partResult.value.Position, applyRequest)
end

function Manager:FocusOnModel(model: Model, applyRequest: TCameraApplyRequest?): Result.Result<TCameraSnapshot>
	local modelResult = Policies.CheckModel(model)
	if not modelResult.success then
		return modelResult
	end

	return self:SetFocusPoint(ModelPlus.GetCenterPosition(modelResult.value), applyRequest)
end

function Manager:PanBy(worldDelta: Vector3, applyRequest: TCameraApplyRequest?): Result.Result<TCameraSnapshot>
	local worldDeltaResult = Policies.CheckVector3("WorldDelta", worldDelta)
	if not worldDeltaResult.success then
		return worldDeltaResult
	end

	local clampedDelta = Vector3.new(worldDeltaResult.value.X, 0, worldDeltaResult.value.Z)
	return self:SetFocusPoint(self._pose.FocusPoint + clampedDelta, applyRequest)
end

function Manager:ZoomBy(delta: number, applyRequest: TCameraApplyRequest?): Result.Result<TCameraSnapshot>
	local deltaResult = Policies.CheckNumber("Delta", delta)
	if not deltaResult.success then
		return deltaResult
	end

	return self:SetZoom(self._pose.Distance + deltaResult.value, applyRequest)
end

function Manager:SetZoom(distance: number, applyRequest: TCameraApplyRequest?): Result.Result<TCameraSnapshot>
	local distanceResult = Policies.CheckNumber("Distance", distance)
	if not distanceResult.success then
		return distanceResult
	end

	return self:SetPose({
		Distance = distanceResult.value,
	}, applyRequest)
end

function Manager:RotateBy(yawDeltaDegrees: number, applyRequest: TCameraApplyRequest?): Result.Result<TCameraSnapshot>
	local yawDeltaResult = Policies.CheckNumber("YawDeltaDegrees", yawDeltaDegrees)
	if not yawDeltaResult.success then
		return yawDeltaResult
	end

	return self:SetYaw(self._pose.YawDegrees + yawDeltaResult.value, applyRequest)
end

function Manager:SetYaw(yawDegrees: number, applyRequest: TCameraApplyRequest?): Result.Result<TCameraSnapshot>
	local yawResult = Policies.CheckNumber("YawDegrees", yawDegrees)
	if not yawResult.success then
		return yawResult
	end

	return self:SetPose({
		YawDegrees = yawResult.value,
	}, applyRequest)
end

function Manager:SetPitch(pitchDegrees: number, applyRequest: TCameraApplyRequest?): Result.Result<TCameraSnapshot>
	local pitchResult = Policies.CheckNumber("PitchDegrees", pitchDegrees)
	if not pitchResult.success then
		return pitchResult
	end

	return self:SetPose({
		PitchDegrees = pitchResult.value,
	}, applyRequest)
end

function Manager:SetFieldOfView(fieldOfView: number, applyRequest: TCameraApplyRequest?): Result.Result<TCameraSnapshot>
	local fieldOfViewResult = Policies.CheckNumber("FieldOfView", fieldOfView)
	if not fieldOfViewResult.success then
		return fieldOfViewResult
	end

	return self:SetPose({
		FieldOfView = fieldOfViewResult.value,
	}, applyRequest)
end

function Manager:Apply(applyRequest: TCameraApplyRequest?): Result.Result<TCameraSnapshot>
	local aliveResult = Policies.CheckServiceAlive(self)
	if not aliveResult.success then
		return aliveResult
	end

	if applyRequest ~= nil then
		Policies.AssertApplyRequest(applyRequest)
	end

	local cameraHandleResult = self:_ResolveCameraHandle()
	if not cameraHandleResult.success then
		return cameraHandleResult
	end

	local cameraHandle = cameraHandleResult.value
	local resolvedApplyRequest = Options.ResolveApplyRequest(self._config.DefaultApply, applyRequest)
	local snapshot = self:_BuildSnapshot(self._camera)

	cameraHandle:MoveTo(
		snapshot.CameraCFrame,
		resolvedApplyRequest.Duration,
		resolvedApplyRequest.EasingStyle,
		resolvedApplyRequest.EasingDirection
	)
	if resolvedApplyRequest.ApplyFieldOfView then
		cameraHandle:SetFOV(
			snapshot.FieldOfView,
			resolvedApplyRequest.Duration,
			resolvedApplyRequest.EasingStyle,
			resolvedApplyRequest.EasingDirection
		)
	end

	return Result.Ok(snapshot)
end

function Manager:Reset(applyRequest: TCameraApplyRequest?): Result.Result<TCameraSnapshot>
	return self:ApplyDefault(applyRequest)
end

function Manager:Destroy()
	if self._isDestroyed then
		return
	end

	self._isDestroyed = true
	self:_InvalidateCamera()
	self._stash:Destroy()
end

function Manager:_SetResolvedPose(nextPose: TCameraPose, applyRequest: TCameraApplyRequest?): Result.Result<TCameraSnapshot>
	local previousSnapshot = self:_BuildSnapshot(self:GetCamera())
	self._pose = Options.CreatePose(nextPose)

	local applyResult = self:Apply(applyRequest)
	if applyResult.success then
		self.Changed:Fire(applyResult.value, previousSnapshot)
	end

	return applyResult
end

function Manager:_BuildSnapshot(camera: Camera?): TCameraSnapshot
	return table.freeze({
		Pose = Options.CreatePose(self._pose),
		CameraCFrame = Resolver.ResolveCameraCFrame(self._pose),
		FieldOfView = self._pose.FieldOfView,
		Camera = camera,
	})
end

function Manager:_PeekResolvedCamera(): Camera?
	if self._cameraOverride ~= nil then
		return self._cameraOverride
	end

	if self._config.CameraProvider ~= nil then
		return self._config.CameraProvider()
	end

	return Workspace.CurrentCamera
end

function Manager:_ResolveCamera(): Result.Result<Camera>
	local cameraResult = Policies.CheckCamera(self:_PeekResolvedCamera())
	if not cameraResult.success then
		return cameraResult
	end

	local camera = cameraResult.value
	if self._camera ~= camera then
		self._camera = camera
		self._cameraHandle = CameraUtil.Init(camera)
	end

	return Result.Ok(camera)
end

function Manager:_ResolveCameraHandle(): Result.Result<any>
	local cameraResult = self:_ResolveCamera()
	if not cameraResult.success then
		return cameraResult
	end

	if self._cameraHandle == nil then
		self._cameraHandle = CameraUtil.Init(cameraResult.value)
	end

	return Result.Ok(self._cameraHandle)
end

function Manager:_InvalidateCamera()
	self._camera = nil
	self._cameraHandle = nil
end

return table.freeze(Manager)
