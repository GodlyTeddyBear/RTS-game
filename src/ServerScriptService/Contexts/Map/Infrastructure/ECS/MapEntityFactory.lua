--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local LocationECSEntityFactory = require(ReplicatedStorage.Utilities.LocationECSEntityFactory)
local Ok = Result.Ok

--[=[
	@class MapEntityFactory
	Creates and queries ECS entities for the active runtime map.
	@server
]=]
local MapEntityFactory = {}
MapEntityFactory.__index = MapEntityFactory
setmetatable(MapEntityFactory, LocationECSEntityFactory)

export type ZoneMap = { [string]: Instance }

--[=[
	Creates the Map entity factory wrapper.
	@within MapEntityFactory
	@return MapEntityFactory -- The new entity factory instance.
]=]
function MapEntityFactory.new()
	return setmetatable(LocationECSEntityFactory.new("Map"), MapEntityFactory)
end

-- Returns the component registry name used to bind Map ECS components.
function MapEntityFactory:_GetComponentRegistryName(): string
	return "MapComponentRegistry"
end

-- Verifies the Map component registry and configures the location-scoped component set.
function MapEntityFactory:_OnInit(_registry: any, _name: string, _componentRegistry: any)
	assert(self._components ~= nil and self._components.MapRootComponent ~= nil, "MapEntityFactory: missing MapComponentRegistry components")
	self:_ConfigureLocationComponents("ZoneComponent", "MapInstanceComponent", "TransformComponent")
end

--[=[
	Creates the runtime map root entity and attaches zone and base metadata.
	@within MapEntityFactory
	@param mapId string -- The generated runtime map identifier.
	@param templateName string -- The template name used to build the runtime map.
	@param mapModel Model -- The cloned runtime map model.
	@param zonesByName ZoneMap -- The discovered runtime zones keyed by zone name.
	@return number -- The created root entity id.
]=]
function MapEntityFactory:CreateMapRoot(mapId: string, templateName: string, mapModel: Model, zonesByName: ZoneMap): number
	self:RequireReady()

	-- Create the root entity before attaching any zone or base metadata.
	local components = self:GetComponentsOrThrow()
	local mapEntity = self:CreateLocationRoot(("RuntimeMap:%s"):format(mapId), mapModel)

	-- Store the runtime map identity and template metadata on the root entity.
	self:_Set(mapEntity, components.MapRootComponent, {
		MapId = mapId,
		Template = templateName,
		CreatedAt = os.clock(),
	})

	-- Register zone descendants and attach base data if the template contains one.
	self:RegisterZones(mapEntity, zonesByName)
	self:_AttachBaseComponent(mapEntity, mapModel)

	return mapEntity
end

-- Attaches the base component when the runtime map contains a valid base model and anchor.
function MapEntityFactory:_AttachBaseComponent(mapEntity: number, mapModel: Model)
	local components = self:GetComponentsOrThrow()
	local baseInstance = self:_FindNamedDescendant(mapModel, "Base")
	if baseInstance == nil then
		return
	end

	local anchor = self:_ResolveAnchor(baseInstance)
	if anchor == nil then
		return
	end

	self:_Set(mapEntity, components.BaseComponent, {
		Instance = baseInstance,
		Anchor = anchor,
	})
	self:_Add(mapEntity, components.BaseZoneTag)
end

--[=[
	Creates a zone entity and marks spawn zones with the cached spawn component.
	@within MapEntityFactory
	@param mapEntity number -- The parent runtime map entity id.
	@param zoneName string -- The zone name being registered.
	@param zoneInstance Instance -- The zone instance discovered in the runtime map.
	@return number -- The created zone entity id.
]=]
function MapEntityFactory:CreateZoneEntity(mapEntity: number, zoneName: string, zoneInstance: Instance): number
	self:RequireReady()

	local components = self:GetComponentsOrThrow()
	local zoneEntity = LocationECSEntityFactory.CreateZoneEntity(self, mapEntity, zoneName, zoneInstance)

	self:_SetName(zoneEntity, ("MapZone:%s"):format(zoneName))

	-- Cache the spawn marker when the runtime map uses the grouped spawn container.
	if zoneName == "Spawns" then
		local spawnMarker = self:_FindNamedBasePart(zoneInstance, "Spawn")
		if spawnMarker ~= nil then
			self:_Set(zoneEntity, components.SpawnComponent, {
				Instance = spawnMarker,
			})
			self:_Add(zoneEntity, components.SpawnZoneTag)
		end
	end

	-- Cache the spawn part directly when the template exposes a single spawn zone.
	if zoneName == "Spawn" and zoneInstance:IsA("BasePart") then
		self:_Set(zoneEntity, components.SpawnComponent, {
			Instance = zoneInstance,
		})
		self:_Add(zoneEntity, components.SpawnZoneTag)
	end

	return zoneEntity
end

--[=[
	Deletes the active runtime map entity by delegating to the shared location lifecycle.
	@within MapEntityFactory
	@return boolean -- Whether the deletion request completed successfully.
]=]
function MapEntityFactory:DeleteActiveMap(): boolean
	return self:DeleteActiveLocation()
end

--[=[
	Returns the active runtime map entity id, if one is currently registered.
	@within MapEntityFactory
	@return number? -- The active runtime map entity id, if present.
]=]
function MapEntityFactory:GetActiveMapEntity(): number?
	return self:GetActiveLocationEntity()
end

--[=[
	Returns the active runtime map model, if one is currently registered.
	@within MapEntityFactory
	@return Model? -- The active runtime map model, if present.
]=]
function MapEntityFactory:GetMapInstance(): Model?
	return self:GetLocationModel()
end

--[=[
	Resolves the spawn marker from the active runtime map entity.
	@within MapEntityFactory
	@return BasePart? -- The active spawn marker, if present.
]=]
function MapEntityFactory:GetSpawnInstance(): BasePart?
	self:RequireReady()

	local mapEntity = self:GetActiveLocationEntity()
	if mapEntity == nil then
		return nil
	end

	-- Only return a spawn owned by the current runtime map entity.
	local components = self:GetComponentsOrThrow()
	for _, zoneEntity in ipairs(self:CollectQuery(components.SpawnZoneTag)) do
		local parentEntity = self:GetParentEntity(zoneEntity)
		if parentEntity == mapEntity then
			-- Read the cached spawn component instead of traversing the live instance tree again.
			local spawnData = self:_Get(zoneEntity, components.SpawnComponent)
			if spawnData and spawnData.Instance then
				return spawnData.Instance
			end
		end
	end

	return nil
end

--[=[
	Resolves the base model from the active runtime map entity.
	@within MapEntityFactory
	@return Instance? -- The active base instance, if present.
]=]
function MapEntityFactory:GetBaseInstance(): Instance?
	self:RequireReady()

	local mapEntity = self:GetActiveLocationEntity()
	if mapEntity == nil then
		return nil
	end

	local baseData = self:_Get(mapEntity, self._components.BaseComponent)
	return baseData and baseData.Instance or nil
end

--[=[
	Resolves the base anchor from the active runtime map entity.
	@within MapEntityFactory
	@return BasePart? -- The active base anchor, if present.
]=]
function MapEntityFactory:GetBaseAnchor(): BasePart?
	self:RequireReady()

	local mapEntity = self:GetActiveLocationEntity()
	if mapEntity == nil then
		return nil
	end

	local baseData = self:_Get(mapEntity, self._components.BaseComponent)
	return baseData and baseData.Anchor or nil
end

--[=[
	Returns the runtime map's CFrame by delegating to the shared location state.
	@within MapEntityFactory
	@return CFrame? -- The runtime map CFrame, if present.
]=]
function MapEntityFactory:GetMapCFrame(): CFrame?
	return self:GetLocationCFrame()
end

--[=[
	Returns the runtime map's position by delegating to the shared location state.
	@within MapEntityFactory
	@return Vector3? -- The runtime map position, if present.
]=]
function MapEntityFactory:GetMapPosition(): Vector3?
	return self:GetLocationPosition()
end

--[=[
	Reports whether the runtime map has an active entity registered.
	@within MapEntityFactory
	@return Result.Result<boolean> -- Whether the runtime map is ready.
]=]
function MapEntityFactory:IsRuntimeMapReady(): Result.Result<boolean>
	return Ok(self:GetActiveLocationEntity() ~= nil)
end

return MapEntityFactory
