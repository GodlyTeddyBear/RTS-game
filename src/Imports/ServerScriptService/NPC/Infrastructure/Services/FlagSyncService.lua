--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CharmSync = require(ReplicatedStorage.Packages["Charm-sync"])
local SharedAtoms = require(ReplicatedStorage.Contexts.NPC.Sync.SharedAtoms)
local FlagSerializer = require(ReplicatedStorage.Contexts.NPC.Sync.FlagSerializer)

--[[
	Flag Sync Service

	Manages player flag state synchronization between server and client using Charm atoms
	with Blink network transport and init-only payload pattern.

	Architecture: CharmSync + Blink Integration
	- CharmSync.server() provides automatic change detection and player filtering
	- Override :connect() callback to always send full state (init-only, no patches)
	- FlagSerializer splits flags into three typed maps for Blink transport
	- Blink handles efficient buffer serialization for network transport

	IMPORTANT: All atom mutations are centralized in this service.
	Application services must use the mutation methods provided here.
]]

local FlagSyncService = {}
FlagSyncService.__index = FlagSyncService

local function deepClone(tbl: any): any
	if type(tbl) ~= "table" then
		return tbl
	end
	local clone = {}
	for key, value in pairs(tbl) do
		clone[key] = deepClone(value)
	end
	return clone
end

function FlagSyncService.new(BlinkServer: any)
	local self = setmetatable({}, FlagSyncService)

	-- Store Blink server module for network communication
	self.BlinkServer = BlinkServer

	-- Create server atom (stores all players' flags)
	self.FlagsAtom = SharedAtoms.CreateServerAtom()

	-- Create server syncer with Blink serialization
	self.Syncer = CharmSync.server({
		atoms = {
			playerFlags = self.FlagsAtom,
		},
		interval = 0,
		preserveHistory = false,
		autoSerialize = false,
	})

	-- Override CharmSync's payload generation to always send full state (init-only)
	self.Cleanup = self.Syncer:connect(function(player: Player, _: any)
		local userId = player.UserId
		local allFlags = self.FlagsAtom()
		local playerFlags = allFlags[userId] or {}

		-- Split flags into three typed maps for Blink transport
		local splitFlags = FlagSerializer.SplitFlags(playerFlags)

		local fullStatePayload = {
			type = "init",
			data = {
				boolFlags = splitFlags.BoolFlags,
				numberFlags = splitFlags.NumberFlags,
				stringFlags = splitFlags.StringFlags,
			},
		}

		self.BlinkServer.SyncNPCFlags.Fire(player, fullStatePayload)
	end)

	return self
end

--[[
	SYNC METHODS
]]

function FlagSyncService:HydratePlayer(player: Player)
	self.Syncer:hydrate(player)
end

function FlagSyncService:GetFlagsAtom()
	return self.FlagsAtom
end

--[[
	READ-ONLY GETTERS (deep clone to prevent in-place mutations)
]]

function FlagSyncService:GetPlayerFlagsReadOnly(userId: number): { [string]: any }?
	local allFlags = self.FlagsAtom()
	local playerFlags = allFlags[userId]
	return playerFlags and deepClone(playerFlags) or nil
end

--[[
	CENTRALIZED MUTATION METHODS (targeted cloning)
]]

--- Set a single flag for a player
function FlagSyncService:SetFlag(userId: number, flagName: string, flagValue: any)
	self.FlagsAtom(function(current)
		local updated = table.clone(current)
		if not updated[userId] then
			updated[userId] = {}
		end
		updated[userId] = table.clone(updated[userId])
		updated[userId][flagName] = flagValue
		return updated
	end)
end

--- Remove a single flag for a player
function FlagSyncService:RemoveFlag(userId: number, flagName: string)
	self.FlagsAtom(function(current)
		local updated = table.clone(current)
		if not updated[userId] then
			return updated
		end
		updated[userId] = table.clone(updated[userId])
		updated[userId][flagName] = nil
		return updated
	end)
end

--- Load all flags for a player (used during player data loading)
function FlagSyncService:LoadPlayerFlags(userId: number, flagsData: { [string]: any })
	self.FlagsAtom(function(current)
		local updated = table.clone(current)
		updated[userId] = flagsData
		return updated
	end)
end

--- Remove all flags for a player (e.g., on player leaving)
function FlagSyncService:RemovePlayerFlags(userId: number)
	self.FlagsAtom(function(current)
		local updated = table.clone(current)
		updated[userId] = nil
		return updated
	end)
end

function FlagSyncService:Destroy()
	if self.Cleanup then
		self.Cleanup()
	end
end

return FlagSyncService
