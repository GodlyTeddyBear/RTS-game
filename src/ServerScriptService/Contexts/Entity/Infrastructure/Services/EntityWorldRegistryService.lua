--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)

local EntityECSWorldService = require(script.Parent.Parent.ECS.EntityECSWorldService)
local EntityEntityFactory = require(script.Parent.Parent.ECS.EntityEntityFactory)
local EntitySchemaRegistry = require(script.Parent.Parent.ECS.EntitySchemaRegistry)
local EntityCoreSchema = require(script.Parent.Parent.ECS.Schemas.EntityCoreSchema)

local EntityWorldRegistryService = {}
EntityWorldRegistryService.__index = EntityWorldRegistryService

local DEFAULT_WORLD = "Actor"
local LOCATION_WORLD = "Location"

local function _BuildScopedRegistry(worldService: any, schemaRegistry: any)
	return {
		Get = function(_self: any, name: string)
			if name == "World" then
				return worldService:GetWorld()
			end
			if name == "EntitySchemaRegistry" then
				return schemaRegistry
			end
			return nil
		end,
	}
end

function EntityWorldRegistryService.new()
	local self = setmetatable({}, EntityWorldRegistryService)
	self._worlds = {}
	return self
end

function EntityWorldRegistryService:Init(registry: any, _name: string)
	self._worlds[DEFAULT_WORLD] = {
		WorldService = registry:Get("EntityECSWorldService"),
		SchemaRegistry = registry:Get("EntitySchemaRegistry"),
		EntityFactory = registry:Get("EntityEntityFactory"),
		IsPrimary = true,
	}

	self:_CreateScopedWorld(LOCATION_WORLD)
end

function EntityWorldRegistryService:GetDefaultWorldName(): string
	return DEFAULT_WORLD
end

function EntityWorldRegistryService:NormalizeWorldName(worldName: any): string
	if type(worldName) ~= "string" or worldName == "" then
		return DEFAULT_WORLD
	end
	return worldName
end

function EntityWorldRegistryService:IsDefaultWorld(worldName: any): boolean
	return self:NormalizeWorldName(worldName) == DEFAULT_WORLD
end

function EntityWorldRegistryService:GetWorldNames(): { string }
	local worldNames = {}
	for worldName in pairs(self._worlds) do
		table.insert(worldNames, worldName)
	end
	table.sort(worldNames)
	return worldNames
end

function EntityWorldRegistryService:GetScopedWorld(worldName: string): Result.Result<any>
	local normalizedWorldName = self:NormalizeWorldName(worldName)
	local scopedWorld = self._worlds[normalizedWorldName]
	if scopedWorld == nil then
		return Result.Err("UnknownEntityWorld", "EntityContext: unknown ECS world", {
			World = normalizedWorldName,
		})
	end
	return Result.Ok(scopedWorld)
end

function EntityWorldRegistryService:GetWorld(worldName: string): Result.Result<any>
	local scopedWorldResult = self:GetScopedWorld(worldName)
	if not scopedWorldResult.success then
		return scopedWorldResult
	end
	return Result.Ok(scopedWorldResult.value.WorldService:GetWorld())
end

function EntityWorldRegistryService:GetSchemaRegistry(worldName: string): Result.Result<any>
	local scopedWorldResult = self:GetScopedWorld(worldName)
	if not scopedWorldResult.success then
		return scopedWorldResult
	end
	return Result.Ok(scopedWorldResult.value.SchemaRegistry)
end

function EntityWorldRegistryService:GetEntityFactory(worldName: string): Result.Result<any>
	local scopedWorldResult = self:GetScopedWorld(worldName)
	if not scopedWorldResult.success then
		return scopedWorldResult
	end
	return Result.Ok(scopedWorldResult.value.EntityFactory)
end

function EntityWorldRegistryService:RegisterFeatureSchema(worldName: string, featureName: string, schema: any): Result.Result<any>
	local schemaRegistryResult = self:GetSchemaRegistry(worldName)
	if not schemaRegistryResult.success then
		return schemaRegistryResult
	end
	return schemaRegistryResult.value:RegisterFeatureSchema(featureName, schema)
end

function EntityWorldRegistryService:BeginCompileSecondaryWorlds(): Result.Result<boolean>
	for worldName, scopedWorld in pairs(self._worlds) do
		if scopedWorld.IsPrimary == true then
			continue
		end
		local beginResult = scopedWorld.SchemaRegistry:BeginCompile()
		if not beginResult.success then
			return Result.Err(beginResult.type, beginResult.message, {
				World = worldName,
				Cause = beginResult,
			})
		end
	end
	return Result.Ok(true)
end

function EntityWorldRegistryService:ValidateSecondaryWorldsReady(): Result.Result<boolean>
	for worldName, scopedWorld in pairs(self._worlds) do
		if scopedWorld.IsPrimary == true then
			continue
		end
		local validateResult = scopedWorld.SchemaRegistry:ValidateReady()
		if not validateResult.success then
			return Result.Err(validateResult.type, validateResult.message, {
				World = worldName,
				Cause = validateResult,
			})
		end
	end
	return Result.Ok(true)
end

function EntityWorldRegistryService:FinalizeCompileSecondaryWorlds(): Result.Result<boolean>
	for worldName, scopedWorld in pairs(self._worlds) do
		if scopedWorld.IsPrimary == true then
			continue
		end
		local finalizeResult = scopedWorld.SchemaRegistry:FinalizeCompile()
		if not finalizeResult.success then
			return Result.Err(finalizeResult.type, finalizeResult.message, {
				World = worldName,
				Cause = finalizeResult,
			})
		end
	end
	return Result.Ok(true)
end

function EntityWorldRegistryService:_CreateScopedWorld(worldName: string)
	local worldService = EntityECSWorldService.new()
	worldService:Init({}, ("Entity%sWorldService"):format(worldName))

	local schemaRegistry = EntitySchemaRegistry.new()
	local registry = _BuildScopedRegistry(worldService, schemaRegistry)
	schemaRegistry:Init(registry, ("Entity%sSchemaRegistry"):format(worldName))

	local coreResult = schemaRegistry:RegisterCoreSchema(EntityCoreSchema)
	assert(coreResult.success, ("EntityWorldRegistryService failed to register core schema for %s"):format(worldName))

	local entityFactory = EntityEntityFactory.new()
	entityFactory:Init(registry, ("Entity%sEntityFactory"):format(worldName))

	self._worlds[worldName] = {
		WorldService = worldService,
		SchemaRegistry = schemaRegistry,
		EntityFactory = entityFactory,
		IsPrimary = false,
	}
end

return EntityWorldRegistryService
