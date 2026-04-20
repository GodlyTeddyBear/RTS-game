--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local MentionSuccess = Result.MentionSuccess

local BuildingConfig = require(ReplicatedStorage.Contexts.Building.Config.BuildingConfig)

--[=[
	@class BuildingModelSyncService
	Synchronizes dirty building ECS entities to workspace models.
	@server
]=]
local BuildingModelSyncService = {}
BuildingModelSyncService.__index = BuildingModelSyncService

export type TBuildingModelSyncService = typeof(setmetatable(
	{} :: {
		_world: any,
		_components: any,
		_entityFactory: any,
		_modelFactory: any,
		_revealAdapter: any,
		_lotContext: any,
		_entityToModel: { [any]: Model },
	},
	BuildingModelSyncService
))

--[=[
	Create a model sync service with deferred dependency wiring.
	@within BuildingModelSyncService
	@return TBuildingModelSyncService -- New model sync service instance.
]=]
function BuildingModelSyncService.new(): TBuildingModelSyncService
	local self = setmetatable({}, BuildingModelSyncService)
	self._world = nil :: any
	self._components = nil :: any
	self._entityFactory = nil :: any
	self._modelFactory = nil :: any
	self._revealAdapter = nil :: any
	self._lotContext = nil :: any
	self._entityToModel = {}
	return self
end

--[=[
	Initialize ECS and model dependencies used during synchronization.
	@within BuildingModelSyncService
	@param registry any -- Context registry for dependency lookup.
	@param _name string -- Unused registration name.
]=]
function BuildingModelSyncService:Init(registry: any, _name: string)
	local worldService = registry:Get("BuildingECSWorldService")
	self._world = worldService:GetWorld()
	self._components = registry:Get("BuildingComponentRegistry")
	self._entityFactory = registry:Get("BuildingEntityFactory")
	self._modelFactory = registry:Get("BuildingModelFactory")
	self._revealAdapter = registry:Get("BuildingRevealAdapter")
end

--[=[
	Attach lot context used to resolve per-user zone folders.
	@within BuildingModelSyncService
	@param lotContext any -- Lot context service instance.
]=]
function BuildingModelSyncService:SetLotContext(lotContext: any)
	self._lotContext = lotContext
end

--[=[
	Synchronize all dirty ECS entities to workspace models.
	@within BuildingModelSyncService
]=]
function BuildingModelSyncService:SyncDirtyEntities()
	for entity in self._world:query(self._components.DirtyTag) do
		local synced = self:_SyncEntity(entity)
		if synced then
			self._world:remove(entity, self._components.DirtyTag)
		end
	end
end

-- Toggle BuildSlot visibility by occupancy while preserving original authored transparency.
function BuildingModelSyncService:_SetBuildSlotOccupied(zoneFolder: Folder, slotIndex: number, occupied: boolean)
	local slotName = "BuildSlot_" .. slotIndex
	local slot = zoneFolder:FindFirstChild(slotName)
	if not slot then
		return
	end
	if not slot:IsA("BasePart") then
		warn(
			"[Building:ModelSyncService] Build slot '"
				.. slotName
				.. "' is "
				.. slot.ClassName
				.. " (expected BasePart); cannot apply visibility toggle."
		)
		return
	end

	local original = slot:GetAttribute("OriginalTransparency")
	if type(original) ~= "number" then
		original = slot.Transparency
		slot:SetAttribute("OriginalTransparency", original)
	end

	slot.Transparency = if occupied then 1 else (original :: number)
end

-- Sync a single ECS entity by updating or spawning its workspace model.
function BuildingModelSyncService:_SyncEntity(entity: any): boolean
	local data: {
		UserId: number,
		ZoneName: string,
		SlotIndex: number,
		BuildingType: string,
		Level: number,
	}? = self._entityFactory:GetBuildingData(entity)
	if not data then
		return true
	end

	local existingModel = self._entityToModel[entity]
	if existingModel then
		local zoneFolder = self:_GetZoneFolder(data.UserId, data.ZoneName)
		if zoneFolder then
			self:_SetBuildSlotOccupied(zoneFolder, data.SlotIndex, true)
		end
		-- Keep visuals in sync for level changes without respawning the model.
		self._modelFactory:UpdateBuildingLevel(existingModel, data.Level)
		self._revealAdapter:ApplyModel(existingModel, data)
		return true
	else
		local zoneFolder = self:_GetZoneFolder(data.UserId, data.ZoneName)
		if not zoneFolder then
			warn("[Building:ModelSyncService] Zone folder not found for zone '" .. data.ZoneName .. "' (userId=" .. data.UserId .. ") -- building model will not be placed")
			MentionSuccess("Building:ModelSyncService:_SyncEntity", "Deferred building model spawn until zone folder is available", {
				userId = data.UserId,
				zoneName = data.ZoneName,
				slotIndex = data.SlotIndex,
				buildingType = data.BuildingType,
				retry = true,
			})
			-- Keep DirtyTag so this entity retries on the next sync tick.
			return false
		end

		local zoneDef = BuildingConfig[data.ZoneName]
		local buildingDef = zoneDef and zoneDef.Buildings[data.BuildingType]
		local companionModel = buildingDef and buildingDef.CompanionModel
		local companionFolder = buildingDef and buildingDef.CompanionFolder

		local model = self._modelFactory:CreateBuildingModel(data.BuildingType, data.Level, zoneFolder, data.SlotIndex, companionModel, companionFolder, data.ZoneName)
		if model then
			self:_SetBuildSlotOccupied(zoneFolder, data.SlotIndex, true)
			self._revealAdapter:ApplyModel(model, data)
			self._entityToModel[entity] = model
			self._world:set(entity, self._components.GameObjectComponent, { Instance = model })
			self:_AttachMachinePromptIfNeeded(model, buildingDef, data.ZoneName, data.SlotIndex)
			MentionSuccess("Building:ModelSyncService:_SyncEntity", "Spawned building model for ECS entity", {
				userId = data.UserId,
				zoneName = data.ZoneName,
				slotIndex = data.SlotIndex,
				buildingType = data.BuildingType,
				level = data.Level,
				modelName = model.Name,
			})
			return true
		end

		MentionSuccess("Building:ModelSyncService:_SyncEntity", "Building model factory returned nil for ECS entity", {
			userId = data.UserId,
			zoneName = data.ZoneName,
			slotIndex = data.SlotIndex,
			buildingType = data.BuildingType,
			level = data.Level,
		})
		return true
	end
end

-- Attach a machine interaction prompt only for eligible machine-style buildings.
function BuildingModelSyncService:_AttachMachinePromptIfNeeded(model: Model, buildingDef: any?, zoneName: string, slotIndex: number)
	if not buildingDef or not buildingDef.FuelItemId or not buildingDef.FuelBurnDurationSeconds then
		return
	end
	if model:FindFirstChild("MachinePrompt") then
		return
	end
	local attach = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if not attach then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "MachinePrompt"
	prompt.ActionText = "Use"
	prompt.ObjectText = "Machine"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	self._revealAdapter:ApplyMachinePrompt(prompt, zoneName, slotIndex)
	prompt.Parent = attach
end

-- Resolve a zone folder getter from LotContext using naming convention by zone.
function BuildingModelSyncService:_GetZoneFolder(userId: number, zoneName: string): Folder?
	if not self._lotContext then
		return nil
	end
	local getter = "Get" .. zoneName .. "FolderForUser"
	local fn = self._lotContext[getter]
	if fn then
		return fn(self._lotContext, userId)
	end
	warn("[Building:ModelSyncService] No LotContext getter found for zone '" .. zoneName .. "' (expected method: " .. getter .. ")")
	return nil
end

--[=[
	Delete one entity model mapping and destroy its model instance.
	@within BuildingModelSyncService
	@param entity any -- ECS entity key.
]=]
function BuildingModelSyncService:DeleteEntity(entity: any)
	local data: {
		UserId: number,
		ZoneName: string,
		SlotIndex: number,
		BuildingType: string,
		Level: number,
	}? = self._entityFactory:GetBuildingData(entity)
	local model = self._entityToModel[entity]
	if model then
		model:Destroy()
		self._entityToModel[entity] = nil
	end

	if data then
		local zoneFolder = self:_GetZoneFolder(data.UserId, data.ZoneName)
		if zoneFolder then
			self:_SetBuildSlotOccupied(zoneFolder, data.SlotIndex, false)
		end
	end
end

--[=[
	Delete all building entities and models for one user.
	@within BuildingModelSyncService
	@param userId number -- Owning user ID.
]=]
function BuildingModelSyncService:DeleteAllForUser(userId: number)
	local entityFactory = self._entityFactory
	local entities = entityFactory:FindBuildingsByUser(userId)
	for _, entity in entities do
		self:DeleteEntity(entity)
		entityFactory:DeleteBuilding(entity)
	end
end

return BuildingModelSyncService
