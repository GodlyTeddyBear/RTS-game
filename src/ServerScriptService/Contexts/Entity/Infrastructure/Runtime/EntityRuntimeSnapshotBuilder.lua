--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JECS = require(ReplicatedStorage.Packages.JECS)
local Result = require(ReplicatedStorage.Utilities.Result)

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

local SHARED_FIELD_KEYS = {
	Identity = "Identity",
	Ownership = "Ownership",
	Transform = "Transform",
	Health = "Health",
	Lifetime = "Lifetime",
	Target = "Target",
	ModelRef = "ModelRef",
	AIActorType = "AIActorType",
	AIRuntimeProfile = "AIRuntimeProfile",
	AIActionState = "AIActionState",
	AIBehaviorConfig = "AIBehaviorConfig",
	AIRegistration = "AIRegistration",
}

local EntityRuntimeSnapshotBuilder = {}
EntityRuntimeSnapshotBuilder.__index = EntityRuntimeSnapshotBuilder

function EntityRuntimeSnapshotBuilder.new()
	local self = setmetatable({}, EntityRuntimeSnapshotBuilder)
	self._world = nil
	self._schemaRegistry = nil
	self._entityFactory = nil
	return self
end

function EntityRuntimeSnapshotBuilder:Init(registry: any, _name: string)
	self._world = registry:Get("World")
	self._schemaRegistry = registry:Get("EntitySchemaRegistry")
	self._entityFactory = registry:Get("EntityEntityFactory")
end

function EntityRuntimeSnapshotBuilder:BuildSnapshot(entity: number): Result.Result<any>
	return Result.Catch(function()
		if not self._entityFactory:Exists(entity) then
			return Result.Err("UnknownEntity", Errors.UNKNOWN_ENTITY, {
				Entity = entity,
			})
		end

		local archetypeName = self._world:get(entity, JECS.Name)
		if type(archetypeName) ~= "string" or archetypeName == "" then
			return Result.Err("UnknownArchetype", Errors.UNKNOWN_ARCHETYPE, {
				Entity = entity,
			})
		end

		local compiledArchetype = self._schemaRegistry:GetCompiledArchetype(archetypeName)
		if compiledArchetype == nil then
			return Result.Err("UnknownArchetype", Errors.UNKNOWN_ARCHETYPE, {
				Entity = entity,
				ArchetypeName = archetypeName,
			})
		end

		local compiledSchema = self._schemaRegistry:GetCompiledSchema(compiledArchetype.FeatureName)
		assert(compiledSchema ~= nil, "EntityRuntimeSnapshotBuilder missing compiled schema")

		local featureData = {}
		local snapshot = {
			Entity = entity,
			FeatureName = compiledArchetype.FeatureName,
			ArchetypeName = archetypeName,
			Identity = nil,
			Ownership = nil,
			Transform = nil,
			Health = nil,
			Lifetime = nil,
			Target = nil,
			ModelRef = nil,
			AIActorType = nil,
			AIRuntimeProfile = nil,
			AIActionState = nil,
			AIBehaviorConfig = nil,
			AIRegistration = nil,
			FeatureData = featureData,
		}

		local coreSchema = self._schemaRegistry:GetCoreCompiledSchema()
		if coreSchema ~= nil then
			self:_ApplySchemaToSnapshot(entity, coreSchema, snapshot, featureData, true)
		end

		self:_ApplySchemaToSnapshot(entity, compiledSchema, snapshot, featureData, false)

		return Result.Ok(snapshot)
	end, "EntityRuntimeSnapshotBuilder:BuildSnapshot")
end

function EntityRuntimeSnapshotBuilder:_ApplySchemaToSnapshot(
	entity: number,
	compiledSchema: any,
	snapshot: any,
	featureData: { [string]: any },
	isCore: boolean
)
	for key, componentId in pairs(compiledSchema.Components) do
		local value = self._world:get(entity, componentId)
		if value == nil then
			continue
		end

		local clonedValue = _DeepClone(value)
		local sharedFieldKey = SHARED_FIELD_KEYS[key]
		if sharedFieldKey ~= nil and snapshot[sharedFieldKey] == nil then
			snapshot[sharedFieldKey] = clonedValue
		else
			featureData[key] = clonedValue
		end
	end
end

return EntityRuntimeSnapshotBuilder
