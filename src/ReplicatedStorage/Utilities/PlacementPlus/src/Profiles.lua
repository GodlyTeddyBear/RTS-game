--!strict

--[=[
    @class PlacementPlusProfiles
    Plain-table placement profile helpers for reusable placement options.
    @server
    @client
]=]

local Footprint = require(script.Parent.Footprint)
local Types = require(script.Parent.Types)

-- ── Types ─────────────────────────────────────────────────────────────────────

type TPlacementFootprint = Types.TPlacementFootprint
type TPlacementOptions = Types.TPlacementOptions
type TPlacementProfile = Types.TPlacementProfile
type TPlacementProfileSpec = Types.TPlacementProfileSpec
type TPlacementValidationOptions = Types.TPlacementValidationOptions

local Profiles = {}

-- ── Private ───────────────────────────────────────────────────────────────────

-- Clones array-style config so profile merges can reuse the original tables safely.
local function _CloneArray<T>(array: { T }?): { T }?
	if array == nil then
		return nil
	end

	local clone = table.create(#array)
	for index, value in ipairs(array) do
		clone[index] = value
	end

	return clone
end

-- Clones dictionary-style config so merged options do not share mutable tables.
local function _CloneDictionary<K, V>(dictionary: { [K]: V }?): { [K]: V }?
	if dictionary == nil then
		return nil
	end

	return table.clone(dictionary)
end

-- Merges metadata with override precedence, returning a frozen table when anything is present.
local function _MergeMetadata(
	baseMetadata: { [string]: any }?,
	overrideMetadata: { [string]: any }?
): { [string]: any }?
	if baseMetadata == nil and overrideMetadata == nil then
		return nil
	end

	local merged = {}
	if baseMetadata ~= nil then
		for key, value in baseMetadata do
			merged[key] = value
		end
	end

	if overrideMetadata ~= nil then
		for key, value in overrideMetadata do
			merged[key] = value
		end
	end

	return table.freeze(merged)
end

-- Clones placement options so profile defaults can be merged without mutating the source table.
local function _ClonePlacementOptions(options: TPlacementOptions?): TPlacementOptions
	if options == nil then
		return {}
	end

	return {
		Model = options.Model,
		CFrame = options.CFrame,
		Rotation = options.Rotation,
		PositionGridSize = options.PositionGridSize,
		YawStepDegrees = options.YawStepDegrees,
		YawRadians = options.YawRadians,
		FaceTarget = options.FaceTarget,
		AlignToGround = options.AlignToGround,
		SurfaceOffset = options.SurfaceOffset,
		BoundsCFrame = options.BoundsCFrame,
		BoundsSize = options.BoundsSize,
		Metadata = _MergeMetadata(nil, options.Metadata),
	}
end

-- Merges placement options with override precedence and profile metadata carrying through.
local function _MergePlacementOptions(
	baseOptions: TPlacementOptions?,
	overrideOptions: TPlacementOptions?,
	profileMetadata: { [string]: any }?
): TPlacementOptions
	local merged = _ClonePlacementOptions(baseOptions)
	local override = _ClonePlacementOptions(overrideOptions)
	local baseMetadata = merged.Metadata
	local overrideMetadata = override.Metadata

	for key, value in override do
		if value ~= nil then
			(merged :: any)[key] = value
		end
	end

	merged.Metadata = _MergeMetadata(_MergeMetadata(profileMetadata, baseMetadata), overrideMetadata)
	return table.freeze(merged)
end

-- Clones validation options so nested collections can be safely frozen after merge.
local function _CloneValidationOptions(options: TPlacementValidationOptions?): TPlacementValidationOptions
	if options == nil then
		return {}
	end

	return {
		BoundsMin = options.BoundsMin,
		BoundsMax = options.BoundsMax,
		AllowedMaterials = _CloneDictionary(options.AllowedMaterials),
		AllowedInstances = _CloneArray(options.AllowedInstances),
		SurfacePredicate = options.SurfacePredicate,
		MaxSlopeDegrees = options.MaxSlopeDegrees,
		RequireClearance = options.RequireClearance,
		ClearanceSize = options.ClearanceSize,
		ClearancePadding = options.ClearancePadding,
		ClearanceQueryOptions = options.ClearanceQueryOptions,
		RequireSupport = options.RequireSupport,
		SupportDistance = options.SupportDistance,
		SupportRayLength = options.SupportRayLength,
		SupportPoints = _CloneArray(options.SupportPoints),
		SupportQueryOptions = options.SupportQueryOptions,
		CustomValidators = _CloneArray(options.CustomValidators),
	}
end

-- Applies footprint defaults before caller overrides so profile-supplied support data fills gaps.
local function _ApplyFootprintDefaults(
	options: TPlacementValidationOptions,
	footprint: TPlacementFootprint?
): TPlacementValidationOptions
	if footprint == nil then
		return options
	end

	if options.ClearanceSize == nil then
		options.ClearanceSize = footprint.Size
	end

	if options.ClearancePadding == nil then
		options.ClearancePadding = footprint.Padding
	end

	if options.SupportPoints == nil then
		options.SupportPoints = Footprint.BuildSupportPointsFromFootprint(footprint)
	end

	return options
end

-- Merges validation options and freezes nested collections so downstream callers receive stable tables.
local function _MergeValidationOptions(
	baseOptions: TPlacementValidationOptions?,
	overrideOptions: TPlacementValidationOptions?,
	footprint: TPlacementFootprint?
): TPlacementValidationOptions
	local merged = _ApplyFootprintDefaults(_CloneValidationOptions(baseOptions), footprint)
	local override = _CloneValidationOptions(overrideOptions)

	for key, value in override do
		if value ~= nil then
			(merged :: any)[key] = value
		end
	end

	if merged.AllowedMaterials ~= nil then
		merged.AllowedMaterials = table.freeze(merged.AllowedMaterials)
	end
	if merged.AllowedInstances ~= nil then
		merged.AllowedInstances = table.freeze(merged.AllowedInstances)
	end
	if merged.SupportPoints ~= nil and not table.isfrozen(merged.SupportPoints) then
		merged.SupportPoints = table.freeze(merged.SupportPoints)
	end
	if merged.CustomValidators ~= nil then
		merged.CustomValidators = table.freeze(merged.CustomValidators)
	end

	return table.freeze(merged)
end

-- Clones a footprint so profile specs can be reused without sharing mutable support data.
local function _CloneFootprint(footprint: TPlacementFootprint?): TPlacementFootprint?
	if footprint == nil then
		return nil
	end

	return table.freeze({
		Size = footprint.Size,
		Padding = footprint.Padding,
		SupportPointMode = footprint.SupportPointMode,
		SupportPoints = if footprint.SupportPoints ~= nil then table.freeze(table.clone(footprint.SupportPoints)) else nil,
	})
end

-- ── Public ────────────────────────────────────────────────────────────────────

--[=[
    Creates a frozen reusable placement profile from plain table data.
    @within PlacementPlusProfiles
    @param spec TPlacementProfileSpec -- Profile input data.
    @return TPlacementProfile -- Frozen placement profile.
]=]
function Profiles.CreateProfile(spec: TPlacementProfileSpec): TPlacementProfile
	-- Clone the footprint first so the profile owns its own support data.
	local footprint = _CloneFootprint(spec.Footprint)
	return table.freeze({
		PlacementOptions = _MergePlacementOptions(spec.PlacementOptions, nil, spec.Metadata),
		ValidationOptions = _MergeValidationOptions(spec.ValidationOptions, nil, footprint),
		Footprint = footprint,
		Metadata = _MergeMetadata(nil, spec.Metadata),
	})
end

--[=[
    Merges a placement profile with per-call placement and validation overrides.
    @within PlacementPlusProfiles
    @param profile TPlacementProfile -- Base placement profile.
    @param placementOptions TPlacementOptions? -- Per-call candidate option overrides.
    @param validationOptions TPlacementValidationOptions? -- Per-call validation option overrides.
    @return TPlacementOptions -- Frozen merged placement options.
    @return TPlacementValidationOptions -- Frozen merged validation options.
]=]
function Profiles.MergeProfile(
	profile: TPlacementProfile,
	placementOptions: TPlacementOptions?,
	validationOptions: TPlacementValidationOptions?
): (TPlacementOptions, TPlacementValidationOptions)
	-- Merge placement and validation overrides against the profile's frozen defaults.
	local mergedPlacementOptions = _MergePlacementOptions(profile.PlacementOptions, placementOptions, profile.Metadata)
	local mergedValidationOptions = _MergeValidationOptions(profile.ValidationOptions, validationOptions, profile.Footprint)
	return mergedPlacementOptions, mergedValidationOptions
end

return table.freeze(Profiles)
