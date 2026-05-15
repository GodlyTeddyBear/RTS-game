--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Janitor = require(ReplicatedStorage.Packages.Janitor)
local MuchachoHitbox = require(ReplicatedStorage.Utilities.MuchachoHitbox)
local SpatialQuery = require(ReplicatedStorage.Utilities.SpatialQuery)

local HITBOX_PROFILING_ENABLED = true
local profileBegin = debug.profilebegin
local profileEnd = debug.profileend
local createProfileTag = "Combat:HitboxService:Create"
local touchProfileTag = "Combat:HitboxService:Touch"
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

export type THitEntity = {
	Kind: TEntityKind,
	Entity: number,
}

local HitboxService = {}
HitboxService.__index = HitboxService

local function _runProfiled(tag: string, callback: () -> any?): any
	if not HITBOX_PROFILING_ENABLED then
		return callback()
	end

	profileBegin(tag)
	local packed = table.pack(xpcall(callback, debug.traceback))
	profileEnd()

	if not packed[1] then
		error(packed[2], 0)
	end

	return table.unpack(packed, 2, packed.n :: number)
end

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
	self._runner = nil :: any
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

function HitboxService:Tick(dt: number)
	local runner = self._runner
	if runner == nil then
		return
	end

	runner:Step(dt)
end

function HitboxService:_ResolveAttackerModel(_entity: number, _kind: TEntityKind): Model?
	return nil
end

function HitboxService:_ResolveTouchedEntity(hitPart: BasePart): THitEntity?
	for _, resolver in ipairs(self._targetResolvers) do
		local hitEntity = resolver(hitPart)
		if hitEntity ~= nil then
			return hitEntity
		end
	end

	return nil
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
	return _runProfiled(createProfileTag, function()
		if model == nil then
			return {
				success = false,
				reason = "MissingModelRef",
			}
		end

		local primaryPart = model.PrimaryPart
		if primaryPart == nil then
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

		hitbox.OverlapParams = SpatialQuery.BuildOverlapParams(SpatialQuery.Presets.ExcludeModel(model))

		if self._runner == nil then
			self._runner = MuchachoHitbox.CreateRunner()
		end

		local handle: THitboxHandle = hitbox.Key
		local janitor = Janitor.new()
		self._janitors[handle] = janitor
		self._hitEntities[handle] = {}
		self._hitEntityKeys[handle] = {}

		janitor:Add(hitbox, "Destroy")
		janitor:Add(
			hitbox.Touched:Connect(function(hitPart: BasePart, _humanoid: Humanoid?)
				_runProfiled(touchProfileTag, function()
					local hitEntity = self:_ResolveTouchedEntity(hitPart)
					if hitEntity == nil then
						return
					end

					local hitKey = _buildHitKey(hitEntity.Kind, hitEntity.Entity)
					local hitKeyMap = self._hitEntityKeys[handle]
					if hitKeyMap == nil or hitKeyMap[hitKey] then
						return
					end

					hitKeyMap[hitKey] = true
					local hitList = self._hitEntities[handle]
					if hitList ~= nil then
						table.insert(hitList, hitEntity)
					end
				end)
			end),
			"Disconnect"
		)

		hitbox:Start(self._runner)

		return {
			success = true,
			handle = handle,
		}
	end)
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
	_runProfiled(destroyProfileTag, function()
		local janitor = self._janitors[handle]
		if janitor ~= nil then
			pcall(function()
				janitor:Cleanup()
			end)
		end

		self._janitors[handle] = nil
		self._hitEntities[handle] = nil
		self._hitEntityKeys[handle] = nil
	end)
end

function HitboxService:CleanupAll()
	local handles = {}
	for handle in self._janitors do
		table.insert(handles, handle)
	end

	for _, handle in ipairs(handles) do
		self:DestroyHitbox(handle)
	end
end

function HitboxService:Destroy()
	self:CleanupAll()

	local runner = self._runner
	if runner ~= nil then
		runner:Destroy()
		self._runner = nil
	end
end

return HitboxService
