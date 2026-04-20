--!strict

--[=[
	@class PlayerLifecycleManager
	Counter-based readiness gate that tracks when all registered loaders have finished loading for a player.

	Contexts call `RegisterLoader` during KnitInit. After `ProfileLoaded` fires, each context loads its
	data and calls `NotifyLoaded`. When all loaders have notified, `Persistence.PlayerReady` is emitted.
	`CheckReady` must be called after `ProfileLoaded` to handle the zero-loaders edge case.
	@server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameEvents = require(ReplicatedStorage.Events.GameEvents)

local PlayerLifecycleManager = {}

PlayerLifecycleManager._RegisteredLoaders = {} :: { [string]: boolean }
PlayerLifecycleManager._RegisteredCount = 0 :: number

PlayerLifecycleManager._LoadedMap = {} :: { [Player]: { [string]: boolean } }
PlayerLifecycleManager._LoadedCounts = {} :: { [Player]: number }

PlayerLifecycleManager._ReadyPlayers = {} :: { [Player]: boolean }

--[=[
	Register a context as a loader. Call during KnitInit before any player joins.
	@within PlayerLifecycleManager
	@param name string -- Unique loader name, typically the context name
]=]
function PlayerLifecycleManager:RegisterLoader(name: string)
	if self._RegisteredLoaders[name] then
		warn("[PlayerLifecycleManager] Loader already registered:", name)
		return
	end
	self._RegisteredLoaders[name] = true
	self._RegisteredCount += 1
end

--[=[
	Initialize per-player tracking state. Must be called by `SessionManager` before emitting `ProfileLoaded`.
	@within PlayerLifecycleManager
	@param player Player -- The player to initialize tracking for
]=]
function PlayerLifecycleManager:InitPlayer(player: Player)
	self._LoadedMap[player] = {}
	self._LoadedCounts[player] = 0
end

--[=[
	Check if all loaders have notified for a player and emit `PlayerReady` if so.
	Called internally after each `NotifyLoaded`, and by `SessionManager` after `ProfileLoaded`
	to handle the zero-loaders edge case.
	@within PlayerLifecycleManager
	@param player Player -- The player to check readiness for
]=]
function PlayerLifecycleManager:CheckReady(player: Player)
	if self._ReadyPlayers[player] then
		return
	end
	assert(self._LoadedCounts[player] ~= nil, "[PlayerLifecycleManager] CheckReady called before InitPlayer for: " .. player.Name)
	if self._LoadedCounts[player] >= self._RegisteredCount then
		self._ReadyPlayers[player] = true
		GameEvents.Bus:Emit(GameEvents.Events.Persistence.PlayerReady, player)
	end
end

--[=[
	Notify that a context has finished loading its data for a player. Call after hydrating atoms.
	@within PlayerLifecycleManager
	@param player Player -- The player whose loader finished
	@param name string -- The loader name, must match the name passed to `RegisterLoader`
]=]
function PlayerLifecycleManager:NotifyLoaded(player: Player, name: string)
	if not self._RegisteredLoaders[name] then
		warn("[PlayerLifecycleManager] Unknown loader:", name)
		return
	end

	local loadedMap = self._LoadedMap[player]
	if not loadedMap then
		warn("[PlayerLifecycleManager] NotifyLoaded called before InitPlayer for player:", player.Name)
		return
	end

	-- Prevent double-notify
	if loadedMap[name] then
		return
	end

	loadedMap[name] = true
	self._LoadedCounts[player] += 1

	self:CheckReady(player)
end

--[=[
	Check if a player has finished loading all registered contexts.
	@within PlayerLifecycleManager
	@param player Player -- The player to check
	@return boolean -- True if all loaders have notified for this player
]=]
function PlayerLifecycleManager:IsPlayerReady(player: Player): boolean
	return self._ReadyPlayers[player] == true
end

--[=[
	Clean up all tracking state for a player. Called when a player leaves.
	@within PlayerLifecycleManager
	@param player Player -- The player to clean up
]=]
function PlayerLifecycleManager:CleanupPlayer(player: Player)
	self._LoadedMap[player] = nil
	self._LoadedCounts[player] = nil
	self._ReadyPlayers[player] = nil
end

return PlayerLifecycleManager
