--!strict

local InsertService = game:GetService("InsertService")

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
	createMeshPartFromMeshId: (
		meshId: string,
		properties: { [string]: any }?,
		collisionFidelity: Enum.CollisionFidelity?,
		renderFidelity: Enum.RenderFidelity?
	) -> MeshPart,
}

local defaultAttributes = {
	RandomSeed = 12345,
}

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

local function Generate(
	parameters: GenerationFunctionParams<typeof(defaultAttributes)>,
	targetContainer: GeneratedFolder
)
	local _random = Random.new(parameters.Attributes.RandomSeed)

	Helpers.createPart({
		Name = "Bounds",
		Parent = targetContainer,
		Transparency = 1,
		Size = parameters.Size,
	})
end

local Generator: GeneratorModuleDefinition<typeof(defaultAttributes)> = {
	Attributes = defaultAttributes,
	OnGenerate = function(parameters, targetContainer)
		Generate(parameters, targetContainer)
	end,
}

return Generator
