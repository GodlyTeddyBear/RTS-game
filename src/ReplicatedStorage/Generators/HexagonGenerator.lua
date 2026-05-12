--!strict

local InsertService = game:GetService("InsertService")

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
	createMeshPartFromMeshId: (
		meshId: string,
		properties: { [string]: any }?,
		collisionFidelity: Enum.CollisionFidelity?,
		renderFidelity: Enum.RenderFidelity?
	) -> MeshPart,
}

type TRunOptions = GeneratorRunner.TRunOptions

local DEFAULTS = table.freeze({
	MeshId = "rbxassetid://0",
	RandomSeed = 12345,
	BottomColor = Color3.fromRGB(86, 125, 70),
	TopColor = Color3.fromRGB(110, 165, 90),
	BottomSizeXZ = 6,
	BottomHeight = 4,
	TopHeight = 2,
	TopScaleXZ = 0.9,
	ArrayRows = 1,
	ArrayColumns = 1,
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
		CanCollide = false,
		Material = Enum.Material.SmoothPlastic,
		TopSurface = Enum.SurfaceType.Smooth,
		BottomSurface = Enum.SurfaceType.Smooth,
	})

	return Helpers.assignProperties(part, properties) :: Part
end

function Helpers.createMeshPartFromMeshId(
	meshId: string,
	properties: { [string]: any }?,
	collisionFidelity: Enum.CollisionFidelity?,
	renderFidelity: Enum.RenderFidelity?
): MeshPart
	local meshPart = InsertService:CreateMeshPartAsync(
		meshId,
		collisionFidelity or Enum.CollisionFidelity.Default,
		renderFidelity or Enum.RenderFidelity.Automatic
	)
	meshPart.Anchored = true
	return Helpers.assignProperties(meshPart, properties) :: MeshPart
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

local function createHexBlock(
	attributes: THexagonAttributes,
	random: Random,
	root: Instance,
	centerXZ: Vector3
)
	local yawDeg, scale = applyRandomization(attributes, random)
	local yawCFrame = CFrame.fromAxisAngle(Vector3.yAxis, math.rad(yawDeg))

	local bottomHeight = clampPositive(attributes.BottomHeight * scale, 1)
	local topHeight = clampPositive(attributes.TopHeight * scale, 0.5)
	local bottomSizeXZ = clampPositive(attributes.BottomSizeXZ * scale, 1)
	local topScaleXZ = math.clamp(attributes.TopScaleXZ, 0.01, 1)

	local bottomPart = Helpers.createMeshPartFromMeshId(attributes.MeshId, {
		Name = "HexBottom",
		Parent = root,
		Color = attributes.BottomColor,
		CastShadow = true,
		Material = Enum.Material.Slate,
	})

	local topPart = Helpers.createMeshPartFromMeshId(attributes.MeshId, {
		Name = "HexTop",
		Parent = root,
		Color = attributes.TopColor,
		CastShadow = true,
		Material = Enum.Material.LeafyGrass,
		MaterialVariant = "Grass2",
	})

	local targetBottomSize = Vector3.new(bottomSizeXZ, bottomHeight, bottomSizeXZ)
	bottomPart.Size = targetBottomSize

	local targetTopSize = Vector3.new(
		targetBottomSize.X * topScaleXZ,
		topHeight,
		targetBottomSize.Z * topScaleXZ
	)
	topPart.Size = targetTopSize

	local groundY = centerXZ.Y
	local bottomCenter = Vector3.new(centerXZ.X, groundY + targetBottomSize.Y * 0.5, centerXZ.Z)
	local topCenter = Vector3.new(centerXZ.X, groundY + targetBottomSize.Y + targetTopSize.Y * 0.5, centerXZ.Z)

	bottomPart.CFrame = CFrame.new(bottomCenter) * yawCFrame
	topPart.CFrame = CFrame.new(topCenter) * yawCFrame
end

local function createArray(attributes: THexagonAttributes, random: Random, root: Instance)
	local rows = floorAtLeastOne(attributes.ArrayRows)
	local columns = floorAtLeastOne(attributes.ArrayColumns)
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
	local random = Random.new(os.time())

	local root = Helpers.createFolder({
		Name = "HexagonArray",
		Parent = targetContainer,
	})

	createArray(attributes, random, root)
end

local Generator: TGeneratorDefinition<THexagonAttributes> & {
	Attributes: THexagonAttributes,
	OnGenerate: (parameters: TGenerationParams<THexagonAttributes>, targetContainer: Instance) -> (),
	Run: (sourceInstance: Instance, targetContainer: Instance, options: TRunOptions?) -> { [string]: any },
} = {
	Defaults = DEFAULTS,
	Generate = Generate,
	Attributes = DEFAULTS,
	OnGenerate = Generate,
	Run = function(sourceInstance: Instance, targetContainer: Instance, options: TRunOptions?)
		return GeneratorRunner.RunGeneratorModule(script, sourceInstance, targetContainer, options)
	end,
}

return table.freeze(Generator)
