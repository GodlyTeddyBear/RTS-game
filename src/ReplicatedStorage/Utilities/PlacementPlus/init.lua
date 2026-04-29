--!strict

--[=[
    @class PlacementPlus
    Shared surface-based placement helpers for candidate construction, validation, and result assembly.

    Preserves the stable `ReplicatedStorage.Utilities.PlacementPlus` require path while
    re-exporting the implementation from `script.src`.
    @server
    @client
]=]

local PlacementPlus = require(script.src)

-- ── Types ─────────────────────────────────────────────────────────────────────

--[=[
    @type TPlacementCandidate
    @within PlacementPlus
    Frozen placement candidate payload returned by the package surface.
]=]
export type TPlacementCandidate = PlacementPlus.TPlacementCandidate

--[=[
    @type TPlacementValidationResult
    @within PlacementPlus
    Frozen validation result returned for each placement candidate.
]=]
export type TPlacementValidationResult = PlacementPlus.TPlacementValidationResult

--[=[
    @type TPlacementValidationReasonDetail
    @within PlacementPlus
    Structured detail payload for one validation failure.
]=]
export type TPlacementValidationReasonDetail = PlacementPlus.TPlacementValidationReasonDetail

--[=[
    @type TPlacementResult
    @within PlacementPlus
    Combined candidate and validation payload returned by `ResolvePlacementCandidate`.
]=]
export type TPlacementResult = PlacementPlus.TPlacementResult

--[=[
    @type TPlacementFootprint
    @within PlacementPlus
    Ground footprint data used for clearance and support helpers.
]=]
export type TPlacementFootprint = PlacementPlus.TPlacementFootprint

--[=[
    @type TPlacementSupportPointMode
    @within PlacementPlus
    Footprint support-point generation mode.
]=]
export type TPlacementSupportPointMode = PlacementPlus.TPlacementSupportPointMode

--[=[
    @type TPlacementOptions
    @within PlacementPlus
    Candidate transform options used while building placement candidates.
]=]
export type TPlacementOptions = PlacementPlus.TPlacementOptions

--[=[
    @type TPlacementValidationOptions
    @within PlacementPlus
    Validation rule options used while evaluating placement candidates.
]=]
export type TPlacementValidationOptions = PlacementPlus.TPlacementValidationOptions

--[=[
    @type TPlacementProfile
    @within PlacementPlus
    Frozen reusable placement profile.
]=]
export type TPlacementProfile = PlacementPlus.TPlacementProfile

--[=[
    @type TPlacementProfileSpec
    @within PlacementPlus
    Input shape accepted by `CreateProfile`.
]=]
export type TPlacementProfileSpec = PlacementPlus.TPlacementProfileSpec

--[=[
    @type TPlacementInput
    @within PlacementPlus
    Union-style placement input resolved by `ResolvePlacementCandidate`.
]=]
export type TPlacementInput = PlacementPlus.TPlacementInput

return PlacementPlus
