--!strict

type GenerationFunctionParams<Attributes> = {
	Attributes: Attributes,
	Size: Vector3,
	Pause: (self: GenerationFunctionParams<Attributes>) -> (),
}

type GeneratorModuleDefinition<Attributes> = {
	Attributes: Attributes,
	OnGenerate: (parameters: GenerationFunctionParams<Attributes>, targetContainer: GeneratedFolder) -> (),
}

type GeneratorHelpers = {
	assignProperties: (instance: Instance, properties: { [string]: any }?) -> Instance,
	createInstance: (className: string, properties: { [string]: any }?) -> Instance,
	createFolder: (properties: { [string]: any }?) -> Folder,
	createModle: (properties: { [string]: any }?) -> Model,
	createPart: (properties: { [string]: any }?) -> Part,
}

local defaultAttributes = {
	RandomSeed = 12345,

	CenterColor = Color3.fromRGB(110, 165, 90),
	CenterMaterial = Enum.Material.LeafyGrass,
	CenterMaterialVariant = "Grass2",
	CenterSizeX = 8,
	CenterSizeY = 4,
	CenterSizeZ = 8,

	WedgeColor = Color3.fromRGB(124, 92, 70),
	WedgeMaterial = Enum.Material.Slate,
	WedgeMaterialVariant = "",

	UseNorth = true,
	UseSouth = true,
	UseEast = true,
	UseWest = true,

	WedgeNorthHeight = 4,
	WedgeNorthSpanScale = 1,
	WedgeNorthDepthScale = 0.5,

	WedgeSouthHeight = 4,
	WedgeSouthSpanScale = 1,
	WedgeSouthDepthScale = 0.5,

	WedgeEastHeight = 4,
	WedgeEastSpanScale = 1,
	WedgeEastDepthScale = 0.5,

	WedgeWestHeight = 4,
	WedgeWestSpanScale = 1,
	WedgeWestDepthScale = 0.5,

	ArrayRows = 1,
	ArrayColumns = 1,
	ArraySpacingX = 12,
	ArraySpacingZ = 12,
	StaggerRowsEnabled = false,
	StaggerOffsetX = 6,
	StaggerColumnsEnabled = false,
	StaggerOffsetZ = 6,

	RandomizeEnabled = false,
	RandomYawMinDeg = 0,
	RandomYawMaxDeg = 360,
	RandomScaleMin = 0.9,
	RandomScaleMax = 1.1,
}

type HillAttributes = typeof(defaultAttributes)

local Helpers: GeneratorHelpers = {}

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
		TopSurface = Enum.SurfaceType.Smooth,
		BottomSurface = Enum.SurfaceType.Smooth,
	}) :: Part
	return Helpers.assignProperties(part, properties) :: Part
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

local function getScaledSize(x: number, y: number, z: number, scale: number): Vector3
	return Vector3.new(clampPositive(x * scale, 1), clampPositive(y * scale, 1), clampPositive(z * scale, 1))
end

local function applyRandomization(attributes: HillAttributes, random: Random): (number, number)
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

local function createWedge(
	root: Instance,
	name: string,
	size: Vector3,
	color: Color3,
	material: Enum.Material,
	materialVariant: string
): WedgePart
	local wedge = Helpers.createInstance("WedgePart", {
		Name = name,
		Parent = root,
		Anchored = true,
		CanCollide = false,
		TopSurface = Enum.SurfaceType.Smooth,
		BottomSurface = Enum.SurfaceType.Smooth,
		Color = color,
		Material = material,
		Size = size,
	}) :: WedgePart

	if materialVariant ~= "" then
		wedge.MaterialVariant = materialVariant
	end

	return wedge
end

local function createHillBlock(attributes: HillAttributes, random: Random, root: Instance, centerXZ: Vector3)
	local yawDeg, scale = applyRandomization(attributes, random)
	local yaw = CFrame.fromAxisAngle(Vector3.yAxis, math.rad(yawDeg))

	local centerSize = getScaledSize(attributes.CenterSizeX, attributes.CenterSizeY, attributes.CenterSizeZ, scale)

	local centerPart = Helpers.createPart({
		Name = "HillCenter",
		Parent = root,
		Color = attributes.CenterColor,
		Material = attributes.CenterMaterial,
		MaterialVariant = attributes.CenterMaterialVariant,
		Size = centerSize,
		CastShadow = true,
	})

	local groundY = centerXZ.Y
	local centerPosition = Vector3.new(centerXZ.X, groundY + centerSize.Y * 0.5, centerXZ.Z)
	local centerCFrame = CFrame.new(centerPosition) * yaw
	centerPart.CFrame = centerCFrame

	local function getAxisValue(size: Vector3, axis: "X" | "Z"): number
		if axis == "X" then
			return size.X
		end
		return size.Z
	end

	local function placeSideWedge(
		sideName: string,
		wedgeSize: Vector3,
		normal: Vector3,
		rotationDegreesY: number,
		centerDepthAxis: "X" | "Z",
		wedgeDepthAxis: "X" | "Z"
	)
		local centerDepth = getAxisValue(centerSize, centerDepthAxis)
		local wedgeDepth = getAxisValue(wedgeSize, wedgeDepthAxis)
		local yOffset = (wedgeSize.Y - centerSize.Y) * 0.5
		local localOffset = normal * ((centerDepth + wedgeDepth) * 0.5) + Vector3.new(0, yOffset, 0)
		local wedge = createWedge(
			root,
			sideName,
			wedgeSize,
			attributes.WedgeColor,
			attributes.WedgeMaterial,
			attributes.WedgeMaterialVariant
		)

		-- Build wedge transform fully in local space, then compose with center transform once.
		local localWedgeCFrame = CFrame.new(localOffset) * CFrame.Angles(0, math.rad(rotationDegreesY), 0)
		wedge.CFrame = centerCFrame * localWedgeCFrame
	end

	local sideDefs = {
		{
			enabled = attributes.UseNorth,
			name = "HillNorthWedge",
			height = attributes.WedgeNorthHeight,
			spanScale = attributes.WedgeNorthSpanScale,
			depthScale = attributes.WedgeNorthDepthScale,
			spanAxis = "X",
			centerDepthAxis = "Z",
			wedgeDepthAxis = "Z",
			normal = Vector3.new(0, 0, -1),
			rotationY = 0,
		},
		{
			enabled = attributes.UseSouth,
			name = "HillSouthWedge",
			height = attributes.WedgeSouthHeight,
			spanScale = attributes.WedgeSouthSpanScale,
			depthScale = attributes.WedgeSouthDepthScale,
			spanAxis = "X",
			centerDepthAxis = "Z",
			wedgeDepthAxis = "Z",
			normal = Vector3.new(0, 0, 1),
			rotationY = 180,
		},
		{
			enabled = attributes.UseEast,
			name = "HillEastWedge",
			height = attributes.WedgeEastHeight,
			spanScale = attributes.WedgeEastSpanScale,
			depthScale = attributes.WedgeEastDepthScale,
			spanAxis = "Z",
			centerDepthAxis = "X",
			wedgeDepthAxis = "Z",
			normal = Vector3.new(1, 0, 0),
			rotationY = -90,
		},
		{
			enabled = attributes.UseWest,
			name = "HillWestWedge",
			height = attributes.WedgeWestHeight,
			spanScale = attributes.WedgeWestSpanScale,
			depthScale = attributes.WedgeWestDepthScale,
			spanAxis = "Z",
			centerDepthAxis = "X",
			wedgeDepthAxis = "Z",
			normal = Vector3.new(-1, 0, 0),
			rotationY = 90,
		},
	}

	for _, side in sideDefs do
		if side.enabled then
			local spanBase = getAxisValue(centerSize, side.spanAxis)
			local depthBase = getAxisValue(centerSize, side.centerDepthAxis)
			local spanSize = clampPositive(spanBase * side.spanScale, 1)
			local depthSize = clampPositive(depthBase * side.depthScale, 1)
			local heightSize = clampPositive(side.height * scale, 1)

			local wedgeSize = Vector3.new(spanSize, heightSize, depthSize)

			placeSideWedge(
				side.name,
				wedgeSize,
				side.normal,
				side.rotationY,
				side.centerDepthAxis,
				side.wedgeDepthAxis
			)
		end
	end
end

local function createArray(attributes: HillAttributes, random: Random, root: Instance)
	local rows = floorAtLeastOne(attributes.ArrayRows)
	local columns = floorAtLeastOne(attributes.ArrayColumns)
	local spacingX = attributes.ArraySpacingX
	local spacingZ = attributes.ArraySpacingZ
	local staggerRowsEnabled = attributes.StaggerRowsEnabled
	local staggerOffsetX = attributes.StaggerOffsetX
	local staggerColumnsEnabled = attributes.StaggerColumnsEnabled
	local staggerOffsetZ = attributes.StaggerOffsetZ

	local halfWidth = (columns - 1) * spacingX * 0.5
	local halfDepth = (rows - 1) * spacingZ * 0.5

	for row = 0, rows - 1 do
		local rowOffsetX = 0
		if staggerRowsEnabled and (row % 2 == 1) then
			rowOffsetX = staggerOffsetX
		end

		for col = 0, columns - 1 do
			local colOffsetZ = 0
			if staggerColumnsEnabled and (col % 2 == 1) then
				colOffsetZ = staggerOffsetZ
			end

			local x = col * spacingX - halfWidth + rowOffsetX
			local z = row * spacingZ - halfDepth + colOffsetZ
			createHillBlock(attributes, random, root, Vector3.new(x, 0, z))
		end
	end
end

local function Generate(parameters: GenerationFunctionParams<HillAttributes>, targetContainer: GeneratedFolder)
	local attributes = parameters.Attributes
	local random = Random.new(os.time())

	local root = Helpers.createFolder({
		Name = "HillArray",
		Parent = targetContainer,
	})

	createArray(attributes, random, root)
end

local Generator: GeneratorModuleDefinition<HillAttributes> = {
	Attributes = defaultAttributes,
	OnGenerate = function(parameters, targetContainer)
		Generate(parameters, targetContainer)
	end,
}

return Generator
