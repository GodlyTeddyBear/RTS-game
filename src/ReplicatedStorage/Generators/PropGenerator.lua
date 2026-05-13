--!strict

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local GeneratorRunner = require(script.Parent.GeneratorRunner)
local ModelPlus = require(ReplicatedStorage.Utilities.ModelPlus)
local PlacementPlus = require(ReplicatedStorage.Utilities.PlacementPlus)
local SpatialQuery = require(ReplicatedStorage.Utilities.SpatialQuery)

-- Types
type TGenerationParams<Attributes> = {
	Attributes: Attributes,
	Size: Vector3,
	Pause: (self: TGenerationParams<Attributes>) -> (),
}

type TGeneratorDefinition<Attributes> = {
	Defaults: Attributes,
	Generate: (parameters: TGenerationParams<Attributes>, targetContainer: Instance) -> (),
}

type TRunOptions = GeneratorRunner.TRunOptions
type TPlacementValidationOptions = PlacementPlus.TPlacementValidationOptions
type TPlacementFootprint = PlacementPlus.TPlacementFootprint
type TSpatialQueryOptions = SpatialQuery.TQueryOptions
type TCategoryName = "Trees" | "Vegetation" | "Rocks" | "Paths" | "Other"
type TCategoryAssetTable = { [TCategoryName]: { string } }
type TCategorySubfolderTable = { [TCategoryName]: Folder }
type TStylePreset = { [TCategoryName]: number }
type TCategorySettings = {
	FolderName: TCategoryName,
	EnabledAttribute: string,
	DensityAttribute: string,
	DensityScale: number,
	SpacingScale: number,
}
type TOccupiedEntry = {
	Position: Vector3,
	Radius: number,
}
type TCategoryRuntime = {
	Name: TCategoryName,
	Folder: Folder,
	Settings: TCategorySettings,
	Assets: { Model },
	EffectiveDensity: number,
}

-- Constants
local ASSET_ROOT_NAME = "__Assets__"
local PATCH_FOLDER_NAME = "PropPatch"
local DEFAULT_STYLE = "Mixed"
local MIN_SCALE = 0.05
local MIN_SPACING = 1
local MIN_PLACEMENT_ATTEMPTS = 1
local MIN_PATCH_AREA = 1
local MIN_Y_SURFACE_NORMAL = 0.75
local MAX_SURFACE_SLOPE_DEGREES = 25
local MAX_RAYCAST_HEIGHT_PADDING = 256
local SUPPORT_RAY_LENGTH = 12
local CLEARANCE_HEIGHT_PADDING = 4
local CATEGORY_ORDER: { TCategoryName } = {
	"Trees",
	"Vegetation",
	"Rocks",
	"Paths",
	"Other",
}

local CATEGORY_ASSETS: TCategoryAssetTable = table.freeze({
	Trees = {
		"PineTree2",
		"Tree1",
		"TreeStump",
	},
	Vegetation = {
		"Bush1",
		"Flower1",
		"Flower2",
		"Flower3",
		"Mushroom2",
		"TallFern",
	},
	Rocks = {
		"RockGroup1",
		"RockGroup2",
	},
	Paths = {
		"RockPath1",
		"RockPath2",
		"LongLog",
	},
	Other = {},
})

local CATEGORY_SETTINGS: { [TCategoryName]: TCategorySettings } = table.freeze({
	Trees = {
		FolderName = "Trees",
		EnabledAttribute = "EnableTrees",
		DensityAttribute = "TreesDensity",
		DensityScale = 0.28,
		SpacingScale = 1.3,
	},
	Vegetation = {
		FolderName = "Vegetation",
		EnabledAttribute = "EnableVegetation",
		DensityAttribute = "VegetationDensity",
		DensityScale = 0.9,
		SpacingScale = 0.65,
	},
	Rocks = {
		FolderName = "Rocks",
		EnabledAttribute = "EnableRocks",
		DensityAttribute = "RocksDensity",
		DensityScale = 0.35,
		SpacingScale = 1.05,
	},
	Paths = {
		FolderName = "Paths",
		EnabledAttribute = "EnablePaths",
		DensityAttribute = "PathsDensity",
		DensityScale = 0.22,
		SpacingScale = 1.15,
	},
	Other = {
		FolderName = "Other",
		EnabledAttribute = "EnableOther",
		DensityAttribute = "OtherDensity",
		DensityScale = 0.2,
		SpacingScale = 1,
	},
})

local STYLE_PRESETS: { [string]: TStylePreset } = table.freeze({
	Mixed = table.freeze({
		Trees = 1,
		Vegetation = 1,
		Rocks = 1,
		Paths = 1,
		Other = 1,
	}),
	Forest = table.freeze({
		Trees = 1.35,
		Vegetation = 1.2,
		Rocks = 0.55,
		Paths = 0.45,
		Other = 0.75,
	}),
	Rocky = table.freeze({
		Trees = 0.45,
		Vegetation = 0.7,
		Rocks = 1.45,
		Paths = 0.8,
		Other = 0.7,
	}),
	Vegetation = table.freeze({
		Trees = 0.85,
		Vegetation = 1.5,
		Rocks = 0.5,
		Paths = 0.5,
		Other = 0.7,
	}),
	Path = table.freeze({
		Trees = 0.25,
		Vegetation = 0.8,
		Rocks = 0.9,
		Paths = 1.55,
		Other = 0.6,
	}),
})

local DEFAULTS = table.freeze({
	RandomSeed = 12345,
	Style = DEFAULT_STYLE,
	BaseSpacing = 16,
	MaxPlacementAttempts = 12,
	ScaleMin = 0.9,
	ScaleMax = 1.1,
	YawMinDeg = 0,
	YawMaxDeg = 360,
	EnableTrees = true,
	EnableVegetation = true,
	EnableRocks = true,
	EnablePaths = false,
	EnableOther = false,
	TreesDensity = 0.55,
	VegetationDensity = 0.7,
	RocksDensity = 0.35,
	PathsDensity = 0.15,
	OtherDensity = 0.1,
})

type TPropAttributes = typeof(DEFAULTS)

-- Module
local PropGenerator = {}
local _CreatePatchRoot
local _CreateCategoryFolders
local _ResolveAssetRoot
local _ResolvePatchBounds
local _BuildRuntimeCategories
local _ResolveStylePreset
local _ResolveCategoryAssets
local _ResolveEffectiveDensity
local _CalculateTargetCount
local _GenerateCategory
local _TryPlaceAsset
local _ChooseAssetModel
local _ResolveScale
local _ResolveYaw
local _SamplePatchPosition
local _RaycastPatchSurface
local _BuildPlacementFootprint
local _BuildValidationOptions
local _BuildSurfaceQueryOptions
local _BuildPlacementQueryOptions
local _AreOccupiedEntriesOverlapping
local _ClampDensity

function PropGenerator.Generate(parameters: TGenerationParams<TPropAttributes>, targetContainer: Instance)
	local attributes = parameters.Attributes
	local random = Random.new(attributes.RandomSeed)

	-- Build the generated patch root and per-category folders up front so empty categories still exist.
	local patchRoot = _CreatePatchRoot(targetContainer)
	local categoryFolders = _CreateCategoryFolders(patchRoot)

	-- Resolve the asset source and the world-space patch bounds before any placement attempts.
	local assetRoot = _ResolveAssetRoot()
	local boundsCenter, boundsSize = _ResolvePatchBounds(targetContainer, parameters.Size)
	local runtimeCategories = _BuildRuntimeCategories(attributes, assetRoot, categoryFolders)

	-- Exit early when the generator has no usable categories or no area to fill.
	if #runtimeCategories == 0 then
		return
	end

	local patchArea = math.max(boundsSize.X * boundsSize.Z, MIN_PATCH_AREA)
	local occupiedEntries = {}
	local hitQueryOptions = _BuildSurfaceQueryOptions(patchRoot)

	-- Run each enabled category independently so styles and densities can emphasize different prop families.
	for _, categoryRuntime in ipairs(runtimeCategories) do
		local targetCount = _CalculateTargetCount(categoryRuntime, patchArea, attributes.BaseSpacing)
		_GenerateCategory(
			parameters,
			random,
			boundsCenter,
			boundsSize,
			attributes,
			categoryRuntime,
			hitQueryOptions,
			occupiedEntries,
			targetCount
		)
	end
end

function PropGenerator.Run(
	sourceInstance: Instance,
	targetContainer: Instance,
	options: TRunOptions?
): { [string]: any }
	return GeneratorRunner.RunGeneratorModule(script, sourceInstance, targetContainer, options)
end

local Generator: TGeneratorDefinition<TPropAttributes> & {
	Attributes: TPropAttributes,
	OnGenerate: (parameters: TGenerationParams<TPropAttributes>, targetContainer: Instance) -> (),
	Run: (sourceInstance: Instance, targetContainer: Instance, options: TRunOptions?) -> { [string]: any },
} =
	{
		Defaults = DEFAULTS,
		Generate = PropGenerator.Generate,
		Attributes = DEFAULTS,
		OnGenerate = PropGenerator.Generate,
		Run = PropGenerator.Run,
	}

-- Helpers
function _CreatePatchRoot(targetContainer: Instance): Folder
	local patchRoot = Instance.new("Folder")
	patchRoot.Name = PATCH_FOLDER_NAME
	patchRoot.Parent = targetContainer
	return patchRoot
end

function _CreateCategoryFolders(patchRoot: Folder): TCategorySubfolderTable
	local categoryFolders = {} :: { [TCategoryName]: Folder }

	for _, categoryName in ipairs(CATEGORY_ORDER) do
		local folder = Instance.new("Folder")
		folder.Name = categoryName
		folder.Parent = patchRoot
		categoryFolders[categoryName] = folder
	end

	return categoryFolders :: TCategorySubfolderTable
end

function _ResolveAssetRoot(): Folder?
	local assetRoot = ReplicatedStorage:FindFirstChild(ASSET_ROOT_NAME)
	if assetRoot == nil or not assetRoot:IsA("Folder") then
		return nil
	end

	return assetRoot
end

function _ResolvePatchBounds(targetContainer: Instance, fallbackSize: Vector3): (Vector3, Vector3)
	local ownerInstance = targetContainer.Parent
	if ownerInstance ~= nil then
		if ownerInstance:IsA("BasePart") then
			return ownerInstance.Position, ownerInstance.Size
		end

		if ownerInstance:IsA("Model") then
			local boundsCFrame, boundsSize = ownerInstance:GetBoundingBox()
			return boundsCFrame.Position, boundsSize
		end
	end

	return Vector3.zero, fallbackSize
end

function _BuildRuntimeCategories(
	attributes: TPropAttributes,
	assetRoot: Folder?,
	categoryFolders: TCategorySubfolderTable
): { TCategoryRuntime }
	local stylePreset = _ResolveStylePreset(attributes.Style)
	local runtimeCategories = {}

	for _, categoryName in ipairs(CATEGORY_ORDER) do
		local settings = CATEGORY_SETTINGS[categoryName]
		local assets = _ResolveCategoryAssets(assetRoot, CATEGORY_ASSETS[categoryName])
		local effectiveDensity = _ResolveEffectiveDensity(attributes, settings, stylePreset[categoryName])

		if (attributes :: any)[settings.EnabledAttribute] == true and effectiveDensity > 0 and #assets > 0 then
			table.insert(runtimeCategories, {
				Name = categoryName,
				Folder = categoryFolders[categoryName],
				Settings = settings,
				Assets = assets,
				EffectiveDensity = effectiveDensity,
			})
		end
	end

	return runtimeCategories
end

function _ResolveStylePreset(styleName: string): TStylePreset
	return STYLE_PRESETS[styleName] or STYLE_PRESETS[DEFAULT_STYLE]
end

function _ResolveCategoryAssets(assetRoot: Folder?, assetNames: { string }): { Model }
	if assetRoot == nil or #assetNames == 0 then
		return {}
	end

	local resolvedAssets = {}

	for _, assetName in ipairs(assetNames) do
		local assetInstance = assetRoot:FindFirstChild(assetName, true)
		if assetInstance ~= nil and assetInstance:IsA("Model") then
			table.insert(resolvedAssets, assetInstance)
		end
	end

	return resolvedAssets
end

function _ResolveEffectiveDensity(
	attributes: TPropAttributes,
	settings: TCategorySettings,
	styleMultiplier: number
): number
	local configuredDensity = _ClampDensity((attributes :: any)[settings.DensityAttribute] :: number)
	return _ClampDensity(configuredDensity * styleMultiplier)
end

function _CalculateTargetCount(categoryRuntime: TCategoryRuntime, patchArea: number, baseSpacing: number): number
	local spacing = math.max(baseSpacing, MIN_SPACING)
	local basePlacementCount = patchArea / (spacing * spacing)
	local scaledCount = basePlacementCount * categoryRuntime.Settings.DensityScale * categoryRuntime.EffectiveDensity

	if scaledCount <= 0 then
		return 0
	end

	return math.max(1, math.floor(scaledCount + 0.5))
end

function _GenerateCategory(
	parameters: TGenerationParams<TPropAttributes>,
	random: Random,
	boundsCenter: Vector3,
	boundsSize: Vector3,
	attributes: TPropAttributes,
	categoryRuntime: TCategoryRuntime,
	hitQueryOptions: TSpatialQueryOptions,
	occupiedEntries: { TOccupiedEntry },
	targetCount: number
)
	if targetCount <= 0 then
		return
	end

	local placementAttempts = 0
	local maxPlacementAttempts = math.max(attributes.MaxPlacementAttempts, MIN_PLACEMENT_ATTEMPTS)

	-- Keep trying until the category reaches its target count or burns through its bounded attempt budget.
	for placementIndex = 1, targetCount do
		local placed = false

		for _ = 1, maxPlacementAttempts do
			placementAttempts += 1
			if placementAttempts % 10 == 0 then
				parameters:Pause()
			end

			if
				_TryPlaceAsset(
					random,
					categoryRuntime.Folder.Parent :: Folder,
					boundsCenter,
					boundsSize,
					attributes,
					categoryRuntime,
					hitQueryOptions,
					occupiedEntries
				)
			then
				placed = true
				break
			end
		end

		if not placed then
			if placementIndex == 1 then
				return
			end
			break
		end
	end
end

function _TryPlaceAsset(
	random: Random,
	patchRoot: Folder,
	boundsCenter: Vector3,
	boundsSize: Vector3,
	attributes: TPropAttributes,
	categoryRuntime: TCategoryRuntime,
	hitQueryOptions: TSpatialQueryOptions,
	occupiedEntries: { TOccupiedEntry }
): boolean
	local assetModel = _ChooseAssetModel(random, categoryRuntime.Assets)
	local cloneModel = assetModel:Clone()

	-- Normalize the clone scale first so every later bounds and footprint calculation uses the final size.
	local scale = _ResolveScale(random, attributes.ScaleMin, attributes.ScaleMax)
	cloneModel:ScaleTo(scale)

	local yawRadians = math.rad(_ResolveYaw(random, attributes.YawMinDeg, attributes.YawMaxDeg))
	local samplePosition = _SamplePatchPosition(random, boundsCenter, boundsSize)
	local surfaceHit = _RaycastPatchSurface(samplePosition, boundsCenter, boundsSize, hitQueryOptions)
	if surfaceHit == nil then
		cloneModel:Destroy()
		return false
	end

	local footprint, clearanceSize, occupiedRadius =
		_BuildPlacementFootprint(cloneModel, attributes.BaseSpacing, categoryRuntime.Settings.SpacingScale)
	local validationOptions =
		_BuildValidationOptions(patchRoot, footprint, clearanceSize, occupiedRadius, occupiedEntries)

	-- Ask PlacementPlus to build and validate the grounded candidate before committing the clone to the patch root.
	local placementResult = PlacementPlus.ResolvePlacementCandidate({
		Hit = surfaceHit,
	}, {
		Model = cloneModel,
		YawRadians = yawRadians,
		AlignToGround = true,
	}, validationOptions)
	local candidate = placementResult.Candidate

	if candidate == nil or not placementResult.Validation.IsValid then
		cloneModel:Destroy()
		return false
	end

	cloneModel.Parent = categoryRuntime.Folder
	ModelPlus.MoveToCFrame(cloneModel, candidate.CFrame)
	table.insert(occupiedEntries, {
		Position = candidate.Position,
		Radius = occupiedRadius,
	})

	return true
end

function _ChooseAssetModel(random: Random, assets: { Model }): Model
	local assetIndex = random:NextInteger(1, #assets)
	return assets[assetIndex]
end

function _ResolveScale(random: Random, scaleMin: number, scaleMax: number): number
	local resolvedMin = math.max(math.min(scaleMin, scaleMax), MIN_SCALE)
	local resolvedMax = math.max(math.max(scaleMin, scaleMax), resolvedMin)
	return random:NextNumber(resolvedMin, resolvedMax)
end

function _ResolveYaw(random: Random, yawMinDeg: number, yawMaxDeg: number): number
	local resolvedMin = math.min(yawMinDeg, yawMaxDeg)
	local resolvedMax = math.max(yawMinDeg, yawMaxDeg)
	return random:NextNumber(resolvedMin, resolvedMax)
end

function _SamplePatchPosition(random: Random, boundsCenter: Vector3, boundsSize: Vector3): Vector3
	local halfWidth = boundsSize.X * 0.5
	local halfDepth = boundsSize.Z * 0.5

	return Vector3.new(
		random:NextNumber(boundsCenter.X - halfWidth, boundsCenter.X + halfWidth),
		boundsCenter.Y,
		random:NextNumber(boundsCenter.Z - halfDepth, boundsCenter.Z + halfDepth)
	)
end

function _RaycastPatchSurface(
	samplePosition: Vector3,
	boundsCenter: Vector3,
	boundsSize: Vector3,
	queryOptions: TSpatialQueryOptions
): RaycastResult?
	local startHeight = math.min(math.max(boundsSize.Y * 0.5 + 64, 64), MAX_RAYCAST_HEIGHT_PADDING)
	local origin = Vector3.new(samplePosition.X, boundsCenter.Y + startHeight, samplePosition.Z)
	local direction = Vector3.new(0, -(boundsSize.Y + startHeight + 128), 0)
	return SpatialQuery.Raycast(origin, direction, queryOptions)
end

function _BuildPlacementFootprint(
	model: Model,
	baseSpacing: number,
	spacingScale: number
): (TPlacementFootprint, Vector3, number)
	local _, boundsSize = ModelPlus.GetBounds(model)
	local horizontalSpacing = math.max(baseSpacing * spacingScale, MIN_SPACING)
	local padding = Vector3.new(horizontalSpacing, CLEARANCE_HEIGHT_PADDING, horizontalSpacing)
	local groundBoundsSize = Vector3.new(boundsSize.X, math.max(boundsSize.Y, 1), boundsSize.Z)
	local footprint = PlacementPlus.BuildFootprintFromBounds(groundBoundsSize, padding)
	local clearanceSize = PlacementPlus.BuildClearanceSizeFromFootprint(footprint)
	local occupiedRadius = (math.max(clearanceSize.X, clearanceSize.Z) * 0.5)

	return footprint, clearanceSize, occupiedRadius
end

function _BuildValidationOptions(
	patchRoot: Folder,
	footprint: TPlacementFootprint,
	clearanceSize: Vector3,
	occupiedRadius: number,
	occupiedEntries: { TOccupiedEntry }
): TPlacementValidationOptions
	local supportPoints = PlacementPlus.BuildSupportPointsFromFootprint(footprint)
	local placementQueryOptions = _BuildPlacementQueryOptions(patchRoot)

	return {
		MaxSlopeDegrees = MAX_SURFACE_SLOPE_DEGREES,
		RequireClearance = true,
		ClearanceSize = clearanceSize,
		ClearanceQueryOptions = placementQueryOptions,
		RequireSupport = true,
		SupportRayLength = SUPPORT_RAY_LENGTH,
		SupportPoints = supportPoints,
		SupportQueryOptions = placementQueryOptions,
		SurfacePredicate = function(candidate)
			local surfaceInstance = candidate.SurfaceInstance
			local surfaceNormal = candidate.SurfaceNormal
			return surfaceInstance ~= nil
				and surfaceInstance:IsA("BasePart")
				and surfaceNormal ~= nil
				and surfaceNormal.Y >= MIN_Y_SURFACE_NORMAL
		end,
		CustomValidators = {
			function(candidate)
				for _, occupiedEntry in ipairs(occupiedEntries) do
					if _AreOccupiedEntriesOverlapping(candidate.Position, occupiedRadius, occupiedEntry) then
						return "OccupiedByProp"
					end
				end

				return nil
			end,
		},
	}
end

function _BuildSurfaceQueryOptions(patchRoot: Folder): TSpatialQueryOptions
	return {
		FilterType = Enum.RaycastFilterType.Exclude,
		FilterDescendantsInstances = { patchRoot },
		IgnoreWater = true,
		RespectCanCollide = false,
	}
end

function _BuildPlacementQueryOptions(patchRoot: Folder): TSpatialQueryOptions
	return {
		FilterType = Enum.RaycastFilterType.Exclude,
		FilterDescendantsInstances = { patchRoot },
		IgnoreWater = true,
		RespectCanCollide = false,
	}
end

function _AreOccupiedEntriesOverlapping(
	candidatePosition: Vector3,
	candidateRadius: number,
	occupiedEntry: TOccupiedEntry
): boolean
	local xDelta = candidatePosition.X - occupiedEntry.Position.X
	local zDelta = candidatePosition.Z - occupiedEntry.Position.Z
	local combinedRadius = candidateRadius + occupiedEntry.Radius
	return (xDelta * xDelta + zDelta * zDelta) < (combinedRadius * combinedRadius)
end

function _ClampDensity(value: number): number
	return math.clamp(value, 0, 1)
end

return table.freeze(Generator)
