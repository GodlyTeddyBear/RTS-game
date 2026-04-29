--!strict

local Constants = require(script.Parent.Constants)

local DEGENERATE_EPSILON = Constants.DEGENERATE_EPSILON

local function _GetRotationOnly(cframe: CFrame): CFrame
	return cframe - cframe.Position
end

--[=[
    @class OrientConversion
    Conversion and decomposition helpers for `Orient`.

    Use this module when you need to read, rebuild, or swap pieces of a
    `CFrame` without changing its semantic position or rotation.
    @server
    @client
]=]
local Conversion = {}

-- Component access
function Conversion.GetPosition(cframe: CFrame): Vector3
	return cframe.Position
end

function Conversion.GetX(cframe: CFrame): number
	return cframe.Position.X
end

function Conversion.GetY(cframe: CFrame): number
	return cframe.Position.Y
end

function Conversion.GetZ(cframe: CFrame): number
	return cframe.Position.Z
end

function Conversion.GetComponents(cframe: CFrame): (Vector3, CFrame)
	return cframe.Position, _GetRotationOnly(cframe)
end

-- Space conversions
function Conversion.ToObjectSpace(from: CFrame, target: CFrame): CFrame
	return from:ToObjectSpace(target)
end

function Conversion.ToWorldSpace(from: CFrame, localTransform: CFrame): CFrame
	return from:ToWorldSpace(localTransform)
end

function Conversion.PointToObjectSpace(from: CFrame, worldPoint: Vector3): Vector3
	return from:PointToObjectSpace(worldPoint)
end

function Conversion.PointToWorldSpace(from: CFrame, localPoint: Vector3): Vector3
	return from:PointToWorldSpace(localPoint)
end

function Conversion.VectorToObjectSpace(from: CFrame, worldVector: Vector3): Vector3
	return from:VectorToObjectSpace(worldVector)
end

function Conversion.VectorToWorldSpace(from: CFrame, localVector: Vector3): Vector3
	return from:VectorToWorldSpace(localVector)
end

-- Constructors
function Conversion.FromPosition(position: Vector3): CFrame
	return CFrame.new(position)
end

function Conversion.FromPositionAndYaw(position: Vector3, yawRadians: number): CFrame
	return CFrame.new(position) * CFrame.Angles(0, yawRadians, 0)
end

function Conversion.FromLookVector(position: Vector3, lookVector: Vector3): CFrame?
	if lookVector.Magnitude <= DEGENERATE_EPSILON then
		return nil
	end

	return CFrame.lookAt(position, position + lookVector)
end

function Conversion.FromFlatLookVector(position: Vector3, lookVector: Vector3): CFrame?
	local flatLookVector = Vector3.new(lookVector.X, 0, lookVector.Z)
	return Conversion.FromLookVector(position, flatLookVector)
end

-- Rotation replacement
function Conversion.WithRotation(position: Vector3, rotation: CFrame): CFrame
	return CFrame.new(position) * _GetRotationOnly(rotation)
end

function Conversion.WithLookVector(position: Vector3, lookVector: Vector3): CFrame?
	return Conversion.FromLookVector(position, lookVector)
end

function Conversion.WithFlatLookVector(position: Vector3, lookVector: Vector3): CFrame?
	return Conversion.FromFlatLookVector(position, lookVector)
end

return table.freeze(Conversion)
