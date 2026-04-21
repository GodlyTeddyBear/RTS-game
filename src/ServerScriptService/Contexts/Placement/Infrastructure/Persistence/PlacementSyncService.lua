--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharmSync = require(ReplicatedStorage.Packages["Charm-sync"])
local PlacementTypes = require(ReplicatedStorage.Contexts.Placement.Types.PlacementTypes)
local SharedAtoms = require(ReplicatedStorage.Contexts.Placement.Sync.SharedAtoms)

type PlacementAtom = PlacementTypes.PlacementAtom
type StructureRecord = PlacementTypes.StructureRecord

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
	self.Atom = SharedAtoms.CreateServerAtom()
	self.Syncer = CharmSync.server({
		atoms = { placements = self.Atom },
		interval = 0.1,
		preserveHistory = false,
		autoSerialize = false,
	})

	-- Use the Blink event as the transport boundary; the atom stays server-authoritative.
	self.Cleanup = self.Syncer:connect(function(player: Player, payload: buffer)
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
	self.Syncer:hydrate(player)
end

--[=[
	Returns the current number of placed structures.
	@within PlacementSyncService
	@return number -- The current placement count.
]=]
-- Placement count is read for cap checks before any write work begins.
function PlacementSyncService:GetPlacementCount(): number
	local state = self.Atom() :: PlacementAtom
	return #state.placements
end

--[=[
	Returns a deep-cloned list of placed structures.
	@within PlacementSyncService
	@return { StructureRecord } -- The cloned placement list.
]=]
-- Return a deep clone so callers cannot mutate the atom snapshot in place.
function PlacementSyncService:GetPlacementsReadOnly(): { StructureRecord }
	local state = self.Atom() :: PlacementAtom
	return deepClone(state.placements)
end

--[=[
	Adds a placement record to the atom.
	@within PlacementSyncService
	@param record StructureRecord -- The placement record to append.
]=]
-- Clone the incoming record before storing it so the atom always sees a new table path.
function PlacementSyncService:AddPlacement(record: StructureRecord)
	self.Atom(function(current: PlacementAtom)
		local updated = table.clone(current)
		updated.placements = table.clone(current.placements)
		table.insert(updated.placements, deepClone(record))
		return updated
	end)
end

--[=[
	Clears every placement from the atom.
	@within PlacementSyncService
]=]
-- Reset the placement atom at run end so the next run starts empty.
function PlacementSyncService:ClearAll()
	self.Atom(function(_current: PlacementAtom)
		return {
			placements = {},
		}
	end)
end

--[=[
	Disconnects the Blink bridge and releases sync resources.
	@within PlacementSyncService
]=]
-- Disconnect the sync bridge during teardown.
function PlacementSyncService:Destroy()
	if self.Cleanup then
		self.Cleanup()
	end
end

return PlacementSyncService
