--!strict

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

type TRunOptions = {
	AttributeOverrides: { [string]: any }?,
	Pause: ((self: any) -> ())?,
	ReferenceName: string?,
	Size: Vector3?,
}

type TTrimAxisMode = "TrimEastWest" | "TrimNorthSouth"
type TSideKey = "North" | "South" | "East" | "West"
type TLocalAxis = "X" | "Z"

type TWallAttributes = {
	RandomSeed: number,
	UseNorth: boolean,
	UseSouth: boolean,
	UseEast: boolean,
	UseWest: boolean,
	WallHeight: number,
	WallThickness: number,
	WallYOffset: number,
	WallColor: Color3,
	WallMaterial: Enum.Material,
	WallMaterialVariant: string,
	CornerTrimMode: string,
}

type TSideTrimState = {
	NegativeTrim: number,
	PositiveTrim: number,
}

type TOwnerBounds = {
	CFrame: CFrame,
	Size: Vector3,
}

type TWallSideDefinition = {
	Key: TSideKey,
	Name: string,
	Enabled: boolean,
	LocalAxis: TLocalAxis,
	BaseSpan: number,
	Thickness: number,
	LocalPosition: Vector3,
}

local WALL_ROOT_NAME = "WallPerimeter"
local MIN_WALL_SPAN = 0.05
local MIN_WALL_SIZE = 0.05
local DEFAULT_TRIM_MODE: TTrimAxisMode = "TrimEastWest"

local DEFAULTS: TWallAttributes = table.freeze({
	RandomSeed = 12345,
	UseNorth = true,
	UseSouth = true,
	UseEast = true,
	UseWest = true,
	WallHeight = 12,
	WallThickness = 2,
	WallYOffset = 0,
	WallColor = Color3.fromRGB(163, 162, 165),
	WallMaterial = Enum.Material.Concrete,
	WallMaterialVariant = "",
	CornerTrimMode = DEFAULT_TRIM_MODE,
})

local function _AssignProperties(instance: Instance, properties: { [string]: any }?): Instance
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

local function _CreateInstance(className: string, properties: { [string]: any }?): Instance
	return _AssignProperties(Instance.new(className), properties)
end

local function _CreateFolder(properties: { [string]: any }?): Folder
	return _CreateInstance("Folder", properties) :: Folder
end

local function _CreatePart(properties: { [string]: any }?): Part
	local part = _CreateInstance("Part", {
		Anchored = true,
		CanCollide = true,
		TopSurface = Enum.SurfaceType.Smooth,
		BottomSurface = Enum.SurfaceType.Smooth,
	}) :: Part

	return _AssignProperties(part, properties) :: Part
end

local function _ClampPositive(value: number, fallback: number): number
	if value <= 0 then
		return fallback
	end

	return value
end

local function _DestroyExistingWallRoots(targetContainer: Instance)
	for _, child in ipairs(targetContainer:GetChildren()) do
		if child.Name == WALL_ROOT_NAME then
			child:Destroy()
		end
	end
end

local function _ResolveOwnerBounds(targetContainer: Instance, fallbackSize: Vector3): TOwnerBounds
	local ownerInstance = targetContainer.Parent
	if ownerInstance ~= nil then
		if ownerInstance:IsA("BasePart") then
			return {
				CFrame = ownerInstance.CFrame,
				Size = ownerInstance.Size,
			}
		end

		if ownerInstance:IsA("Model") then
			local boundsCFrame, boundsSize = ownerInstance:GetBoundingBox()
			return {
				CFrame = boundsCFrame,
				Size = boundsSize,
			}
		end
	end

	return {
		CFrame = CFrame.new(),
		Size = fallbackSize,
	}
end

local function _ResetPivot(object: Model)
	local centerCFrame = object:GetBoundingBox()
	object.WorldPivot = centerCFrame
end

local function _ResolveTrimMode(trimModeValue: string): TTrimAxisMode
	if trimModeValue == "TrimNorthSouth" then
		return "TrimNorthSouth"
	end

	return DEFAULT_TRIM_MODE
end

local function _ResolveThickness(attributes: TWallAttributes, ownerSize: Vector3): number
	local smallestHorizontalDimension = math.max(math.min(ownerSize.X, ownerSize.Z), MIN_WALL_SIZE)
	return math.clamp(attributes.WallThickness, MIN_WALL_SIZE, smallestHorizontalDimension)
end

local function _BuildInitialTrimStates(): { [TSideKey]: TSideTrimState }
	return {
		North = {
			NegativeTrim = 0,
			PositiveTrim = 0,
		},
		South = {
			NegativeTrim = 0,
			PositiveTrim = 0,
		},
		East = {
			NegativeTrim = 0,
			PositiveTrim = 0,
		},
		West = {
			NegativeTrim = 0,
			PositiveTrim = 0,
		},
	}
end

local function _ApplyCornerTrim(
	trimStates: { [TSideKey]: TSideTrimState },
	trimMode: TTrimAxisMode,
	cornerName: string
)
	if trimMode == "TrimEastWest" then
		if cornerName == "NE" then
			trimStates.East.NegativeTrim += 1
			return
		end

		if cornerName == "NW" then
			trimStates.West.NegativeTrim += 1
			return
		end

		if cornerName == "SE" then
			trimStates.East.PositiveTrim += 1
			return
		end

		if cornerName == "SW" then
			trimStates.West.PositiveTrim += 1
		end

		return
	end

	if cornerName == "NE" then
		trimStates.North.PositiveTrim += 1
		return
	end

	if cornerName == "NW" then
		trimStates.North.NegativeTrim += 1
		return
	end

	if cornerName == "SE" then
		trimStates.South.PositiveTrim += 1
		return
	end

	if cornerName == "SW" then
		trimStates.South.NegativeTrim += 1
	end
end

local function _BuildTrimStates(attributes: TWallAttributes, wallThickness: number): { [TSideKey]: TSideTrimState }
	local trimMode = _ResolveTrimMode(attributes.CornerTrimMode)
	local trimStates = _BuildInitialTrimStates()

	if attributes.UseNorth and attributes.UseEast then
		_ApplyCornerTrim(trimStates, trimMode, "NE")
	end

	if attributes.UseNorth and attributes.UseWest then
		_ApplyCornerTrim(trimStates, trimMode, "NW")
	end

	if attributes.UseSouth and attributes.UseEast then
		_ApplyCornerTrim(trimStates, trimMode, "SE")
	end

	if attributes.UseSouth and attributes.UseWest then
		_ApplyCornerTrim(trimStates, trimMode, "SW")
	end

	for _, trimState in trimStates do
		trimState.NegativeTrim *= wallThickness
		trimState.PositiveTrim *= wallThickness
	end

	return trimStates
end

local function _ResolveSpanAndShift(baseSpan: number, negativeTrim: number, positiveTrim: number): (number, number)
	local positiveBaseSpan = math.max(baseSpan, MIN_WALL_SPAN)
	local maxTotalTrim = math.max(positiveBaseSpan - MIN_WALL_SPAN, 0)
	local totalTrim = negativeTrim + positiveTrim

	if totalTrim <= maxTotalTrim or totalTrim <= 0 then
		return positiveBaseSpan - totalTrim, (negativeTrim - positiveTrim) * 0.5
	end

	local trimScale = maxTotalTrim / totalTrim
	local resolvedNegativeTrim = negativeTrim * trimScale
	local resolvedPositiveTrim = positiveTrim * trimScale
	local resolvedSpan = positiveBaseSpan - resolvedNegativeTrim - resolvedPositiveTrim
	local resolvedShift = (resolvedNegativeTrim - resolvedPositiveTrim) * 0.5

	return resolvedSpan, resolvedShift
end

local function _BuildWallCFrame(ownerCFrame: CFrame, baseLocalPosition: Vector3, localAxis: TLocalAxis, localShift: number): CFrame
	if localAxis == "X" then
		return ownerCFrame * CFrame.new(baseLocalPosition + Vector3.new(localShift, 0, 0))
	end

	return ownerCFrame * CFrame.new(baseLocalPosition + Vector3.new(0, 0, localShift))
end

local function _BuildWallSize(sideDefinition: TWallSideDefinition, span: number, wallHeight: number): Vector3
	if sideDefinition.LocalAxis == "X" then
		return Vector3.new(span, wallHeight, sideDefinition.Thickness)
	end

	return Vector3.new(sideDefinition.Thickness, wallHeight, span)
end

local function _BuildSideDefinitions(attributes: TWallAttributes, ownerSize: Vector3, wallHeight: number, wallThickness: number): { TWallSideDefinition }
	local halfWidth = ownerSize.X * 0.5
	local halfDepth = ownerSize.Z * 0.5
	local halfHeight = ownerSize.Y * 0.5
	local wallCenterY = halfHeight + attributes.WallYOffset + wallHeight * 0.5
	local wallInsetX = math.max(halfWidth - wallThickness * 0.5, 0)
	local wallInsetZ = math.max(halfDepth - wallThickness * 0.5, 0)

	return {
		{
			Key = "North",
			Name = "WallNorth",
			Enabled = attributes.UseNorth,
			LocalAxis = "X",
			BaseSpan = ownerSize.X,
			Thickness = wallThickness,
			LocalPosition = Vector3.new(0, wallCenterY, -wallInsetZ),
		},
		{
			Key = "South",
			Name = "WallSouth",
			Enabled = attributes.UseSouth,
			LocalAxis = "X",
			BaseSpan = ownerSize.X,
			Thickness = wallThickness,
			LocalPosition = Vector3.new(0, wallCenterY, wallInsetZ),
		},
		{
			Key = "East",
			Name = "WallEast",
			Enabled = attributes.UseEast,
			LocalAxis = "Z",
			BaseSpan = ownerSize.Z,
			Thickness = wallThickness,
			LocalPosition = Vector3.new(wallInsetX, wallCenterY, 0),
		},
		{
			Key = "West",
			Name = "WallWest",
			Enabled = attributes.UseWest,
			LocalAxis = "Z",
			BaseSpan = ownerSize.Z,
			Thickness = wallThickness,
			LocalPosition = Vector3.new(-wallInsetX, wallCenterY, 0),
		},
	}
end

local function _CreateWallPart(
	root: Instance,
	attributes: TWallAttributes,
	ownerCFrame: CFrame,
	sideDefinition: TWallSideDefinition,
	trimState: TSideTrimState,
	wallHeight: number
)
	local span, localShift =
		_ResolveSpanAndShift(sideDefinition.BaseSpan, trimState.NegativeTrim, trimState.PositiveTrim)
	local wallSize = _BuildWallSize(sideDefinition, span, wallHeight)
	local wallCFrame = _BuildWallCFrame(ownerCFrame, sideDefinition.LocalPosition, sideDefinition.LocalAxis, localShift)

	local wallPart = _CreatePart({
		Name = sideDefinition.Name,
		Parent = root,
		CFrame = wallCFrame,
		Size = wallSize,
		Color = attributes.WallColor,
		Material = attributes.WallMaterial,
		CastShadow = true,
	})

	if attributes.WallMaterialVariant ~= "" then
		wallPart.MaterialVariant = attributes.WallMaterialVariant
	end
end

local function Generate(parameters: TGenerationParams<TWallAttributes>, targetContainer: Instance)
	local attributes = parameters.Attributes
	local _random = Random.new(attributes.RandomSeed)
	local ownerInstance = targetContainer.Parent
	local ownerBoundsBefore: TOwnerBounds? = nil
	if ownerInstance ~= nil and ownerInstance:IsA("Model") then
		local ownerCFrameBefore, ownerSizeBefore = ownerInstance:GetBoundingBox()
		ownerBoundsBefore = {
			CFrame = ownerCFrameBefore,
			Size = ownerSizeBefore,
		}
	end

	local ownerBounds = _ResolveOwnerBounds(targetContainer, parameters.Size)
	local ownerSize = ownerBounds.Size
	local ownerCFrame = ownerBounds.CFrame
	local wallHeight = _ClampPositive(attributes.WallHeight, 1)
	local wallThickness = _ResolveThickness(attributes, ownerSize)
	local trimStates = _BuildTrimStates(attributes, wallThickness)
	local sideDefinitions = _BuildSideDefinitions(attributes, ownerSize, wallHeight, wallThickness)

	-- Replace the prior generated root so reruns do not stack duplicate walls.
	_DestroyExistingWallRoots(targetContainer)

	local root = _CreateFolder({
		Name = WALL_ROOT_NAME,
		Parent = targetContainer,
	})

	-- Build only the walls requested by the source attributes.
	for _, sideDefinition in ipairs(sideDefinitions) do
		if sideDefinition.Enabled then
			_CreateWallPart(root, attributes, ownerCFrame, sideDefinition, trimStates[sideDefinition.Key], wallHeight)
		end
	end

	if ownerInstance ~= nil and ownerInstance:IsA("Model") and ownerBoundsBefore ~= nil then
		local ownerCFrameAfter, ownerSizeAfter = ownerInstance:GetBoundingBox()
		if ownerCFrameAfter ~= ownerBoundsBefore.CFrame or ownerSizeAfter ~= ownerBoundsBefore.Size then
			_ResetPivot(ownerInstance)
		end
	end
end

local Generator: TGeneratorDefinition<TWallAttributes> & {
	Attributes: TWallAttributes,
	OnGenerate: (parameters: TGenerationParams<TWallAttributes>, targetContainer: Instance) -> (),
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
