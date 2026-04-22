--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseSyncService = require(ReplicatedStorage.Utilities.BaseSyncService)
local SharedAtoms = require(ReplicatedStorage.Contexts.Commander.Sync.SharedAtoms)
local CommanderTypes = require(ReplicatedStorage.Contexts.Commander.Types.CommanderTypes)

type CommanderState = CommanderTypes.CommanderState

--[=[
	@class CommanderSyncService
	Projects authoritative Commander ECS state to the replicated commander atom.
	@server
]=]
local CommanderSyncService = {}
CommanderSyncService.__index = CommanderSyncService
setmetatable(CommanderSyncService, BaseSyncService)

function CommanderSyncService.new()
	local self = setmetatable({}, CommanderSyncService)
	self.AtomKey = "commander"
	self.BlinkEventName = "SyncCommander"
	self.CreateAtom = SharedAtoms.CreateServerAtom
	return self
end

function CommanderSyncService:Init(registry: any, name: string)
	BaseSyncService.Init(self, registry, name)
	self._entityFactory = registry:Get("CommanderEntityFactory")
end

function CommanderSyncService:SyncCommanderState(userId: number)
	local state = self._entityFactory:GetCommanderState(userId) :: CommanderState?
	if state == nil then
		self:RemoveUserData(userId)
		return
	end

	self:LoadUserData(userId, state)
end

function CommanderSyncService:HydrateAndSyncPlayer(player: Player)
	self:SyncCommanderState(player.UserId)
	BaseSyncService.HydratePlayer(self, player)
end

function CommanderSyncService:RemovePlayer(userId: number)
	self:RemoveUserData(userId)
end

function CommanderSyncService:GetStateReadOnly(userId: number): CommanderState?
	return self._entityFactory:GetCommanderState(userId)
end

return CommanderSyncService

