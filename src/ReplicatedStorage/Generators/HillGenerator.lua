--!strict

local GeometryService = game:GetService("GeometryService")

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
}

type TRunOptions = GeneratorRunner.TRunOptions

local DEFAULTS = table.freeze({
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
	AutoScaleWedgeHeight = false,
	UseNorthValues = false,
	EnableCornerCSG = true,

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
})

type THillAttributes = typeof(DEFAULTS)

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

local function applyRandomization(attributes: THillAttributes, random: Random): (number, number)
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

local function createHillBlock(attributes: THillAttributes, random: Random, root: Instance, centerXZ: Vector3)
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
	): WedgePart
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

		local localWedgeCFrame = CFrame.new(localOffset) * CFrame.Angles(0, math.rad(rotationDegreesY), 0)
		wedge.CFrame = centerCFrame * localWedgeCFrame
		return wedge
	end

	local sideDefs = {
		{
			key = "North",
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
			key = "South",
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
			key = "East",
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
			key = "West",
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

	local placedSides: { [string]: WedgePart } = {}

	for _, side in sideDefs do
		if side.enabled then
			local spanScale = side.spanScale
			local depthScale = side.depthScale
			local sideHeight = side.height
			if attributes.UseNorthValues and side.key ~= "North" then
				spanScale = attributes.WedgeNorthSpanScale
				depthScale = attributes.WedgeNorthDepthScale
				sideHeight = attributes.WedgeNorthHeight
			end

			local spanBase = getAxisValue(centerSize, side.spanAxis)
			local depthBase = getAxisValue(centerSize, side.centerDepthAxis)
			local spanSize = clampPositive(spanBase * spanScale, 1)
			local depthSize = clampPositive(depthBase * depthScale, 1)
			local heightBase = sideHeight * scale
			if attributes.AutoScaleWedgeHeight then
				heightBase = centerSize.Y
			end
			local heightSize = clampPositive(heightBase, 1)

			local wedgeSize = Vector3.new(spanSize, heightSize, depthSize)

			local placedWedge = placeSideWedge(
				side.name,
				wedgeSize,
				side.normal,
				side.rotationY,
				side.centerDepthAxis,
				side.wedgeDepthAxis
			)
			placedSides[side.key] = placedWedge
		end
	end

	local function finalizeCornerPart(part: BasePart, cornerName: string): BasePart
		part.Name = cornerName
		part.Color = attributes.WedgeColor
		part.Material = attributes.WedgeMaterial
		if attributes.WedgeMaterialVariant ~= "" then
			part.MaterialVariant = attributes.WedgeMaterialVariant
		else
			part.MaterialVariant = ""
		end
		part.Anchored = true
		part.CanCollide = false
		part.CastShadow = true
		part.Parent = root
		return part
	end

	local function getBaseParts(results: { any }): { BasePart }
		local parts: { BasePart } = {}
		for _, item in results do
			if typeof(item) == "Instance" and item:IsA("BasePart") then
				table.insert(parts, item)
			end
		end
		return parts
	end

	local function cleanupCornerTemporaryParts(parts: { Instance })
		for _, part in parts do
			if part.Parent ~= nil then
				part:Destroy()
			end
		end
	end

	local function getCornerOperandShiftDirection(cornerName: string, sideKey: string): number
		local cornerDirections = {
			HillCornerNE = {
				North = 1,
				East = -1,
			},
			HillCornerNW = {
				North = -1,
				West = 1,
			},
			HillCornerSE = {
				South = -1,
				East = 1,
			},
			HillCornerSW = {
				South = 1,
				West = -1,
			},
		}

		local cornerDirection = cornerDirections[cornerName]
		if cornerDirection == nil then
			return 0
		end

		return cornerDirection[sideKey] or 0
	end

	local function createCornerBaseOperand(cornerName: string, sideKey: string, sourceWedge: WedgePart): WedgePart
		local baseOperand = sourceWedge:Clone()
		baseOperand.Name = cornerName .. "_" .. sideKey .. "_Base"
		baseOperand.Parent = root
		return baseOperand
	end

	local function createCornerExtensionOperand(
		cornerName: string,
		sideKey: string,
		sourceWedge: WedgePart,
		adjacentWedge: WedgePart
	): WedgePart
		local extensionOperand = sourceWedge:Clone()
		extensionOperand.Name = cornerName .. "_" .. sideKey .. "_Extension"
		extensionOperand.Parent = root

		local addedSpan = adjacentWedge.Size.Z
		if addedSpan <= 0 then
			return extensionOperand
		end

		local shiftDirection = getCornerOperandShiftDirection(cornerName, sideKey)
		if shiftDirection == 0 then
			return extensionOperand
		end

		local expandedSpan = extensionOperand.Size.X + addedSpan
		local localShiftX = shiftDirection * addedSpan * 0.5
		extensionOperand.Size = Vector3.new(expandedSpan, extensionOperand.Size.Y, extensionOperand.Size.Z)
		extensionOperand.CFrame *= CFrame.new(localShiftX, 0, 0)
		return extensionOperand
	end

	local function unionCornerOperandPair(
		cornerName: string,
		sideKey: string,
		baseOperand: BasePart,
		extensionOperand: BasePart
	): BasePart?
		local okUnion, unionResult = pcall(function()
			return GeometryService:UnionAsync(baseOperand, { extensionOperand }, nil)
		end)

		if not okUnion or unionResult == nil then
			return nil
		end

		local unionParts = getBaseParts(unionResult)
		if #unionParts == 0 then
			return nil
		end

		local unionSource = unionParts[1]
		local unionTargets = {}
		for index = 2, #unionParts do
			table.insert(unionTargets, unionParts[index])
		end

		if #unionTargets == 0 then
			unionSource.Name = cornerName .. "_" .. sideKey .. "_Composite"
			unionSource.Parent = root
			return unionSource
		end

		local okUnionMerged, unionMergedResult = pcall(function()
			return GeometryService:UnionAsync(unionSource, unionTargets, nil)
		end)

		if not okUnionMerged or unionMergedResult == nil then
			return nil
		end

		local mergedParts = getBaseParts(unionMergedResult)
		if #mergedParts == 0 then
			return nil
		end

		local compositeOperand = mergedParts[1]
		compositeOperand.Name = cornerName .. "_" .. sideKey .. "_Composite"
		compositeOperand.Parent = root
		return compositeOperand
	end

	local function createCornerCompositeOperand(
		cornerName: string,
		sideKey: string,
		sourceWedge: WedgePart,
		adjacentWedge: WedgePart,
		temporaryParts: { Instance }
	): BasePart?
		local baseOperand = createCornerBaseOperand(cornerName, sideKey, sourceWedge)
		local extensionOperand = createCornerExtensionOperand(cornerName, sideKey, sourceWedge, adjacentWedge)
		table.insert(temporaryParts, baseOperand)
		table.insert(temporaryParts, extensionOperand)

		local compositeOperand = unionCornerOperandPair(cornerName, sideKey, baseOperand, extensionOperand)
		if compositeOperand ~= nil then
			table.insert(temporaryParts, compositeOperand)
		end

		return compositeOperand
	end

	local function tryCreateCornerPart(
		cornerName: string,
		firstSideKey: string,
		secondSideKey: string,
		firstWedge: WedgePart,
		secondWedge: WedgePart
	)
		local temporaryParts: { Instance } = {}

		-- Build a composite operand for each participating side
		local firstComposite =
			createCornerCompositeOperand(cornerName, firstSideKey, firstWedge, secondWedge, temporaryParts)
		local secondComposite =
			createCornerCompositeOperand(cornerName, secondSideKey, secondWedge, firstWedge, temporaryParts)

		if firstComposite == nil or secondComposite == nil then
			cleanupCornerTemporaryParts(temporaryParts)
			return nil
		end

		-- Intersect the two side composites to form the corner body
		local okIntersect, intersectResult = pcall(function()
			return GeometryService:IntersectAsync(firstComposite, { secondComposite }, nil)
		end)

		if okIntersect and intersectResult ~= nil then
			local intersectParts = getBaseParts(intersectResult)
			if #intersectParts > 0 then
				local unionSource = intersectParts[1]
				local unionTargets = {}
				for index = 2, #intersectParts do
					table.insert(unionTargets, intersectParts[index])
				end

				if #unionTargets > 0 then
					local okUnionIntersect, unionIntersectResult = pcall(function()
						return GeometryService:UnionAsync(unionSource, unionTargets, nil)
					end)
					if okUnionIntersect and unionIntersectResult ~= nil then
						local unionedParts = getBaseParts(unionIntersectResult)
						if #unionedParts > 0 then
							local finalized = finalizeCornerPart(unionedParts[1], cornerName)
							cleanupCornerTemporaryParts(temporaryParts)
							return finalized
						end
					end
				else
					local finalized = finalizeCornerPart(unionSource, cornerName)
					cleanupCornerTemporaryParts(temporaryParts)
					return finalized
				end
			end
		end

		-- Fallback to a union of the two composites if intersection fails
		local okUnion, unionResult = pcall(function()
			return GeometryService:UnionAsync(firstComposite, { secondComposite }, nil)
		end)

		if okUnion and unionResult ~= nil then
			local unionParts = getBaseParts(unionResult)
			if #unionParts > 0 then
				local finalized = finalizeCornerPart(unionParts[1], cornerName)
				cleanupCornerTemporaryParts(temporaryParts)
				return finalized
			end
		end

		cleanupCornerTemporaryParts(temporaryParts)
		return nil
	end

	if attributes.EnableCornerCSG then
		if placedSides.North ~= nil and placedSides.East ~= nil then
			tryCreateCornerPart("HillCornerNE", "North", "East", placedSides.North, placedSides.East)
		end
		if placedSides.North ~= nil and placedSides.West ~= nil then
			tryCreateCornerPart("HillCornerNW", "North", "West", placedSides.North, placedSides.West)
		end
		if placedSides.South ~= nil and placedSides.East ~= nil then
			tryCreateCornerPart("HillCornerSE", "South", "East", placedSides.South, placedSides.East)
		end
		if placedSides.South ~= nil and placedSides.West ~= nil then
			tryCreateCornerPart("HillCornerSW", "South", "West", placedSides.South, placedSides.West)
		end
	end
end

local function createArray(attributes: THillAttributes, random: Random, root: Instance)
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

local function Generate(parameters: TGenerationParams<THillAttributes>, targetContainer: Instance)
	local attributes = parameters.Attributes
	local random = Random.new(os.time())

	local root = Helpers.createFolder({
		Name = "HillArray",
		Parent = targetContainer,
	})

	createArray(attributes, random, root)
end

local Generator: TGeneratorDefinition<THillAttributes> & {
	Attributes: THillAttributes,
	OnGenerate: (parameters: TGenerationParams<THillAttributes>, targetContainer: Instance) -> (),
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
