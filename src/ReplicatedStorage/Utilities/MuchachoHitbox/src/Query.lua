--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SpatialQuery = require(ReplicatedStorage.Utilities.SpatialQuery)
local FilterRegistry = require(script.Parent.FilterRegistry)
local Types = require(script.Parent.Parent.Types)

type THitbox = Types.Hitbox

local Query = {}

local SHAPE_BLOCK = 1
local SHAPE_BALL = 2

local function buildQueryOptionsFromOverlapParams(overlapParams: OverlapParams)
	return SpatialQuery.CreateOverlapOptions({
		FilterType = overlapParams.FilterType,
		FilterDescendantsInstances = overlapParams.FilterDescendantsInstances,
		CollisionGroup = overlapParams.CollisionGroup,
		RespectCanCollide = overlapParams.RespectCanCollide,
		MaxParts = overlapParams.MaxParts,
	})
end

local function resolveShapeId(shape: Enum.PartType): number?
	if shape == Enum.PartType.Block then
		return SHAPE_BLOCK
	end
	if shape == Enum.PartType.Ball then
		return SHAPE_BALL
	end

	return nil
end

local function resolveBallRadius(size: Vector3 | number): number?
	if type(size) == "number" then
		return size
	end
	if typeof(size) == "Vector3" then
		return math.max(size.X, size.Y, size.Z) * 0.5
	end

	return nil
end

local function resolveParallelSize(shapeId: number, size: Vector3 | number): Vector3?
	if shapeId == SHAPE_BLOCK then
		if typeof(size) == "Vector3" then
			return size
		end

		return nil
	end

	if shapeId == SHAPE_BALL then
		local radius = resolveBallRadius(size)
		if not radius then
			return nil
		end

		local diameter = radius * 2
		return Vector3.new(diameter, diameter, diameter)
	end

	return nil
end

local function castQueryByShape(
	queryCFrame: CFrame,
	size: Vector3 | number,
	shapeId: number,
	queryOptions: any
): { BasePart }
	if shapeId == SHAPE_BLOCK then
		if typeof(size) ~= "Vector3" then
			return {}
		end

		return SpatialQuery.OverlapBox(queryCFrame, size, queryOptions)
	end
	if shapeId == SHAPE_BALL then
		local radius = resolveBallRadius(size)
		if not radius then
			return {}
		end

		return SpatialQuery.OverlapRadius(queryCFrame.Position, radius, queryOptions)
	end

	error("Unsupported MuchachoHitbox shape id: " .. tostring(shapeId))
end

function Query.CastSpatialQuery(hitbox: THitbox, hitboxCFrame: CFrame): { BasePart }
	local shapeId = resolveShapeId(hitbox.Shape)
	if not shapeId then
		error("Part type: " .. tostring(hitbox.Shape) .. " isn't compatible with MuchachoHitbox")
	end

	return castQueryByShape(
		hitboxCFrame,
		hitbox.Size,
		shapeId,
		buildQueryOptionsFromOverlapParams(hitbox.OverlapParams)
	)
end

function Query.BuildParallelSnapshot(hitbox: THitbox, _hitboxCFrame: CFrame): (Vector3?, number?, string?)
	local overlapParams = hitbox.OverlapParams
	if not FilterRegistry.SupportsParallelOverlapParams(overlapParams) then
		return nil, nil, nil
	end

	local shapeId = resolveShapeId(hitbox.Shape)
	local parallelSize = shapeId and resolveParallelSize(shapeId, hitbox.Size) or nil
	if shapeId == nil or parallelSize == nil then
		return nil, nil, nil
	end

	local filterToken = FilterRegistry.SyncOverlapParams(hitbox.Key, overlapParams)
	if not filterToken then
		return nil, nil, nil
	end

	return parallelSize, shapeId, filterToken
end

function Query.CastParallelPresenceQuery(
	queryCFrame: CFrame,
	size: Vector3,
	shapeId: number,
	filterToken: string
): boolean
	local overlapParams = FilterRegistry.ResolveOverlapParams(filterToken)
	if not overlapParams then
		return false
	end

	local parts = castQueryByShape(queryCFrame, size, shapeId, buildQueryOptionsFromOverlapParams(overlapParams))
	return #parts > 0
end

return Query
