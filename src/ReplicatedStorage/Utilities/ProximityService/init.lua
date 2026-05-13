--!strict

local ProximityService = require(script.src)
local Types = require(script.src.Types)

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

return ProximityService
