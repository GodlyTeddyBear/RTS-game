--!strict

local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local DEFAULT_REFERENCE_NAME = "GeneratorModule"

export type TGenerationParams<T> = {
	Attributes: T,
	Size: Vector3,
	Pause: (self: TGenerationParams<T>) -> (),
}

export type TGeneratorDefinition<T> = {
	Defaults: T,
	Generate: (params: TGenerationParams<T>, targetContainer: Instance) -> (),
}

export type TRunOptions = {
	AttributeOverrides: { [string]: any }?,
	Pause: ((self: any) -> ())?,
	ReferenceName: string?,
	Size: Vector3?,
}

local GeneratorRunner = {}

local function _AssertServer()
	assert(RunService:IsServer(), "[GeneratorRunner] Generator modules can only run on the server")
end

local function _GetGeneratorsFolder(): Folder
	local generatorsFolder = ServerStorage:FindFirstChild("Generators")
	assert(generatorsFolder ~= nil and generatorsFolder:IsA("Folder"), "[GeneratorRunner] ServerStorage.Generators is missing")
	return generatorsFolder
end

local function _ResolveDefaults(rawDefinition: { [string]: any }, generatorModule: ModuleScript): { [string]: any }
	local defaults = rawDefinition.Defaults or rawDefinition.Attributes
	assert(type(defaults) == "table", string.format("[GeneratorRunner] '%s' is missing a Defaults table", generatorModule:GetFullName()))
	return defaults
end

local function _ResolveGenerate(rawDefinition: { [string]: any }, generatorModule: ModuleScript): (params: any, targetContainer: Instance) -> ()
	local generate = rawDefinition.Generate or rawDefinition.OnGenerate
	assert(
		type(generate) == "function",
		string.format("[GeneratorRunner] '%s' is missing a Generate function", generatorModule:GetFullName())
	)
	return generate
end

local function _AreEnumItemsCompatible(expectedValue: EnumItem, candidateValue: EnumItem): boolean
	return expectedValue.EnumType == candidateValue.EnumType
end

local function _ValidateAttributeType(
	generatorName: string,
	attributeName: string,
	expectedValue: any,
	candidateValue: any
)
	local expectedType = typeof(expectedValue)
	local candidateType = typeof(candidateValue)

	assert(
		expectedType == candidateType,
		string.format(
			"[GeneratorRunner] Attribute '%s' on generator '%s' expected '%s' but received '%s'",
			attributeName,
			generatorName,
			expectedType,
			candidateType
		)
	)

	if expectedType == "EnumItem" then
		assert(
			_AreEnumItemsCompatible(expectedValue :: EnumItem, candidateValue :: EnumItem),
			string.format(
				"[GeneratorRunner] Attribute '%s' on generator '%s' expected enum type '%s' but received '%s'",
				attributeName,
				generatorName,
				tostring((expectedValue :: EnumItem).EnumType),
				tostring((candidateValue :: EnumItem).EnumType)
			)
		)
	end
end

local function _ApplyAttributes(
	targetAttributes: { [string]: any },
	defaults: { [string]: any },
	attributes: { [string]: any },
	generatorName: string
)
	for attributeName, attributeValue in attributes do
		local defaultValue = defaults[attributeName]
		if defaultValue ~= nil then
			_ValidateAttributeType(generatorName, attributeName, defaultValue, attributeValue)
			targetAttributes[attributeName] = attributeValue
		end
	end
end

local function _ResolveSize(sourceInstance: Instance, explicitSize: Vector3?): Vector3
	if explicitSize ~= nil then
		return explicitSize
	end

	if sourceInstance:IsA("Model") then
		return sourceInstance:GetExtentsSize()
	end

	if sourceInstance:IsA("BasePart") then
		return sourceInstance.Size
	end

	return Vector3.zero
end

local function _Pause(_self: any) end

function GeneratorRunner.RequireGeneratorModule(generatorModule: ModuleScript): TGeneratorDefinition<any>
	_AssertServer()

	local generatorsFolder = _GetGeneratorsFolder()
	assert(
		generatorModule:IsDescendantOf(generatorsFolder),
		string.format(
			"[GeneratorRunner] '%s' must be a descendant of '%s'",
			generatorModule:GetFullName(),
			generatorsFolder:GetFullName()
		)
	)

	local rawDefinition = require(generatorModule)
	assert(type(rawDefinition) == "table", string.format("[GeneratorRunner] '%s' must return a table", generatorModule:GetFullName()))

	return {
		Defaults = _ResolveDefaults(rawDefinition, generatorModule),
		Generate = _ResolveGenerate(rawDefinition, generatorModule),
	}
end

function GeneratorRunner.ResolveGeneratorModule(sourceInstance: Instance, referenceName: string?): ModuleScript
	_AssertServer()

	local resolvedReferenceName = referenceName or DEFAULT_REFERENCE_NAME
	local referenceValue = sourceInstance:FindFirstChild(resolvedReferenceName)
	assert(
		referenceValue ~= nil,
		string.format(
			"[GeneratorRunner] '%s' is missing the '%s' reference object",
			sourceInstance:GetFullName(),
			resolvedReferenceName
		)
	)
	assert(
		referenceValue:IsA("ObjectValue"),
		string.format(
			"[GeneratorRunner] '%s.%s' must be an ObjectValue",
			sourceInstance:GetFullName(),
			resolvedReferenceName
		)
	)

	local generatorModule = referenceValue.Value
	assert(
		generatorModule ~= nil,
		string.format(
			"[GeneratorRunner] '%s.%s' does not point at a generator module",
			sourceInstance:GetFullName(),
			resolvedReferenceName
		)
	)
	assert(
		generatorModule:IsA("ModuleScript"),
		string.format(
			"[GeneratorRunner] '%s.%s' must reference a ModuleScript",
			sourceInstance:GetFullName(),
			resolvedReferenceName
		)
	)

	local generatorsFolder = _GetGeneratorsFolder()
	assert(
		generatorModule:IsDescendantOf(generatorsFolder),
		string.format(
			"[GeneratorRunner] '%s.%s' must point inside '%s'",
			sourceInstance:GetFullName(),
			resolvedReferenceName,
			generatorsFolder:GetFullName()
		)
	)

	return generatorModule
end

function GeneratorRunner.BuildAttributes(sourceInstance: Instance, generatorModule: ModuleScript, attributeOverrides: { [string]: any }?): { [string]: any }
	local definition = GeneratorRunner.RequireGeneratorModule(generatorModule)
	local mergedAttributes = table.clone(definition.Defaults)

	_ApplyAttributes(mergedAttributes, definition.Defaults, sourceInstance:GetAttributes(), generatorModule.Name)

	if attributeOverrides ~= nil then
		_ApplyAttributes(mergedAttributes, definition.Defaults, attributeOverrides, generatorModule.Name)
	end

	return mergedAttributes
end

function GeneratorRunner.RunGeneratorModule(
	generatorModule: ModuleScript,
	sourceInstance: Instance,
	targetContainer: Instance,
	options: TRunOptions?
): { [string]: any }
	local definition = GeneratorRunner.RequireGeneratorModule(generatorModule)
	local mergedAttributes = GeneratorRunner.BuildAttributes(sourceInstance, generatorModule, options and options.AttributeOverrides or nil)
	local size = _ResolveSize(sourceInstance, options and options.Size or nil)
	local pause = options and options.Pause or _Pause

	definition.Generate({
		Attributes = mergedAttributes,
		Size = size,
		Pause = pause,
	}, targetContainer)

	return mergedAttributes
end

function GeneratorRunner.RunProceduralModel(
	sourceInstance: Instance,
	targetContainer: Instance,
	options: TRunOptions?
): { [string]: any }
	local generatorModule = GeneratorRunner.ResolveGeneratorModule(
		sourceInstance,
		options and options.ReferenceName or nil
	)

	return GeneratorRunner.RunGeneratorModule(generatorModule, sourceInstance, targetContainer, options)
end

return GeneratorRunner
