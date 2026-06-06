--!strict

--[=[
    @class UnitSpawnPolicy
    Validates unit spawn requests against configuration and owner capacity limits.

    @server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local UnitConfig = require(ReplicatedStorage.Contexts.Unit.Config.UnitConfig)
local UnitTypes = require(ReplicatedStorage.Contexts.Unit.Types.UnitTypes)
local EntityDefinitionSpecs = require(ReplicatedStorage.Contexts.Entity.Specs.EntityDefinitionSpecs)
local Errors = require(script.Parent.Parent.Parent.Errors)

type SpawnUnitRequest = UnitTypes.SpawnUnitRequest
type UnitDefinition = UnitTypes.UnitDefinition

local Ok = Result.Ok
local Ensure = Result.Ensure

local UnitSpawnPolicy = {}
UnitSpawnPolicy.__index = UnitSpawnPolicy

function UnitSpawnPolicy.new()
	return setmetatable({}, UnitSpawnPolicy)
end

-- Resolves the entity read service needed to enforce the per-owner concurrency limit.
function UnitSpawnPolicy:Init(registry: any, _name: string)
	self._unitReadService = registry:Get("UnitEntityReadService")
end

-- Validates the spawn request and returns the resolved unit definition when all policy checks pass.
function UnitSpawnPolicy:Check(request: SpawnUnitRequest): Result.Result<UnitDefinition>
	return Result.Catch(function()
		Ensure(type(request) == "table", "InvalidRequest", Errors.INVALID_REQUEST)
		Ensure(type(request.UnitId) == "string" and request.UnitId ~= "", "InvalidUnitId", Errors.INVALID_UNIT_ID)
		Ensure(request.Faction == "Player" or request.Faction == "Enemy", "InvalidFaction", Errors.INVALID_FACTION)
		Ensure(
			request.OwnerKind == "Player" or request.OwnerKind == "PlayerBase" or request.OwnerKind == "EnemyBase",
			"InvalidOwnerKind",
			Errors.INVALID_OWNER_KIND
		)
		Ensure(type(request.OwnerId) == "string" and request.OwnerId ~= "", "InvalidOwnerId", Errors.INVALID_OWNER_ID)
		Ensure(typeof(request.SpawnCFrame) == "CFrame", "InvalidSpawnCFrame", Errors.INVALID_SPAWN_CFRAME)
		Ensure(request.Lifetime == nil or (type(request.Lifetime) == "number" and request.Lifetime > 0), "InvalidLifetime", Errors.INVALID_LIFETIME)

		local definition = UnitConfig.Definitions[request.UnitId]
		Ensure(definition ~= nil, "InvalidUnitId", Errors.INVALID_UNIT_ID, {
			UnitId = request.UnitId,
		})
		Ensure(EntityDefinitionSpecs.IsValid(definition), "InvalidUnitId", Errors.INVALID_UNIT_ID, {
			UnitId = request.UnitId,
		})
		Ensure(definition.DefinitionId == request.UnitId, "InvalidUnitId", Errors.INVALID_UNIT_ID, {
			UnitId = request.UnitId,
		})
		Ensure(
			type(definition.Limits) == "table"
				and type(definition.Limits.MaxConcurrentPerOwner) == "number"
				and definition.Limits.MaxConcurrentPerOwner > 0,
			"InvalidUnitId",
			Errors.INVALID_UNIT_ID,
			{ UnitId = request.UnitId }
		)
		if definition.Role == "Builder" then
			local build = if type(definition.Capabilities) == "table" then definition.Capabilities.Build else nil
			Ensure(
				build ~= nil and type(build.WorkPerSecond) == "number" and build.WorkPerSecond > 0 and type(build.Range) == "number" and build.Range > 0,
				"InvalidUnitId",
				Errors.INVALID_UNIT_ID,
				{ UnitId = request.UnitId }
			)
		end

		local currentCount = self._unitReadService:GetOwnerUnitCount(request.OwnerKind, request.OwnerId)
		Ensure(currentCount < definition.Limits.MaxConcurrentPerOwner, "MaxConcurrentReached", Errors.MAX_CONCURRENT_REACHED, {
			OwnerKind = request.OwnerKind,
			OwnerId = request.OwnerId,
			UnitId = request.UnitId,
		})

		return Ok(definition)
	end, "Unit:UnitSpawnPolicy")
end

return UnitSpawnPolicy
