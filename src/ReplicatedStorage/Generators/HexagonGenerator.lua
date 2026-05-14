--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GeneratorRunner = require(script.Parent.GeneratorRunner)

type TGenerationParams<Attributes> = {
	Attributes: Attributes,
	Size: Vector3,
	Pause: (self: TGenerationParams<Attributes>) -> (),
}

type TGeneratorDefinition<Attributes> = {
	Defaults: Attributes,
	Generate: (parameters: TGenerationParams<Attributes>, targetContainer: Instance) -> (),
}

type TGeneratorHelpers = {
	assignProperties: (instance: Instance, properties: { [string]: any }?) -> Instance,
	createInstance: (className: string, properties: { [string]: any }?) -> Instance,
	createFolder: (properties: { [string]: any }?) -> Folder,
	createModle: (properties: { [string]: any }?) -> Model,
	createPart: (properties: { [string]: any }?) -> Part,
	createHexagonPart: (properties: { [string]: any }?) -> BasePart,
}

type TRunOptions = GeneratorRunner.TRunOptions

local DEFAULT_RANDOM_SEED = 12345
local ARRAY_ROOT_NAME = "HexagonArray"
local ASSET_ROOT_NAME = "__Assets__"
local HEXAGON_ASSET_NAME = "BaseHexagon"

local DEFAULTS = table.freeze({
	RandomSeed = DEFAULT_RANDOM_SEED,
	BottomColor = Color3.fromRGB(86, 125, 70),
	TopColor = Color3.fromRGB(110, 165, 90),
	BottomSizeXZ = 6,
	BottomHeight = 4,
	TopHeight = 2,
	TopScaleXZ = 0.9,
	UseTopHexagon = true,
	ArrayRows = 1,
	ArrayColumns = 1,
	RandomizeArraySizeEnabled = false,
	ArraySpacingX = 8,
	ArraySpacingZ = 8,
	StaggerRowsEnabled = false,
	StaggerOffsetX = 4,
	StaggerColumnsEnabled = false,
	StaggerOffsetZ = 4,
	RandomizeEnabled = false,
	RandomYawMinDeg = 0,
	RandomYawMaxDeg = 360,
	RandomScaleMin = 0.9,
	RandomScaleMax = 1.1,
})

type THexagonAttributes = typeof(DEFAULTS)

local Helpers: TGeneratorHelpers = {}

function Helpers.assignProperties(instance: Instance, properties: { [string]: any }?): Instance
	if properties == nil then
		return instance
	end

	for name, value in properties do
		if name ~= "Parent" then
			(instance :: any)[name] = value
		end
	end

	local parent = properties.Parent
	if parent ~= nil then
		instance.Parent = parent
	end

	return instance
end

local e = function(className: string, properties: { [string]: any }?): Instance
	return Helpers.assignProperties(Instance.new(className), properties)
end

function Helpers.createInstance(className: string, properties: { [string]: any }?): Instance
	return e(className, properties)
end

Helpers.createFolder = function(properties)
	return e("Folder", properties) :: Folder
end

Helpers.createModle = function(properties)
	return e("Model", properties) :: Model
end

function Helpers.createPart(properties: { [string]: any }?): Part
	local part = e("Part", {
		Anchored = true,
		CanCollide = true,
		Material = Enum.Material.SmoothPlastic,
		TopSurface = Enum.SurfaceType.Smooth,
		BottomSurface = Enum.SurfaceType.Smooth,
	})

	return Helpers.assignProperties(part, properties) :: Part
end

local function resolveHexagonAsset(): BasePart
	local assetRoot = ReplicatedStorage:FindFirstChild(ASSET_ROOT_NAME)
	assert(assetRoot ~= nil and assetRoot:IsA("Folder"), "[HexagonGenerator] ReplicatedStorage.__Assets__ is missing")

	local hexagonAsset = assetRoot:FindFirstChild(HEXAGON_ASSET_NAME, true)
	assert(hexagonAsset ~= nil, "[HexagonGenerator] __Assets__.BaseHexagon is missing")
	assert(hexagonAsset:IsA("BasePart"), "[HexagonGenerator] __Assets__.BaseHexagon must be a BasePart")

	return hexagonAsset
end

function Helpers.createHexagonPart(properties: { [string]: any }?): BasePart
	local hexagonPart = resolveHexagonAsset():Clone()
	hexagonPart.Anchored = true
	hexagonPart.CanCollide = false
	return Helpers.assignProperties(hexagonPart, properties) :: BasePart
end

local function clampPositive(value: number, fallback: number): number
	if value <= 0 then
		return fallback
	end
	return value
end

local function floorAtLeastOne(value: number): number
	local floored = math.floor(value)
	if floored < 1 then
		return 1
	end
	return floored
end

local function applyRandomization(attributes: THexagonAttributes, random: Random): (number, number)
	if not attributes.RandomizeEnabled then
		return 0, 1
	end

	local yawMin = math.min(attributes.RandomYawMinDeg, attributes.RandomYawMaxDeg)
	local yawMax = math.max(attributes.RandomYawMinDeg, attributes.RandomYawMaxDeg)
	local scaleMin = math.min(attributes.RandomScaleMin, attributes.RandomScaleMax)
	local scaleMax = math.max(attributes.RandomScaleMin, attributes.RandomScaleMax)

	local yawDeg = random:NextNumber(yawMin, yawMax)
	local scale = random:NextNumber(scaleMin, scaleMax)
	if scale <= 0 then
		scale = 1
	end

	return yawDeg, scale
end

local function createHexBlock(attributes: THexagonAttributes, random: Random, root: Instance, centerXZ: Vector3)
	local yawDeg, scale = applyRandomization(attributes, random)
	local yawCFrame = CFrame.fromAxisAngle(Vector3.yAxis, math.rad(yawDeg))
	local useTopHexagon = attributes.UseTopHexagon

	local bottomHeight = clampPositive(attributes.BottomHeight * scale, 1)
	local bottomSizeXZ = clampPositive(attributes.BottomSizeXZ * scale, 1)

	local bottomPart = Helpers.createHexagonPart({
		Name = "HexBottom",
		Parent = root,
		Color = attributes.BottomColor,
		CastShadow = true,
		Material = Enum.Material.Slate,
	})

	local targetBottomSize = Vector3.new(bottomSizeXZ, bottomHeight, bottomSizeXZ)
	bottomPart.Size = targetBottomSize

	local groundY = centerXZ.Y
	local bottomCenter = Vector3.new(centerXZ.X, groundY + targetBottomSize.Y * 0.5, centerXZ.Z)

	bottomPart.CFrame = CFrame.new(bottomCenter) * yawCFrame

	if not useTopHexagon then
		return
	end

	local topHeight = clampPositive(attributes.TopHeight * scale, 0.5)
	local topScaleXZ = math.clamp(attributes.TopScaleXZ, 0.01, 1)
	local topPart = Helpers.createHexagonPart({
		Name = "HexTop",
		Parent = root,
		Color = attributes.TopColor,
		CastShadow = true,
		Material = Enum.Material.LeafyGrass,
		MaterialVariant = "Grass2",
	})
	local targetTopSize = Vector3.new(targetBottomSize.X * topScaleXZ, topHeight, targetBottomSize.Z * topScaleXZ)
	local topCenter = Vector3.new(centerXZ.X, groundY + targetBottomSize.Y + targetTopSize.Y * 0.5, centerXZ.Z)

	topPart.Size = targetTopSize
	topPart.CFrame = CFrame.new(topCenter) * yawCFrame
end

local function resolveArrayDimensions(attributes: THexagonAttributes, random: Random): (number, number)
	local rows = floorAtLeastOne(attributes.ArrayRows)
	local columns = floorAtLeastOne(attributes.ArrayColumns)

	if not attributes.RandomizeArraySizeEnabled then
		return rows, columns
	end

	return random:NextInteger(1, rows), random:NextInteger(1, columns)
end

local function destroyExistingArrayRoots(targetContainer: Instance)
	for _, child in ipairs(targetContainer:GetChildren()) do
		if child.Name == ARRAY_ROOT_NAME then
			child:Destroy()
		end
	end
end

local function resolveRunSeed(attributes: THexagonAttributes): number
	if attributes.RandomSeed ~= DEFAULT_RANDOM_SEED then
		return attributes.RandomSeed
	end

	return os.time() + math.floor(os.clock() * 1000)
end

local function createArray(attributes: THexagonAttributes, random: Random, root: Instance)
	local rows, columns = resolveArrayDimensions(attributes, random)
	local spacingX = attributes.ArraySpacingX
	local spacingZ = attributes.ArraySpacingZ
	local staggerEnabled = attributes.StaggerRowsEnabled
	local staggerOffsetX = attributes.StaggerOffsetX
	local staggerColumnsEnabled = attributes.StaggerColumnsEnabled
	local staggerOffsetZ = attributes.StaggerOffsetZ

	local halfWidth = (columns - 1) * spacingX * 0.5
	local halfDepth = (rows - 1) * spacingZ * 0.5

	for row = 0, rows - 1 do
		local rowOffsetX = 0
		if staggerEnabled and (row % 2 == 1) then
			rowOffsetX = staggerOffsetX
		end

		for col = 0, columns - 1 do
			local colOffsetZ = 0
			if staggerColumnsEnabled and (col % 2 == 1) then
				colOffsetZ = staggerOffsetZ
			end

			local x = col * spacingX - halfWidth + rowOffsetX
			local z = row * spacingZ - halfDepth + colOffsetZ
			createHexBlock(attributes, random, root, Vector3.new(x, 0, z))
		end
	end
end

local function Generate(parameters: TGenerationParams<THexagonAttributes>, targetContainer: Instance)
	local attributes = parameters.Attributes
	local random = Random.new(resolveRunSeed(attributes))

	destroyExistingArrayRoots(targetContainer)

	local root = Helpers.createFolder({
		Name = ARRAY_ROOT_NAME,
		Parent = targetContainer,
	})

	createArray(attributes, random, root)
end

local Generator: TGeneratorDefinition<THexagonAttributes> & {
	Attributes: THexagonAttributes,
	OnGenerate: (parameters: TGenerationParams<THexagonAttributes>, targetContainer: Instance) -> (),
	Run: (sourceInstance: Instance, targetContainer: Instance, options: TRunOptions?) -> { [string]: any },
} =
	{
		Defaults = DEFAULTS,
		Generate = Generate,
		Attributes = DEFAULTS,
		OnGenerate = Generate,
		Run = function(sourceInstance: Instance, targetContainer: Instance, options: TRunOptions?)
			return GeneratorRunner.RunGeneratorModule(script, sourceInstance, targetContainer, options)
		end,
	}

return table.freeze(Generator)
