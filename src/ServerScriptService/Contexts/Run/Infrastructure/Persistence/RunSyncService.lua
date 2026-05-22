--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local CharmSync = require(ReplicatedStorage.Packages["Charm-sync"])
local BaseSyncService = require(ServerStorage.Utilities.ContextUtilities.BaseSyncService)
local SharedAtoms = require(ReplicatedStorage.Contexts.Run.Sync.SharedAtoms)
local RunTypes = require(ReplicatedStorage.Contexts.Run.Types.RunTypes)

type RunSnapshot = RunTypes.RunSnapshot
type SyncPayload = {
	type: "init",
	data: {
		RunState: {
			State: string?,
			WaveNumber: number?,
			PhaseStartedAt: number?,
			PhaseEndsAt: number?,
			PhaseDuration: number?,
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
	self.AtomKey = "RunState"
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
			RunState = {
				State = type(snapshot.State) == "string" and snapshot.State or nil,
				WaveNumber = toFiniteNumber(snapshot.WaveNumber),
				PhaseStartedAt = toFiniteNumber(snapshot.PhaseStartedAt),
				PhaseEndsAt = toFiniteNumber(snapshot.PhaseEndsAt),
				PhaseDuration = toFiniteNumber(snapshot.PhaseDuration),
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
	self:_Profile("SetState", function()
		-- Replace the atom value wholesale so Charm-sync can diff the run snapshot cleanly.
		-- This keeps the payload shape stable across server and client mirrors.
		self.Atom(function()
			return {
				State = snapshot.State,
				WaveNumber = snapshot.WaveNumber,
				PhaseStartedAt = snapshot.PhaseStartedAt,
				PhaseEndsAt = snapshot.PhaseEndsAt,
				PhaseDuration = snapshot.PhaseDuration,
			}
		end)
	end)
end

return RunSyncService
