--!strict

local Orient = require(script.Parent.Parent.Parent.Orient)
local PlacementPlus = require(script.Parent.Parent.Parent.PlacementPlus)
local SpatialQuery = require(script.Parent.Parent.Parent.SpatialQuery)
local Types = require(script.Parent.Types)

type THighlightConfig = Types.THighlightConfig
type TRadiusConfig = Types.TRadiusConfig
type TResolvedSelectionTarget = Types.TResolvedSelectionTarget
type TSelectionRequest = Types.TSelectionRequest

--[=[
    @class SelectionPlusVisuals
    Creates and registers the built-in `SelectionPlus` visuals for one handle.
    @client
]=]
local Visuals = {}

local DEFAULT_RADIUS_HEIGHT = 0.2
local RADIUS_ROTATION = CFrame.Angles(0, 0, math.rad(90))

local _BuildHighlightVisual
local _BuildRadiusVisual
local _ResolveRadiusCFrame
local _ResolveGroundClampedCandidate

--[=[
    Builds and registers every enabled visual from a selection request.
    @within SelectionPlusVisuals
    @param request TSelectionRequest -- Normalized selection request.
    @param target TResolvedSelectionTarget -- Resolved target bound to the handle.
    @param parent Instance -- Runtime visual parent for this manager.
    @param janitor any -- Janitor that owns the created visual resources.
]=]
function Visuals.BuildSelectionVisuals(
	request: TSelectionRequest,
	target: TResolvedSelectionTarget,
	parent: Instance,
	janitor: any
)
	-- Create the built-in highlight first so the target outline is always present when enabled.
	local highlightConfig = request.Highlight
	if highlightConfig ~= nil and highlightConfig.Enabled ~= false then
		local highlightVisual = _BuildHighlightVisual(target, highlightConfig, parent)
		if highlightVisual ~= nil then
			janitor:Add(highlightVisual)
		end
	end

	-- Create the optional radius indicator only when the request provides a positive radius config.
	local radiusConfig = request.Radius
	if radiusConfig ~= nil and radiusConfig.Enabled ~= false and radiusConfig.Radius > 0 then
		local radiusVisual = _BuildRadiusVisual(target, radiusConfig, parent)
		if radiusVisual ~= nil then
			janitor:Add(radiusVisual)
		end
	end
end

_BuildHighlightVisual = function(
	target: TResolvedSelectionTarget,
	config: THighlightConfig,
	parent: Instance
): any
	if config.BuildVisual ~= nil then
		return config.BuildVisual(target, config, parent)
	end

	local highlight = Instance.new("Highlight")
	highlight.Name = "SelectionHighlight"
	highlight.Adornee = if config.Adornee ~= nil then config.Adornee else target.Adornee
	highlight.FillColor = if config.FillColor ~= nil then config.FillColor else Color3.new(1, 1, 1)
	highlight.OutlineColor = if config.OutlineColor ~= nil then config.OutlineColor else Color3.new(1, 1, 1)
	highlight.FillTransparency = if config.FillTransparency ~= nil then config.FillTransparency else 0.75
	highlight.OutlineTransparency = if config.OutlineTransparency ~= nil then config.OutlineTransparency else 0
	highlight.DepthMode = if config.DepthMode ~= nil then config.DepthMode else Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = if config.Parent ~= nil then config.Parent else parent

	return highlight
end

_BuildRadiusVisual = function(
	target: TResolvedSelectionTarget,
	config: TRadiusConfig,
	parent: Instance
): any
	if config.BuildVisual ~= nil then
		return config.BuildVisual(target, config, parent)
	end

	local radiusPart = Instance.new("Part")
	local height = if config.Height ~= nil then config.Height else DEFAULT_RADIUS_HEIGHT
	local radiusCFrame = _ResolveRadiusCFrame(target, config, height)

	radiusPart.Name = "SelectionRadius"
	radiusPart.Anchored = true
	radiusPart.CanCollide = false
	radiusPart.CanQuery = false
	radiusPart.CanTouch = false
	radiusPart.CastShadow = false
	radiusPart.Material = Enum.Material.ForceField
	radiusPart.Shape = Enum.PartType.Cylinder
	radiusPart.Color = if config.Color ~= nil then config.Color else Color3.new(1, 1, 1)
	radiusPart.Transparency = if config.Transparency ~= nil then config.Transparency else 0.7
	radiusPart.Size = Vector3.new(height, config.Radius * 2, config.Radius * 2)
	radiusPart.CFrame = radiusCFrame
	radiusPart.Parent = if config.Parent ~= nil then config.Parent else parent

	return radiusPart
end

_ResolveRadiusCFrame = function(target: TResolvedSelectionTarget, config: TRadiusConfig, height: number): CFrame
	local targetPosition = target.WorldPosition + if config.Offset ~= nil then config.Offset else Vector3.zero
	local clampedPosition = targetPosition

	if config.ClampToGround ~= false then
		local clampedCandidate = _ResolveGroundClampedCandidate(target, config, height, targetPosition)
		if clampedCandidate ~= nil then
			clampedPosition = clampedCandidate.Position
		end
	end

	return Orient.WithPosition(RADIUS_ROTATION, clampedPosition)
end

_ResolveGroundClampedCandidate = function(
	target: TResolvedSelectionTarget,
	config: TRadiusConfig,
	height: number,
	targetPosition: Vector3
): any
	if target.Hit ~= nil then
		return PlacementPlus.BuildCandidateFromHit(target.Hit, {
			SurfaceOffset = height * 0.5,
		})
	end

	local boundsHeight = if target.BoundsSize ~= nil then target.BoundsSize.Y else 0
	local rayOrigin = targetPosition + Vector3.yAxis * math.max(4, boundsHeight + 4)
	local rayLength = math.max(24, boundsHeight + 16)
	local hit = SpatialQuery.Raycast(rayOrigin, -Vector3.yAxis * rayLength, config.QueryOptions)
	if hit == nil then
		return nil
	end

	return PlacementPlus.BuildCandidateFromHit(hit, {
		SurfaceOffset = height * 0.5,
	})
end

return table.freeze(Visuals)
