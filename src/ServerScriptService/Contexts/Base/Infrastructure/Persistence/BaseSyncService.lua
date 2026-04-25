--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local CharmSync = require(ReplicatedStorage.Packages["Charm-sync"])
local SharedAtoms = require(ReplicatedStorage.Contexts.Base.Sync.SharedAtoms)
local BaseTypes = require(ReplicatedStorage.Contexts.Base.Types.BaseTypes)

type BaseState = BaseTypes.BaseState

local BaseSyncService = {}
BaseSyncService.__index = BaseSyncService

function BaseSyncService.new()
	local self = setmetatable({}, BaseSyncService)
	self._atom = SharedAtoms.CreateServerAtom()
	return self
end

function BaseSyncService:Init(registry: any, _name: string)
	self._blinkServer = registry:Get("BlinkServer")
	self._entityFactory = registry:Get("BaseEntityFactory")
	self._syncer = CharmSync.server({
		atoms = { base = self._atom },
		interval = 0.33,
		preserveHistory = false,
		autoSerialize = false,
	})

	self._cleanup = self._syncer:connect(function(player: Player, payload: any)
		self._blinkServer.SyncBase.Fire(player, payload)
	end)
end

function BaseSyncService:SyncBaseState()
	self._atom(self._entityFactory:GetBaseState() :: BaseState?)
end

function BaseSyncService:ClearState()
	self._atom(nil)
end

function BaseSyncService:HydratePlayer(player: Player)
	self._syncer:hydrate(player)
end

function BaseSyncService:HydrateAllPlayers()
	for _, player in Players:GetPlayers() do
		self:HydratePlayer(player)
	end
end

function BaseSyncService:GetStateReadOnly(): BaseState?
	local state = self._atom()
	if state == nil then
		return nil
	end

	return {
		hp = state.hp,
		maxHp = state.maxHp,
	}
end

function BaseSyncService:Destroy()
	if self._cleanup then
		self._cleanup()
	end
end

return BaseSyncService
