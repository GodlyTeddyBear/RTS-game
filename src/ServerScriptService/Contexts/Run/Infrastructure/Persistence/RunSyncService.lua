--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseSyncService = require(ReplicatedStorage.Utilities.BaseSyncService)
local SharedAtoms = require(ReplicatedStorage.Contexts.Run.Sync.SharedAtoms)
local RunTypes = require(ReplicatedStorage.Contexts.Run.Types.RunTypes)

type RunSnapshot = RunTypes.RunSnapshot

--[=[
	@class RunSyncService
	Owns the global run-state atom and forwards Charm-sync payloads through Blink.
	@server
]=]
local RunSyncService = setmetatable({}, { __index = BaseSyncService })
RunSyncService.__index = RunSyncService

--[=[
	Creates a new run sync service.
	@within RunSyncService
	@return RunSyncService -- The new sync service.
]=]
function RunSyncService.new()
	local self = setmetatable({}, RunSyncService)
	-- BaseSyncService consumes these instance fields during Init(), so they live on the constructor-owned object.
	self.AtomKey = "runState"
	self.BlinkEventName = "SyncRunState"
	self.CreateAtom = SharedAtoms.CreateServerAtom
	self.UseRawPayload = true
	self.SyncInterval = 0.1
	return self
end

--[=[
	Sets the authoritative run state snapshot in the shared atom.
	@within RunSyncService
	@param snapshot RunSnapshot -- The new run snapshot.
]=]
function RunSyncService:SetState(snapshot: RunSnapshot)
	-- Replace the atom value wholesale so Charm-sync can diff the run snapshot cleanly.
	-- This keeps the payload shape stable across server and client mirrors.
	self.Atom(function()
		return {
			state = snapshot.state,
			waveNumber = snapshot.waveNumber,
		}
	end)
end

return RunSyncService
