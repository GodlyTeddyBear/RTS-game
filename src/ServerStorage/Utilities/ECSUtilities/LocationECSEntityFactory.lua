--!strict

--[=[
    @class LocationECSEntityFactory
    Owns one active location root and its named ECS zone children for a single
    bounded context.

    Flow: create root -> register zones -> query active location and zone state.
    @server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseECSEntityFactory = require(ReplicatedStorage.Utilities.BaseECSEntityFactory)

-- Resolve an anchor part so zone entities can inherit a stable CFrame from
-- models, parts, or nested containers.
-- Resolve the current world-space transform for a zone source without caring
-- whether it is a part, model, or generic container.
local function _ResolveCFrame(factory: any, instance: Instance): CFrame?
	if instance:IsA("BasePart") then
		return instance.CFrame
	end

	if instance:IsA("Model") then
		return instance:GetPivot()
	end

	local anchor = factory:_ResolveAnchor(instance)
	return anchor and anchor.CFrame or nil
end

local LocationECSEntityFactory = {}
LocationECSEntityFactory.__index = LocationECSEntityFactory
setmetatable(LocationECSEntityFactory, BaseECSEntityFactory)

-- ── Public ───────────────────────────────────────────────────────────────────

--[=[
	Creates a new location factory instance for the supplied context name.
	@within LocationECSEntityFactory
	@param contextName string -- Owning context label used in assertions and diagnostics.
	@return LocationECSEntityFactory -- New factory instance.
]=]
function LocationECSEntityFactory.new(contextName: string)
	local self = setmetatable(BaseECSEntityFactory.new(contextName), LocationECSEntityFactory)
	self._locationEntity = nil :: number?
	self._zoneEntityByName = {} :: { [string]: number }
	self._zoneComponent = nil
	return self
end

-- ── Private ──────────────────────────────────────────────────────────────────

-- Configures the zone and spatial component keys before any location entity is created.
function LocationECSEntityFactory:_ConfigureLocationComponents(
	zoneComponentKey: string,
	modelRefComponentKey: string,
	transformComponentKey: string
)
	self:RequireReady()

	local zoneComponent = self._components[zoneComponentKey]
	assert(
		zoneComponent ~= nil,
		("%sEntityFactory: missing location component '%s'"):format(self._contextName, zoneComponentKey)
	)

	self._zoneComponent = zoneComponent
	self:_ConfigureSpatialComponents(modelRefComponentKey, transformComponentKey)
end

-- Resolves the first descendant with the supplied name, including the root.
function LocationECSEntityFactory:_FindNamedDescendant(root: Instance, markerName: string): Instance?
	assert(root, ("%sEntityFactory:_FindNamedDescendant requires root"):format(self._contextName))
	assert(
		type(markerName) == "string" and markerName ~= "",
		("%sEntityFactory:_FindNamedDescendant requires markerName"):format(self._contextName)
	)

	if root.Name == markerName then
		return root
	end

	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant.Name == markerName then
			return descendant
		end
	end

	return nil
end

-- Resolves the first BasePart descendant with the supplied name, including the root.
function LocationECSEntityFactory:_FindNamedBasePart(root: Instance, markerName: string): BasePart?
	assert(root, ("%sEntityFactory:_FindNamedBasePart requires root"):format(self._contextName))
	assert(
		type(markerName) == "string" and markerName ~= "",
		("%sEntityFactory:_FindNamedBasePart requires markerName"):format(self._contextName)
	)

	if root:IsA("BasePart") and root.Name == markerName then
		return root
	end

	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Name == markerName then
			return descendant
		end
	end

	return nil
end

-- Resolves a stable anchor part from a location-owned instance subtree.
function LocationECSEntityFactory:_ResolveAnchor(instance: Instance): BasePart?
	assert(instance, ("%sEntityFactory:_ResolveAnchor requires instance"):format(self._contextName))

	if instance:IsA("BasePart") then
		return instance
	end

	if instance:IsA("Model") then
		return instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart", true)
	end

	return instance:FindFirstChildWhichIsA("BasePart", true)
end

--[=[
	Creates a new active location root and clears any previous location state.
	@within LocationECSEntityFactory
	@param rootEntityName string -- Name assigned to the root ECS entity.
	@param model Model -- Live model that backs the location root.
	@return number -- Created location entity id.
]=]
function LocationECSEntityFactory:CreateLocationRoot(rootEntityName: string, model: Model): number
	self:RequireReady()
	assert(
		type(rootEntityName) == "string" and rootEntityName ~= "",
		("%sEntityFactory:CreateLocationRoot requires rootEntityName"):format(self._contextName)
	)
	assert(model, ("%sEntityFactory:CreateLocationRoot requires model"):format(self._contextName))

	-- Clear any previous location before creating the replacement root.
	self:DeleteActiveLocation()

	-- Create the root entity and seed its spatial identity.
	local locationEntity = self:_CreateEntity()
	self:SetModelRef(locationEntity, model)
	self:SetTransformCFrame(locationEntity, model:GetPivot())
	self:_SetName(locationEntity, rootEntityName)

	-- Reset the zone index so lookups only see the new active location.
	self._locationEntity = locationEntity
	table.clear(self._zoneEntityByName)

	return locationEntity
end

--[=[
	Creates a zone child entity under the active location root.
	@within LocationECSEntityFactory
	@param locationEntity number -- Active location entity that owns the zone.
	@param zoneName string -- Unique zone name within the active location.
	@param zoneInstance Instance -- Runtime instance that represents the zone.
	@return number -- Created zone entity id.
]=]
function LocationECSEntityFactory:CreateZoneEntity(
	locationEntity: number,
	zoneName: string,
	zoneInstance: Instance
): number
	self:RequireReady()
	self:_RequireLocationComponentConfigured()
	self:_RequireEntityExists(locationEntity, "CreateZoneEntity")
	assert(
		locationEntity == self._locationEntity,
		("%sEntityFactory:CreateZoneEntity requires active location root"):format(self._contextName)
	)
	assert(
		type(zoneName) == "string" and zoneName ~= "",
		("%sEntityFactory:CreateZoneEntity requires zoneName"):format(self._contextName)
	)
	assert(zoneInstance, ("%sEntityFactory:CreateZoneEntity requires zoneInstance"):format(self._contextName))
	assert(
		self._zoneEntityByName[zoneName] == nil,
		("%sEntityFactory: duplicate zone name '%s'"):format(self._contextName, zoneName)
	)

	-- Create the child entity and store the zone metadata payload.
	local zoneEntity = self:_CreateChildEntity(locationEntity)
	self:_Set(zoneEntity, self._zoneComponent, {
		ZoneName = zoneName,
		Instance = zoneInstance,
	})

	-- Seed transform data so the zone has a stable world-space position.
	local zoneCFrame = _ResolveCFrame(self, zoneInstance)
	if zoneCFrame ~= nil then
		self:SetTransformCFrame(zoneEntity, zoneCFrame)
	end

	-- Name and index the zone for later lookup.
	self:_SetName(zoneEntity, ("LocationZone:%s"):format(zoneName))
	self._zoneEntityByName[zoneName] = zoneEntity
	return zoneEntity
end

--[=[
	Registers every named zone instance against the active location root.
	@within LocationECSEntityFactory
	@param locationEntity number -- Active location entity that owns the zones.
	@param zonesByName { [string]: Instance } -- Zone instances keyed by zone name.
]=]
function LocationECSEntityFactory:RegisterZones(locationEntity: number, zonesByName: { [string]: Instance })
	self:RequireReady()
	assert(
		type(zonesByName) == "table",
		("%sEntityFactory:RegisterZones requires zonesByName"):format(self._contextName)
	)

	-- Register each named zone under the current active location.
	for zoneName, zoneInstance in pairs(zonesByName) do
		self:CreateZoneEntity(locationEntity, zoneName, zoneInstance)
	end
end

--[=[
	Deletes the active location root and clears all cached zone lookups.
	@within LocationECSEntityFactory
	@return boolean -- True when an active location existed and was removed.
]=]
function LocationECSEntityFactory:DeleteActiveLocation(): boolean
	self:RequireReady()

	local locationEntity = self._locationEntity
	if locationEntity == nil then
		return false
	end

	-- Destroy the root before clearing local caches so child entities are removed too.
	self:MarkForDestruction(locationEntity)
	self:FlushDestructionQueue()
	self._locationEntity = nil
	table.clear(self._zoneEntityByName)
	return true
end

--[=[
	Returns the active location entity id, if one exists.
	@within LocationECSEntityFactory
	@return number? -- Active location entity id or nil.
]=]
function LocationECSEntityFactory:GetActiveLocationEntity(): number?
	return self._locationEntity
end

--[=[
	Returns the model bound to the active location root, if one exists.
	@within LocationECSEntityFactory
	@return Model? -- Bound location model or nil.
]=]
function LocationECSEntityFactory:GetLocationModel(): Model?
	local locationEntity = self._locationEntity
	if locationEntity == nil then
		return nil
	end

	return self:GetEntityModel(locationEntity)
end

--[=[
	Returns the current world CFrame for the active location root, if one exists.
	@within LocationECSEntityFactory
	@return CFrame? -- Active location world CFrame or nil.
]=]
function LocationECSEntityFactory:GetLocationCFrame(): CFrame?
	local locationEntity = self._locationEntity
	if locationEntity == nil then
		return nil
	end

	return self:GetEntityCFrame(locationEntity)
end

--[=[
	Returns the current world position for the active location root, if one exists.
	@within LocationECSEntityFactory
	@return Vector3? -- Active location world position or nil.
]=]
function LocationECSEntityFactory:GetLocationPosition(): Vector3?
	local cframe = self:GetLocationCFrame()
	return cframe and cframe.Position or nil
end

--[=[
	Returns the ECS entity id for a named zone, if it has been registered.
	@within LocationECSEntityFactory
	@param zoneName string -- Zone name to look up.
	@return number? -- Matching zone entity id or nil.
]=]
function LocationECSEntityFactory:GetZoneEntity(zoneName: string): number?
	self:RequireReady()
	return self._zoneEntityByName[zoneName]
end

--[=[
	Returns the runtime instance bound to a registered zone, if one exists.
	@within LocationECSEntityFactory
	@param zoneName string -- Zone name to inspect.
	@return Instance? -- Bound zone instance or nil.
]=]
function LocationECSEntityFactory:GetZoneInstance(zoneName: string): Instance?
	local zoneEntity = self:GetZoneEntity(zoneName)
	if zoneEntity == nil then
		return nil
	end

	local zoneData = self:_Get(zoneEntity, self:_GetZoneComponent())
	return zoneData and zoneData.Instance or nil
end

--[=[
	Returns the world CFrame for a registered zone, if one exists.
	@within LocationECSEntityFactory
	@param zoneName string -- Zone name to inspect.
	@return CFrame? -- Zone world CFrame or nil.
]=]
function LocationECSEntityFactory:GetZoneCFrame(zoneName: string): CFrame?
	local zoneEntity = self:GetZoneEntity(zoneName)
	if zoneEntity == nil then
		return nil
	end

	local transform = self:GetTransform(zoneEntity)
	return transform and transform.CFrame or nil
end

--[=[
	Returns the world position for a registered zone, if one exists.
	@within LocationECSEntityFactory
	@param zoneName string -- Zone name to inspect.
	@return Vector3? -- Zone world position or nil.
]=]
function LocationECSEntityFactory:GetZonePosition(zoneName: string): Vector3?
	local cframe = self:GetZoneCFrame(zoneName)
	return cframe and cframe.Position or nil
end

--[=[
	Returns every registered zone name in sorted order.
	@within LocationECSEntityFactory
	@return { string } -- Sorted zone names.
]=]
function LocationECSEntityFactory:GetZoneNames(): { string }
	self:RequireReady()

	local zoneNames = {}
	for zoneName in pairs(self._zoneEntityByName) do
		table.insert(zoneNames, zoneName)
	end
	table.sort(zoneNames)
	return zoneNames
end

--[=[
	Returns whether a zone with the given name has been registered.
	@within LocationECSEntityFactory
	@param zoneName string -- Zone name to check.
	@return boolean -- True when the zone exists.
]=]
function LocationECSEntityFactory:HasZone(zoneName: string): boolean
	self:RequireReady()
	return self._zoneEntityByName[zoneName] ~= nil
end

-- Validates that the zone component has been configured before zone entities are created.
function LocationECSEntityFactory:_RequireLocationComponentConfigured()
	assert(
		self._zoneComponent ~= nil,
		("%sEntityFactory: location zone component not configured"):format(self._contextName)
	)
end

-- Returns the configured zone component after validating initialization state.
function LocationECSEntityFactory:_GetZoneComponent()
	self:_RequireLocationComponentConfigured()
	return self._zoneComponent
end

return LocationECSEntityFactory
