--!strict

local Enums = require(script.Enums)
local Manager = require(script.Manager)
local Profiles = require(script.Profiles)
local Types = require(script.Types)

export type TProximityTarget = Types.TProximityTarget
export type TResolvePromptParentCallback = Types.TResolvePromptParentCallback
export type TProximityOptions = Types.TProximityOptions
export type TResolvedProximityOptions = Types.TResolvedProximityOptions
export type TProximityProfile = Types.TProximityProfile
export type TProximityProfileSpec = Types.TProximityProfileSpec
export type TProximityManagerConfig = Types.TProximityManagerConfig
export type TProximityHandleState = Types.TProximityHandleState
export type TProximityEligibilityContext = Types.TProximityEligibilityContext
export type TProximityHandle = Types.TProximityHandle
export type TProximityManager = Types.TProximityManager

local ProximityService = {
	ActionKind = Enums.ActionKind,
	HandleState = Enums.HandleState,
	RegistrationMode = Enums.RegistrationMode,
	ErrorKey = Enums.ErrorKey,
}

function ProximityService.new(config: Types.TProximityManagerConfig?): TProximityManager
	return Manager.new(config)
end

function ProximityService.CreateProfile(profileSpec: Types.TProximityProfileSpec?): TProximityProfile
	return Profiles.CreateProfile(profileSpec)
end

return table.freeze(ProximityService)
