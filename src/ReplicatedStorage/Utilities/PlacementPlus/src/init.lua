--!strict

--[=[
    @class PlacementPlusPackage
    Shared surface-based placement helpers for preview-first, validate-second workflows.

    Flow: resolve input -> build candidate -> run validation -> return frozen result.
    @server
    @client
]=]

local Candidate = require(script.Candidate)
local Footprint = require(script.Footprint)
local Profiles = require(script.Profiles)
local Rules = require(script.Rules)
local Types = require(script.Types)
local Validation = require(script.Validation)

-- ── Types ─────────────────────────────────────────────────────────────────────

--[=[
    @type TPlacementCandidate
    @within PlacementPlusPackage
    Frozen placement candidate payload returned by the package surface.
]=]
export type TPlacementCandidate = Types.TPlacementCandidate

--[=[
    @type TPlacementValidationResult
    @within PlacementPlusPackage
    Frozen validation result returned for each placement candidate.
]=]
export type TPlacementValidationResult = Types.TPlacementValidationResult
export type TPlacementValidationReasonDetail = Types.TPlacementValidationReasonDetail

--[=[
    @type TPlacementResult
    @within PlacementPlusPackage
    Combined candidate and validation payload returned by `ResolvePlacementCandidate`.
]=]
export type TPlacementResult = Types.TPlacementResult
export type TPlacementFootprint = Types.TPlacementFootprint
export type TPlacementSupportPointMode = Types.TPlacementSupportPointMode

--[=[
    @type TPlacementOptions
    @within PlacementPlusPackage
    Candidate transform options used while building placement candidates.
]=]
export type TPlacementOptions = Types.TPlacementOptions

--[=[
    @type TPlacementValidationOptions
    @within PlacementPlusPackage
    Validation rule options used while evaluating placement candidates.
]=]
export type TPlacementValidationOptions = Types.TPlacementValidationOptions
export type TPlacementProfile = Types.TPlacementProfile
export type TPlacementProfileSpec = Types.TPlacementProfileSpec

--[=[
    @type TPlacementInput
    @within PlacementPlusPackage
    Union-style placement input resolved by `ResolvePlacementCandidate`.
]=]
export type TPlacementInput = Types.TPlacementInput

-- ── Public ────────────────────────────────────────────────────────────────────

--[=[
    @prop Reasons table
    @within PlacementPlusPackage
    Frozen reason codes used by the built-in validation rules.
]=]

local PlacementPlus = {
	Reasons = Rules.Reasons,
}

-- Candidate construction
PlacementPlus.BuildCandidateFromCursor = Candidate.BuildCandidateFromCursor
PlacementPlus.BuildCandidateFromHit = Candidate.BuildCandidateFromHit
PlacementPlus.BuildCandidateFromWorldPosition = Candidate.BuildCandidateFromWorldPosition
PlacementPlus.BuildPreviewCFrame = Candidate.BuildPreviewCFrame
PlacementPlus.SnapPosition = Candidate.SnapPosition
PlacementPlus.AlignToGround = Candidate.AlignToGround
PlacementPlus.ApplyFacing = Candidate.ApplyFacing

-- Profiles / footprints
PlacementPlus.CreateProfile = Profiles.CreateProfile
PlacementPlus.MergeProfile = Profiles.MergeProfile
PlacementPlus.BuildFootprintFromBounds = Footprint.BuildFootprintFromBounds
PlacementPlus.BuildSupportPointsFromFootprint = Footprint.BuildSupportPointsFromFootprint
PlacementPlus.BuildClearanceSizeFromFootprint = Footprint.BuildClearanceSizeFromFootprint

-- Validation
PlacementPlus.ValidateCandidate = Validation.ValidateCandidate
PlacementPlus.IsWithinBounds = Rules.IsWithinBounds
PlacementPlus.IsSurfaceAllowed = Rules.IsSurfaceAllowed
PlacementPlus.IsClearOfObstacles = Rules.IsClearOfObstacles
PlacementPlus.IsWithinSlopeLimit = Rules.IsWithinSlopeLimit
PlacementPlus.HasRequiredSupport = Rules.HasRequiredSupport

--[=[
    Builds a placement candidate from the first available input shape and validates it.
    @within PlacementPlusPackage
    @param input TPlacementInput -- Hit, cursor ray, or world-position input.
    @param options TPlacementOptions? -- Candidate transform options.
    @param validationOptions TPlacementValidationOptions? -- Validation rule options.
    @return TPlacementResult -- Candidate plus validation result.
]=]
function PlacementPlus.ResolvePlacementCandidate(
	input: TPlacementInput,
	options: TPlacementOptions?,
	validationOptions: TPlacementValidationOptions?
): TPlacementResult
	-- Resolve the first usable input shape in priority order.
	local candidate: TPlacementCandidate? = nil

	if input.Hit ~= nil then
		candidate = Candidate.BuildCandidateFromHit(input.Hit, options)
	elseif input.Camera ~= nil and input.ScreenPosition ~= nil then
		candidate = Candidate.BuildCandidateFromCursor(
			input.Camera,
			input.ScreenPosition,
			input.RayLength,
			input.QueryOptions,
			options
		)
	elseif input.Position ~= nil then
		candidate = Candidate.BuildCandidateFromWorldPosition(input.Position, options)
	end

	-- Return an invalid result when no input produced a candidate.
	if candidate == nil then
		return table.freeze({
			Candidate = nil,
			Validation = Validation.BuildInvalidResult("NoCandidate"),
		})
	end

	-- Package the candidate with its validation result for downstream callers.
	return table.freeze({
		Candidate = candidate,
		Validation = Validation.ValidateCandidate(candidate, validationOptions),
	})
end

--[=[
    Builds and validates a placement candidate using a reusable profile plus per-call overrides.
    @within PlacementPlusPackage
    @param input TPlacementInput -- Hit, cursor ray, or world-position input.
    @param profile TPlacementProfile -- Reusable placement profile.
    @param placementOptions TPlacementOptions? -- Per-call candidate option overrides.
    @param validationOptions TPlacementValidationOptions? -- Per-call validation option overrides.
    @return TPlacementResult -- Candidate plus validation result.
]=]
function PlacementPlus.ResolveProfiledPlacement(
	input: TPlacementInput,
	profile: TPlacementProfile,
	placementOptions: TPlacementOptions?,
	validationOptions: TPlacementValidationOptions?
): TPlacementResult
	local mergedPlacementOptions, mergedValidationOptions =
		Profiles.MergeProfile(profile, placementOptions, validationOptions)

	return PlacementPlus.ResolvePlacementCandidate(input, mergedPlacementOptions, mergedValidationOptions)
end

return table.freeze(PlacementPlus)
