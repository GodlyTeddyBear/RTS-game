--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local DebugPlus = require(ReplicatedStorage.Utilities.DebugPlus)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local MuchachoHitbox = require(ReplicatedStorage.Utilities.MuchachoHitbox)
local SpatialQuery = require(ReplicatedStorage.Utilities.SpatialQuery)
local TableRecycler = require(ReplicatedStorage.Utilities.TableRecycler)

local HITBOX_PROFILING_ENABLED = true
local TOUCH_SUBPROFILE_SAMPLE_RATE = 1
local createProfileTag = "Combat:HitboxService:Create"
local touchProfileTag = "Combat:HitboxService:Touch"
local touchBuildKeyAndLookupProfileTag = "Combat:HitboxService:Touch:BuildKeyAndLookup"
local tickProfileTag = "Combat:HitboxService:Tick"
local tickRunnerStepProfileTag = "Combat:HitboxService:Tick:RunnerStep"
local destroyProfileTag = "Combat:HitboxService:Destroy"

type THitboxConfig = {
	DetectionMode: "Default" | "ConstantDetection" | "HitOnce" | "HitParts",
	Shape: Enum.PartType,
	Size: Vector3,
	Offset: CFrame,
	Visualize: boolean,
	MaxDuration: number,
}

export type THitboxHandle = string
export type TEntityKind = "Enemy" | "Structure" | "Base"
type TWhitelistResolver = (attackerEntity: number, attackerKind: TEntityKind, attackerModel: Model?) -> { Instance }

export type THitEntity = {
	Kind: TEntityKind,
	Entity: number,
}

type TTableRecyclerHandle = TableRecycler.TTableRecyclerHandle

local HitboxService = {}
HitboxService.__index = HitboxService

local function EnsureHitboxFolder(): Folder
	local existing = Workspace:FindFirstChild("Hitboxes")
	if existing and existing:IsA("Folder") then
		return existing :: Folder
	end

	local folder = Instance.new("Folder")
	folder.Name = "Hitboxes"
	folder.Parent = Workspace
	return folder
end

local function _buildHitKey(kind: TEntityKind, entity: number): string
	return string.format("%s:%d", kind, entity)
end

function HitboxService.new()
	local self = setmetatable({}, HitboxService)
	self._janitors = {} :: { [THitboxHandle]: any }
	self._hitEntities = {} :: { [THitboxHandle]: { THitEntity } }
	self._hitEntityKeys = {} :: { [THitboxHandle]: { [string]: boolean } }
	self._hitboxFolder = EnsureHitboxFolder()
	self._targetResolvers = {} :: { (BasePart) -> THitEntity? }
	self._whitelistResolvers = {} :: { [TEntityKind]: TWhitelistResolver }
	self._runner = nil :: any
	self._tableRecycler = nil :: TTableRecyclerHandle?
	self._touchSubprofileCounter = 0
	return self
end

function HitboxService:Init(registry: any, _name: string)
	self._registry = registry
end

function HitboxService:Start()
	if self._runner == nil then
		self._runner = MuchachoHitbox.CreateRunner()
	end
end

function HitboxService:RegisterTargetResolver(resolver: (BasePart) -> THitEntity?)
	table.insert(self._targetResolvers, resolver)
end

function HitboxService:RegisterWhitelistResolver(attackerKind: TEntityKind, resolver: TWhitelistResolver)
	self._whitelistResolvers[attackerKind] = resolver
end

function HitboxService:Tick(dt: number)
	DebugPlus.profile(tickProfileTag, function()
		local runner = self._runner
		if runner == nil then
			return
		end

		DebugPlus.profile(tickRunnerStepProfileTag, function()
			runner:Step(dt)
		end, HITBOX_PROFILING_ENABLED)
	end, HITBOX_PROFILING_ENABLED)
end

function HitboxService:_ResolveAttackerModel(_entity: number, _kind: TEntityKind): Model?
	return nil
end

function HitboxService:_ResolveTouchedEntity(hitPart: BasePart): THitEntity?
	if #self._targetResolvers == 0 then
		return nil
	end

	for _, resolver in ipairs(self._targetResolvers) do
		local hitEntity = resolver(hitPart)
		if hitEntity ~= nil then
			return hitEntity
		end
	end

	return nil
end

function HitboxService:_ResolveWhitelistInstances(
	attackerEntity: number,
	attackerKind: TEntityKind,
	attackerModel: Model?
): { Instance }
	local whitelistInstances = self:_AcquireTempArray(nil)
	local resolver = self._whitelistResolvers[attackerKind]
	if resolver == nil then
		return whitelistInstances
	end

	local resolvedInstances = resolver(attackerEntity, attackerKind, attackerModel)
	if type(resolvedInstances) ~= "table" then
		return whitelistInstances
	end

	for _, instance in ipairs(resolvedInstances) do
		if instance ~= nil and instance.Parent ~= nil and instance ~= attackerModel then
			table.insert(whitelistInstances, instance)
		end
	end

	return whitelistInstances
end

function HitboxService:_GetOrCreateTableRecycler(): TTableRecyclerHandle
	local recycler = self._tableRecycler
	if recycler ~= nil then
		return recycler
	end

	recycler = TableRecycler.new({
		Strict = true,
		DebugName = "CombatHitboxService.Temps",
	})
	self._tableRecycler = recycler
	return recycler
end

function HitboxService:_AcquireTempArray<TValue>(capacityHint: number?): { TValue }
	return self:_GetOrCreateTableRecycler():AcquireArray(capacityHint) :: { TValue }
end

function HitboxService:_AcquireTempMap<TKey, TValue>(): { [TKey]: TValue }
	return self:_GetOrCreateTableRecycler():AcquireMap() :: { [TKey]: TValue }
end

function HitboxService:_ReleaseTempArray(tbl: { any })
	local didRelease, releaseError = self:_GetOrCreateTableRecycler():ReleaseArray(tbl)
	assert(didRelease, releaseError)
end

function HitboxService:_ReleaseTempMap(tbl: { [any]: any })
	local didRelease, releaseError = self:_GetOrCreateTableRecycler():ReleaseMap(tbl)
	assert(didRelease, releaseError)
end

function HitboxService:CreateAttackHitbox(
	attackerEntity: number,
	attackerKind: TEntityKind,
	config: THitboxConfig
): { success: boolean, handle: THitboxHandle?, reason: string? }
	local model = self:_ResolveAttackerModel(attackerEntity, attackerKind)
	return self:CreateAttackHitboxForModel(attackerEntity, attackerKind, model, config)
end

function HitboxService:CreateAttackHitboxForModel(
	attackerEntity: number,
	attackerKind: TEntityKind,
	model: Model?,
	config: THitboxConfig
): { success: boolean, handle: THitboxHandle?, reason: string? }
	local closeCreateProfile = DebugPlus.begin(createProfileTag, HITBOX_PROFILING_ENABLED)

	if model == nil then
		closeCreateProfile()
		return {
			success = false,
			reason = "MissingModelRef",
		}
	end

	local primaryPart = model.PrimaryPart
	if primaryPart == nil then
		closeCreateProfile()
		return {
			success = false,
			reason = "MissingPrimaryPart",
		}
	end

	local hitbox = MuchachoHitbox.CreateHitbox()
	hitbox.DetectionMode = config.DetectionMode
	hitbox.Shape = config.Shape
	hitbox.Size = config.Size
	hitbox.Offset = config.Offset
	hitbox.CFrame = primaryPart
	hitbox.Visualizer = config.Visualize
	hitbox.VisualizerContainer = self._hitboxFolder
	hitbox.AutoDestroy = false

	local whitelistInstances = self:_ResolveWhitelistInstances(attackerEntity, attackerKind, model)
	hitbox.OverlapParams = SpatialQuery.BuildOverlapParams(SpatialQuery.Presets.IncludeInstances(whitelistInstances))

	if self._runner == nil then
		self._runner = MuchachoHitbox.CreateRunner()
	end

	local handle: THitboxHandle = hitbox.Key
	local janitor = Janitor.new()
	self._janitors[handle] = janitor
	self._hitEntities[handle] = {}
	self._hitEntityKeys[handle] = self:_AcquireTempMap()

	local onTouched = DebugPlus.wrap(touchProfileTag, function(hitPart: BasePart, _humanoid: Humanoid?)
		local shouldSampleSubprofiles = TOUCH_SUBPROFILE_SAMPLE_RATE <= 1
		if not shouldSampleSubprofiles then
			self._touchSubprofileCounter += 1
			shouldSampleSubprofiles = (self._touchSubprofileCounter % TOUCH_SUBPROFILE_SAMPLE_RATE) == 0
		end

		local hitEntity = self:_ResolveTouchedEntity(hitPart)
		if hitEntity == nil then
			return
		end

		local hitKeyMap = self._hitEntityKeys[handle]
		if hitKeyMap == nil then
			return
		end

		local hitKey = ""
		if shouldSampleSubprofiles then
			DebugPlus.profile(touchBuildKeyAndLookupProfileTag, function()
				hitKey = _buildHitKey(hitEntity.Kind, hitEntity.Entity)
			end, HITBOX_PROFILING_ENABLED)
		else
			hitKey = _buildHitKey(hitEntity.Kind, hitEntity.Entity)
		end

		if hitKeyMap[hitKey] == true then
			return
		end

		hitKeyMap[hitKey] = true

		local hitList = self._hitEntities[handle]
		if hitList ~= nil then
			table.insert(hitList, hitEntity)
		end
	end, HITBOX_PROFILING_ENABLED)

	janitor:Add(hitbox, "Destroy")
	janitor:Add(hitbox.Touched:Connect(onTouched), "Disconnect")
	janitor:Add(function()
		self:_ReleaseTempArray(whitelistInstances)
	end)

	hitbox:Start(self._runner)
	closeCreateProfile()

	return {
		success = true,
		handle = handle,
	}
end

function HitboxService:DidHitTarget(handle: THitboxHandle, targetEntity: number, targetKind: TEntityKind): boolean
	local hitKeyMap = self._hitEntityKeys[handle]
	if hitKeyMap == nil then
		return false
	end

	return hitKeyMap[_buildHitKey(targetKind, targetEntity)] == true
end

function HitboxService:DidHitBase(handle: THitboxHandle): boolean
	return self:DidHitTarget(handle, 0, "Base")
end

function HitboxService:GetHitEntities(handle: THitboxHandle): { THitEntity }
	return self._hitEntities[handle] or {}
end

function HitboxService:DestroyHitbox(handle: THitboxHandle)
	DebugPlus.profile(destroyProfileTag, function()
		local janitor = self._janitors[handle]
		if janitor ~= nil then
			pcall(function()
				janitor:Cleanup()
			end)
		end

		local hitKeyMap = self._hitEntityKeys[handle]
		if hitKeyMap ~= nil then
			self:_ReleaseTempMap(hitKeyMap)
		end

		self._janitors[handle] = nil
		self._hitEntities[handle] = nil
		self._hitEntityKeys[handle] = nil
	end, HITBOX_PROFILING_ENABLED)
end

function HitboxService:CleanupAll()
	local handles = self:_AcquireTempArray(nil)
	for handle in self._janitors do
		table.insert(handles, handle)
	end

	for _, handle in ipairs(handles) do
		self:DestroyHitbox(handle)
	end

	self:_ReleaseTempArray(handles)
end

function HitboxService:Destroy()
	self:CleanupAll()

	local runner = self._runner
	if runner ~= nil then
		runner:Destroy()
		self._runner = nil
	end

	local recycler = self._tableRecycler
	if recycler ~= nil then
		local didDestroyRecycler, destroyRecyclerError = recycler:Destroy()
		assert(didDestroyRecycler, destroyRecyclerError)
		self._tableRecycler = nil
	end
end

return HitboxService
