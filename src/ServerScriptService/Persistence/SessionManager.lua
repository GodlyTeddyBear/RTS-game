--!strict

--[=[
	@class SessionManager
	Owns the ProfileStore session lifecycle — coordinates `ProfileManager` and `PlayerLifecycleManager`
	to handle player join and leave flows end-to-end.

	Event flow:
	- `PlayerAdded` → `StartSession` → `Register` → `InitPlayer` → Emit `ProfileLoaded` → `CheckReady`
	- `PlayerRemoving` → Emit `ProfileSaving` → `Unregister` → `CleanupPlayer` → `EndSession`
	@server
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScript = game:GetService("ServerScriptService")

local Promise = require(ReplicatedStorage.Packages.Promise)
local DebugConfig = require(ReplicatedStorage.Config.DebugConfig)
local GameEvents = require(ReplicatedStorage.Events.GameEvents)
local ProfileManager = require(ServerScript.Persistence.ProfileManager)
local PlayerLifecycleManager = require(ServerScript.Persistence.PlayerLifecycleManager)

type PStore = {
	StartSessionAsync: (
		self: PStore,
		key: string,
		options: { Cancel: () -> boolean }
	) -> ProfileManager.Profile?,
}

local Events = GameEvents.Events

-------------------------------------------------------------------------------

local function _startSession(profileStore: PStore, player: Player)
	return Promise.new(function(resolve, reject)
		local profile = profileStore:StartSessionAsync("Player_" .. player.UserId, {
			Cancel = function()
				return player.Parent ~= Players
			end,
		})

		if profile == nil then
			reject("ProfileStore returned nil")
		else
			print("Profile", profile)
			resolve(profile)
		end
	end)
end

local function _prepareProfile(profile: ProfileManager.Profile, player: Player)
	profile:AddUserId(player.UserId)
	profile:Reconcile()
end

-- OnSessionEnd fires on unexpected session loss (session lock, data errors).
-- Normal leave is handled by PlayerRemoving, which calls Unregister before
-- EndSession, so Has() is false here on a normal leave — prevents redundant kick.
local function _watchSessionEnd(profile: ProfileManager.Profile, player: Player)
	profile.OnSessionEnd:Connect(function()
		if ProfileManager:Has(player) then
			ProfileManager:Unregister(player)
			PlayerLifecycleManager:CleanupPlayer(player)
			player:Kick("Data error occurred, please rejoin.")
		end
	end)
end

local function _activateSession(profile: ProfileManager.Profile, player: Player)
	ProfileManager:Register(player, profile)
	if DebugConfig.RESET_DATA_ON_JOIN then
		ProfileManager:ResetData(player)
	end
	PlayerLifecycleManager:InitPlayer(player)
	GameEvents.Bus:Emit(Events.Persistence.ProfileLoaded, player)
	-- Handles the edge case where no loaders are registered
	PlayerLifecycleManager:CheckReady(player)
end

local function _onPlayerAdded(profileStore: PStore, player: Player)
	_startSession(profileStore, player)
		:andThen(function(profile: ProfileManager.Profile)
			_prepareProfile(profile, player)
			_watchSessionEnd(profile, player)

			if player.Parent == Players then
				_activateSession(profile, player)
			else
				profile:EndSession()
			end
		end)
		:catch(function(err)
			warn("[SessionManager] Session failed for", player.Name, "-", tostring(err))
			player:Kick("Data error occurred, please rejoin.")
		end)
end

local function _onPlayerRemoving(player: Player)
	local profile = ProfileManager:GetProfile(player)
	if not profile then
		PlayerLifecycleManager:CleanupPlayer(player)
		return
	end

	-- Emit ProfileSaving so contexts can flush their state to profile.Data.
	-- All saves are synchronous mutations on profile.Data — ProfileStore
	-- auto-persists the final state when EndSession is called below.
	GameEvents.Bus:Emit(Events.Persistence.ProfileSaving, player)

	-- Unregister before EndSession so OnSessionEnd guard doesn't kick a leaving player
	ProfileManager:Unregister(player)
	PlayerLifecycleManager:CleanupPlayer(player)

	profile:EndSession()
end

-------------------------------------------------------------------------------

--[=[
	Wire `PlayerAdded`/`PlayerRemoving` listeners and handle players who joined before the function ran.
	Call exactly once from `ProfileInit` with the initialized `ProfileStore`.
	@within SessionManager
	@param profileStore PStore -- The initialized ProfileStore instance
	@function SessionManager
]=]
local function SessionManager(profileStore: PStore)
	for _, player in Players:GetPlayers() do
		_onPlayerAdded(profileStore, player)
	end

	Players.PlayerAdded:Connect(function(player: Player)
		_onPlayerAdded(profileStore, player)
	end)

	Players.PlayerRemoving:Connect(_onPlayerRemoving)
end

return SessionManager
