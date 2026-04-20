--!strict

--[=[
	@class RemoteLotEntityFactory
	Creates and queries ECS entities for remote lots and their zones.
	@server
]=]

--[[
	Creates and queries ECS entities for remote lots.
	Reuses the same JECS world and component types as LotContext so that
	LotContext's zone folder getters (FindFarmFolderByUserId, etc.) can find
	remote zone entities transparently — they traverse the same ChildOf hierarchy.

	Entity hierarchy created per player:
	  RemoteLotEntity  (LotComponent, PositionComponent)
	    └── RemoteProductionEntity (ZoneComponent)
	      └── FarmEntity        (FarmComponent)
	      └── GardenEntity      (GardenComponent)
	      └── ForestEntity      (ForestComponent)
	      └── MinesEntity       (MinesComponent)

	Remote zone entities are indirect children of RemoteLotEntity via a production
	intermediary because _FindZoneFolderByUserId traverses grandparent → must match
	the lot entity. We insert a RemoteProductionEntity to match the village lot hierarchy.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local JECS = require(ReplicatedStorage.Packages.JECS)

local RemoteLotEntityFactory = {}
RemoteLotEntityFactory.__index = RemoteLotEntityFactory

export type TRemoteLotEntityFactory = typeof(setmetatable(
	{} :: {
		_world: any,
		_components: any,
	},
	RemoteLotEntityFactory
))

function RemoteLotEntityFactory.new(): TRemoteLotEntityFactory
	local self = setmetatable({}, RemoteLotEntityFactory)
	self._world = nil :: any
	self._components = nil :: any
	return self
end

function RemoteLotEntityFactory:Init(registry: any, _name: string)
	-- Reuse the Lot ECS world and components — same world, same component types
	self._world = registry:Get("LotWorld")
	self._components = registry:Get("LotComponents")
end

--[=[
	Creates a RemoteLot entity for a player.
	Returns the entity so the caller can pass it to CreateZoneEntities.
	@within RemoteLotEntityFactory
	@param userId number
	@param cframe CFrame
	@return any -- The created entity
]=]
function RemoteLotEntityFactory:CreateRemoteLot(userId: number, cframe: CFrame): any
	local world: any = self._world
	local entity = world:entity()
	local remoteLotId = "RemoteLot_" .. userId
	local entityName = "RemoteLot:" .. userId

	-- Set lot identity component
	world:set(entity, self._components.LotComponent, {
		LotId = remoteLotId,
		UserId = userId,
	})

	-- Set position component
	world:set(entity, self._components.PositionComponent, {
		CFrameValue = cframe,
	})

	-- Set debug tags for identification
	world:set(entity, self._components.EntityTag, entityName)
	world:set(entity, JECS.Name, entityName)

	return entity
end

--[=[
	Creates zone entities as children of the remote lot entity.
	Only creates entities for folders that actually exist on the remote lot model.
	Uses the same ChildOf depth (grandparent pattern) as LotEntityFactory by
	inserting a RemoteProductionEntity in between.
	@within RemoteLotEntityFactory
	@param remoteLotEntity any
	@param remoteLotModel Model
]=]
function RemoteLotEntityFactory:CreateZoneEntities(remoteLotEntity: any, remoteLotModel: Model)
	local world: any = self._world

	-- Step 1: Create a production intermediary so _FindZoneFolderByUserId's grandparent
	-- traversal resolves to remoteLotEntity (mirrors the village lot hierarchy)
	local productionEntity = world:entity()
	world:set(productionEntity, self._components.ZoneComponent, {
		ZoneName = "RemoteProduction",
		Instance = remoteLotModel,
	})
	world:add(productionEntity, JECS.pair(self._components.ChildOf, remoteLotEntity))
	world:set(productionEntity, JECS.Name, "RemoteProduction:" .. remoteLotModel.Name)

	-- Step 2: Create entities for each zone folder that exists on the model
	local zoneComponentMap = self:_GetZoneComponentMap()

	for zoneName, component in zoneComponentMap do
		local folder = remoteLotModel:FindFirstChild(zoneName) :: Folder?
		-- Skip zones that don't exist on this model
		if not folder then
			continue
		end

		-- Create zone entity as child of production entity
		local entity = world:entity()
		world:set(entity, component, { Instance = folder })
		world:add(entity, JECS.pair(self._components.ChildOf, productionEntity))
		world:set(entity, self._components.EntityTag, zoneName)
		world:set(entity, JECS.Name, "Remote:" .. zoneName .. ":" .. tostring(remoteLotModel.Name))
	end
end

--[=[
	Registers zone folders that become available from an unlocked expansion area.
	@within RemoteLotEntityFactory
	@param remoteLotEntity any -- The player's remote lot entity
	@param remoteLotModel Model -- The player's remote lot model
	@param areaDef any -- Remote lot area config row
]=]
function RemoteLotEntityFactory:RegisterExpansionZones(remoteLotEntity: any, remoteLotModel: Model, areaDef: any)
	local productionEntity = self:_FindRemoteProductionEntity(remoteLotEntity)
	if not productionEntity then
		return
	end

	local zoneComponentMap = self:_GetZoneComponentMap()
	for _, zoneName in areaDef.ZoneFolders do
		local component = zoneComponentMap[zoneName]
		local folder = component and self:_FindExpansionZoneFolder(remoteLotModel, areaDef, zoneName)
		if folder and not self:_ZoneFolderIsRegistered(component, folder) then
			self:_CreateZoneEntity(productionEntity, zoneName, component, folder, remoteLotModel.Name)
		end
	end
end

--[=[
	Finds the remote lot entity for a player by userId.
	@within RemoteLotEntityFactory
	@param userId number
	@return any? -- The remote lot entity, or nil if not found
]=]
function RemoteLotEntityFactory:FindRemoteLotByUserId(userId: number): any?
	local world: any = self._world
	local remoteLotPrefix = "RemoteLot_"
	-- Query all entities with LotComponent and find the one matching this userId
	for entity, data in world:query(self._components.LotComponent) do
		if data.UserId == userId and string.find(data.LotId, remoteLotPrefix) then
			return entity
		end
	end
	return nil
end

--[=[
	Returns the CFrame stored on a remote lot entity, or nil.
	@within RemoteLotEntityFactory
	@param entity any
	@return CFrame? -- The entity's CFrame, or nil if not found
]=]
function RemoteLotEntityFactory:GetLotCFrame(entity: any): CFrame?
	local position = self._world:get(entity, self._components.PositionComponent)
	return position and position.CFrameValue or nil
end

--[=[
	Injects the Lot ECS world and components from LotContext.
	Called manually in KnitStart after cross-context dependencies are available.
	@within RemoteLotEntityFactory
	@param world any
	@param components any
]=]
function RemoteLotEntityFactory:InjectLotWorld(world: any, components: any)
	self._world = world
	self._components = components
end

function RemoteLotEntityFactory:_GetZoneComponentMap(): { [string]: any }
	return {
		Farm = self._components.FarmComponent,
		Garden = self._components.GardenComponent,
		Forest = self._components.ForestComponent,
		Mines = self._components.MinesComponent,
		Forge = self._components.ForgeComponent,
		Brewery = self._components.BreweryComponent,
		TailorShop = self._components.TailorShopComponent,
	}
end

function RemoteLotEntityFactory:_FindRemoteProductionEntity(remoteLotEntity: any): any?
	for entity, data in self._world:query(self._components.ZoneComponent) do
		if data.ZoneName == "RemoteProduction" then
			local parentEntity = self._world:target(entity, self._components.ChildOf)
			if parentEntity == remoteLotEntity then
				return entity
			end
		end
	end
	return nil
end

function RemoteLotEntityFactory:_FindExpansionZoneFolder(remoteLotModel: Model, areaDef: any, zoneName: string): Folder?
	local areasFolder = remoteLotModel:FindFirstChild("ExpansionAreas")
	local areaGroup = areasFolder and areasFolder:FindFirstChild(areaDef.RevealGroupName)
	if not areaGroup then
		return nil
	end

	local folder = areaGroup:FindFirstChild(zoneName, true)
	return if folder and folder:IsA("Folder") then folder else nil
end

function RemoteLotEntityFactory:_ZoneFolderIsRegistered(component: any, folder: Folder): boolean
	for _, data in self._world:query(component) do
		if data.Instance == folder then
			return true
		end
	end
	return false
end

function RemoteLotEntityFactory:_CreateZoneEntity(
	productionEntity: any,
	zoneName: string,
	component: any,
	folder: Folder,
	modelName: string
)
	local entity = self._world:entity()
	self._world:set(entity, component, { Instance = folder })
	self._world:add(entity, JECS.pair(self._components.ChildOf, productionEntity))
	self._world:set(entity, self._components.EntityTag, zoneName)
	self._world:set(entity, JECS.Name, "Remote:" .. zoneName .. ":" .. modelName)
end

--[=[
	Deletes a remote lot entity and all its children (cascade deletes zone entities).
	@within RemoteLotEntityFactory
	@param entity any
]=]
function RemoteLotEntityFactory:DeleteRemoteLot(entity: any)
	self._world:delete(entity)
end

return RemoteLotEntityFactory
