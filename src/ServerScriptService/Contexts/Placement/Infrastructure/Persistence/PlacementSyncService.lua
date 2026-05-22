--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharmSync = require(ReplicatedStorage.Packages["Charm-sync"])
local DebugConfig = require(ReplicatedStorage.Config.DebugConfig)
local DebugPlus = require(ReplicatedStorage.Utilities.DebugPlus)
local PlacementFootprintResolver = require(ReplicatedStorage.Contexts.Placement.PlacementFootprintResolver)
local PlacementTypes = require(ReplicatedStorage.Contexts.Placement.Types.PlacementTypes)
local SharedAtoms = require(ReplicatedStorage.Contexts.Placement.Sync.SharedAtoms)

type PlacementAtom = PlacementTypes.PlacementAtom
type StructureRecord = PlacementTypes.StructureRecord
type FootprintCacheEntry = PlacementTypes.FootprintCacheEntry
type FootprintCacheLookup = PlacementTypes.FootprintCacheLookup

local function deepClone(value: any): any
	if type(value) ~= "table" then
		return value
	end

	local clone = {}
	for key, entry in value do
		clone[key] = deepClone(entry)
	end
	return clone
end

--[=[
	@class PlacementSyncService
	Owns the global placement atom and sync payload replication.
	@server
]=]
local PlacementSyncService = {}
PlacementSyncService.__index = PlacementSyncService

local PROFILE_NAME = "PlacementSyncService"
local SYNC_SERVICE_PROFILING_ENABLED = DebugConfig.SYNC_SERVICE_PROFILING

--[=[
	Creates a new placement sync service.
	@within PlacementSyncService
	@return PlacementSyncService -- The new service instance.
]=]
function PlacementSyncService.new()
	local self = setmetatable({}, PlacementSyncService)
	self.Atom = nil :: any
	self.Syncer = nil :: any
	self.Cleanup = nil :: (() -> ())?
	self.BlinkServer = nil :: any
	self._footprintCacheLookup = {} :: FootprintCacheLookup
	return self
end

--[=[
	Initializes the atom, Charm-sync server, and Blink bridge.
	@within PlacementSyncService
	@param registry any -- The dependency registry for this context.
	@param _name string -- The registered module name.
]=]
-- Wire Charm-sync to the placement atom and forward raw delta payloads through Blink.
function PlacementSyncService:Init(registry: any, _name: string)
	self.BlinkServer = registry:Get("BlinkSyncServer")
	local footprintCache = PlacementFootprintResolver.BuildCacheEntriesForConfiguredStructures()
	self._footprintCacheLookup = PlacementFootprintResolver.BuildLookup(footprintCache)
	self.Atom = SharedAtoms.CreateServerAtom(footprintCache)
	self.Syncer = CharmSync.server({
		atoms = { Placements = self.Atom },
		interval = 0.1,
		preserveHistory = false,
		autoSerialize = false,
	})

	-- Build the Placement Blink payload explicitly so the enum discriminator stays Pascal-case.
	self.Cleanup = self.Syncer:connect(function(player: Player, payload)
		self.BlinkServer.SyncPlacements.Fire(player, payload)
	end)
end

--[=[
	Hydrates a player with the current placement atom snapshot.
	@within PlacementSyncService
	@param player Player -- The player to hydrate.
]=]
-- Hydrate new players so the client atom starts from the current authoritative snapshot.
function PlacementSyncService:HydratePlayer(player: Player)
	DebugPlus.profile(("%s:HydratePlayer"):format(PROFILE_NAME), function()
		self.Syncer:hydrate(player)
	end, SYNC_SERVICE_PROFILING_ENABLED)
end

--[=[
	Returns the current number of placed structures.
	@within PlacementSyncService
	@return number -- The current placement count.
]=]
-- Placement count is read for cap checks before any write work begins.
function PlacementSyncService:GetPlacementCount(): number
	local state = self.Atom() :: PlacementAtom
	return #state.Placements
end

--[=[
	Returns a deep-cloned list of placed structures.
	@within PlacementSyncService
	@return { StructureRecord } -- The cloned placement list.
]=]
-- Return a deep clone so callers cannot mutate the atom snapshot in place.
function PlacementSyncService:GetPlacementsReadOnly(): { StructureRecord }
	local state = self.Atom() :: PlacementAtom
	return deepClone(state.Placements)
end

function PlacementSyncService:GetFootprintCacheLookup(): FootprintCacheLookup
	return self._footprintCacheLookup
end

function PlacementSyncService:GetFootprintCacheReadOnly(): { FootprintCacheEntry }
	local state = self.Atom() :: PlacementAtom
	return deepClone(state.FootprintCache)
end

--[=[
	Adds a placement record to the atom.
	@within PlacementSyncService
	@param record StructureRecord -- The placement record to append.
]=]
-- Clone the incoming record before storing it so the atom always sees a new table path.
function PlacementSyncService:AddPlacement(record: StructureRecord)
	DebugPlus.profile(("%s:AddPlacement"):format(PROFILE_NAME), function()
		self.Atom(function(current: PlacementAtom)
			local updated = table.clone(current)
			updated.Placements = table.clone(current.Placements)
			updated.Revision = current.Revision + 1
			table.insert(updated.Placements, deepClone(record))
			return updated
		end)
	end, SYNC_SERVICE_PROFILING_ENABLED)
end

--[=[
	Removes a placement record by runtime instance id.
	@within PlacementSyncService
	@param instanceId number -- Runtime instance id to remove.
	@return StructureRecord? -- The removed placement record, or nil when not found.
]=]
function PlacementSyncService:RemovePlacementByInstanceId(instanceId: number): StructureRecord?
	return DebugPlus.profile(("%s:RemovePlacementByInstanceId"):format(PROFILE_NAME), function()
		local removedRecord = nil :: StructureRecord?

		self.Atom(function(current: PlacementAtom)
			local removeIndex = nil :: number?
			for index, record in ipairs(current.Placements) do
				if record.InstanceId == instanceId then
					removeIndex = index
					removedRecord = deepClone(record)
					break
				end
			end

			if removeIndex == nil then
				return current
			end

			local updated = table.clone(current)
			updated.Placements = table.clone(current.Placements)
			updated.Revision = current.Revision + 1
			table.remove(updated.Placements, removeIndex)
			return updated
		end)

		return removedRecord
	end, SYNC_SERVICE_PROFILING_ENABLED)
end

--[=[
	Clears every placement from the atom.
	@within PlacementSyncService
]=]
-- Reset the placement atom at run end so the next run starts empty.
function PlacementSyncService:ClearAll()
	DebugPlus.profile(("%s:ClearAll"):format(PROFILE_NAME), function()
		self.Atom(function(current: PlacementAtom)
			return {
				Placements = {},
				FootprintCache = table.clone(current.FootprintCache),
				Revision = current.Revision + 1,
			}
		end)
	end, SYNC_SERVICE_PROFILING_ENABLED)
end

--[=[
	Disconnects the Blink bridge and releases sync resources.
	@within PlacementSyncService
]=]
-- Disconnect the sync bridge during teardown.
function PlacementSyncService:Destroy()
	DebugPlus.profile(("%s:Destroy"):format(PROFILE_NAME), function()
		if self.Cleanup then
			self.Cleanup()
		end
	end, SYNC_SERVICE_PROFILING_ENABLED)
end

return PlacementSyncService
