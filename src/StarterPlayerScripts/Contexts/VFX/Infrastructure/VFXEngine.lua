--!strict

--[=[
	@class VFXEngine
	Client-side visual effect spawner that clones effect assets and places or attaches them in the world.
	@client
]=]

local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AssetFetcher = require(ReplicatedStorage.Utilities.Assets.AssetFetcher)

local VFXEngine = {}
VFXEngine.__index = VFXEngine

local DEFAULT_LIFETIME = 3
local EFFECTS_FOLDER_NAME = "Effects"
local STATUS_EFFECT_CATEGORY = "StatusEffect"

local function _EnsureEffectsFolder(): Folder
	local existing = Workspace:FindFirstChild(EFFECTS_FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		return existing
	end

	if existing and not existing:IsA("Folder") then
		warn("[VFXEngine] Workspace.Effects exists but is not a Folder; replacing it")
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = EFFECTS_FOLDER_NAME
	folder.Parent = Workspace
	return folder
end

--[[
	Calculates the time needed for all particle emitters in a container to finish,
	based on Lifetime.Max + a small buffer. Returns nil if no emitters found.
]]
local function _GetParticleLifetime(container: Instance): number?
	local maxLifetime: number? = nil

	for _, desc in container:GetDescendants() do
		if desc:IsA("ParticleEmitter") then
			local emitter = desc :: ParticleEmitter
			local particleLifetime = emitter.Lifetime.Max
			maxLifetime = maxLifetime and math.max(maxLifetime, particleLifetime) or particleLifetime
		end
	end

	return maxLifetime and (maxLifetime + 0.5) or nil
end

--[[
	Explicit one-shot emission handling.

	Authoring:
	- Set ParticleEmitter attribute `EmitCount` to a positive number to emit once.
	- Optional: set container attribute `EmitCount` as fallback for all child emitters.

	Continuous emitters (Rate > 0) continue working normally.
]]
local function _EmitConfiguredBursts(container: Instance)
	local defaultEmitCount = container:GetAttribute("EmitCount")
	local hasDefault = type(defaultEmitCount) == "number" and (defaultEmitCount :: number) > 0

	for _, desc in container:GetDescendants() do
		if desc:IsA("ParticleEmitter") then
			local emitter = desc :: ParticleEmitter
			local emitCountAttr = emitter:GetAttribute("EmitCount")
			local emitCount: number? = nil

			if type(emitCountAttr) == "number" and emitCountAttr > 0 then
				emitCount = emitCountAttr
			elseif hasDefault then
				emitCount = defaultEmitCount :: number
			end

			if emitCount then
				emitter:Emit(math.floor(emitCount))
			end
		end
	end
end

local function _WeldDescendantPartsToAnchor(container: Instance, anchorRoot: BasePart)
	for _, desc in container:GetDescendants() do
		if desc:IsA("BasePart") then
			local part = desc :: BasePart
			part.CFrame = anchorRoot.CFrame
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = anchorRoot
			weld.Part1 = part
			weld.Parent = anchorRoot
		end
	end
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

local function _GetCategoryAccessors(registry: any, category: string): ((string) -> boolean, (string) -> (Folder | Model))
	if category == STATUS_EFFECT_CATEGORY then
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

local function _TryGetEffect(getEffect: (string) -> (Folder | Model), effectKey: string, category: string): (Folder | Model)?
	local ok, effectOrError = pcall(function()
		return getEffect(effectKey)
	end)
	if not ok then
		warn("[VFXEngine] Failed to get effect:", effectKey, category, effectOrError)
		return nil
	end

	return effectOrError
end

--[[
	Clones an effect from the registry by key and category.
	Returns the cloned container, or nil if the effect doesn't exist.
]]
local function _CloneEffect(registry: any, effectKey: string, category: string): (Folder | Model)?
	local effectExists, getEffect = _GetCategoryAccessors(registry, category)
	if not effectExists(effectKey) then
		warn("[VFXEngine] Effect not found:", effectKey, category)
		return nil
	end

	return _TryGetEffect(getEffect, effectKey, category)
end

local function _ResolveAttachmentTarget(parent: Instance): (BasePart?, CFrame?)
	if parent:IsA("BasePart") then
		return parent, parent.CFrame
	end

	if parent:IsA("Model") then
		local targetModel = parent :: Model
		local targetPart = targetModel.PrimaryPart or targetModel:FindFirstChildWhichIsA("BasePart", true)
		local ok, pivotCFrame = pcall(function()
			return targetModel:GetPivot()
		end)
		if ok then
			return targetPart, pivotCFrame
		end
		if targetPart then
			return targetPart, targetPart.CFrame
		end
		return targetPart, nil
	end

	if parent:IsA("Attachment") then
		local targetPart: BasePart? = nil
		local attachmentParent = parent.Parent
		if attachmentParent and attachmentParent:IsA("BasePart") then
			targetPart = attachmentParent
		end
		return targetPart, parent.WorldCFrame
	end

	return nil, nil
end

local function _BuildAnchorAt(runtimeFolder: Instance, cframe: CFrame, targetPart: BasePart?): (Model, BasePart)
	local anchorModel, anchorRoot = _CreateAnchorModel(cframe, runtimeFolder)
	if targetPart then
		anchorRoot.Anchored = false
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = anchorRoot
		weld.Part1 = targetPart
		weld.Parent = anchorRoot
	end

	return anchorModel, anchorRoot
end

local function _PlaceEffect(effectContainer: Folder | Model, anchorModel: Model, anchorRoot: BasePart, effectCFrame: CFrame)
	if effectContainer:IsA("Model") then
		local model = effectContainer :: Model
		if model.PrimaryPart then
			model:PivotTo(effectCFrame)
		end
	end
	effectContainer.Parent = anchorModel
	_WeldDescendantPartsToAnchor(effectContainer, anchorRoot)
	_EmitConfiguredBursts(effectContainer)
end

local function _ScheduleCleanup(effectContainer: Folder | Model, anchorModel: Model)
	local lifetime = _GetParticleLifetime(effectContainer) or DEFAULT_LIFETIME
	Debris:AddItem(anchorModel, lifetime)
end

--[=[
	Construct a new `VFXEngine` instance.
	@within VFXEngine
	@param effectsFolder Folder? -- The `ReplicatedStorage/Assets/Effects` folder; pass `nil` to create an engine that no-ops on spawn/attach calls
	@return VFXEngine
]=]
function VFXEngine.new(effectsFolder: Folder?)
	local self = setmetatable({}, VFXEngine)

	if effectsFolder then
		self._Registry = AssetFetcher.CreateEffectRegistry(effectsFolder)
	else
		self._Registry = nil
	end
	self._RuntimeFolder = _EnsureEffectsFolder()

	return self
end

--[=[
	Spawn a named visual effect at the given world position.
	@within VFXEngine
	@param effectKey string -- Name of the effect folder under `Assets/Effects/`
	@param position Vector3 -- World position at which to spawn the effect
	@param category string? -- Asset category; `"Skill"` (default) or `"StatusEffect"`
]=]
function VFXEngine:Spawn(effectKey: string, position: Vector3, category: string?)
	if not self._Registry then
		return
	end
	self._RuntimeFolder = _EnsureEffectsFolder()

	local effectContainer = _CloneEffect(self._Registry, effectKey, category or "Skill")
	if not effectContainer then
		return
	end

	local effectCFrame = CFrame.new(position)
	local anchorModel, anchorRoot = _BuildAnchorAt(self._RuntimeFolder, effectCFrame, nil)
	_PlaceEffect(effectContainer, anchorModel, anchorRoot, effectCFrame)
	_ScheduleCleanup(effectContainer, anchorModel)
end

--[=[
	Attach a named visual effect to a target `Instance`.

	The cloned effect is anchored via a `WeldConstraint` to the target part and automatically
	removed via `Debris` after its particle lifetime expires. If the target is destroyed first,
	Roblox's parent hierarchy cleans up the clone automatically.

	@within VFXEngine
	@param effectKey string -- Name of the effect folder under `Assets/Effects/`
	@param parent Instance -- The instance to attach the effect to; supports `BasePart`, `Model`, and `Attachment`
	@param offset CFrame? -- Optional CFrame offset from the resolved attachment point
	@param category string? -- Asset category; `"Skill"` (default) or `"StatusEffect"`
	@return Instance? -- The cloned effect container, or `nil` if the effect was not found or the parent was invalid
]=]
function VFXEngine:Attach(effectKey: string, parent: Instance, offset: CFrame?, category: string?): Instance?
	if not self._Registry then
		return nil
	end
	self._RuntimeFolder = _EnsureEffectsFolder()

	if not parent or not parent.Parent then
		warn("[VFXEngine] Cannot attach effect to nil or orphaned parent:", effectKey)
		return nil
	end

	local effectContainer = _CloneEffect(self._Registry, effectKey, category or "Skill")
	if not effectContainer then
		return nil
	end

	local targetPart, attachCFrame = _ResolveAttachmentTarget(parent)

	if not attachCFrame then
		warn("[VFXEngine] Failed to resolve attach CFrame for:", effectKey)
		return nil
	end

	local finalCFrame = attachCFrame * (offset or CFrame.new())
	local anchorModel, anchorRoot = _BuildAnchorAt(self._RuntimeFolder, finalCFrame, targetPart)
	_PlaceEffect(effectContainer, anchorModel, anchorRoot, finalCFrame)
	_ScheduleCleanup(effectContainer, anchorModel)

	return effectContainer
end

return VFXEngine
