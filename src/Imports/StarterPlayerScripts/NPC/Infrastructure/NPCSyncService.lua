--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CharmSync = require(ReplicatedStorage.Packages["Charm-sync"])
local SharedAtoms = require(ReplicatedStorage.Contexts.NPC.Sync.SharedAtoms)
local FlagSerializer = require(ReplicatedStorage.Contexts.NPC.Sync.FlagSerializer)

--[[
	Client-Side NPC Sync Service

	Manages CharmSync + Blink integration for player flags on the client.
	Server sends three typed maps (boolFlags, numberFlags, stringFlags).
	Client merges them into a unified TPlayerFlags atom.

	Architecture Pattern: CharmSync + Blink Integration
	- Blink client receives init payloads with split flag maps
	- FlagSerializer merges them into unified flags
	- CharmSync.client() applies merged payload to atom
	- Client atom stores TClientFlags (this player's flags)
]]

local NPCSyncService = {}
NPCSyncService.__index = NPCSyncService

--- Creates client-side sync service with Blink integration
function NPCSyncService.new(BlinkClient: any)
	local self = setmetatable({}, NPCSyncService)

	-- Store Blink client module for network communication
	self.BlinkClient = BlinkClient

	-- Create client atom (stores only this player's flags)
	self.FlagsAtom = SharedAtoms.CreateClientAtom()

	-- Create client syncer
	self.Syncer = CharmSync.client({
		atoms = {
			playerFlags = self.FlagsAtom,
		},
		ignoreUnhydrated = true,
	})

	return self
end

--- Starts listening for sync events from server via Blink
--- Merges the three typed maps into a unified flags table before syncing
function NPCSyncService:Start()
	self.BlinkClient.SyncNPCFlags.On(function(payload)
		-- Merge split flag maps into unified TPlayerFlags
		if payload.data then
			local mergedFlags = FlagSerializer.MergeFlags(
				payload.data.boolFlags,
				payload.data.numberFlags,
				payload.data.stringFlags
			)
			-- Replace split data with merged data for CharmSync
			payload.data = {
				playerFlags = mergedFlags,
			}
		end

		self.Syncer:sync(payload) -- CharmSync applies init payload
	end)
end

--- Returns the client-side flags atom for React components and condition checks
function NPCSyncService:GetFlagsAtom()
	return self.FlagsAtom
end

return NPCSyncService
