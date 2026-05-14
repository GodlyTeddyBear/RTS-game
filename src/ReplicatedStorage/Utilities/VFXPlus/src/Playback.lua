--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)

local Cleanup = require(script.Parent.Cleanup)
local Enums = require(script.Parent.Enums)
local Handle = require(script.Parent.Handle)
local Types = require(script.Parent.Types)

type TPreparedVFXRequest = Types.TPreparedVFXRequest
type TVFXHandle = Types.TVFXHandle
type TVFXRegistry = Types.TVFXRegistry

local DEFAULT_LIFETIME = 3
local PARTICLE_LIFETIME_BUFFER = 0.5

local Playback = {}

local function _GetCategoryAccessors(registry: TVFXRegistry, category: any): ((string) -> boolean, (string) -> (Folder | Model))
	if category == Enums.EffectCategory.StatusEffect then
		return function(effectKey: string): boolean
				return registry:StatusEffectExists(effectKey)
			end, function(effectKey: string): Folder | Model
				return registry:GetStatusEffect(effectKey)
			end
	end

	return function(effectKey: string): boolean
			return registry:SkillEffectExists(effectKey)
		end, function(effectKey: string): Folder | Model
			return registry:GetSkillEffect(effectKey)
		end
end

local function _CloneEffect(registry: TVFXRegistry, preparedRequest: TPreparedVFXRequest): Result.Result<Folder | Model>
	local effectExists, getEffect = _GetCategoryAccessors(registry, preparedRequest.Category)

	if not effectExists(preparedRequest.EffectKey) then
		return Result.Err(
			Enums.ErrorKey.EffectNotFound.Name,
			Enums.ErrorMessage[Enums.ErrorKey.EffectNotFound],
			{
				EffectKey = preparedRequest.EffectKey,
				Category = preparedRequest.Category.Name,
			}
		)
	end

	local ok, effectOrError = pcall(function()
		return getEffect(preparedRequest.EffectKey)
	end)

	if not ok then
		return Result.Err(
			Enums.ErrorKey.EffectCloneFailed.Name,
			Enums.ErrorMessage[Enums.ErrorKey.EffectCloneFailed],
			{
				EffectKey = preparedRequest.EffectKey,
				Category = preparedRequest.Category.Name,
				Error = tostring(effectOrError),
			}
		)
	end

	return Result.Ok(effectOrError)
end

local function _CreateAnchorModel(cframe: CFrame, parent: Instance): (Model, BasePart)
	local anchorModel = Instance.new("Model")
	anchorModel.Name = "VFXAnchor"
	anchorModel.Parent = parent

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.Transparency = 1
	root.Size = Vector3.new(1, 1, 1)
	root.CFrame = cframe
	root.Parent = anchorModel

	anchorModel.PrimaryPart = root
	return anchorModel, root
end

local function _BuildAnchor(preparedRequest: TPreparedVFXRequest): (Model, BasePart)
	local anchorModel, anchorRoot = _CreateAnchorModel(preparedRequest.CFrame, preparedRequest.Parent)

	if preparedRequest.TargetPart ~= nil then
		anchorRoot.Anchored = false
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = anchorRoot
		weld.Part1 = preparedRequest.TargetPart
		weld.Parent = anchorRoot
	end

	return anchorModel, anchorRoot
end

local function _WeldDescendantPartsToAnchor(container: Instance, anchorRoot: BasePart)
	for _, descendant in container:GetDescendants() do
		if descendant:IsA("BasePart") then
			local part = descendant :: BasePart
			part.CFrame = anchorRoot.CFrame
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = anchorRoot
			weld.Part1 = part
			weld.Parent = anchorRoot
		end
	end
end

local function _PlaceEffect(effectContainer: Folder | Model, anchorModel: Model, anchorRoot: BasePart, effectCFrame: CFrame)
	if effectContainer:IsA("Model") then
		(effectContainer :: Model):PivotTo(effectCFrame)
	end

	effectContainer.Parent = anchorModel
	_WeldDescendantPartsToAnchor(effectContainer, anchorRoot)
end

function Playback.ResolveLifetime(container: Instance, lifetimeOverride: number?): number
	if lifetimeOverride ~= nil then
		return lifetimeOverride
	end

	local maxLifetime: number? = nil
	for _, descendant in container:GetDescendants() do
		if descendant:IsA("ParticleEmitter") then
			local emitter = descendant :: ParticleEmitter
			local particleLifetime = emitter.Lifetime.Max
			maxLifetime = if maxLifetime ~= nil then math.max(maxLifetime, particleLifetime) else particleLifetime
		end
	end

	if maxLifetime ~= nil then
		return maxLifetime + PARTICLE_LIFETIME_BUFFER
	end

	return DEFAULT_LIFETIME
end

function Playback.EmitConfiguredBursts(container: Instance, emitCountOverride: number?)
	local defaultEmitCount = emitCountOverride or container:GetAttribute("EmitCount")
	local hasDefault = type(defaultEmitCount) == "number" and (defaultEmitCount :: number) > 0

	for _, descendant in container:GetDescendants() do
		if not descendant:IsA("ParticleEmitter") then
			continue
		end

		local emitter = descendant :: ParticleEmitter
		local emitCountAttribute = emitter:GetAttribute("EmitCount")
		local emitCount: number? = nil

		if type(emitCountAttribute) == "number" and emitCountAttribute > 0 then
			emitCount = emitCountAttribute
		elseif hasDefault then
			emitCount = defaultEmitCount :: number
		end

		if emitCount ~= nil then
			emitter:Emit(math.floor(emitCount))
		end
	end
end

function Playback.Play(registry: TVFXRegistry, preparedRequest: TPreparedVFXRequest): Result.Result<TVFXHandle>
	local effectResult = _CloneEffect(registry, preparedRequest)
	if not effectResult.success then
		return effectResult :: any
	end

	local effectContainer = effectResult.value
	local anchorModel, anchorRoot = _BuildAnchor(preparedRequest)

	_PlaceEffect(effectContainer, anchorModel, anchorRoot, preparedRequest.CFrame)
	Playback.EmitConfiguredBursts(effectContainer, preparedRequest.EmitCount)

	local lifetime = Playback.ResolveLifetime(effectContainer, preparedRequest.Lifetime)
	local handle = Handle.new(effectContainer, anchorModel, anchorRoot, lifetime, preparedRequest)

	if preparedRequest.AutoCleanup then
		return Cleanup.Schedule(handle)
	end

	return Result.Ok(handle)
end

return table.freeze(Playback)
