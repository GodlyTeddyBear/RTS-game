--!strict

--[=[
	@class BuildingEntityFactory
	Creates, queries, and deletes JECS entities for buildings.
	Each building is its own entity keyed by BuildingId.
	@server
]=]
local BuildingEntityFactory = {}
BuildingEntityFactory.__index = BuildingEntityFactory

export type TBuildingEntityFactory = typeof(setmetatable(
	{} :: {
		_world: any,
		_components: any,
	},
	BuildingEntityFactory
))

function BuildingEntityFactory.new(): TBuildingEntityFactory
	local self = setmetatable({}, BuildingEntityFactory)
	self._world = nil :: any
	self._components = nil :: any
	return self
end

function BuildingEntityFactory:Init(registry: any, _name: string)
	local worldService = registry:Get("BuildingECSWorldService")
	self._world = worldService:GetWorld()
	self._components = registry:Get("BuildingComponentRegistry")
end

--[=[
	Creates a building entity and marks it dirty for sync.
	@within BuildingEntityFactory
]=]
function BuildingEntityFactory:CreateBuilding(
	buildingId: string,
	userId: number,
	zoneName: string,
	slotIndex: number,
	buildingType: string
): any
	local entity = self._world:entity()

	self._world:set(entity, self._components.BuildingComponent, {
		BuildingId = buildingId,
		UserId = userId,
		ZoneName = zoneName,
		SlotIndex = slotIndex,
		BuildingType = buildingType,
		Level = 1,
	})

	self._world:set(entity, self._components.DirtyTag, true)

	return entity
end

--[=[
	Destroys a building entity.
	@within BuildingEntityFactory
]=]
function BuildingEntityFactory:DeleteBuilding(entity: any)
	self._world:delete(entity)
end

--[=[
	Finds a building entity by its BuildingId string.
	@within BuildingEntityFactory
]=]
function BuildingEntityFactory:FindBuildingById(buildingId: string): any?
	for entity, data in self._world:query(self._components.BuildingComponent) do
		if data.BuildingId == buildingId then
			return entity
		end
	end
	return nil
end

--[=[
	Finds a building entity by userId, zone, and slot.
	@within BuildingEntityFactory
]=]
function BuildingEntityFactory:FindBuildingBySlot(userId: number, zoneName: string, slotIndex: number): any?
	for entity, data in self._world:query(self._components.BuildingComponent) do
		if data.UserId == userId and data.ZoneName == zoneName and data.SlotIndex == slotIndex then
			return entity
		end
	end
	return nil
end

--[=[
	Returns all building entities owned by a userId.
	@within BuildingEntityFactory
]=]
function BuildingEntityFactory:FindBuildingsByUser(userId: number): { any }
	local results = {}
	for entity, data in self._world:query(self._components.BuildingComponent) do
		if data.UserId == userId then
			table.insert(results, entity)
		end
	end
	return results
end

--[=[
	Bumps the level on a building entity and marks it dirty.
	@within BuildingEntityFactory
]=]
function BuildingEntityFactory:IncrementLevel(entity: any)
	local data = self._world:get(entity, self._components.BuildingComponent)
	if data then
		local updated = table.clone(data)
		updated.Level = updated.Level + 1
		self._world:set(entity, self._components.BuildingComponent, updated)
		self._world:set(entity, self._components.DirtyTag, true)
	end
end

--[=[
	Gets the BuildingComponent data for an entity.
	@within BuildingEntityFactory
]=]
function BuildingEntityFactory:GetBuildingData(entity: any): any?
	return self._world:get(entity, self._components.BuildingComponent)
end

return BuildingEntityFactory
