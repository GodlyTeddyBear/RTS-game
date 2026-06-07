--!strict

local Profiles = require(script.Parent.Profiles)
local Types = require(script.Parent.Parent.Types.AnimationTypes)

type TAnimationProfile = Types.TAnimationProfile

local AnimationProfileRegistry = {}

function AnimationProfileRegistry.Get(profileId: string): TAnimationProfile
	local profile = Profiles[profileId]
	assert(profile ~= nil, ("AnimationProfileRegistry: unknown profile '%s'"):format(tostring(profileId)))
	return profile
end

function AnimationProfileRegistry.Exists(profileId: string): boolean
	return Profiles[profileId] ~= nil
end

function AnimationProfileRegistry.GetAll(): { [string]: TAnimationProfile }
	return Profiles
end

return table.freeze(AnimationProfileRegistry)
