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
		if radius == nil then
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
		if radius == nil then
			return {}
		end

		return SpatialQuery.OverlapRadius(queryCFrame.Position, radius, queryOptions)
	end

	error("Unsupported MuchachoHitbox shape id: " .. tostring(shapeId))
end

function Query.CastSpatialQuery(hitbox: THitbox, hitboxCFrame: CFrame): { BasePart }
	local shapeId = resolveShapeId(hitbox.Shape)
	if shapeId == nil then
		error("Part type: " .. tostring(hitbox.Shape) .. " isn't compatible with MuchachoHitbox")
	end

	return castQueryByShape(hitboxCFrame, hitbox.Size, shapeId, buildQueryOptionsFromOverlapParams(hitbox.OverlapParams))
end

function Query.BuildParallelSnapshot(hitbox: THitbox, hitboxCFrame: CFrame): { QueryCFrame: CFrame, Size: Vector3, ShapeId: number, FilterToken: string }?
	local overlapParams = hitbox.OverlapParams
	if not FilterRegistry.SupportsParallelOverlapParams(overlapParams) then
		return nil
	end

	local shapeId = resolveShapeId(hitbox.Shape)
	local parallelSize = if shapeId ~= nil then resolveParallelSize(shapeId, hitbox.Size) else nil
	if shapeId == nil or parallelSize == nil then
		return nil
	end

	local filterToken = FilterRegistry.SyncOverlapParams(hitbox.Key, overlapParams)
	if filterToken == nil then
		return nil
	end

	return {
		QueryCFrame = hitboxCFrame,
		Size = parallelSize,
		ShapeId = shapeId,
		FilterToken = filterToken,
	}
end

function Query.CastParallelPresenceQuery(queryCFrame: CFrame, size: Vector3, shapeId: number, filterToken: string): boolean
	local overlapParams = FilterRegistry.ResolveOverlapParams(filterToken)
	if overlapParams == nil then
		return false
	end

	local parts = castQueryByShape(queryCFrame, size, shapeId, buildQueryOptionsFromOverlapParams(overlapParams))
	return #parts > 0
end

return Query
