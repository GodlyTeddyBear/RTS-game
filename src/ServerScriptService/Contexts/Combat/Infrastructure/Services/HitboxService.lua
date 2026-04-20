--!strict

--[[
	HitboxService - Infrastructure service that manages combat hitboxes.

	Responsibilities:
	- Create MuchachoHitbox instances attached to attacker models or at target positions
	- Resolve Humanoid hits back to JECS entities via NPCGameObjectSyncService
	- Track per-handle hit results for executor queries
	- Manage hitbox lifecycle (create, query, destroy, cleanup)

	This is the ONLY service that knows about MuchachoHitbox internals
	and the Model→Entity mapping. Executors interact through opaque handles.

	Pattern: Infrastructure layer service with constructor injection
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MuchachoHitbox = require(ReplicatedStorage.Utilities.MuchachoHitbox)
local HitboxConfig = require(ReplicatedStorage.Contexts.Combat.Config.HitboxConfig)
local Janitor = require(ReplicatedStorage.Packages.Janitor)

type THitboxConfig = HitboxConfig.THitboxConfig

local HitboxService = {}
HitboxService.__index = HitboxService

export type THitboxHandle = string
export type TCreateAttackHitboxResult = {
	success: boolean,
	handle: THitboxHandle?,
	reason: string?,
}

export type THitboxService = typeof(setmetatable({} :: {
	_GameObjectSyncService: any,
	_NPCEntityFactory: any,
	_HitEntities: { [THitboxHandle]: { any } },
	_Janitors: { [THitboxHandle]: any },
}, HitboxService))

local function EnsureHitboxFolder(): Folder
	local existing = workspace:FindFirstChild("Hitboxes")
	if existing and existing:IsA("Folder") then
		return existing :: Folder
	end
	local folder = Instance.new("Folder")
	folder.Name = "Hitboxes"
	folder.Parent = workspace
	return folder
end

function HitboxService.new(): THitboxService
	local self = setmetatable({}, HitboxService)
	self._HitEntities = {}
	self._Janitors = {}
	EnsureHitboxFolder()
	return self
end

function HitboxService:Init(registry: any, _name: string)
	self.Registry = registry
end

function HitboxService:Start()
	self._GameObjectSyncService = self.Registry:Get("GameObjectSyncService")
	self._NPCEntityFactory = self.Registry:Get("NPCEntityFactory")
end

--[[
	Create and start a hitbox attached to an attacker entity's model.
	The hitbox follows the attacker's model CFrame each frame.

	@param attackerEntity - The JECS entity performing the attack
	@param config - Hitbox configuration (from HitboxConfig)
	@return THitboxHandle - Opaque handle for querying/destroying this hitbox
]]
function HitboxService:CreateAttackHitbox(attackerEntity: any, config: THitboxConfig): TCreateAttackHitboxResult
	local modelRef = self._NPCEntityFactory:GetModelRef(attackerEntity)
	if not modelRef or not modelRef.Instance then
		return {
			success = false,
			reason = "MissingModelRef",
		}
	end

	local model: Model = modelRef.Instance
	local primaryPart = model.PrimaryPart
	if not primaryPart then
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

	-- Exclude the attacker's own parts from detection
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = { model }
	hitbox.OverlapParams = overlapParams

	local handle: THitboxHandle = hitbox.Key
	local janitor = Janitor.new()
	self._HitEntities[handle] = {}
	self._Janitors[handle] = janitor

	janitor:Add(hitbox, "Destroy")

	-- Connect Touched signal to resolve Humanoid → JECS entity
	janitor:Add(hitbox.Touched:Connect(function(_hitPart: BasePart, humanoid: Humanoid?)
		if not humanoid then
			return
		end

		local characterModel = humanoid.Parent :: Model?
		if not characterModel then
			return
		end

		local entity = self._GameObjectSyncService.InstanceToEntity[characterModel]
		if not entity then
			return
		end

		-- Avoid duplicate entries
		local hitList = self._HitEntities[handle]
		if hitList then
			for _, existingEntity in ipairs(hitList) do
				if existingEntity == entity then
					return
				end
			end
			table.insert(hitList, entity)
		end
	end), "Disconnect")

	hitbox:Start()

	return {
		success = true,
		handle = handle,
	}
end

--[[
	Create and start a hitbox at a specific world position (for ranged attacks).
	The hitbox does NOT follow any model — it stays at the given CFrame.

	@param targetCFrame - World CFrame to place the hitbox at
	@param config - Hitbox configuration (from HitboxConfig)
	@param excludeModel - Optional model to exclude from detection (e.g., the attacker)
	@return THitboxHandle - Opaque handle for querying/destroying this hitbox
]]
function HitboxService:CreateTargetedHitbox(targetCFrame: CFrame, config: THitboxConfig, excludeModel: Model?): THitboxHandle?
	local hitbox = MuchachoHitbox.CreateHitbox()
	hitbox.DetectionMode = config.DetectionMode
	hitbox.Shape = config.Shape
	hitbox.Size = config.Size
	hitbox.Offset = config.Offset
	hitbox.CFrame = targetCFrame
	hitbox.Visualizer = false
	hitbox.AutoDestroy = false

	if excludeModel then
		local overlapParams = OverlapParams.new()
		overlapParams.FilterType = Enum.RaycastFilterType.Exclude
		overlapParams.FilterDescendantsInstances = { excludeModel }
		hitbox.OverlapParams = overlapParams
	end

	local handle: THitboxHandle = hitbox.Key
	local janitor = Janitor.new()
	self._HitEntities[handle] = {}
	self._Janitors[handle] = janitor

	janitor:Add(hitbox, "Destroy")

	janitor:Add(hitbox.Touched:Connect(function(_hitPart: BasePart, humanoid: Humanoid?)
		if not humanoid then
			return
		end

		local characterModel = humanoid.Parent :: Model?
		if not characterModel then
			return
		end

		local entity = self._GameObjectSyncService.InstanceToEntity[characterModel]
		if not entity then
			return
		end

		local hitList = self._HitEntities[handle]
		if hitList then
			for _, existingEntity in ipairs(hitList) do
				if existingEntity == entity then
					return
				end
			end
			table.insert(hitList, entity)
		end
	end), "Disconnect")

	hitbox:Start()

	return handle
end

--[[
	Check if a specific target entity was hit by this hitbox.

	@param handle - The hitbox handle from CreateAttackHitbox/CreateTargetedHitbox
	@param targetEntity - The JECS entity to check for
	@return boolean - True if the target's model was detected in the hitbox
]]
function HitboxService:DidHitTarget(handle: THitboxHandle, targetEntity: any): boolean
	local hitList = self._HitEntities[handle]
	if not hitList then
		return false
	end

	for _, entity in ipairs(hitList) do
		if entity == targetEntity then
			return true
		end
	end

	return false
end

--[[
	Get all JECS entities hit by this hitbox (for AoE attacks).

	@param handle - The hitbox handle
	@return { Entity } - Array of JECS entities that were detected
]]
function HitboxService:GetHitEntities(handle: THitboxHandle): { any }
	return self._HitEntities[handle] or {}
end

--[[
	Stop and clean up a single hitbox.

	@param handle - The hitbox handle to destroy
]]
function HitboxService:DestroyHitbox(handle: THitboxHandle)
	local janitor = self._Janitors[handle]
	if janitor then
		-- pcall guards against MuchachoHitbox:Destroy() throwing if the hitbox
		-- was already stopped (e.g. double-cancel from concurrent cleanup paths)
		pcall(function()
			janitor:Cleanup()
		end)
	end

	self._HitEntities[handle] = nil
	self._Janitors[handle] = nil
end

--[[
	Clean up all active hitboxes. Called on combat end.
]]
function HitboxService:CleanupAll()
	local handles = {}
	for handle in pairs(self._Janitors) do
		table.insert(handles, handle)
	end

	for _, handle in ipairs(handles) do
		self:DestroyHitbox(handle)
	end
end

return HitboxService
