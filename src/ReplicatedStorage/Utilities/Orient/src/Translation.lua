--!strict

local Facing = require(script.Parent.Facing)

--[=[
    @class OrientTranslation
    Translation and offset helpers for `Orient`.
    @server
    @client
]=]
local Translation = {}

function Translation.BuildAtPosition(sourceCFrame: CFrame, targetPosition: Vector3): CFrame
	return Facing.BuildFromRotation(targetPosition, sourceCFrame)
end

function Translation.TranslateWorld(cframe: CFrame, delta: Vector3): CFrame
	return Translation.BuildAtPosition(cframe, cframe.Position + delta)
end

function Translation.TranslateLocal(cframe: CFrame, localDelta: Vector3): CFrame
	local worldDelta = cframe:VectorToWorldSpace(localDelta)
	return Translation.TranslateWorld(cframe, worldDelta)
end

function Translation.OffsetWorld(position: Vector3, delta: Vector3): Vector3
	return position + delta
end

function Translation.OffsetLocal(cframe: CFrame, localDelta: Vector3): Vector3
	return cframe:PointToWorldSpace(localDelta)
end

function Translation.MoveTowards(current: Vector3, goal: Vector3, maxDistance: number): Vector3
	if maxDistance <= 0 then
		return current
	end

	local delta = goal - current
	local distance = delta.Magnitude
	if distance <= 0 then
		return current
	end
	if distance <= maxDistance then
		return goal
	end

	return current + delta.Unit * maxDistance
end

function Translation.MoveCFrameTowards(cframe: CFrame, goalPosition: Vector3, maxDistance: number): CFrame
	local nextPosition = Translation.MoveTowards(cframe.Position, goalPosition, maxDistance)
	return Translation.BuildAtPosition(cframe, nextPosition)
end

function Translation.WithX(cframe: CFrame, x: number): CFrame
	return Translation.BuildAtPosition(cframe, Vector3.new(x, cframe.Position.Y, cframe.Position.Z))
end

function Translation.WithY(cframe: CFrame, y: number): CFrame
	return Translation.BuildAtPosition(cframe, Vector3.new(cframe.Position.X, y, cframe.Position.Z))
end

function Translation.WithZ(cframe: CFrame, z: number): CFrame
	return Translation.BuildAtPosition(cframe, Vector3.new(cframe.Position.X, cframe.Position.Y, z))
end

function Translation.WithPosition(cframe: CFrame, position: Vector3): CFrame
	return Translation.BuildAtPosition(cframe, position)
end

return table.freeze(Translation)
