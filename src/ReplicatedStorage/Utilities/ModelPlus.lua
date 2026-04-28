--!strict

--[=[
    @class ModelPlus
    Shared `Model` transform helpers for pivot, bounds, alignment, rotation, and grid snapping.
    Client and server placement code use this module to keep model movement math consistent.
    @server
    @client
]=]

type TGridSize = number | Vector3

local _AssertModel: (model: Model) -> ()
local _GetPivotRotation: (cframe: CFrame) -> CFrame
local _BuildPivotWithPositionAndRotation: (position: Vector3, rotation: CFrame) -> CFrame
local _ResolveGridSize: (gridSize: TGridSize) -> Vector3
local _SnapScalar: (value: number, step: number) -> number
local _GetYawFromRotation: (rotation: CFrame) -> number

local ModelPlus = {}
local MIN_DIRECTION_MAGNITUDE = 1e-5

-- ── Public ────────────────────────────────────────────────────────────────

--[=[
    Get the current pivot CFrame for a model.
    @within ModelPlus
    @param model Model -- The model to inspect.
    @return CFrame -- The model pivot.
    @error string -- Thrown when `model` is nil.
]=]
function ModelPlus.GetPivot(model: Model): CFrame
	_AssertModel(model)
	return model:GetPivot()
end

--[=[
    Get the current pivot position for a model.
    @within ModelPlus
    @param model Model -- The model to inspect.
    @return Vector3 -- The pivot position.
    @error string -- Thrown when `model` is nil.
]=]
function ModelPlus.GetPosition(model: Model): Vector3
	return ModelPlus.GetPivot(model).Position
end

--[=[
    Get the current pivot rotation for a model.
    @within ModelPlus
    @param model Model -- The model to inspect.
    @return CFrame -- The pivot rotation without translation.
    @error string -- Thrown when `model` is nil.
]=]
function ModelPlus.GetRotation(model: Model): CFrame
	return _GetPivotRotation(ModelPlus.GetPivot(model))
end

--[=[
    Get the model bounding box.
    @within ModelPlus
    @param model Model -- The model to inspect.
    @return CFrame -- The bounding-box CFrame.
    @return Vector3 -- The bounding-box size.
    @error string -- Thrown when `model` is nil.
]=]
function ModelPlus.GetBounds(model: Model): (CFrame, Vector3)
	_AssertModel(model)
	return model:GetBoundingBox()
end

--[=[
    Get the bounding-box center position for a model.
    @within ModelPlus
    @param model Model -- The model to inspect.
    @return Vector3 -- The bounding-box center position.
    @error string -- Thrown when `model` is nil.
]=]
function ModelPlus.GetCenterPosition(model: Model): Vector3
	local boundsCFrame, _ = ModelPlus.GetBounds(model)
	return boundsCFrame.Position
end

--[=[
    Get the Y coordinate of the model's lowest bound.
    @within ModelPlus
    @param model Model -- The model to inspect.
    @return number -- The bottom-most Y position.
    @error string -- Thrown when `model` is nil.
]=]
function ModelPlus.GetBottomY(model: Model): number
	local boundsCFrame, boundsSize = ModelPlus.GetBounds(model)
	return boundsCFrame.Position.Y - (boundsSize.Y * 0.5)
end

--[=[
    Get the Y coordinate of the model's highest bound.
    @within ModelPlus
    @param model Model -- The model to inspect.
    @return number -- The top-most Y position.
    @error string -- Thrown when `model` is nil.
]=]
function ModelPlus.GetTopY(model: Model): number
	local boundsCFrame, boundsSize = ModelPlus.GetBounds(model)
	return boundsCFrame.Position.Y + (boundsSize.Y * 0.5)
end

--[=[
    Build a pivot that keeps the model rotation and moves it to a world position.
    @within ModelPlus
    @param model Model -- The model to reposition.
    @param worldPos Vector3 -- The target pivot position.
    @return CFrame -- The new pivot CFrame.
    @error string -- Thrown when `model` is nil.
]=]
function ModelPlus.BuildPivotAtPosition(model: Model, worldPos: Vector3): CFrame
	local pivotRotation = ModelPlus.GetRotation(model)
	return _BuildPivotWithPositionAndRotation(worldPos, pivotRotation)
end

--[=[
    Build a pivot that exactly matches a supplied CFrame.
    @within ModelPlus
    @param model Model -- The model to reposition.
    @param targetCFrame CFrame -- The target pivot transform.
    @return CFrame -- The new pivot CFrame.
    @error string -- Thrown when `model` is nil.
]=]
function ModelPlus.BuildPivotFromCFrame(model: Model, targetCFrame: CFrame): CFrame
	_AssertModel(model)
	return _BuildPivotWithPositionAndRotation(targetCFrame.Position, _GetPivotRotation(targetCFrame))
end

--[=[
    Build a CFrame that preserves rotation and replaces only translation.
    @within ModelPlus
    @param sourceCFrame CFrame -- The source transform whose rotation should be preserved.
    @param targetPosition Vector3 -- The replacement world position.
    @return CFrame -- The rebuilt transform.
]=]
function ModelPlus.BuildCFrameAtPosition(sourceCFrame: CFrame, targetPosition: Vector3): CFrame
	return _BuildPivotWithPositionAndRotation(targetPosition, _GetPivotRotation(sourceCFrame))
end

--[=[
    Build a look-at CFrame from one world position toward another.
    @within ModelPlus
    @param position Vector3 -- The world position to place the transform at.
    @param lookAtPosition Vector3 -- The world position to face.
    @return CFrame? -- The look-at CFrame, or `nil` when the direction is degenerate.
]=]
function ModelPlus.BuildLookAtCFrame(position: Vector3, lookAtPosition: Vector3): CFrame?
	local direction = lookAtPosition - position
	if direction.Magnitude <= MIN_DIRECTION_MAGNITUDE then
		return nil
	end

	return CFrame.lookAt(position, lookAtPosition)
end

--[=[
    Build a horizontal look-at CFrame by flattening the target direction onto the XZ plane.
    @within ModelPlus
    @param fromPosition Vector3 -- The world position to place the transform at.
    @param toPosition Vector3 -- The world position to face toward on the ground plane.
    @return CFrame? -- The flattened look-at CFrame, or `nil` when the direction is degenerate.
]=]
function ModelPlus.BuildFlatLookAtCFrame(fromPosition: Vector3, toPosition: Vector3): CFrame?
	local flatTarget = Vector3.new(toPosition.X, fromPosition.Y, toPosition.Z)
	return ModelPlus.BuildLookAtCFrame(fromPosition, flatTarget)
end

--[=[
    Build a pivot that bottom-aligns the model to a world position.
    @within ModelPlus
    @param model Model -- The model to reposition.
    @param targetWorldPos Vector3 -- The world position the bottom face should touch.
    @return CFrame -- The new pivot CFrame.
    @error string -- Thrown when `model` is nil.
]=]
function ModelPlus.BuildBottomAlignedPivot(model: Model, targetWorldPos: Vector3): CFrame
	-- Read the current pivot and bounding box so alignment preserves rotation and uses real model bounds.
	local currentPivot = ModelPlus.GetPivot(model)
	local currentBottomY = ModelPlus.GetBottomY(model)

	-- Offset the pivot in Y until the model's bottom face touches the target world position.
	local yOffset = targetWorldPos.Y - currentBottomY
	local targetPivotPosition = Vector3.new(
		targetWorldPos.X,
		currentPivot.Position.Y + yOffset,
		targetWorldPos.Z
	)

	-- Rebuild the pivot from the preserved rotation and new target position.
	return _BuildPivotWithPositionAndRotation(targetPivotPosition, _GetPivotRotation(currentPivot))
end

--[=[
    Build a pivot that top-aligns the model to a world position.
    @within ModelPlus
    @param model Model -- The model to reposition.
    @param targetWorldPos Vector3 -- The world position the top face should touch.
    @return CFrame -- The new pivot CFrame.
    @error string -- Thrown when `model` is nil.
]=]
function ModelPlus.BuildTopAlignedPivot(model: Model, targetWorldPos: Vector3): CFrame
	-- Read the current pivot and bounding box so alignment preserves rotation and uses real model bounds.
	local currentPivot = ModelPlus.GetPivot(model)
	local currentTopY = ModelPlus.GetTopY(model)

	-- Offset the pivot in Y until the model's top face touches the target world position.
	local yOffset = targetWorldPos.Y - currentTopY
	local targetPivotPosition = Vector3.new(
		targetWorldPos.X,
		currentPivot.Position.Y + yOffset,
		targetWorldPos.Z
	)

	-- Rebuild the pivot from the preserved rotation and new target position.
	return _BuildPivotWithPositionAndRotation(targetPivotPosition, _GetPivotRotation(currentPivot))
end

--[=[
    Build a pivot that translates the model by a delta vector.
    @within ModelPlus
    @param model Model -- The model to reposition.
    @param delta Vector3 -- The world-space offset to apply.
    @return CFrame -- The new pivot CFrame.
    @error string -- Thrown when `model` is nil.
]=]
function ModelPlus.BuildTranslatedPivot(model: Model, delta: Vector3): CFrame
	local currentPivot = ModelPlus.GetPivot(model)
	local targetPosition = currentPivot.Position + delta
	return _BuildPivotWithPositionAndRotation(targetPosition, _GetPivotRotation(currentPivot))
end

--[=[
    Build a pivot that rotates the model around its own Y axis.
    @within ModelPlus
    @param model Model -- The model to rotate.
    @param yawRadians number -- The absolute yaw rotation to apply in radians.
    @return CFrame -- The new pivot CFrame.
    @error string -- Thrown when `model` is nil.
]=]
function ModelPlus.BuildYawRotatedPivot(model: Model, yawRadians: number): CFrame
	local currentPivot = ModelPlus.GetPivot(model)
	local targetRotation = CFrame.Angles(0, yawRadians, 0) * _GetPivotRotation(currentPivot)
	return _BuildPivotWithPositionAndRotation(currentPivot.Position, targetRotation)
end

--[=[
    Build a pivot that rotates the model around an arbitrary world point.
    @within ModelPlus
    @param model Model -- The model to rotate.
    @param point Vector3 -- The world point to rotate around.
    @param rotation CFrame -- The rotation to apply.
    @return CFrame -- The new pivot CFrame.
    @error string -- Thrown when `model` is nil.
]=]
function ModelPlus.BuildRotatedPivotAroundPoint(model: Model, point: Vector3, rotation: CFrame): CFrame
	-- Strip translation from the input rotation so the pivot math only uses orientation.
	local currentPivot = ModelPlus.GetPivot(model)
	local rotationOnly = _GetPivotRotation(rotation)

	-- Rotate the pivot offset around the point, then combine the requested rotation with the model's current orientation.
	local offset = currentPivot.Position - point
	local targetPosition = point + rotationOnly:VectorToWorldSpace(offset)
	local targetRotation = rotationOnly * _GetPivotRotation(currentPivot)

	return _BuildPivotWithPositionAndRotation(targetPosition, targetRotation)
end

--[=[
    Snap a world position to a grid.
    @within ModelPlus
    @param worldPos Vector3 -- The world position to snap.
    @param gridSize number | Vector3 -- The grid size to use.
    @return Vector3 -- The snapped world position.
]=]
function ModelPlus.SnapVector3ToGrid(worldPos: Vector3, gridSize: TGridSize): Vector3
	-- Resolve scalar or vector grid input into a per-axis size before snapping.
	local resolvedGridSize = _ResolveGridSize(gridSize)

	return Vector3.new(
		_SnapScalar(worldPos.X, resolvedGridSize.X),
		_SnapScalar(worldPos.Y, resolvedGridSize.Y),
		_SnapScalar(worldPos.Z, resolvedGridSize.Z)
	)
end

--[=[
    Build a pivot that snaps the model to a grid before repositioning.
    @within ModelPlus
    @param model Model -- The model to reposition.
    @param worldPos Vector3 -- The world position to snap before moving.
    @param gridSize number | Vector3 -- The grid size to use.
    @return CFrame -- The new pivot CFrame.
    @error string -- Thrown when `model` is nil.
]=]
function ModelPlus.BuildGridSnappedPivot(model: Model, worldPos: Vector3, gridSize: TGridSize): CFrame
	local snappedPosition = ModelPlus.SnapVector3ToGrid(worldPos, gridSize)
	return ModelPlus.BuildPivotAtPosition(model, snappedPosition)
end

--[=[
    Build a pivot with yaw snapped to a fixed angular step.
    @within ModelPlus
    @param model Model -- The model to rotate.
    @param angleStepDegrees number -- The yaw step size in degrees.
    @return CFrame -- The new pivot CFrame.
    @error string -- Thrown when `model` is nil or `angleStepDegrees` is not positive.
]=]
function ModelPlus.BuildYawSnappedPivot(model: Model, angleStepDegrees: number): CFrame
	assert(angleStepDegrees > 0, "ModelPlus.BuildYawSnappedPivot requires a positive angleStepDegrees")

	-- Read the current yaw so the snap is relative to the model's existing facing.
	local currentPivot = ModelPlus.GetPivot(model)
	local currentRotation = _GetPivotRotation(currentPivot)
	local currentYaw = _GetYawFromRotation(currentRotation)

	-- Snap the yaw angle, then apply only the delta so the pivot position stays fixed.
	local angleStepRadians = math.rad(angleStepDegrees)
	local snappedYaw = _SnapScalar(currentYaw, angleStepRadians)
	local deltaYaw = snappedYaw - currentYaw
	local targetRotation = CFrame.Angles(0, deltaYaw, 0) * currentRotation

	return _BuildPivotWithPositionAndRotation(currentPivot.Position, targetRotation)
end

--[=[
    Move a model to a world position while preserving rotation.
    @within ModelPlus
    @param model Model -- The model to move.
    @param worldPos Vector3 -- The target pivot position.
    @error string -- Thrown when `model` is nil.
]=]
function ModelPlus.MoveToPosition(model: Model, worldPos: Vector3)
	model:PivotTo(ModelPlus.BuildPivotAtPosition(model, worldPos))
end

--[=[
    Move a model to an exact target CFrame.
    @within ModelPlus
    @param model Model -- The model to move.
    @param targetCFrame CFrame -- The target pivot transform.
    @error string -- Thrown when `model` is nil.
]=]
function ModelPlus.MoveToCFrame(model: Model, targetCFrame: CFrame)
	model:PivotTo(ModelPlus.BuildPivotFromCFrame(model, targetCFrame))
end

--[=[
    Move a model so its bottom face rests on a world position.
    @within ModelPlus
    @param model Model -- The model to move.
    @param targetWorldPos Vector3 -- The target bottom-alignment position.
    @error string -- Thrown when `model` is nil.
]=]
function ModelPlus.MoveBottomAligned(model: Model, targetWorldPos: Vector3)
	model:PivotTo(ModelPlus.BuildBottomAlignedPivot(model, targetWorldPos))
end

--[=[
    Move a model so its top face rests on a world position.
    @within ModelPlus
    @param model Model -- The model to move.
    @param targetWorldPos Vector3 -- The target top-alignment position.
    @error string -- Thrown when `model` is nil.
]=]
function ModelPlus.MoveTopAligned(model: Model, targetWorldPos: Vector3)
	model:PivotTo(ModelPlus.BuildTopAlignedPivot(model, targetWorldPos))
end

--[=[
    Translate a model by a world-space delta.
    @within ModelPlus
    @param model Model -- The model to move.
    @param delta Vector3 -- The offset to apply.
    @error string -- Thrown when `model` is nil.
]=]
function ModelPlus.Translate(model: Model, delta: Vector3)
	model:PivotTo(ModelPlus.BuildTranslatedPivot(model, delta))
end

--[=[
    Rotate a model around its own Y axis.
    @within ModelPlus
    @param model Model -- The model to rotate.
    @param yawRadians number -- The yaw rotation in radians.
    @error string -- Thrown when `model` is nil.
]=]
function ModelPlus.RotateYaw(model: Model, yawRadians: number)
	model:PivotTo(ModelPlus.BuildYawRotatedPivot(model, yawRadians))
end

--[=[
    Rotate a model around an arbitrary world point.
    @within ModelPlus
    @param model Model -- The model to rotate.
    @param point Vector3 -- The world point to rotate around.
    @param rotation CFrame -- The rotation to apply.
    @error string -- Thrown when `model` is nil.
]=]
function ModelPlus.RotateAroundPoint(model: Model, point: Vector3, rotation: CFrame)
	model:PivotTo(ModelPlus.BuildRotatedPivotAroundPoint(model, point, rotation))
end

--[=[
    Move a model after snapping the target position to a grid.
    @within ModelPlus
    @param model Model -- The model to move.
    @param worldPos Vector3 -- The target position to snap.
    @param gridSize number | Vector3 -- The grid size to use.
    @error string -- Thrown when `model` is nil.
]=]
function ModelPlus.MoveSnappedToGrid(model: Model, worldPos: Vector3, gridSize: TGridSize)
	model:PivotTo(ModelPlus.BuildGridSnappedPivot(model, worldPos, gridSize))
end

--[=[
    Snap a model's yaw to a fixed angular step.
    @within ModelPlus
    @param model Model -- The model to rotate.
    @param angleStepDegrees number -- The yaw step size in degrees.
    @error string -- Thrown when `model` is nil or `angleStepDegrees` is not positive.
]=]
function ModelPlus.SnapYaw(model: Model, angleStepDegrees: number)
	model:PivotTo(ModelPlus.BuildYawSnappedPivot(model, angleStepDegrees))
end

-- ── Private ───────────────────────────────────────────────────────────────

-- Fails fast when callers pass a nil model into the shared transform helpers.
_AssertModel = function(model: Model)
	assert(model ~= nil, "ModelPlus requires a model instance")
end

-- Removes translation from a pivot or rotation CFrame so only orientation remains.
_GetPivotRotation = function(cframe: CFrame): CFrame
	return cframe - cframe.Position
end

-- Rebuilds a pivot CFrame from a world position and an existing rotation.
_BuildPivotWithPositionAndRotation = function(position: Vector3, rotation: CFrame): CFrame
	return CFrame.new(position) * rotation
end

-- Normalizes grid size input into a per-axis Vector3 and rejects non-positive values.
_ResolveGridSize = function(gridSize: TGridSize): Vector3
	if type(gridSize) == "number" then
		assert(gridSize > 0, "ModelPlus gridSize must be positive")
		return Vector3.new(gridSize, gridSize, gridSize)
	end

	assert(gridSize.X > 0 and gridSize.Y > 0 and gridSize.Z > 0, "ModelPlus gridSize Vector3 must be positive")
	return gridSize
end

-- Rounds a scalar to the nearest grid step.
_SnapScalar = function(value: number, step: number): number
	return math.round(value / step) * step
end

-- Extracts yaw from a rotation CFrame so yaw snapping can preserve the current facing.
_GetYawFromRotation = function(rotation: CFrame): number
	local lookVector = rotation.LookVector
	return math.atan2(-lookVector.X, -lookVector.Z)
end

return ModelPlus
