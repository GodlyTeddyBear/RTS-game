--!strict

--[=[
	@class ProfileManager
	Repository for active player profiles — exposes controlled access to the private profile store.
	@server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Promise = require(ReplicatedStorage.Packages.Promise)
local Template = require(script.Parent.Template)

--[=[
	@type ProfileData typeof(Template)
	@within ProfileManager
	The full data payload stored inside a player's profile.
]=]
export type ProfileData = typeof(Template)

--[=[
	@interface Profile
	@within ProfileManager
	.Data ProfileData -- The player's persisted data
	.AddUserId (self: Profile, userId: number) -> () -- Associates a UserId with the profile for GDPR compliance
	.Reconcile (self: Profile) -> () -- Fills in any missing keys from the template defaults
	.EndSession (self: Profile) -> () -- Saves and closes the active ProfileStore session
	.OnSessionEnd RBXScriptSignal -- Fires when the session ends unexpectedly (session lock, data errors)
]=]
export type Profile = {
	Data: ProfileData,
	AddUserId: (self: Profile, userId: number) -> (),
	Reconcile: (self: Profile) -> (),
	EndSession: (self: Profile) -> (),
	OnSessionEnd: RBXScriptSignal,
}

local ProfileManager = {}

local _Profiles: { [Player]: Profile } = {}

--[=[
	Register a profile for a player on session start.
	@within ProfileManager
	@param player Player -- The player whose profile is being registered
	@param profile Profile -- The ProfileStore profile object to register
]=]
function ProfileManager:Register(player: Player, profile: Profile)
	_Profiles[player] = profile
end

--[=[
	Unregister a player's profile on session end.
	@within ProfileManager
	@param player Player -- The player whose profile should be removed
]=]
function ProfileManager:Unregister(player: Player)
	_Profiles[player] = nil
end

--[=[
	Return the full profile object for a player, or `nil` if not yet loaded.
	@within ProfileManager
	@param player Player -- The player to look up
	@return Profile? -- The active profile, or nil
]=]
function ProfileManager:GetProfile(player: Player): Profile?
	return _Profiles[player]
end

--[=[
	Check if a player has an active registered profile.
	@within ProfileManager
	@param player Player -- The player to check
	@return boolean -- True if the player has a registered profile
]=]
function ProfileManager:Has(player: Player): boolean
	return self:GetProfile(player) ~= nil
end

--[=[
	Return the profile data for a player, or `nil` if not yet loaded.
	@within ProfileManager
	@param player Player -- The player to look up
	@return ProfileData? -- The player's data table, or nil
]=]
function ProfileManager:GetData(player: Player): ProfileData?
	local profile = self:GetProfile(player)
	if not profile then
		return nil
	end
	return profile.Data
end

--[=[
	Wait for a player's profile data to be available, retrying every 0.05s.
	Rejects with a timeout error if data is not available within 10 seconds.
	Use this in PersistenceServices when hydrating atoms from `ProfileLoaded`,
	since the profile may not be registered yet when the event fires.
	@within ProfileManager
	@param player Player -- The player whose data to wait for
	@return Promise -- Resolves with `ProfileData`, or rejects on timeout
	@yields
]=]
function ProfileManager:WaitForData(player: Player): typeof(Promise.new(function() end))
	return Promise.retryWithDelay(function()
		return Promise.try(function()
			local profileData = self:GetData(player)
			if not profileData then
				error("Profile not yet available for " .. player.Name)
			end
			return profileData
		end)
	end, 1000, 0.05):timeout(10)
end

--- Deep copy utility for cloning template defaults
local function _DeepCopy(original: any): any
	if type(original) ~= "table" then
		return original
	end
	local copy = {}
	for k, v in original do
		copy[k] = _DeepCopy(v)
	end
	return copy
end

--[=[
	Reset a player's profile data to template defaults (dev/testing only).
	@within ProfileManager
	@param player Player -- The player whose data to reset
	@return boolean -- True if the reset succeeded, false if the player has no active profile
]=]
function ProfileManager:ResetData(player: Player): boolean
	local profile = self:GetProfile(player)
	if not profile then
		return false
	end
	profile.Data = _DeepCopy(Template)
	return true
end

return ProfileManager
