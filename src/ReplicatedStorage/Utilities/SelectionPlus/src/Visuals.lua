--!strict

local Orient = require(script.Parent.Parent.Parent.Orient)
local PlacementPlus = require(script.Parent.Parent.Parent.PlacementPlus)
local SpatialQuery = require(script.Parent.Parent.Parent.SpatialQuery)
local Types = require(script.Parent.Types)

type THighlightConfig = Types.THighlightConfig
type TRadiusConfig = Types.TRadiusConfig
type TResolvedSelectionTarget = Types.TResolvedSelectionTarget
type TSelectionSnapshot = Types.TSelectionSnapshot

local DEFAULT_RADIUS_HEIGHT = 0.2
local RADIUS_ROTATION = CFrame.Angles(0, 0, math.rad(90))

local Visuals = {}

local function _ResolveGroundClampedCandidate(
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

local function _ResolveRadiusCFrame(target: TResolvedSelectionTarget, config: TRadiusConfig, height: number): CFrame
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

local function _BuildHighlightVisual(target: TResolvedSelectionTarget, config: THighlightConfig, parent: Instance): any
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

local function _BuildRadiusVisual(target: TResolvedSelectionTarget, config: TRadiusConfig, parent: Instance): any
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
	radiusPart.Size = Vector3.new(height, (config.Radius or 0) * 2, (config.Radius or 0) * 2)
	radiusPart.CFrame = radiusCFrame
	radiusPart.Parent = if config.Parent ~= nil then config.Parent else parent

	return radiusPart
end

function Visuals.BuildSelectionVisuals(
	snapshot: TSelectionSnapshot,
	highlightConfig: THighlightConfig?,
	radiusConfig: TRadiusConfig?,
	parent: Instance,
	stash: any
)
	for _, entry in ipairs(snapshot.Entries) do
		local target = entry.Target
		if highlightConfig ~= nil and highlightConfig.Enabled ~= false then
			local highlightVisual = _BuildHighlightVisual(target, highlightConfig, parent)
			if highlightVisual ~= nil then
				stash:Add(highlightVisual)
			end
		end

		if radiusConfig ~= nil and radiusConfig.Enabled ~= false and radiusConfig.Radius ~= nil and radiusConfig.Radius > 0 then
			local radiusVisual = _BuildRadiusVisual(target, radiusConfig, parent)
			if radiusVisual ~= nil then
				stash:Add(radiusVisual)
			end
		end
	end
end

return table.freeze(Visuals)
