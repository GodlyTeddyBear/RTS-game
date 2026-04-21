--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharmSync = require(ReplicatedStorage.Packages["Charm-sync"])
local BaseSyncService = require(ReplicatedStorage.Utilities.BaseSyncService)
local SharedAtoms = require(ReplicatedStorage.Contexts.Run.Sync.SharedAtoms)
local RunTypes = require(ReplicatedStorage.Contexts.Run.Types.RunTypes)

type RunSnapshot = RunTypes.RunSnapshot
type SyncPayload = {
	type: "init",
	data: {
		runState: {
			state: string?,
			waveNumber: number?,
			phaseStartedAt: number?,
			phaseEndsAt: number?,
			phaseDuration: number?,
		}?,
	}?,
}

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

local function toFiniteNumber(value: any): number?
	if type(value) ~= "number" then
		return nil
	end

	if value ~= value then
		return nil
	end

	if value == math.huge or value == -math.huge then
		return nil
	end

	return value
end

function RunSyncService:_BuildInitPayload(): SyncPayload
	local snapshot = self.Atom()
	return {
		type = "init",
		data = {
			runState = {
				state = type(snapshot.state) == "string" and snapshot.state or nil,
				waveNumber = toFiniteNumber(snapshot.waveNumber),
				phaseStartedAt = toFiniteNumber(snapshot.phaseStartedAt),
				phaseEndsAt = toFiniteNumber(snapshot.phaseEndsAt),
				phaseDuration = toFiniteNumber(snapshot.phaseDuration),
			},
		},
	}
end

function RunSyncService:Init(registry: any, _name: string)
	self.BlinkServer = registry:Get("BlinkServer")
	self.Atom = self.CreateAtom()

	self.Syncer = CharmSync.server({
		atoms = { [self.AtomKey] = self.Atom },
		interval = self.SyncInterval or 0.33,
		preserveHistory = false,
		autoSerialize = false,
	})

	self.Cleanup = self.Syncer:connect(function(player: Player, _payload: any)
		self.BlinkServer[self.BlinkEventName].Fire(player, self:_BuildInitPayload())
	end)
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
			phaseStartedAt = snapshot.phaseStartedAt,
			phaseEndsAt = snapshot.phaseEndsAt,
			phaseDuration = snapshot.phaseDuration,
		}
	end)
end

return RunSyncService
