--!strict

--[[
	Module: RecordRunCompletedCommand
	Purpose: Records a completed run and synchronizes the updated run stats snapshot.
	Used In System: Invoked by EconomyContext when a run transitions into the RunEnd state.
	Boundaries: Owns command orchestration only; does not own persistence schema or sync atom mutation.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseCommand = require(ReplicatedStorage.Utilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)
local EconomyTypes = require(ReplicatedStorage.Contexts.Economy.Types.EconomyTypes)

local Ok = Result.Ok
local Try = Result.Try

type ProfileRunStats = EconomyTypes.ProfileRunStats

-- [Initialization]

--[=[
	@class RecordRunCompletedCommand
	Records completed-run progress and persists updated run stats.
	@server
]=]
local RecordRunCompletedCommand = {}
RecordRunCompletedCommand.__index = RecordRunCompletedCommand
setmetatable(RecordRunCompletedCommand, BaseCommand)

--[=[
	Creates a new run-complete command.
	@within RecordRunCompletedCommand
	@return RecordRunCompletedCommand -- The new command instance.
]=]
function RecordRunCompletedCommand.new()
	local self = BaseCommand.new("Economy", "RecordRunCompletedCommand")
	return setmetatable(self, RecordRunCompletedCommand)
end

--[=[
	Initializes command dependencies.
	@within RecordRunCompletedCommand
	@param registry any -- The registry that owns this command.
	@param _name string -- The registered module name.
]=]
function RecordRunCompletedCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_persistenceService = "EconomyPersistenceService",
		_syncService = "ResourceSyncService",
	})
end

-- [Public API]

--[=[
	Updates and persists run stats for a completed run.
	@within RecordRunCompletedCommand
	@param player Player -- The player whose run stats should be updated.
	@return Result.Result<ProfileRunStats> -- Updated run stats.
]=]
function RecordRunCompletedCommand:Execute(player: Player): Result.Result<ProfileRunStats>
	-- Persist the completed run and reuse the authoritative run-stat snapshot.
	local updatedRunStats = Try(self._persistenceService:AddCompletedRun(player))

	-- Mirror the persisted snapshot into the replicated wallet atom.
	self._syncService:SyncRunStats(player.UserId, updatedRunStats)

	-- Return the updated snapshot so callers can keep the same state without rereading storage.
	return Ok(updatedRunStats)
end

return RecordRunCompletedCommand
