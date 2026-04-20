--!strict

--[[
	Lot Entity Factory - Create and manage lot JECS entities

	Responsibility: Create lot entities with components, delete entities cleanly.
	Infrastructure layer - handles technical entity lifecycle.
]]

--[=[
	@class LotEntityFactory
	Creates and manages lot JECS entities and zone sub-entities.
	@server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local JECS = require(ReplicatedStorage.Packages.JECS)

local LotEntityFactory = {}
LotEntityFactory.__index = LotEntityFactory

--[=[
	Create a new LotEntityFactory instance.
	@within LotEntityFactory
	@return LotEntityFactory -- Service instance
]=]
function LotEntityFactory.new()
	local self = setmetatable({}, LotEntityFactory)
	return self
end

--[=[
	Initialize with injected dependencies.
	@within LotEntityFactory
	@param registry any -- Registry to resolve dependencies from
]=]
function LotEntityFactory:Init(registry: any)
	self.World = registry:Get("World")
	self.Components = registry:Get("Components")
end

--[=[
	Create a new lot entity with core components.
	@within LotEntityFactory
	@param lotId any -- LotId value object
	@param userId number -- Player ID who owns this lot
	@param cframe CFrame -- World CFrame from LotArea Part
	@return any -- The created JECS entity
]=]
function LotEntityFactory:CreateLot(lotId: any, userId: number, cframe: CFrame)
	local world: any = self.World
	local entity = world:entity()

	-- Add LotComponent with core data
	world:set(entity, self.Components.LotComponent, {
		LotId = lotId:GetId(),
		UserId = userId,
	})

	-- Add PositionComponent with CFrame
	world:set(entity, self.Components.PositionComponent, {
		CFrameValue = cframe,
	})

	-- Mark for sync on next Heartbeat
	world:set(entity, self.Components.DirtyTag)
	world:set(entity, self.Components.EntityTag, `Lot:{lotId:GetId()}`)
	world:set(entity, JECS.Name, `Lot:{lotId:GetId()}`)

	return entity
end

--[=[
	Delete a lot entity and all child entities.
	Uses world:delete() which cascade-deletes all child entities via ChildOf relationship.
	@within LotEntityFactory
	@param entity any -- The JECS entity to delete
]=]
function LotEntityFactory:DeleteLot(entity: any)
	local world: any = self.World
	world:delete(entity)
end

--[=[
	Create zone sub-entities as children of a lot entity.
	Creates ProductionEntity and zone sub-entities (Mines, Farm, Garden, Forest, Forge, Brewery, TailorShop).
	@within LotEntityFactory
	@param lotEntity any -- The parent lot JECS entity
	@param lotModel Model -- The Roblox model for the lot (must have Zones.Production structure)
]=]
function LotEntityFactory:CreateZoneEntities(lotEntity: any, lotModel: Model)
	local world: any = self.World

	local zonesFolder = lotModel:FindFirstChild("Zones") :: Folder?
	if not zonesFolder then
		warn("[LotEntityFactory:CreateZoneEntities] No Zones folder on lot model")
		return
	end

	local productionFolder = zonesFolder:FindFirstChild("Production") :: Folder?
	if not productionFolder then
		warn("[LotEntityFactory:CreateZoneEntities] No Production zone on lot model")
		return
	end

	-- Create ProductionEntity as child of LotEntity
	local productionEntity = world:entity()
	world:set(productionEntity, self.Components.ZoneComponent, {
		ZoneName = "Production",
		Instance = productionFolder,
	})
	world:add(productionEntity, JECS.pair(self.Components.ChildOf, lotEntity))
	world:set(productionEntity, self.Components.EntityTag, "Production")
	world:set(productionEntity, JECS.Name, "Production")

	-- Create zone entities for each production zone that exists on the lot model
	self:_CreateZoneEntity(productionEntity, productionFolder, "Mines", self.Components.MinesComponent)
	self:_CreateZoneEntity(productionEntity, productionFolder, "Farm", self.Components.FarmComponent)
	self:_CreateZoneEntity(productionEntity, productionFolder, "Garden", self.Components.GardenComponent)
	self:_CreateZoneEntity(productionEntity, productionFolder, "Forest", self.Components.ForestComponent)
	self:_CreateZoneEntity(productionEntity, productionFolder, "Forge", self.Components.ForgeComponent)
	self:_CreateZoneEntity(productionEntity, productionFolder, "Brewery", self.Components.BreweryComponent)
	self:_CreateZoneEntity(productionEntity, productionFolder, "TailorShop", self.Components.TailorShopComponent)
end

--[=[
	Create a zone sub-entity if the folder exists on the lot model.
	Silently skips if the folder is not present (zone not yet built).
	@within LotEntityFactory
	@param parentEntity any -- The parent ProductionEntity
	@param parentFolder Folder -- The Production folder to search in
	@param zoneName string -- The folder name to look for (e.g. "Mines", "Farm")
	@param component any -- The JECS component type to set on the entity
]=]
function LotEntityFactory:_CreateZoneEntity(parentEntity: any, parentFolder: Folder, zoneName: string, component: any)
	local world: any = self.World
	local folder = parentFolder:FindFirstChild(zoneName) :: Folder?
	if not folder then
		return
	end

	local entity = world:entity()
	world:set(entity, component, { Instance = folder })
	world:add(entity, JECS.pair(self.Components.ChildOf, parentEntity))
	world:set(entity, self.Components.EntityTag, zoneName)
	world:set(entity, JECS.Name, zoneName)
end

--[=[
	Find any lot entity by UserId (village or remote).
	When the player has both village and remote lots, order is not guaranteed; use FindVillageLotByUserId for specificity.
	@within LotEntityFactory
	@param userId number -- Player ID to search for
	@return any -- The entity if found, nil otherwise
]=]
function LotEntityFactory:FindLotByUserId(userId: number)
	local world: any = self.World
	for entity in world:query(self.Components.LotComponent) do
		local lot = world:get(entity, self.Components.LotComponent)
		if lot.UserId == userId then
			return entity
		end
	end
	return nil
end

--[=[
	Find village lot entity only (excludes RemoteLot_* identifiers used by RemoteLotContext).
	@within LotEntityFactory
	@param userId number -- Player ID to search for
	@return any -- The village lot entity if found, nil otherwise
]=]
function LotEntityFactory:FindVillageLotByUserId(userId: number)
	local world: any = self.World
	local remotePrefix = "RemoteLot_"
	for entity in world:query(self.Components.LotComponent) do
		local lot = world:get(entity, self.Components.LotComponent)
		if lot.UserId == userId and string.sub(lot.LotId, 1, #remotePrefix) ~= remotePrefix then
			return entity
		end
	end
	return nil
end

--[=[
	Collect all lot entities owned by this player (village + remote when both exist).
	@within LotEntityFactory
	@param userId number -- Player ID to search for
	@return {any} -- Array of lot entities owned by this player
]=]
function LotEntityFactory:_CollectLotEntitiesForUser(userId: number): { any }
	local world: any = self.World
	local out = {}
	for entity in world:query(self.Components.LotComponent) do
		local lot = world:get(entity, self.Components.LotComponent)
		if lot.UserId == userId then
			table.insert(out, entity)
		end
	end
	return out
end

--[=[
	Find a zone folder for a player's lot by component type.
	Checks all lot entities (village and remote) for this player.
	@within LotEntityFactory
	@param userId number -- Player ID to search for
	@param component any -- The JECS component type to query
	@return Folder -- The zone folder if found, nil otherwise
]=]
function LotEntityFactory:_FindZoneFolderByUserId(userId: number, component: any): Folder?
	local world: any = self.World

	local lotEntities = self:_CollectLotEntitiesForUser(userId)
	if #lotEntities == 0 then
		return nil
	end

	for _, lotEntity in lotEntities do
		for entity in world:query(component) do
			local parentEntity = world:target(entity, self.Components.ChildOf)
			if parentEntity then
				local grandparentEntity = world:target(parentEntity, self.Components.ChildOf)
				if grandparentEntity == lotEntity then
					local data = world:get(entity, component)
					local folder = data and data.Instance or nil
					if folder then
						return folder
					end
				end
			end
		end
	end

	return nil
end

--[=[
	Find the Mines folder for a player's lot.
	@within LotEntityFactory
	@param userId number -- Player ID to search for
	@return Folder -- The Mines folder if found, nil otherwise
]=]
function LotEntityFactory:FindMinesFolderByUserId(userId: number): Folder?
	return self:_FindZoneFolderByUserId(userId, self.Components.MinesComponent)
end

--[=[
	Find the Farm folder for a player's lot.
	@within LotEntityFactory
	@param userId number -- Player ID to search for
	@return Folder -- The Farm folder if found, nil otherwise
]=]
function LotEntityFactory:FindFarmFolderByUserId(userId: number): Folder?
	return self:_FindZoneFolderByUserId(userId, self.Components.FarmComponent)
end

--[=[
	Find the Garden folder for a player's lot.
	@within LotEntityFactory
	@param userId number -- Player ID to search for
	@return Folder -- The Garden folder if found, nil otherwise
]=]
function LotEntityFactory:FindGardenFolderByUserId(userId: number): Folder?
	return self:_FindZoneFolderByUserId(userId, self.Components.GardenComponent)
end

--[=[
	Find the Forest folder for a player's lot.
	@within LotEntityFactory
	@param userId number -- Player ID to search for
	@return Folder -- The Forest folder if found, nil otherwise
]=]
function LotEntityFactory:FindForestFolderByUserId(userId: number): Folder?
	return self:_FindZoneFolderByUserId(userId, self.Components.ForestComponent)
end

--[=[
	Find the Forge folder for a player's lot.
	@within LotEntityFactory
	@param userId number -- Player ID to search for
	@return Folder -- The Forge folder if found, nil otherwise
]=]
function LotEntityFactory:FindForgeFolderByUserId(userId: number): Folder?
	return self:_FindZoneFolderByUserId(userId, self.Components.ForgeComponent)
end

--[=[
	Find the Brewery folder for a player's lot.
	@within LotEntityFactory
	@param userId number -- Player ID to search for
	@return Folder -- The Brewery folder if found, nil otherwise
]=]
function LotEntityFactory:FindBreweryFolderByUserId(userId: number): Folder?
	return self:_FindZoneFolderByUserId(userId, self.Components.BreweryComponent)
end

--[=[
	Find the TailorShop folder for a player's lot.
	@within LotEntityFactory
	@param userId number -- Player ID to search for
	@return Folder -- The TailorShop folder if found, nil otherwise
]=]
function LotEntityFactory:FindTailorShopFolderByUserId(userId: number): Folder?
	return self:_FindZoneFolderByUserId(userId, self.Components.TailorShopComponent)
end

return LotEntityFactory
