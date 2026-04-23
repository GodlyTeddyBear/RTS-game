--!strict

--[=[
    @class Profile
    Owns profile lifecycle registration and loaded-profile notifications.
    @server
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameEvents = require(ReplicatedStorage.Events.GameEvents)
local PlayerLifecycleManager = require(ServerScriptService.Persistence.PlayerLifecycleManager)
local ProfileManager = require(ServerScriptService.Persistence.ProfileManager)

local Assertions = require(script.Parent.Parent.Internal.Assertions)
local Config = require(script.Parent.Parent.Internal.Config)
local ServiceAccess = require(script.Parent.Parent.Internal.ServiceAccess)
local Validation = require(script.Parent.Parent.Validation)

local ProfileMethods = {}

-- Returns the configured profile lifecycle table and rejects missing bootstrap state.
--[=[
    Returns the configured profile lifecycle table.
    @within Profile
    @return any -- Profile lifecycle configuration.
    @error string -- Raised when profile lifecycle is not configured.
]=]
function ProfileMethods:RequireProfileLifecycle(): any
	local profileLifecycle = self._service.ProfileLifecycle
	assert(type(profileLifecycle) == "table", "BaseContext ProfileLifecycle must be configured")
	return profileLifecycle
end

-- Resolves the loader name used by the lifecycle manager.
--[=[
    Returns the configured profile loader name.
    @within Profile
    @return string -- Profile loader name.
    @error string -- Raised when the loader name is missing or invalid.
]=]
function ProfileMethods:GetProfileLoaderName(): string
	local profileLifecycle = self:RequireProfileLifecycle()
	Assertions.AssertNonEmptyString(profileLifecycle.LoaderName, "BaseContext ProfileLifecycle.LoaderName")
	return profileLifecycle.LoaderName
end

--[=[
	Registers this context as a profile loader.
	@within Profile
	@return nil -- No return value.
]=]
function ProfileMethods:RegisterProfileLoader()
	PlayerLifecycleManager:RegisterLoader(self:GetProfileLoaderName())
end

--[=[
	Wires profile loaded, profile saving, player removing, and loaded-profile backfill.
	@within Profile
	@return nil -- No return value.
]=]
function ProfileMethods:StartProfileLifecycle()
	Validation.ValidateProfileLifecycleMethods(self)

	local profileLifecycle = self:RequireProfileLifecycle()
	-- Wire the mandatory loaded handler first so the loader completion path is ready.
	self:OnProfileLoaded(profileLifecycle.OnLoaded, Config.DefaultProfileLoadedCache)

	-- Wire optional saving and removing handlers only when the service provides them.
	if profileLifecycle.OnSaving ~= nil then
		self:OnProfileSaving(profileLifecycle.OnSaving, Config.DefaultProfileSavingCache)
	end

	if profileLifecycle.OnRemoving ~= nil then
		self:OnProfileRemoving(profileLifecycle.OnRemoving, Config.DefaultPlayerRemovingCache)
	end

	if profileLifecycle.Backfill ~= false then
		self:BackfillLoadedProfiles(profileLifecycle.OnLoaded)
	end
end

--[=[
	Subscribes to `Persistence.ProfileLoaded`, calls the handler, then notifies lifecycle readiness.
	@within Profile
    @param callbackOrMethodName any -- Callback or service method name to invoke.
    @param cacheAs string? -- Optional service field used to cache the connection.
    @return any -- ProfileLoaded connection.
]=]
function ProfileMethods:OnProfileLoaded(callbackOrMethodName: any, cacheAs: string?)
	Assertions.AssertCallbackOrMethodName(callbackOrMethodName, "BaseContext:OnProfileLoaded callbackOrMethodName")

	return self:OnGameEvent(GameEvents.Events.Persistence.ProfileLoaded, function(player: Player)
		ServiceAccess.CallProfileHandler(self, callbackOrMethodName, player)
		self:NotifyProfileLoaded(player)
	end, cacheAs)
end

--[=[
	Subscribes to `Persistence.ProfileSaving`.
	@within Profile
    @param callbackOrMethodName any -- Callback or service method name to invoke.
    @param cacheAs string? -- Optional service field used to cache the connection.
    @return any -- ProfileSaving connection.
]=]
function ProfileMethods:OnProfileSaving(callbackOrMethodName: any, cacheAs: string?)
	Assertions.AssertCallbackOrMethodName(callbackOrMethodName, "BaseContext:OnProfileSaving callbackOrMethodName")

	return self:OnGameEvent(GameEvents.Events.Persistence.ProfileSaving, function(player: Player)
		ServiceAccess.CallProfileHandler(self, callbackOrMethodName, player)
	end, cacheAs)
end

--[=[
	Subscribes to `Players.PlayerRemoving`.
	@within Profile
    @param callbackOrMethodName any -- Callback or service method name to invoke.
    @param cacheAs string? -- Optional service field used to cache the connection.
    @return any -- PlayerRemoving connection.
]=]
function ProfileMethods:OnProfileRemoving(callbackOrMethodName: any, cacheAs: string?)
	Assertions.AssertCallbackOrMethodName(callbackOrMethodName, "BaseContext:OnProfileRemoving callbackOrMethodName")

	return self:OnPlayerRemoving(function(player: Player)
		ServiceAccess.CallProfileHandler(self, callbackOrMethodName, player)
	end, cacheAs)
end

--[=[
	Runs the loaded handler for players whose profile was already registered.
	@within Profile
    @param callbackOrMethodName any -- Callback or service method name to invoke.
]=]
function ProfileMethods:BackfillLoadedProfiles(callbackOrMethodName: any)
	Assertions.AssertCallbackOrMethodName(callbackOrMethodName, "BaseContext:BackfillLoadedProfiles callbackOrMethodName")

	for _, player in Players:GetPlayers() do
		-- Replay the loaded handler only for players whose profile is already registered.
		if self:IsProfileLoaded(player) then
			ServiceAccess.CallProfileHandler(self, callbackOrMethodName, player)
			self:NotifyProfileLoaded(player)
		end
	end
end

--[=[
	Marks a player's profile lifecycle load complete for this context.
	@within Profile
    @param player Player -- Player whose profile is now fully loaded.
]=]
function ProfileMethods:NotifyProfileLoaded(player: Player)
	PlayerLifecycleManager:NotifyLoaded(player, self:GetProfileLoaderName())
end

--[=[
	Returns whether a player has a registered profile.
	@within Profile
    @param player Player -- Player to check.
    @return boolean -- Whether the profile is registered.
]=]
function ProfileMethods:IsProfileLoaded(player: Player): boolean
	return ProfileManager:Has(player)
end

return ProfileMethods
