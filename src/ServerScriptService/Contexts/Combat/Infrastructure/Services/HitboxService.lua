--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Janitor = require(ReplicatedStorage.Packages.Janitor)
local MuchachoHitbox = require(ReplicatedStorage.Utilities.MuchachoHitbox)
local Result = require(ReplicatedStorage.Utilities.Result)
local SpatialQuery = require(ReplicatedStorage.Utilities.SpatialQuery)

local HITBOX_PROFILING_ENABLED = false
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

--[=[
	@class HitboxService
	Owns combat hitbox spawning, overlap capture, and hit tracking for melee attacks.
	@server
]=]
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

--[=[
	@within HitboxService
	Creates a new hitbox service with empty tracking tables and a shared workspace folder.
	@return HitboxService -- Service instance used to spawn and track combat hitboxes.
]=]
function HitboxService.new()
	local self = setmetatable({}, HitboxService)
	self._janitors = {} :: { [THitboxHandle]: any }
	self._hitEntities = {} :: { [THitboxHandle]: { THitEntity } }
	self._hitEntityKeys = {} :: { [THitboxHandle]: { [string]: boolean } }
	self._hitboxFolder = EnsureHitboxFolder()
	self._targetResolvers = {} :: { (BasePart) -> THitEntity? }
	return self
end

--[=[
	@within HitboxService
	Resolves entity factories needed to map hit parts back to combat entities.
	@param registry any -- Registry instance supplied by the context bootstrap.
	@param _name string -- Registry key used to register the service.
]=]
function HitboxService:Init(registry: any, _name: string)
	self._registry = registry
end

--[=[
	@within HitboxService
	Stores the context dependencies used while translating touches into combat targets.
]=]
function HitboxService:Start() end

function HitboxService:RegisterTargetResolver(resolver: (BasePart) -> THitEntity?)
	table.insert(self._targetResolvers, resolver)
end

local function _buildHitKey(kind: TEntityKind, entity: number): string
	return string.format("%s:%d", kind, entity)
end

-- Resolves the model that should own the spawned hitbox.
function HitboxService:_ResolveAttackerModel(_entity: number, _kind: TEntityKind): Model?
	return nil
end

-- Maps a touched part back to a combat entity so hitbox callbacks stay domain-aware.
function HitboxService:_ResolveTouchedEntity(hitPart: BasePart): THitEntity?
	for _, resolver in ipairs(self._targetResolvers) do
		local hitEntity = resolver(hitPart)
		if hitEntity ~= nil then
			return hitEntity
		end
	end

	return nil
end

--[=[
	@within HitboxService
	Creates and starts a combat attack hitbox attached to the attacker model.
	@param attackerEntity number -- Entity id that owns the hitbox.
	@param attackerKind TEntityKind -- Entity kind used to resolve the model.
	@param config THitboxConfig -- Shape and detection settings for the hitbox.
	@return { success: boolean, handle: THitboxHandle?, reason: string? } -- Spawn result or failure reason.
]=]
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
		hitbox.AutoDestroy = false

		hitbox.OverlapParams = SpatialQuery.BuildOverlapParams(SpatialQuery.Presets.ExcludeModel(model))

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

		hitbox:Start()

		return {
			success = true,
			handle = handle,
		}
	end)
end

--[=[
	@within HitboxService
	Returns whether this hitbox already touched a specific target entity.
	@param handle THitboxHandle -- Hitbox handle to inspect.
	@param targetEntity number -- Target entity id to check.
	@param targetKind TEntityKind -- Target kind to check.
	@return boolean -- Whether the target was already captured.
]=]
function HitboxService:DidHitTarget(handle: THitboxHandle, targetEntity: number, targetKind: TEntityKind): boolean
	local hitKeyMap = self._hitEntityKeys[handle]
	if hitKeyMap == nil then
		return false
	end

	return hitKeyMap[_buildHitKey(targetKind, targetEntity)] == true
end

--[=[
	@within HitboxService
	Returns whether this hitbox has already touched the base.
	@param handle THitboxHandle -- Hitbox handle to inspect.
	@return boolean -- Whether the base was already captured.
]=]
function HitboxService:DidHitBase(handle: THitboxHandle): boolean
	return self:DidHitTarget(handle, 0, "Base")
end

--[=[
	@within HitboxService
	Returns the entities captured by one hitbox handle in touch order.
	@param handle THitboxHandle -- Hitbox handle to inspect.
	@return { THitEntity } -- Captured entities for the hitbox.
]=]
function HitboxService:GetHitEntities(handle: THitboxHandle): { THitEntity }
	return self._hitEntities[handle] or {}
end

--[=[
	@within HitboxService
	Destroys one hitbox and clears all tracking for its handle.
	@param handle THitboxHandle -- Hitbox handle to destroy.
]=]
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

--[=[
	@within HitboxService
	Destroys every tracked hitbox so combat teardown leaves no active overlap handlers behind.
]=]
function HitboxService:CleanupAll()
	local handles = {}
	for handle in self._janitors do
		table.insert(handles, handle)
	end

	for _, handle in ipairs(handles) do
		self:DestroyHitbox(handle)
	end
end

return HitboxService
