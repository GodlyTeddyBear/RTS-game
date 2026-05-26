--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JECS = require(ReplicatedStorage.Packages.JECS)
local Result = require(ReplicatedStorage.Utilities.Result)

local Errors = require(script.Parent.Parent.Parent.Errors)

type TComponentSpec = {
	ECSName: string,
	Authority: "AUTHORITATIVE" | "DERIVED",
	Default: any?,
}

type TTagSpec = {}

type TArchetypeSpec = {
	Extends: string?,
	Components: { [string]: any }?,
	Tags: { [string]: boolean }?,
}

type TFeatureSchema = {
	FeatureName: string,
	Components: { [string]: TComponentSpec },
	Tags: { [string]: TTagSpec }?,
	Archetypes: { [string]: TArchetypeSpec }?,
}

local CORE_FEATURE_NAME = "Entity"
local METADATA_COMPONENT_SPECS = {
	FeatureName = {
		ECSName = "Entity.FeatureName",
		Key = "FeatureName",
	},
	ArchetypeName = {
		ECSName = "Entity.ArchetypeName",
		Key = "ArchetypeName",
	},
}

local function _DeepClone(value: any): any
	if type(value) ~= "table" then
		return value
	end

	local clone = {}
	for key, nestedValue in pairs(value) do
		clone[key] = _DeepClone(nestedValue)
	end
	return clone
end

local function _FreezeMap(source: { [string]: any }): { [string]: any }
	return table.freeze(table.clone(source))
end

local function _BuildAmbiguousKeyError(key: string, kind: string, matches: { string })
	table.sort(matches)
	return Result.Err("AmbiguousEntityKey", Errors.AMBIGUOUS_ENTITY_KEY, {
		Key = key,
		Kind = kind,
		Matches = matches,
	})
end

local EntitySchemaRegistry = {}
EntitySchemaRegistry.__index = EntitySchemaRegistry

function EntitySchemaRegistry.new()
	local self = setmetatable({}, EntitySchemaRegistry)
	self._world = nil
	self._allComponents = {
		ChildOf = JECS.ChildOf,
	}
	self._componentMetadataById = {}
	self._compiledSchemasByFeature = {}
	self._compiledArchetypesByName = {}
	self._ecsNames = {
		ChildOf = true,
	}
	self._isCompiling = false
	self._isCompiled = false
	self._isRegistrationClosed = false
	self._runtimeMetadataComponents = nil
	return self
end

function EntitySchemaRegistry:Init(registry: any, _name: string)
	self._world = registry:Get("World")
	assert(self._world ~= nil, "EntitySchemaRegistry requires World during Init")
	self:_RegisterRuntimeMetadataComponents()
end

function EntitySchemaRegistry:GetComponents()
	return self._allComponents
end

function EntitySchemaRegistry:GetRuntimeMetadataComponents()
	return self._runtimeMetadataComponents
end

function EntitySchemaRegistry:GetCoreFeatureName(): string
	return CORE_FEATURE_NAME
end

function EntitySchemaRegistry:GetComponentMetadataById(componentId: any)
	return self._componentMetadataById[componentId]
end

function EntitySchemaRegistry:HasFeature(featureName: string): boolean
	return self._compiledSchemasByFeature[featureName] ~= nil
end

function EntitySchemaRegistry:GetCompiledSchema(featureName: string)
	return self._compiledSchemasByFeature[featureName]
end

function EntitySchemaRegistry:GetCompiledSchemas()
	return self._compiledSchemasByFeature
end

function EntitySchemaRegistry:GetCompiledArchetype(archetypeName: string)
	return self._compiledArchetypesByName[archetypeName]
end

function EntitySchemaRegistry:GetCoreCompiledSchema()
	return self._compiledSchemasByFeature[CORE_FEATURE_NAME]
end

function EntitySchemaRegistry:GetFeatureComponents(featureName: string): Result.Result<any>
	local compiledSchema = self._compiledSchemasByFeature[featureName]
	if compiledSchema == nil then
		return Result.Err("UnknownFeature", Errors.UNKNOWN_FEATURE, {
			FeatureName = featureName,
		})
	end

	return Result.Ok(compiledSchema.Components)
end

function EntitySchemaRegistry:GetFeatureComponentId(featureName: string, key: string): Result.Result<any>
	local compiledSchema = self._compiledSchemasByFeature[featureName]
	if compiledSchema == nil then
		return Result.Err("UnknownFeature", Errors.UNKNOWN_FEATURE, {
			FeatureName = featureName,
			Key = key,
		})
	end

	local componentId = compiledSchema.Components[key]
	if componentId == nil then
		return Result.Err("UnknownComponent", Errors.UNKNOWN_COMPONENT, {
			FeatureName = featureName,
			Key = key,
		})
	end

	return Result.Ok(componentId)
end

function EntitySchemaRegistry:GetFeatureTagId(featureName: string, key: string): Result.Result<any>
	local compiledSchema = self._compiledSchemasByFeature[featureName]
	if compiledSchema == nil then
		return Result.Err("UnknownFeature", Errors.UNKNOWN_FEATURE, {
			FeatureName = featureName,
			Key = key,
		})
	end

	local tagId = compiledSchema.Tags[key]
	if tagId == nil then
		return Result.Err("UnknownTag", Errors.UNKNOWN_TAG, {
			FeatureName = featureName,
			Key = key,
		})
	end

	return Result.Ok(tagId)
end

function EntitySchemaRegistry:GetCoreComponentId(key: string): Result.Result<any>
	return self:GetFeatureComponentId(CORE_FEATURE_NAME, key)
end

function EntitySchemaRegistry:GetCoreTagId(key: string): Result.Result<any>
	return self:GetFeatureTagId(CORE_FEATURE_NAME, key)
end

function EntitySchemaRegistry:GetCoreArchetype(name: string): Result.Result<any>
	local fullName = if string.find(name, ".", 1, true) ~= nil then name else (CORE_FEATURE_NAME .. "." .. name)
	local compiledArchetype = self._compiledArchetypesByName[fullName]
	if compiledArchetype == nil then
		return Result.Err("UnknownArchetype", Errors.UNKNOWN_ARCHETYPE, {
			ArchetypeName = fullName,
		})
	end

	return Result.Ok(compiledArchetype)
end

function EntitySchemaRegistry:ResolveComponentId(key: string, featureName: string?): Result.Result<any>
	if featureName ~= nil then
		return self:GetFeatureComponentId(featureName, key)
	end

	local coreResult = self:GetCoreComponentId(key)
	if coreResult.success then
		return coreResult
	end

	local matches = {}
	local resolvedComponentId = nil
	for candidateFeatureName, compiledSchema in pairs(self._compiledSchemasByFeature) do
		local componentId = compiledSchema.Components[key]
		if componentId ~= nil then
			table.insert(matches, candidateFeatureName)
			resolvedComponentId = componentId
		end
	end

	if #matches == 1 and resolvedComponentId ~= nil then
		return Result.Ok(resolvedComponentId)
	end
	if #matches > 1 then
		return _BuildAmbiguousKeyError(key, "Component", matches)
	end

	return Result.Err("UnknownComponent", Errors.UNKNOWN_COMPONENT, {
		Key = key,
	})
end

function EntitySchemaRegistry:ResolveTagId(key: string, featureName: string?): Result.Result<any>
	if featureName ~= nil then
		return self:GetFeatureTagId(featureName, key)
	end

	local coreResult = self:GetCoreTagId(key)
	if coreResult.success then
		return coreResult
	end

	local matches = {}
	local resolvedTagId = nil
	for candidateFeatureName, compiledSchema in pairs(self._compiledSchemasByFeature) do
		local tagId = compiledSchema.Tags[key]
		if tagId ~= nil then
			table.insert(matches, candidateFeatureName)
			resolvedTagId = tagId
		end
	end

	if #matches == 1 and resolvedTagId ~= nil then
		return Result.Ok(resolvedTagId)
	end
	if #matches > 1 then
		return _BuildAmbiguousKeyError(key, "Tag", matches)
	end

	return Result.Err("UnknownTag", Errors.UNKNOWN_TAG, {
		Key = key,
	})
end

function EntitySchemaRegistry:ResolveAnyId(key: string, featureName: string?): Result.Result<any>
	local componentResult = self:ResolveComponentId(key, featureName)
	if componentResult.success then
		return Result.Ok({
			Id = componentResult.value,
			Kind = "Component",
		})
	end
	if componentResult.type == "AmbiguousEntityKey" then
		return componentResult
	end

	local tagResult = self:ResolveTagId(key, featureName)
	if tagResult.success then
		return Result.Ok({
			Id = tagResult.value,
			Kind = "Tag",
		})
	end
	if tagResult.type == "AmbiguousEntityKey" then
		return tagResult
	end

	return Result.Err("UnknownComponent", Errors.UNKNOWN_COMPONENT, {
		Key = key,
		FeatureName = featureName,
	})
end

function EntitySchemaRegistry:RegisterCoreSchema(schema: TFeatureSchema): Result.Result<any>
	return self:_RegisterSchema(CORE_FEATURE_NAME, schema, true)
end

function EntitySchemaRegistry:RegisterFeatureSchema(featureName: string, schema: TFeatureSchema): Result.Result<any>
	return self:_RegisterSchema(featureName, schema, featureName == CORE_FEATURE_NAME)
end

function EntitySchemaRegistry:BeginCompile(): Result.Result<boolean>
	return Result.Catch(function()
		if self._isCompiled then
			return Result.Ok(true)
		end

		self._isRegistrationClosed = true
		self._isCompiling = true
		return Result.Ok(true)
	end, "EntitySchemaRegistry:BeginCompile")
end

function EntitySchemaRegistry:FinalizeCompile(): Result.Result<boolean>
	return Result.Catch(function()
		if self._isCompiled then
			return Result.Ok(true)
		end

		if not self._isCompiling then
			return Result.Err("InvalidSchema", Errors.INVALID_SCHEMA, {
				Reason = "CompileNotStarted",
			})
		end

		local validateResult = self:ValidateReady()
		if not validateResult.success then
			return validateResult
		end

		self._isCompiling = false
		self._isCompiled = true
		return Result.Ok(true)
	end, "EntitySchemaRegistry:FinalizeCompile")
end

function EntitySchemaRegistry:ValidateReady(): Result.Result<boolean>
	if self._compiledSchemasByFeature[CORE_FEATURE_NAME] == nil then
		return Result.Err("InvalidSchema", Errors.INVALID_SCHEMA, {
			FeatureName = CORE_FEATURE_NAME,
			Reason = "MissingCoreSchema",
		})
	end

	if not self._isRegistrationClosed then
		return Result.Err("InvalidSchema", Errors.INVALID_SCHEMA, {
			FeatureName = CORE_FEATURE_NAME,
			Reason = "RegistrationStillOpen",
		})
	end

	if not self._isCompiling and not self._isCompiled then
		return Result.Err("InvalidSchema", Errors.INVALID_SCHEMA, {
			FeatureName = CORE_FEATURE_NAME,
			Reason = "CompileNotStarted",
		})
	end

	return Result.Ok(true)
end

function EntitySchemaRegistry:GetStatus(): any
	return table.freeze({
		RegistrationClosed = self._isRegistrationClosed,
		CompileStarted = self._isCompiling or self._isCompiled,
		Compiling = self._isCompiling,
		Compiled = self._isCompiled,
		CoreSchemaRegistered = self._compiledSchemasByFeature[CORE_FEATURE_NAME] ~= nil,
		FeatureSchemaCount = self:_CountEntries(self._compiledSchemasByFeature),
		ArchetypeCount = self:_CountEntries(self._compiledArchetypesByName),
	})
end

function EntitySchemaRegistry:_RegisterRuntimeMetadataComponents()
	local runtimeFeatureNameComponent = self._world:component()
	self._world:set(runtimeFeatureNameComponent, JECS.Name, METADATA_COMPONENT_SPECS.FeatureName.ECSName)
	self._componentMetadataById[runtimeFeatureNameComponent] = table.freeze({
		ECSName = METADATA_COMPONENT_SPECS.FeatureName.ECSName,
		Kind = "Component",
		FeatureName = CORE_FEATURE_NAME,
		Key = METADATA_COMPONENT_SPECS.FeatureName.Key,
	})

	local runtimeArchetypeNameComponent = self._world:component()
	self._world:set(runtimeArchetypeNameComponent, JECS.Name, METADATA_COMPONENT_SPECS.ArchetypeName.ECSName)
	self._componentMetadataById[runtimeArchetypeNameComponent] = table.freeze({
		ECSName = METADATA_COMPONENT_SPECS.ArchetypeName.ECSName,
		Kind = "Component",
		FeatureName = CORE_FEATURE_NAME,
		Key = METADATA_COMPONENT_SPECS.ArchetypeName.Key,
	})

	self._ecsNames[METADATA_COMPONENT_SPECS.FeatureName.ECSName] = true
	self._ecsNames[METADATA_COMPONENT_SPECS.ArchetypeName.ECSName] = true
	self._allComponents[METADATA_COMPONENT_SPECS.FeatureName.ECSName] = runtimeFeatureNameComponent
	self._allComponents[METADATA_COMPONENT_SPECS.ArchetypeName.ECSName] = runtimeArchetypeNameComponent
	self._runtimeMetadataComponents = table.freeze({
		FeatureNameComponent = runtimeFeatureNameComponent,
		ArchetypeNameComponent = runtimeArchetypeNameComponent,
	})
end

function EntitySchemaRegistry:_CountEntries(source: { [any]: any }): number
	local count = 0
	for _ in pairs(source) do
		count += 1
	end
	return count
end

function EntitySchemaRegistry:_RegisterSchema(
	featureName: string,
	schema: TFeatureSchema,
	isCore: boolean
): Result.Result<any>
	return Result.Catch(function()
		assert(self._world ~= nil, "EntitySchemaRegistry must be initialized before registration")
		assert(type(featureName) == "string" and featureName ~= "", Errors.INVALID_SCHEMA)
		assert(type(schema) == "table", Errors.INVALID_SCHEMA)
		assert(type(schema.FeatureName) == "string" and schema.FeatureName ~= "", Errors.INVALID_SCHEMA)
		assert(schema.FeatureName == featureName, Errors.INVALID_SCHEMA)

		if self._isRegistrationClosed then
			return Result.Err("InvalidSchema", Errors.INVALID_SCHEMA, {
				FeatureName = featureName,
				Reason = "RegistrationClosed",
			})
		end

		if self._compiledSchemasByFeature[featureName] ~= nil then
			return Result.Err("DuplicateFeatureSchema", Errors.DUPLICATE_FEATURE_SCHEMA, {
				FeatureName = featureName,
			})
		end

		local compiledComponents = {}
		local compiledTags = {}
		local componentSpecs = {}
		local featureComponents = schema.Components or {}
		local featureTags = schema.Tags or {}
		local featureArchetypes = schema.Archetypes or {}

		for key, componentSpec in pairs(featureComponents) do
			assert(type(key) == "string" and key ~= "", Errors.INVALID_SCHEMA)
			assert(type(componentSpec) == "table", Errors.INVALID_SCHEMA)
			assert(type(componentSpec.ECSName) == "string" and componentSpec.ECSName ~= "", Errors.INVALID_SCHEMA)
			assert(componentSpec.Authority == "AUTHORITATIVE" or componentSpec.Authority == "DERIVED", Errors.INVALID_SCHEMA)
			if self._ecsNames[componentSpec.ECSName] == true then
				return Result.Err("DuplicateECSName", Errors.DUPLICATE_ECS_NAME, {
					FeatureName = featureName,
					Key = key,
					ECSName = componentSpec.ECSName,
				})
			end

			local componentId = self._world:component()
			self._world:set(componentId, JECS.Name, componentSpec.ECSName)
			self._ecsNames[componentSpec.ECSName] = true
			compiledComponents[key] = componentId
			componentSpecs[key] = table.freeze({
				Authority = componentSpec.Authority,
				Default = _DeepClone(componentSpec.Default),
				ECSName = componentSpec.ECSName,
			})
			self._componentMetadataById[componentId] = table.freeze({
				ECSName = componentSpec.ECSName,
				Kind = "Component",
				FeatureName = featureName,
				Key = key,
			})
			self._allComponents[featureName .. "." .. key] = componentId
		end

		for key in pairs(featureTags) do
			assert(type(key) == "string" and key ~= "", Errors.INVALID_SCHEMA)
			local ecsName = featureName .. "." .. key
			if self._ecsNames[ecsName] == true then
				return Result.Err("DuplicateECSName", Errors.DUPLICATE_ECS_NAME, {
					FeatureName = featureName,
					Key = key,
					ECSName = ecsName,
				})
			end

			local tagId = self._world:entity()
			self._world:set(tagId, JECS.Name, ecsName)
			self._ecsNames[ecsName] = true
			compiledTags[key] = tagId
			self._componentMetadataById[tagId] = table.freeze({
				ECSName = ecsName,
				Kind = "Tag",
				FeatureName = featureName,
				Key = key,
			})
			self._allComponents[featureName .. "." .. key] = tagId
		end

		local compiledArchetypesByLocalName = {}
		local function resolveArchetype(referenceName: string, resolutionStack: { [string]: boolean }): Result.Result<any>
			local localName = referenceName
			local fullName = if string.find(referenceName, ".", 1, true) ~= nil
				then referenceName
				else (featureName .. "." .. referenceName)

			local existingLocal = compiledArchetypesByLocalName[localName]
			if existingLocal ~= nil then
				return Result.Ok(existingLocal)
			end

			local existingGlobal = self._compiledArchetypesByName[fullName]
			if existingGlobal ~= nil then
				return Result.Ok(existingGlobal)
			end

			local spec = featureArchetypes[localName]
			if spec == nil then
				return Result.Err("UnknownParentArchetype", Errors.UNKNOWN_PARENT_ARCHETYPE, {
					FeatureName = featureName,
					ArchetypeName = referenceName,
				})
			end

			if resolutionStack[fullName] == true then
				return Result.Err("UnknownParentArchetype", Errors.UNKNOWN_PARENT_ARCHETYPE, {
					FeatureName = featureName,
					ArchetypeName = referenceName,
					Reason = "CycleDetected",
				})
			end

			resolutionStack[fullName] = true
			local resolvedComponents = {}
			local resolvedTags = {}

			if spec.Extends ~= nil then
				local parentResult = resolveArchetype(spec.Extends, resolutionStack)
				if not parentResult.success then
					return parentResult
				end

				local parentArchetype = parentResult.value
				for key, payload in pairs(parentArchetype.Components) do
					resolvedComponents[key] = {
						ComponentId = payload.ComponentId,
						Value = _DeepClone(payload.Value),
					}
				end
				for key, tagId in pairs(parentArchetype.Tags) do
					resolvedTags[key] = tagId
				end
			end

			for key, componentValue in pairs(spec.Components or {}) do
				local componentId = compiledComponents[key]
				local componentSpec = componentSpecs[key]
				if componentId == nil or componentSpec == nil then
					return Result.Err("InvalidSchema", Errors.INVALID_SCHEMA, {
						FeatureName = featureName,
						ArchetypeName = localName,
						Key = key,
						Reason = "UnknownComponent",
					})
				end

				local nextValue = if componentValue == true then _DeepClone(componentSpec.Default) else _DeepClone(componentValue)
				resolvedComponents[key] = {
					ComponentId = componentId,
					Value = nextValue,
				}
			end

			for key, isEnabled in pairs(spec.Tags or {}) do
				if isEnabled ~= true then
					continue
				end

				local tagId = compiledTags[key]
				if tagId == nil then
					return Result.Err("InvalidSchema", Errors.INVALID_SCHEMA, {
						FeatureName = featureName,
						ArchetypeName = localName,
						Key = key,
						Reason = "UnknownTag",
					})
				end

				resolvedTags[key] = tagId
			end

			local compiledArchetype = table.freeze({
				ArchetypeName = fullName,
				FeatureName = featureName,
				LocalName = localName,
				Components = _FreezeMap(resolvedComponents),
				Tags = _FreezeMap(resolvedTags),
			})
			compiledArchetypesByLocalName[localName] = compiledArchetype
			self._compiledArchetypesByName[fullName] = compiledArchetype
			resolutionStack[fullName] = nil
			return Result.Ok(compiledArchetype)
		end

		for localName in pairs(featureArchetypes) do
			local archetypeResult = resolveArchetype(localName, {})
			if not archetypeResult.success then
				return archetypeResult
			end
		end

		local compiledSchema = table.freeze({
			FeatureName = featureName,
			IsCore = isCore,
			Components = table.freeze(compiledComponents),
			Tags = table.freeze(compiledTags),
			ComponentSpecs = table.freeze(componentSpecs),
			Archetypes = table.freeze(compiledArchetypesByLocalName),
		})
		self._compiledSchemasByFeature[featureName] = compiledSchema
		return Result.Ok(compiledSchema)
	end, "EntitySchemaRegistry:_RegisterSchema")
end

return EntitySchemaRegistry
