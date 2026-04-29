--!strict

--[=[
    @class PlacementPlusValidation
    Aggregates technical placement validation rules into structured UI-ready results.

    The module owns result assembly only; the rule logic lives in `PlacementPlusRules`.
    @server
    @client
]=]

local Rules = require(script.Parent.Rules)
local Types = require(script.Parent.Types)

-- ── Types ─────────────────────────────────────────────────────────────────────

type TPlacementCandidate = Types.TPlacementCandidate
type TPlacementValidationReasonDetail = Types.TPlacementValidationReasonDetail
type TPlacementValidationOptions = Types.TPlacementValidationOptions
type TPlacementValidationResult = Types.TPlacementValidationResult

local Validation = {}

-- ── Private ───────────────────────────────────────────────────────────────────

local function _FreezeData(data: { [string]: any }?): { [string]: any }?
	if data == nil then
		return nil
	end

	return table.freeze(table.clone(data))
end

local function _BuildDetail(code: string, data: { [string]: any }?): TPlacementValidationReasonDetail
	return table.freeze({
		Code = code,
		MessageKey = nil,
		Data = _FreezeData(data),
	})
end

local function _NormalizeDetail(
	reason: (string | TPlacementValidationReasonDetail)?
): TPlacementValidationReasonDetail?
	if reason == nil then
		return nil
	end

	if type(reason) == "string" then
		if reason == "" then
			return nil
		end

		return _BuildDetail(reason, nil)
	end

	if reason.Code == "" then
		return nil
	end

	return table.freeze({
		Code = reason.Code,
		MessageKey = reason.MessageKey,
		Data = _FreezeData(reason.Data),
	})
end

-- Appends only non-empty reasons so callers can compose validation results safely.
local function _AddReasonDetail(
	reasons: { string },
	reasonDetails: { TPlacementValidationReasonDetail },
	detail: TPlacementValidationReasonDetail?
)
	if detail == nil then
		return
	end

	table.insert(reasons, detail.Code)
	table.insert(reasonDetails, detail)
end

-- Freezes the collected reasons into a stable validation result for downstream UI and logic.
local function _BuildResult(
	reasons: { string },
	reasonDetails: { TPlacementValidationReasonDetail }
): TPlacementValidationResult
	return table.freeze({
		IsValid = #reasons == 0,
		Reasons = table.freeze(reasons),
		PrimaryReason = reasons[1],
		ReasonDetails = table.freeze(reasonDetails),
	})
end

local function _BuildOutOfBoundsDetail(
	candidate: TPlacementCandidate,
	options: TPlacementValidationOptions
): TPlacementValidationReasonDetail
	return _BuildDetail(Rules.Reasons.OutOfBounds, {
		Position = candidate.Position,
		BoundsMin = options.BoundsMin,
		BoundsMax = options.BoundsMax,
	})
end

local function _BuildInvalidSurfaceDetail(candidate: TPlacementCandidate): TPlacementValidationReasonDetail
	return _BuildDetail(Rules.Reasons.InvalidSurface, {
		SurfaceInstance = candidate.SurfaceInstance,
		SurfaceMaterial = candidate.SurfaceMaterial,
	})
end

local function _BuildSlopeDetail(
	candidate: TPlacementCandidate,
	options: TPlacementValidationOptions
): TPlacementValidationReasonDetail
	local slopeDegrees: number? = nil
	if candidate.SurfaceNormal ~= nil and candidate.SurfaceNormal.Magnitude > 0 then
		local normal = candidate.SurfaceNormal.Unit
		slopeDegrees = math.deg(math.acos(math.clamp(normal:Dot(Vector3.yAxis), -1, 1)))
	end

	return _BuildDetail(Rules.Reasons.SlopeTooSteep, {
		MaxSlopeDegrees = options.MaxSlopeDegrees,
		SlopeDegrees = slopeDegrees,
		SurfaceNormal = candidate.SurfaceNormal,
	})
end

local function _BuildObstructedDetail(candidate: TPlacementCandidate): TPlacementValidationReasonDetail
	return _BuildDetail(Rules.Reasons.Obstructed, {
		BoundsCFrame = candidate.BoundsCFrame,
		BoundsSize = candidate.BoundsSize,
	})
end

local function _BuildMissingSupportDetail(options: TPlacementValidationOptions): TPlacementValidationReasonDetail
	return _BuildDetail(Rules.Reasons.MissingSupport, {
		SupportRayLength = options.SupportRayLength or options.SupportDistance,
		SupportPointCount = if options.SupportPoints ~= nil then #options.SupportPoints else 1,
	})
end

-- ── Public ────────────────────────────────────────────────────────────────────

--[=[
    Builds an invalid validation result from a single reason.
    @within PlacementPlusValidation
    @param reason string -- Primary invalid reason.
    @return TPlacementValidationResult -- Frozen validation result.
]=]
function Validation.BuildInvalidResult(reason: string): TPlacementValidationResult
	return _BuildResult({ reason }, { _BuildDetail(reason, nil) })
end

--[=[
    Validates a placement candidate with built-in technical checks and custom validators.
    @within PlacementPlusValidation
    @param candidate TPlacementCandidate -- Candidate to validate.
    @param options TPlacementValidationOptions? -- Validation rule options.
    @return TPlacementValidationResult -- Structured validation result.
]=]
function Validation.ValidateCandidate(
	candidate: TPlacementCandidate,
	options: TPlacementValidationOptions?
): TPlacementValidationResult
	-- Normalize optional input so every rule reads from the same resolved options table.
	local resolvedOptions = (options or {}) :: TPlacementValidationOptions
	local reasons = {}
	local reasonDetails = {}

	-- Run the built-in rule set first so core failures always appear in the result.
	if not Rules.IsWithinBounds(candidate, resolvedOptions) then
		_AddReasonDetail(reasons, reasonDetails, _BuildOutOfBoundsDetail(candidate, resolvedOptions))
	end

	if not Rules.IsSurfaceAllowed(candidate, resolvedOptions) then
		_AddReasonDetail(reasons, reasonDetails, _BuildInvalidSurfaceDetail(candidate))
	end

	if not Rules.IsWithinSlopeLimit(candidate, resolvedOptions) then
		_AddReasonDetail(reasons, reasonDetails, _BuildSlopeDetail(candidate, resolvedOptions))
	end

	if not Rules.IsClearOfObstacles(candidate, resolvedOptions) then
		_AddReasonDetail(reasons, reasonDetails, _BuildObstructedDetail(candidate))
	end

	if not Rules.HasRequiredSupport(candidate, resolvedOptions) then
		_AddReasonDetail(reasons, reasonDetails, _BuildMissingSupportDetail(resolvedOptions))
	end

	-- Allow custom validators to contribute additional reasons without short-circuiting earlier checks.
	if resolvedOptions.CustomValidators ~= nil then
		for _, validator in ipairs(resolvedOptions.CustomValidators) do
			_AddReasonDetail(reasons, reasonDetails, _NormalizeDetail(validator(candidate, resolvedOptions)))
		end
	end

	return _BuildResult(reasons, reasonDetails)
end

return table.freeze(Validation)
