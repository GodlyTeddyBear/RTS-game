--!strict

local ModelPlus = require(script.Parent.Parent.Parent.ModelPlus)
local Query = require(script.Parent.Parent.Parent.Query)
local SpatialQuery = require(script.Parent.Parent.Parent.SpatialQuery)
local Types = require(script.Parent.Types)
local Validation = require(script.Parent.Validation)

type TResolvedSelectionTarget = Types.TResolvedSelectionTarget
type TSelectionResolverOptions = Types.TSelectionResolverOptions

local Resolver = {}

local DEFAULT_RAY_LENGTH = 1000

local function _ResolveInstanceWorldPosition(instance: Instance?): Vector3?
	if instance == nil then
		return nil
	end

	if instance:IsA("Attachment") then
		return instance.WorldPosition
	end

	if instance:IsA("BasePart") then
		return instance.Position
	end

	if instance:IsA("Model") then
		return ModelPlus.GetCenterPosition(instance)
	end

	return nil
end

local function _ResolveRoot(
	hitInstance: Instance,
	hit: RaycastResult?,
	options: TSelectionResolverOptions?
): Instance?
	if options ~= nil and options.ResolveRoot ~= nil then
		return options.ResolveRoot(hitInstance, hit)
	end

	local modelAncestor = hitInstance:FindFirstAncestorWhichIsA("Model")
	if modelAncestor ~= nil then
		return modelAncestor
	end

	if hitInstance:IsA("BasePart") then
		return hitInstance
	end

	return hitInstance:FindFirstAncestorWhichIsA("BasePart")
end

local function _ResolveAdornee(root: Instance, hit: RaycastResult?, options: TSelectionResolverOptions?): Instance?
	if options ~= nil and options.ResolveAdornee ~= nil then
		return options.ResolveAdornee(root, hit)
	end

	local selector = if options ~= nil then options.AdorneeSelector else nil
	if selector ~= nil and selector ~= "" then
		local queriedAdornee = Query.first(root, selector)
		if queriedAdornee ~= nil and (queriedAdornee:IsA("Model") or queriedAdornee:IsA("BasePart")) then
			return queriedAdornee
		end
	end

	if root:IsA("Model") or root:IsA("BasePart") then
		return root
	end

	return nil
end

local function _ResolveWorldPosition(
	root: Instance,
	model: Model?,
	hit: RaycastResult?,
	options: TSelectionResolverOptions?
): Vector3?
	if options ~= nil and options.ResolveWorldPosition ~= nil then
		return options.ResolveWorldPosition(root, hit)
	end

	local selector = if options ~= nil then options.WorldPositionSelector else nil
	if selector ~= nil and selector ~= "" then
		local queriedAnchor = Query.first(root, selector)
		local queriedPosition = _ResolveInstanceWorldPosition(queriedAnchor)
		if queriedPosition ~= nil then
			return queriedPosition
		end
	end

	if model ~= nil then
		return ModelPlus.GetCenterPosition(model)
	end

	local rootPosition = _ResolveInstanceWorldPosition(root)
	if rootPosition ~= nil then
		return rootPosition
	end

	if hit ~= nil then
		return hit.Position
	end

	return nil
end

local function _ResolveModel(root: Instance): Model?
	if root:IsA("Model") then
		return root
	end

	return root:FindFirstAncestorWhichIsA("Model")
end

local function _ResolveBounds(root: Instance, model: Model?): (CFrame?, Vector3?)
	if model ~= nil then
		return ModelPlus.GetBounds(model)
	end

	if root:IsA("BasePart") then
		return root.CFrame, root.Size
	end

	return nil, nil
end

local function _ResolveTargetFromInstance(
	hitInstance: Instance,
	hit: RaycastResult?,
	options: TSelectionResolverOptions?
): TResolvedSelectionTarget?
	local root = _ResolveRoot(hitInstance, hit, options)
	if root == nil then
		return nil
	end

	local adornee = _ResolveAdornee(root, hit, options)
	if adornee == nil then
		return nil
	end

	local model = _ResolveModel(root)
	local boundsCFrame, boundsSize = _ResolveBounds(root, model)
	local worldPosition = _ResolveWorldPosition(root, model, hit, options)
	if worldPosition == nil then
		return nil
	end

	local resolvedTarget: TResolvedSelectionTarget = table.freeze({
		Root = root,
		Adornee = adornee,
		Model = model,
		WorldPosition = worldPosition,
		BoundsCFrame = boundsCFrame,
		BoundsSize = boundsSize,
		Hit = hit,
	})

	Validation.AssertResolvedTarget(resolvedTarget)
	return resolvedTarget
end

function Resolver.ResolveTarget(
	target: (Instance | TResolvedSelectionTarget)?,
	options: TSelectionResolverOptions?
): TResolvedSelectionTarget?
	if target == nil then
		return nil
	end

	if Validation.IsResolvedTarget(target) then
		local resolvedTarget = target :: TResolvedSelectionTarget
		Validation.AssertResolvedTarget(resolvedTarget)
		return resolvedTarget
	end

	if typeof(target) ~= "Instance" then
		return nil
	end

	return _ResolveTargetFromInstance(target, nil, options)
end

function Resolver.ResolveTargetFromScreenPoint(
	camera: Camera,
	screenPoint: Vector2,
	options: TSelectionResolverOptions?
): TResolvedSelectionTarget?
	local rayLength = if options ~= nil and options.RayLength ~= nil then options.RayLength else DEFAULT_RAY_LENGTH
	if rayLength <= 0 then
		return nil
	end

	local ray = camera:ViewportPointToRay(screenPoint.X, screenPoint.Y, 0)
	local hit = SpatialQuery.Raycast(ray.Origin, ray.Direction * rayLength, if options ~= nil then options.QueryOptions else nil)
	if hit == nil then
		return nil
	end

	return _ResolveTargetFromInstance(hit.Instance, hit, options)
end

return table.freeze(Resolver)
