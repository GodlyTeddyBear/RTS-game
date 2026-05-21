--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SpatialQuery = require(ReplicatedStorage.Utilities.SpatialQuery)
local FilterRegistry = require(script.Parent.FilterRegistry)
local Types = require(script.Parent.Parent.Types)

type THitbox = Types.Hitbox

local Query = {}

local SHAPE_BLOCK = 1
local SHAPE_BALL = 2

type TQueryCache = {
	OverlapParamsRef: OverlapParams?,
	FilterTypeValue: number?,
	FilterInstancesRef: { Instance }?,
	CollisionGroup: string?,
	RespectCanCollide: boolean?,
	MaxParts: number?,
	Shape: Enum.PartType?,
	Size: Vector3 | number?,
	QueryOptions: any,
	ShapeId: number?,
	ParallelSize: Vector3?,
	FilterToken: string?,
	CanUseParallel: boolean,
}

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

local function _GetOrCreateQueryCache(hitbox: THitbox): TQueryCache
	local queryCache = hitbox._QueryCache
	if queryCache ~= nil then
		return queryCache
	end

	queryCache = {
		OverlapParamsRef = nil,
		FilterTypeValue = nil,
		FilterInstancesRef = nil,
		CollisionGroup = nil,
		RespectCanCollide = nil,
		MaxParts = nil,
		Shape = nil,
		Size = nil,
		QueryOptions = nil,
		ShapeId = nil,
		ParallelSize = nil,
		FilterToken = nil,
		CanUseParallel = false,
	}
	hitbox._QueryCache = queryCache
	return queryCache
end

local function _HasOverlapParamsChanged(queryCache: TQueryCache, overlapParams: OverlapParams): boolean
	local filterInstances = overlapParams.FilterDescendantsInstances
	return queryCache.OverlapParamsRef ~= overlapParams
		or queryCache.FilterTypeValue ~= overlapParams.FilterType.Value
		or queryCache.FilterInstancesRef ~= filterInstances
		or queryCache.CollisionGroup ~= overlapParams.CollisionGroup
		or queryCache.RespectCanCollide ~= overlapParams.RespectCanCollide
		or queryCache.MaxParts ~= overlapParams.MaxParts
end

local function _HasShapeStateChanged(queryCache: TQueryCache, hitbox: THitbox): boolean
	return queryCache.Shape ~= hitbox.Shape or queryCache.Size ~= hitbox.Size
end

local function _ResolveQueryCache(hitbox: THitbox): TQueryCache
	local queryCache = _GetOrCreateQueryCache(hitbox)
	local overlapParams = hitbox.OverlapParams
	local didOverlapParamsChange = _HasOverlapParamsChanged(queryCache, overlapParams)
	local didShapeStateChange = _HasShapeStateChanged(queryCache, hitbox)

	if didOverlapParamsChange then
		queryCache.OverlapParamsRef = overlapParams
		queryCache.FilterTypeValue = overlapParams.FilterType.Value
		queryCache.FilterInstancesRef = overlapParams.FilterDescendantsInstances
		queryCache.CollisionGroup = overlapParams.CollisionGroup
		queryCache.RespectCanCollide = overlapParams.RespectCanCollide
		queryCache.MaxParts = overlapParams.MaxParts
		queryCache.QueryOptions = buildQueryOptionsFromOverlapParams(overlapParams)
		queryCache.FilterToken = nil
	end

	if didShapeStateChange then
		queryCache.Shape = hitbox.Shape
		queryCache.Size = hitbox.Size
		queryCache.ShapeId = resolveShapeId(hitbox.Shape)
		queryCache.ParallelSize = if queryCache.ShapeId ~= nil
			then resolveParallelSize(queryCache.ShapeId, hitbox.Size)
			else nil
	end

	if didOverlapParamsChange or didShapeStateChange then
		queryCache.CanUseParallel = FilterRegistry.SupportsParallelOverlapParams(overlapParams)
			and queryCache.ShapeId ~= nil
			and queryCache.ParallelSize ~= nil
	end

	return queryCache
end

function Query.CastSpatialQuery(hitbox: THitbox, hitboxCFrame: CFrame): { BasePart }
	local queryCache = _ResolveQueryCache(hitbox)
	local shapeId = queryCache.ShapeId
	if not shapeId then
		error("Part type: " .. tostring(hitbox.Shape) .. " isn't compatible with MuchachoHitbox")
	end

	return castQueryByShape(
		hitboxCFrame,
		hitbox.Size,
		shapeId,
		queryCache.QueryOptions
	)
end

function Query.BuildParallelSnapshot(hitbox: THitbox, _hitboxCFrame: CFrame): (Vector3?, number?, string?)
	local queryCache = _ResolveQueryCache(hitbox)
	if not queryCache.CanUseParallel then
		return nil, nil, nil
	end

	local filterToken = queryCache.FilterToken
	if not filterToken then
		filterToken = FilterRegistry.SyncOverlapParams(hitbox.Key, hitbox.OverlapParams)
		if not filterToken then
			return nil, nil, nil
		end
		queryCache.FilterToken = filterToken
	end

	return queryCache.ParallelSize, queryCache.ShapeId, filterToken
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
