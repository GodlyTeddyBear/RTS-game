--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local BaseECSEntityFactory = require(ServerStorage.Utilities.ECSUtilities.BaseECSEntityFactory)

local Errors = require(script.Parent.Parent.Parent.Errors)

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

local function _NormalizeQueryEntries(querySpec: any): { any }?
	if type(querySpec) == "string" then
		return { querySpec }
	end

	if type(querySpec) ~= "table" then
		return nil
	end

	if type(querySpec.Key) == "string" then
		return { querySpec }
	end

	if type(querySpec.Keys) == "table" then
		local entries = {}
		for _, keyOrEntry in ipairs(querySpec.Keys) do
			if type(keyOrEntry) == "string" then
				table.insert(entries, {
					Key = keyOrEntry,
					FeatureName = querySpec.FeatureName,
				})
			elseif type(keyOrEntry) == "table" then
				local cloned = table.clone(keyOrEntry)
				if cloned.FeatureName == nil then
					cloned.FeatureName = querySpec.FeatureName
				end
				table.insert(entries, cloned)
			end
		end
		return entries
	end

	local entries = {}
	for _, entry in ipairs(querySpec) do
		table.insert(entries, entry)
	end
	if #entries > 0 then
		return entries
	end

	return nil
end

local EntityEntityFactory = {}
EntityEntityFactory.__index = EntityEntityFactory
setmetatable(EntityEntityFactory, { __index = BaseECSEntityFactory })

function EntityEntityFactory.new()
	return setmetatable(BaseECSEntityFactory.new("Entity"), EntityEntityFactory)
end

function EntityEntityFactory:_GetComponentRegistryName(): string
	return "EntitySchemaRegistry"
end

function EntityEntityFactory:_OnInit(registry: any, _name: string, componentRegistry: any)
	self._schemaRegistry = componentRegistry
	self._world = registry:Get("World")
	self._runtimeMetadataComponents = componentRegistry:GetRuntimeMetadataComponents()
end

function EntityEntityFactory:GetComponentId(featureName: string, key: string): Result.Result<any>
	return self._schemaRegistry:GetFeatureComponentId(featureName, key)
end

function EntityEntityFactory:GetTagId(featureName: string, key: string): Result.Result<any>
	return self._schemaRegistry:GetFeatureTagId(featureName, key)
end

function EntityEntityFactory:GetCoreComponentId(key: string): Result.Result<any>
	return self._schemaRegistry:GetCoreComponentId(key)
end

function EntityEntityFactory:GetCoreTagId(key: string): Result.Result<any>
	return self._schemaRegistry:GetCoreTagId(key)
end

function EntityEntityFactory:Exists(entity: number): boolean
	return self:_Exists(entity)
end

function EntityEntityFactory:CreateFromArchetype(archetypeName: string, payload: { [string]: any }?): Result.Result<number>
	return Result.Catch(function()
		local compiledArchetype = self._schemaRegistry:GetCompiledArchetype(archetypeName)
		if compiledArchetype == nil then
			return Result.Err("UnknownArchetype", Errors.UNKNOWN_ARCHETYPE, {
				ArchetypeName = archetypeName,
			})
		end

		local featureName = compiledArchetype.FeatureName
		local compiledSchema = self._schemaRegistry:GetCompiledSchema(featureName)
		assert(compiledSchema ~= nil, "EntityEntityFactory missing compiled schema for archetype feature")

		for key in pairs(payload or {}) do
			if compiledArchetype.Components[key] == nil then
				return Result.Err("UnknownComponent", Errors.UNKNOWN_COMPONENT, {
					ArchetypeName = archetypeName,
					FeatureName = featureName,
					Key = key,
				})
			end
		end

		local entity = self:_CreateEntity()
		self:_SetName(entity, archetypeName)
		if self._runtimeMetadataComponents ~= nil then
			self:_Set(entity, self._runtimeMetadataComponents.FeatureNameComponent, featureName)
			self:_Set(entity, self._runtimeMetadataComponents.ArchetypeNameComponent, archetypeName)
		end

		for _, componentPayload in pairs(compiledArchetype.Components) do
			self:_Set(entity, componentPayload.ComponentId, _DeepClone(componentPayload.Value))
		end

		for _, tagId in pairs(compiledArchetype.Tags) do
			self:_Add(entity, tagId)
		end

		for key, value in pairs(payload or {}) do
			local componentPayload = compiledArchetype.Components[key]
			if componentPayload ~= nil then
				self:_Set(entity, componentPayload.ComponentId, _DeepClone(value))
			end
		end

		return Result.Ok(entity)
	end, "EntityEntityFactory:CreateFromArchetype")
end

function EntityEntityFactory:SetComponent(entity: number, featureName: string, key: string, value: any): Result.Result<boolean>
	return Result.Catch(function()
		local componentIdResult = self:GetComponentId(featureName, key)
		if not componentIdResult.success then
			return componentIdResult
		end

		self:_Set(entity, componentIdResult.value, value)
		return Result.Ok(true)
	end, "EntityEntityFactory:SetComponent")
end

function EntityEntityFactory:GetComponent(entity: number, featureName: string, key: string): Result.Result<any>
	return Result.Catch(function()
		local componentIdResult = self:GetComponentId(featureName, key)
		if not componentIdResult.success then
			return componentIdResult
		end

		return Result.Ok(self:_Get(entity, componentIdResult.value))
	end, "EntityEntityFactory:GetComponent")
end

function EntityEntityFactory:AddTag(entity: number, featureName: string, key: string): Result.Result<boolean>
	return Result.Catch(function()
		local tagIdResult = self:GetTagId(featureName, key)
		if not tagIdResult.success then
			return tagIdResult
		end

		self:_Add(entity, tagIdResult.value)
		return Result.Ok(true)
	end, "EntityEntityFactory:AddTag")
end

function EntityEntityFactory:RemoveTag(entity: number, featureName: string, key: string): Result.Result<boolean>
	return Result.Catch(function()
		local tagIdResult = self:GetTagId(featureName, key)
		if not tagIdResult.success then
			return tagIdResult
		end

		self:_Remove(entity, tagIdResult.value)
		return Result.Ok(true)
	end, "EntityEntityFactory:RemoveTag")
end

function EntityEntityFactory:Has(entity: number, featureName: string, key: string): Result.Result<boolean>
	return Result.Catch(function()
		local componentIdResult = self:GetComponentId(featureName, key)
		if componentIdResult.success then
			return Result.Ok(self:_Has(entity, componentIdResult.value))
		end

		local tagIdResult = self:GetTagId(featureName, key)
		if not tagIdResult.success then
			return tagIdResult
		end

		return Result.Ok(self:_Has(entity, tagIdResult.value))
	end, "EntityEntityFactory:Has")
end

function EntityEntityFactory:Get(entity: number, key: string, featureName: string?): Result.Result<any>
	return Result.Catch(function()
		local resolvedIdResult = self._schemaRegistry:ResolveAnyId(key, featureName)
		if not resolvedIdResult.success then
			return resolvedIdResult
		end

		local resolvedId = resolvedIdResult.value
		if resolvedId.Kind == "Tag" then
			return Result.Ok(self:_Has(entity, resolvedId.Id))
		end

		return Result.Ok(self:_Get(entity, resolvedId.Id))
	end, "EntityEntityFactory:Get")
end

function EntityEntityFactory:Set(entity: number, key: string, value: any, featureName: string?): Result.Result<boolean>
	return Result.Catch(function()
		local componentIdResult = self._schemaRegistry:ResolveComponentId(key, featureName)
		if not componentIdResult.success then
			return componentIdResult
		end

		self:_Set(entity, componentIdResult.value, value)
		return Result.Ok(true)
	end, "EntityEntityFactory:Set")
end

function EntityEntityFactory:Add(entity: number, key: string, featureName: string?): Result.Result<boolean>
	return Result.Catch(function()
		local tagIdResult = self._schemaRegistry:ResolveTagId(key, featureName)
		if not tagIdResult.success then
			return tagIdResult
		end

		self:_Add(entity, tagIdResult.value)
		return Result.Ok(true)
	end, "EntityEntityFactory:Add")
end

function EntityEntityFactory:Remove(entity: number, key: string, featureName: string?): Result.Result<boolean>
	return Result.Catch(function()
		local resolvedIdResult = self._schemaRegistry:ResolveAnyId(key, featureName)
		if not resolvedIdResult.success then
			return resolvedIdResult
		end

		self:_Remove(entity, resolvedIdResult.value.Id)
		return Result.Ok(true)
	end, "EntityEntityFactory:Remove")
end

function EntityEntityFactory:Query(querySpec: any): Result.Result<{ number }>
	return Result.Catch(function()
		local entries = _NormalizeQueryEntries(querySpec)
		if entries == nil or #entries == 0 then
			return Result.Err("InvalidQuery", Errors.INVALID_QUERY, {
				QuerySpec = querySpec,
			})
		end

		local queryIds = {}
		for _, entry in ipairs(entries) do
			local key: string?
			local featureName: string? = nil
			if type(entry) == "string" then
				key = entry
			elseif type(entry) == "table" then
				key = entry.Key
				featureName = entry.FeatureName
			end

			if type(key) ~= "string" or key == "" then
				return Result.Err("InvalidQuery", Errors.INVALID_QUERY, {
					QuerySpec = querySpec,
				})
			end

			local resolvedIdResult = self._schemaRegistry:ResolveAnyId(key, featureName)
			if not resolvedIdResult.success then
				return resolvedIdResult
			end

			table.insert(queryIds, resolvedIdResult.value.Id)
		end

		return Result.Ok(self:CollectQuery(table.unpack(queryIds)))
	end, "EntityEntityFactory:Query")
end

function EntityEntityFactory:MarkEntityForDestruction(entity: number): Result.Result<boolean>
	return Result.Catch(function()
		self:MarkForDestruction(entity)
		return Result.Ok(true)
	end, "EntityEntityFactory:MarkEntityForDestruction")
end

function EntityEntityFactory:FlushDestroyQueue(): Result.Result<number>
	return Result.Catch(function()
		local deletedAny = self:FlushDestructionQueue()
		if not deletedAny then
			return Result.Ok(0)
		end

		return Result.Ok(1)
	end, "EntityEntityFactory:FlushDestroyQueue")
end

function EntityEntityFactory:DeleteEntityNow(entity: number): Result.Result<boolean>
	return Result.Catch(function()
		if not self:Exists(entity) then
			return Result.Ok(false)
		end

		self:_DeleteNow(entity)
		return Result.Ok(true)
	end, "EntityEntityFactory:DeleteEntityNow")
end

return EntityEntityFactory
