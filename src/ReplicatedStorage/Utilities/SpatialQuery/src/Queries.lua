--!strict

local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")

local Shared = require(script.Parent.Shared)
local Options = require(script.Parent.Options)
local Types = require(script.Parent.Types)
local VectorViz = require(script.Parent.Parent.Parent.VectorViz)

type TQueryOptions = Types.TQueryOptions
type TVisualizationOptions = Types.TVisualizationOptions

local DEFAULT_VISUALIZATION_COLOR = Color3.fromRGB(255, 0, 0)
local DEFAULT_VISUALIZATION_WIDTH = 0.2
local DEFAULT_VISUALIZATION_SCALE = 1
local DEFAULT_VISUALIZATION_DURATION = 0.1
local MIN_VISUALIZATION_DURATION = 0.01
local ACTIVE_VISUALIZATION_TOKENS = {} :: { [string]: string }
local ACTIVE_SHAPE_VISUALIZATION_TOKENS = {} :: { [string]: string }

--[=[
    @class SpatialQueryQueries
    Raw spatial query wrappers and geometric range helpers for `Workspace` queries.
    @server
    @client
]=]

-- ── Public ────────────────────────────────────────────────────────────────────

local Queries = {}

local function _ResolvePositiveNumberOrDefault(value: number?, defaultValue: number): number
	if value == nil or not Shared.IsPositiveNumber(value) then
		return defaultValue
	end

	return value
end

local function _ResolveVisualizationOptions(options: TQueryOptions?): TVisualizationOptions?
	if options == nil or options.Visualization == nil or options.Visualization.Enabled ~= true then
		return nil
	end

	return {
		Enabled = true,
		Color = options.Visualization.Color or DEFAULT_VISUALIZATION_COLOR,
		Width = _ResolvePositiveNumberOrDefault(options.Visualization.Width, DEFAULT_VISUALIZATION_WIDTH),
		Scale = _ResolvePositiveNumberOrDefault(options.Visualization.Scale, DEFAULT_VISUALIZATION_SCALE),
		Duration = math.max(
			_ResolvePositiveNumberOrDefault(options.Visualization.Duration, DEFAULT_VISUALIZATION_DURATION),
			MIN_VISUALIZATION_DURATION
		),
		Name = options.Visualization.Name,
	}
end

local function _ResolveVisualizationOptionsForShapeCast(
	options: TQueryOptions?,
	visualize: boolean?
): TVisualizationOptions?
	if visualize == false then
		return nil
	end

	if visualize == true then
		local source = if options ~= nil then options.Visualization else nil
		return {
			Enabled = true,
			Color = if source ~= nil and source.Color ~= nil then source.Color else DEFAULT_VISUALIZATION_COLOR,
			Width = _ResolvePositiveNumberOrDefault(
				if source ~= nil then source.Width else nil,
				DEFAULT_VISUALIZATION_WIDTH
			),
			Scale = _ResolvePositiveNumberOrDefault(
				if source ~= nil then source.Scale else nil,
				DEFAULT_VISUALIZATION_SCALE
			),
			Duration = math.max(
				_ResolvePositiveNumberOrDefault(
					if source ~= nil then source.Duration else nil,
					DEFAULT_VISUALIZATION_DURATION
				),
				MIN_VISUALIZATION_DURATION
			),
			Name = if source ~= nil then source.Name else nil,
		}
	end

	return _ResolveVisualizationOptions(options)
end

local function _VisualizeRaycast(origin: Vector3, direction: Vector3, raycastResult: RaycastResult?, options: TQueryOptions?)
	local visualizationOptions = _ResolveVisualizationOptions(options)
	if visualizationOptions == nil then
		return
	end

	local visualName = visualizationOptions.Name or ("SpatialQueryRay_%s"):format(HttpService:GenerateGUID(false))
	local visualToken = HttpService:GenerateGUID(false)
	local visualDirection = direction
	if raycastResult ~= nil then
		visualDirection = raycastResult.Position - origin
	end

	ACTIVE_VISUALIZATION_TOKENS[visualName] = visualToken
	VectorViz:CreateVisualiser(visualName, origin, visualDirection, {
		Colour = visualizationOptions.Color,
		Width = visualizationOptions.Width,
		Scale = visualizationOptions.Scale,
	})

	task.delay(visualizationOptions.Duration :: number, function()
		if ACTIVE_VISUALIZATION_TOKENS[visualName] ~= visualToken then
			return
		end

		ACTIVE_VISUALIZATION_TOKENS[visualName] = nil
		VectorViz:DestroyVisualiser(visualName)
	end)
end

local function _CreateShapeDebugPart(name: string, cframe: CFrame, size: Vector3, color: Color3): Part
	local debugPart = Instance.new("Part")
	debugPart.Name = name
	debugPart.Anchored = true
	debugPart.CanCollide = false
	debugPart.CanTouch = false
	debugPart.CanQuery = false
	debugPart.Transparency = 0.75
	debugPart.Material = Enum.Material.ForceField
	debugPart.Color = color
	debugPart.Size = size
	debugPart.CFrame = cframe
	debugPart.Parent = Workspace
	return debugPart
end

local function _VisualizeShapeCast(
	shapePart: BasePart,
	origin: Vector3,
	direction: Vector3,
	shapeCastResult: RaycastResult?,
	options: TQueryOptions?,
	visualize: boolean?
)
	local visualizationOptions = _ResolveVisualizationOptionsForShapeCast(options, visualize)
	if visualizationOptions == nil then
		return
	end

	local visualName = visualizationOptions.Name or ("SpatialQueryShape_%s"):format(HttpService:GenerateGUID(false))
	local visualToken = HttpService:GenerateGUID(false)
	local debugPartNamePrefix = ("%s_Box"):format(visualName)
	local endPosition = origin + direction
	if shapeCastResult ~= nil then
		endPosition = shapeCastResult.Position
	end

	local startPart = _CreateShapeDebugPart(
		("%s_Start"):format(debugPartNamePrefix),
		shapePart.CFrame,
		shapePart.Size,
		visualizationOptions.Color :: Color3
	)
	local endPart = _CreateShapeDebugPart(
		("%s_End"):format(debugPartNamePrefix),
		CFrame.lookAt(endPosition, endPosition + shapePart.CFrame.LookVector),
		shapePart.Size,
		visualizationOptions.Color :: Color3
	)

	ACTIVE_SHAPE_VISUALIZATION_TOKENS[visualName] = visualToken
	VectorViz:CreateVisualiser(visualName, origin, endPosition - origin, {
		Colour = visualizationOptions.Color,
		Width = visualizationOptions.Width,
		Scale = visualizationOptions.Scale,
	})

	task.delay(visualizationOptions.Duration :: number, function()
		if ACTIVE_SHAPE_VISUALIZATION_TOKENS[visualName] ~= visualToken then
			return
		end

		ACTIVE_SHAPE_VISUALIZATION_TOKENS[visualName] = nil
		VectorViz:DestroyVisualiser(visualName)
		if startPart.Parent ~= nil then
			startPart:Destroy()
		end
		if endPart.Parent ~= nil then
			endPart:Destroy()
		end
	end)
end

--[=[
    Casts a ray using normalized query options.
    @within SpatialQueryQueries
    @param origin Vector3 -- Ray origin.
    @param direction Vector3 -- Ray direction and length.
    @param options TQueryOptions? -- Query configuration to apply. `Visualization` is debug-only and ray-only.
    @return RaycastResult? -- First hit, or `nil` when the ray hits nothing or the direction is degenerate.
]=]
function Queries.Raycast(origin: Vector3, direction: Vector3, options: TQueryOptions?): RaycastResult?
	if direction.Magnitude <= Shared.EPSILON then
		return nil
	end

	local raycastResult = Workspace:Raycast(origin, direction, Options.BuildRaycastParams(options))
	_VisualizeRaycast(origin, direction, raycastResult, options)
	return raycastResult
end

--[=[
    Casts a shape part along a direction using normalized query options.
    @within SpatialQueryQueries
    @param shapePart BasePart -- Part that defines the swept shape.
    @param direction Vector3 -- Cast direction and length.
    @param options TQueryOptions? -- Query configuration to apply.
    @param visualize boolean? -- Explicit visualization toggle. `true` forces visualization, `false` suppresses it.
    @return RaycastResult? -- First hit, or `nil` when the cast hits nothing or the direction is degenerate.
]=]
function Queries.ShapeCast(
	shapePart: BasePart,
	direction: Vector3,
	options: TQueryOptions?,
	visualize: boolean?
): RaycastResult?
	if direction.Magnitude <= Shared.EPSILON then
		return nil
	end

	local shapeCastResult = Workspace:Shapecast(shapePart, direction, Options.BuildRaycastParams(options))
	_VisualizeShapeCast(shapePart, shapePart.Position, direction, shapeCastResult, options, visualize)
	return shapeCastResult
end

--[=[
    Casts a ray from `origin` toward `target`.
    @within SpatialQueryQueries
    @param origin Vector3 -- Ray origin.
    @param target Vector3 -- Target position.
    @param options TQueryOptions? -- Query configuration to apply. `Visualization` is debug-only and ray-only.
    @return RaycastResult? -- First hit, or `nil` when the ray hits nothing or the points coincide.
]=]
function Queries.RaycastTo(origin: Vector3, target: Vector3, options: TQueryOptions?): RaycastResult?
	local direction = target - origin
	if direction.Magnitude <= Shared.EPSILON then
		return nil
	end

	return Queries.Raycast(origin, direction, options)
end

--[=[
    Returns parts overlapping an axis-aligned box.
    @within SpatialQueryQueries
    @param cframe CFrame -- Query box center and orientation.
    @param size Vector3 -- Box dimensions.
    @param options TQueryOptions? -- Query configuration to apply.
    @return { BasePart } -- Overlapping parts, or an empty array when the size is invalid.
]=]
function Queries.OverlapBox(cframe: CFrame, size: Vector3, options: TQueryOptions?): { BasePart }
	if not Shared.IsPositiveVector(size) then
		return {}
	end

	return Workspace:GetPartBoundsInBox(cframe, size, Options.BuildOverlapParams(options))
end

--[=[
    Returns parts overlapping a spherical radius around a position.
    @within SpatialQueryQueries
    @param position Vector3 -- Sphere center.
    @param radius number -- Sphere radius.
    @param options TQueryOptions? -- Query configuration to apply.
    @return { BasePart } -- Overlapping parts, or an empty array when the radius is invalid.
]=]
function Queries.OverlapRadius(position: Vector3, radius: number, options: TQueryOptions?): { BasePart }
	if not Shared.IsPositiveNumber(radius) then
		return {}
	end

	return Workspace:GetPartBoundsInRadius(position, radius, Options.BuildOverlapParams(options))
end

--[=[
    Returns parts overlapping the provided part.
    @within SpatialQueryQueries
    @param part BasePart -- Part to use as the overlap shape.
    @param options TQueryOptions? -- Query configuration to apply.
    @return { BasePart } -- Overlapping parts.
]=]
function Queries.OverlapPart(part: BasePart, options: TQueryOptions?): { BasePart }
	return Workspace:GetPartsInPart(part, Options.BuildOverlapParams(options))
end

--[=[
    Checks whether a point lies inside an oriented box.
    @within SpatialQueryQueries
    @param point Vector3 -- Point to test.
    @param cframe CFrame -- Box center and orientation.
    @param size Vector3 -- Box dimensions.
    @return boolean -- Whether the point is inside the box.
]=]
function Queries.ContainsPointInBox(point: Vector3, cframe: CFrame, size: Vector3): boolean
	if not Shared.IsPositiveVector(size) then
		return false
	end

	local localPoint = cframe:PointToObjectSpace(point)
	local halfSize = size * 0.5
	return math.abs(localPoint.X) <= halfSize.X + Shared.EPSILON
		and math.abs(localPoint.Y) <= halfSize.Y + Shared.EPSILON
		and math.abs(localPoint.Z) <= halfSize.Z + Shared.EPSILON
end

--[=[
    Checks whether a point lies inside a radius.
    @within SpatialQueryQueries
    @param point Vector3 -- Point to test.
    @param center Vector3 -- Radius center.
    @param radius number -- Radius length.
    @return boolean -- Whether the point is within range.
]=]
function Queries.ContainsPointInRadius(point: Vector3, center: Vector3, radius: number): boolean
	if not Shared.IsPositiveNumber(radius) then
		return false
	end

	return Shared.GetDistanceSquared(point, center) <= radius * radius
end

--[=[
    Returns the squared distance between two positions.
    @within SpatialQueryQueries
    @param a Vector3 -- First position.
    @param b Vector3 -- Second position.
    @return number -- Squared distance between the positions.
]=]
function Queries.DistanceSquared(a: Vector3, b: Vector3): number
	return Shared.GetDistanceSquared(a, b)
end

--[=[
    Checks whether two positions are within range.
    @within SpatialQueryQueries
    @param a Vector3 -- First position.
    @param b Vector3 -- Second position.
    @param range number -- Maximum distance.
    @return boolean -- Whether the positions are within range.
]=]
function Queries.IsWithinRange(a: Vector3, b: Vector3, range: number): boolean
	if not Shared.IsPositiveNumber(range) then
		return false
	end

	return Shared.GetDistanceSquared(a, b) <= range * range
end

--[=[
    Casts toward a target point and checks range against the surface hit point.
    @within SpatialQueryQueries
    @param origin Vector3 -- Ray origin.
    @param target Vector3 -- Aim point used to choose the ray direction.
    @param maxRange number -- Maximum allowed distance to the raycast hit point.
    @param options TQueryOptions? -- Query configuration to apply.
    @param rangePadding number? -- Extra range tolerance added after a surface hit.
    @return boolean -- Whether the first raycast hit is within range.
]=]
function Queries.IsWithinRaycastRange(
	origin: Vector3,
	target: Vector3,
	maxRange: number,
	options: TQueryOptions?,
	rangePadding: number?
): boolean
	if not Shared.IsPositiveNumber(maxRange) then
		return false
	end

	local direction = target - origin
	if direction.Magnitude <= Shared.EPSILON then
		return true
	end

	local raycastResult = Queries.RaycastTo(origin, target, options)
	if raycastResult == nil then
		return false
	end

	local padding = rangePadding or 0
	return Queries.IsWithinRange(origin, raycastResult.Position, maxRange + padding)
end

--[=[
    Checks whether a target is visible from an origin point.
    @within SpatialQueryQueries
    @param origin Vector3 -- Ray origin.
    @param target Vector3 -- Target position.
    @param options TQueryOptions? -- Query configuration to apply.
    @return boolean -- Whether the target is unobstructed from the origin.
]=]
function Queries.HasLineOfSight(origin: Vector3, target: Vector3, options: TQueryOptions?): boolean
	local direction = target - origin
	if direction.Magnitude <= Shared.EPSILON then
		return true
	end

	return Queries.Raycast(origin, direction, options) == nil
end

--[=[
    Checks whether a target is both in range and visible from an origin point.
    @within SpatialQueryQueries
    @param origin Vector3 -- Ray origin.
    @param target Vector3 -- Target position.
    @param maxRange number -- Maximum distance.
    @param options TQueryOptions? -- Query configuration to apply.
    @return boolean -- Whether the target is visible and within range.
]=]
function Queries.IsTargetVisibleInRange(
	origin: Vector3,
	target: Vector3,
	maxRange: number,
	options: TQueryOptions?
): boolean
	if not Queries.IsWithinRange(origin, target, maxRange) then
		return false
	end

	return Queries.HasLineOfSight(origin, target, options)
end

return table.freeze(Queries)
