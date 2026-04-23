--!strict

--[=[
    @class Signals
    Wires game events, player hooks, and sync-service callbacks into tracked connections.
    @server
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameEvents = require(ReplicatedStorage.Events.GameEvents)

local Assertions = require(script.Parent.Parent.Internal.Assertions)
local Config = require(script.Parent.Parent.Internal.Config)
local ServiceAccess = require(script.Parent.Parent.Internal.ServiceAccess)
local Types = require(script.Parent.Parent.Types)

local SignalsMethods = {}

type TPlayerSyncOptions = Types.TPlayerSyncOptions

-- Connects to a game event and tracks the returned connection for cleanup.
--[=[
    Subscribes to a game event.
    @within Signals
    @param eventName string -- Registered game event name.
    @param callback (...any) -> () -- Event callback.
    @param cacheAs string? -- Optional service field used to cache the connection.
    @return any -- Event connection.
]=]
function SignalsMethods:OnGameEvent(eventName: string, callback: (...any) -> (), cacheAs: string?)
	Assertions.AssertNonEmptyString(eventName, "BaseContext:OnGameEvent eventName")
	Assertions.AssertFunction(callback, "BaseContext:OnGameEvent callback")
	Assertions.AssertOptionalNonEmptyString(cacheAs, "BaseContext:OnGameEvent cacheAs")

	local connection = GameEvents.Bus:On(eventName, callback)
	return self:TrackSignalConnection(connection, cacheAs)
end

-- Resolves a context-scoped event name from the shared game-event registry.
--[=[
    Returns the fully qualified event name for a context event.
    @within Signals
    @param contextName string -- Context name.
    @param eventName string -- Event name within the context.
    @return string -- Fully qualified registered event name.
    @error string -- Raised when the context or event is not registered.
]=]
function SignalsMethods:GetContextEvent(contextName: string, eventName: string): string
	Assertions.AssertNonEmptyString(contextName, "BaseContext:GetContextEvent contextName")
	Assertions.AssertNonEmptyString(eventName, "BaseContext:GetContextEvent eventName")

	local contextEvents = GameEvents.Events[contextName]
	assert(contextEvents ~= nil, ("BaseContext GameEvent context '%s' is not registered"):format(contextName))

	local resolvedEventName = contextEvents[eventName]
	assert(resolvedEventName ~= nil, ("BaseContext GameEvent '%s.%s' is not registered"):format(contextName, eventName))

	return resolvedEventName
end

-- Subscribes to a context-scoped event and tracks the returned connection.
--[=[
    Subscribes to a context event.
    @within Signals
    @param contextName string -- Context name.
    @param eventName string -- Event name within the context.
    @param callback (...any) -> () -- Event callback.
    @param cacheAs string? -- Optional service field used to cache the connection.
    @return any -- Event connection.
]=]
function SignalsMethods:OnContextEvent(contextName: string, eventName: string, callback: (...any) -> (), cacheAs: string?)
	return self:OnGameEvent(self:GetContextEvent(contextName, eventName), callback, cacheAs)
end

-- Emits a shared game event through the event bus.
--[=[
    Emits a game event.
    @within Signals
    @param eventName string -- Registered game event name.
    @param ... any -- Event payload.
]=]
function SignalsMethods:EmitGameEvent(eventName: string, ...: any)
	Assertions.AssertNonEmptyString(eventName, "BaseContext:EmitGameEvent eventName")
	GameEvents.Bus:Emit(eventName, ...)
end

-- Emits a context-scoped event through the shared game-event registry.
--[=[
    Emits a context event.
    @within Signals
    @param contextName string -- Context name.
    @param eventName string -- Event name within the context.
    @param ... any -- Event payload.
]=]
function SignalsMethods:EmitContextEvent(contextName: string, eventName: string, ...: any)
	self:EmitGameEvent(self:GetContextEvent(contextName, eventName), ...)
end

-- Tracks the `Players.PlayerAdded` connection for cleanup.
--[=[
    Subscribes to `Players.PlayerAdded`.
    @within Signals
    @param callback (Player) -> () -- Player-added callback.
    @param cacheAs string? -- Optional service field used to cache the connection.
    @return any -- PlayerAdded connection.
]=]
function SignalsMethods:OnPlayerAdded(callback: (Player) -> (), cacheAs: string?)
	Assertions.AssertFunction(callback, "BaseContext:OnPlayerAdded callback")
	Assertions.AssertOptionalNonEmptyString(cacheAs, "BaseContext:OnPlayerAdded cacheAs")

	local connection = Players.PlayerAdded:Connect(callback)
	return self:TrackSignalConnection(connection, cacheAs)
end

-- Tracks the `Players.PlayerRemoving` connection for cleanup.
--[=[
    Subscribes to `Players.PlayerRemoving`.
    @within Signals
    @param callback (Player) -> () -- Player-removing callback.
    @param cacheAs string? -- Optional service field used to cache the connection.
    @return any -- PlayerRemoving connection.
]=]
function SignalsMethods:OnPlayerRemoving(callback: (Player) -> (), cacheAs: string?)
	Assertions.AssertFunction(callback, "BaseContext:OnPlayerRemoving callback")
	Assertions.AssertOptionalNonEmptyString(cacheAs, "BaseContext:OnPlayerRemoving cacheAs")

	local connection = Players.PlayerRemoving:Connect(callback)
	return self:TrackSignalConnection(connection, cacheAs)
end

-- Iterates the current player list and invokes the callback for each player.
--[=[
    Calls a callback for every currently connected player.
    @within Signals
    @param callback (Player) -> () -- Callback invoked for each player.
]=]
function SignalsMethods:ForEachPlayer(callback: (Player) -> ())
	Assertions.AssertFunction(callback, "BaseContext:ForEachPlayer callback")

	for _, player in Players:GetPlayers() do
		callback(player)
	end
end

-- Replays the callback for existing players before wiring future joins.
--[=[
    Runs a callback for existing players and future player joins.
    @within Signals
    @param callback (Player) -> () -- Player callback to run.
    @param cacheAs string? -- Optional service field used to cache the join connection.
    @return any -- PlayerAdded connection.
]=]
function SignalsMethods:HandleExistingAndAddedPlayers(callback: (Player) -> (), cacheAs: string?)
	-- Subscribe to future joins first so nothing is missed after the replay.
	local connection = self:OnPlayerAdded(callback, cacheAs)

	-- Replay the current state immediately for players already in the server.
	self:ForEachPlayer(callback)
	return connection
end

-- Replays sync hydration for current players and keeps future joins in sync.
--[=[
    Hydrates the provided sync service for current and future players.
    @within Signals
    @param syncServiceField string -- Service field containing the sync service.
    @param options TPlayerSyncOptions? -- Optional method and cache overrides.
    @return any -- PlayerAdded connection.
]=]
function SignalsMethods:HydrateExistingAndAddedPlayers(syncServiceField: string, options: TPlayerSyncOptions?)
	Assertions.AssertNonEmptyString(syncServiceField, "BaseContext:HydrateExistingAndAddedPlayers syncServiceField")

	local methodName = Config.DefaultHydrateMethod
	local cacheAs: string? = nil
	if options ~= nil then
		methodName = options.MethodName or methodName
		cacheAs = options.CacheAs
	end

	Assertions.AssertNonEmptyString(methodName, "BaseContext:HydrateExistingAndAddedPlayers MethodName")
	Assertions.AssertOptionalNonEmptyString(cacheAs, "BaseContext:HydrateExistingAndAddedPlayers CacheAs")

	return self:HandleExistingAndAddedPlayers(function(player: Player)
		self:CallSyncServiceForPlayer(syncServiceField, methodName, player)
	end, cacheAs)
end

-- Removes sync state for players as they leave the server.
--[=[
    Removes the sync state for players when they leave.
    @within Signals
    @param syncServiceField string -- Service field containing the sync service.
    @param options TPlayerSyncOptions? -- Optional method and cache overrides.
    @return any -- PlayerRemoving connection.
]=]
function SignalsMethods:RemoveLeavingPlayersByUserId(syncServiceField: string, options: TPlayerSyncOptions?)
	Assertions.AssertNonEmptyString(syncServiceField, "BaseContext:RemoveLeavingPlayersByUserId syncServiceField")

	local methodName = Config.DefaultRemoveMethod
	local cacheAs: string? = nil
	if options ~= nil then
		methodName = options.MethodName or methodName
		cacheAs = options.CacheAs
	end

	Assertions.AssertNonEmptyString(methodName, "BaseContext:RemoveLeavingPlayersByUserId MethodName")
	Assertions.AssertOptionalNonEmptyString(cacheAs, "BaseContext:RemoveLeavingPlayersByUserId CacheAs")

	return self:OnPlayerRemoving(function(player: Player)
		self:CallSyncServiceWithUserId(syncServiceField, methodName, player.UserId)
	end, cacheAs)
end

-- Tracks a connection in the janitor and optionally caches it on the service.
--[=[
    Tracks a signal connection for later cleanup.
    @within Signals
    @param connection any -- Signal connection to track.
    @param cacheAs string? -- Optional service field used to cache the connection.
    @return any -- The same connection.
]=]
function SignalsMethods:TrackSignalConnection(connection: any, cacheAs: string?)
	self:AddCleanup(connection, "Disconnect")

	if cacheAs then
		self._service[cacheAs] = connection
	end

	return connection
end

-- Calls the requested sync service method for a player instance.
--[=[
    Calls a sync service method with a `Player`.
    @within Signals
    @param syncServiceField string -- Service field containing the sync service.
    @param methodName string -- Method name to call.
    @param player Player -- Player to pass to the sync method.
]=]
function SignalsMethods:CallSyncServiceForPlayer(syncServiceField: string, methodName: string, player: Player)
	local syncService = ServiceAccess.RequireField(self, syncServiceField)
	local method = ServiceAccess.RequireMethod(syncService, methodName, syncServiceField)
	method(syncService, player)
end

-- Calls the requested sync service method with the leaving player's user ID.
--[=[
    Calls a sync service method with a user ID.
    @within Signals
    @param syncServiceField string -- Service field containing the sync service.
    @param methodName string -- Method name to call.
    @param userId number -- User ID to pass to the sync method.
]=]
function SignalsMethods:CallSyncServiceWithUserId(syncServiceField: string, methodName: string, userId: number)
	local syncService = ServiceAccess.RequireField(self, syncServiceField)
	local method = ServiceAccess.RequireMethod(syncService, methodName, syncServiceField)
	method(syncService, userId)
end

return SignalsMethods
