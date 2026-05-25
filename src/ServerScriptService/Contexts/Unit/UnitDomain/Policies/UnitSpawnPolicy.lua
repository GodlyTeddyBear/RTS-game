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

-- Resolves the entity factory needed to enforce the per-owner concurrency limit.
function UnitSpawnPolicy:Init(registry: any, _name: string)
	self._entityFactory = registry:Get("UnitEntityFactory")
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

		local currentCount = self._entityFactory:GetOwnerUnitCount(request.OwnerKind, request.OwnerId)
		Ensure(currentCount < definition.MaxConcurrentUnitsPerOwner, "MaxConcurrentReached", Errors.MAX_CONCURRENT_REACHED, {
			OwnerKind = request.OwnerKind,
			OwnerId = request.OwnerId,
			UnitId = request.UnitId,
		})

		return Ok(definition)
	end, "Unit:UnitSpawnPolicy")
end

return UnitSpawnPolicy
