--!strict

local Types = require(script.Parent.Types)
local Policies = require(script.Parent.Policies)
local Validation = require(script.Parent.Validation)

type TProximityOptions = Types.TProximityOptions
type TProximityProfile = Types.TProximityProfile
type TProximityProfileSpec = Types.TProximityProfileSpec
type TResolvedProximityOptions = Types.TResolvedProximityOptions

local Profiles = {}

function Profiles.CreateProfile(profileSpec: TProximityProfileSpec?): TProximityProfile
	Policies.CheckOptions(profileSpec)

	return table.freeze({
		Defaults = Validation.NormalizeManagerConfig(profileSpec),
	})
end

function Profiles.ResolveProfile(
	managerDefaults: TResolvedProximityOptions,
	profile: TProximityProfile,
	overrides: TProximityOptions?
): TResolvedProximityOptions
	Policies.CheckProfile(profile)

	local profiledDefaults = Validation.ResolveOptions(managerDefaults, profile.Defaults :: any)
	return Validation.ResolveOptions(profiledDefaults, overrides)
end

return table.freeze(Profiles)
