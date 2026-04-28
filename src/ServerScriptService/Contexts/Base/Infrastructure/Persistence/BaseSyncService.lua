--!strict

--[=[
    @class BaseSyncService
    Mirrors the Base entity state to connected players and local readers.
    @server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local CharmSync = require(ReplicatedStorage.Packages["Charm-sync"])
local SharedAtoms = require(ReplicatedStorage.Contexts.Base.Sync.SharedAtoms)
local BaseTypes = require(ReplicatedStorage.Contexts.Base.Types.BaseTypes)

type BaseState = BaseTypes.BaseState

local BaseSyncService = {}
BaseSyncService.__index = BaseSyncService

--[=[
    Create a new base sync service.
    @within BaseSyncService
    @return BaseSyncService -- Sync service instance.
]=]
function BaseSyncService.new()
	local self = setmetatable({}, BaseSyncService)
	self._atom = SharedAtoms.CreateServerAtom()
	return self
end

--[=[
    Bind the Blink server and base entity factory dependencies.
    @within BaseSyncService
    @param registry any -- Registry that provides dependencies.
    @param _name string -- Module name supplied by the BaseContext framework.
]=]
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

--[=[
    Write the current base state into the sync atom.
    @within BaseSyncService
]=]
function BaseSyncService:SyncBaseState()
	self._atom(self._entityFactory:GetBaseState() :: BaseState?)
end

--[=[
    Clear the sync atom when the base is removed.
    @within BaseSyncService
]=]
function BaseSyncService:ClearState()
	self._atom(nil)
end

--[=[
    Hydrate a single player with the current base state.
    @within BaseSyncService
    @param player Player -- Player to hydrate.
]=]
function BaseSyncService:HydratePlayer(player: Player)
	self._syncer:hydrate(player)
end

--[=[
    Hydrate every connected player with the current base state.
    @within BaseSyncService
]=]
function BaseSyncService:HydrateAllPlayers()
	for _, player in Players:GetPlayers() do
		self:HydratePlayer(player)
	end
end

--[=[
    Read the current base state without exposing the sync atom itself.
    @within BaseSyncService
    @return BaseState? -- Read-only copy of the current base state.
]=]
function BaseSyncService:GetStateReadOnly(): BaseState?
	local state = self._atom()
	if state == nil then
		return nil
	end

	return {
		Hp = state.Hp,
		MaxHp = state.MaxHp,
	}
end

--[=[
    Disconnect the sync bridge and release the server atom connection.
    @within BaseSyncService
]=]
function BaseSyncService:Destroy()
	if self._cleanup then
		self._cleanup()
	end
end

return BaseSyncService
