--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseSyncService = require(ReplicatedStorage.Utilities.BaseSyncService)
local SharedAtoms = require(ReplicatedStorage.Contexts.Building.Sync.SharedAtoms)

--[=[
	@class BuildingSyncService
	Synchronizes server-authoritative building slot state to client atoms.
	@server
]=]
local BuildingSyncService = setmetatable({}, { __index = BaseSyncService })
BuildingSyncService.__index = BuildingSyncService
BuildingSyncService.AtomKey = "buildings"
BuildingSyncService.BlinkEventName = "SyncBuildings"
BuildingSyncService.CreateAtom = SharedAtoms.CreateServerAtom

--[=[
	Create a building sync service instance.
	@within BuildingSyncService
	@return any -- New sync service instance.
]=]
function BuildingSyncService.new()
	return setmetatable({}, BuildingSyncService)
end

--[=[
	Initialize base sync service wiring.
	@within BuildingSyncService
	@param registry any -- Context registry for sync dependencies.
	@param name string -- Registered service name.
]=]
function BuildingSyncService:Init(registry: any, name: string)
	BaseSyncService.Init(self, registry, name)
end

--[=[
	Load a player's full building map into synchronized atom state.
	@within BuildingSyncService
	@param userId number -- User ID key in sync atom.
	@param buildings SharedAtoms.TBuildingsMap -- Full zone-slot building map.
]=]
function BuildingSyncService:LoadPlayerBuildings(userId: number, buildings: SharedAtoms.TBuildingsMap)
	self:LoadUserData(userId, buildings)
end

--[=[
	Remove a player's building map from synchronized atom state.
	@within BuildingSyncService
	@param userId number -- User ID key in sync atom.
]=]
function BuildingSyncService:RemovePlayerBuildings(userId: number)
	self:RemoveUserData(userId)
end

--[=[
	Set one building slot entry in synchronized atom state.
	@within BuildingSyncService
	@param userId number -- User ID key in sync atom.
	@param zoneName string -- Zone containing the slot.
	@param slotIndex number -- One-based slot index.
	@param buildingType string -- Building type key for the slot.
	@param level number -- Current building level.
]=]
function BuildingSyncService:SetSlot(
	userId: number,
	zoneName: string,
	slotIndex: number,
	buildingType: string,
	level: number
)
	self.Atom(function(current)
		local updated = table.clone(current)
		local userMap = if updated[userId] then table.clone(updated[userId]) else {}
		local zoneSlots = if userMap[zoneName] then table.clone(userMap[zoneName]) else {}
		zoneSlots[slotIndex] = { BuildingType = buildingType, Level = level }
		userMap[zoneName] = zoneSlots
		updated[userId] = userMap
		return updated
	end)
end

--[=[
	Get a read-only building map for one player.
	@within BuildingSyncService
	@param userId number -- User ID key in sync atom.
	@return SharedAtoms.TBuildingsMap? -- Read-only zone-slot map for player.
]=]
function BuildingSyncService:GetBuildingsReadOnly(userId: number): SharedAtoms.TBuildingsMap?
	return self:GetReadOnly(userId)
end

--[=[
	Get the shared buildings atom object.
	@within BuildingSyncService
	@return any -- Shared atom used for building synchronization.
]=]
function BuildingSyncService:GetBuildingsAtom()
	return self:GetAtom()
end

return BuildingSyncService
