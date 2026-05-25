--!strict

--[=[
    @class SpawnUnitCommand
    Validates a spawn request, creates the unit entity and model, and registers the spawned unit with sync and team services.

    @server
]=]

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local ModelPlus = require(ReplicatedStorage.Utilities.ModelPlus)
local Result = require(ReplicatedStorage.Utilities.Result)
local TeamTypes = require(ReplicatedStorage.Contexts.Team.Types.TeamTypes)
local UnitTypes = require(ReplicatedStorage.Contexts.Unit.Types.UnitTypes)
local Errors = require(script.Parent.Parent.Parent.Errors)

type SpawnUnitRequest = UnitTypes.SpawnUnitRequest
type SpawnUnitResult = UnitTypes.SpawnUnitResult

local Ok = Result.Ok
local Try = Result.Try
local Ensure = Result.Ensure

local SpawnUnitCommand = {}
SpawnUnitCommand.__index = SpawnUnitCommand
setmetatable(SpawnUnitCommand, BaseCommand)

function SpawnUnitCommand.new()
	local self = BaseCommand.new("Unit", "SpawnUnit")
	return setmetatable(self, SpawnUnitCommand)
end

-- Resolves the unit dependencies the command needs before any spawn can be attempted.
function SpawnUnitCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_spawnPolicy = "UnitSpawnPolicy",
		_entityFactory = "UnitEntityFactory",
		_instanceFactory = "UnitInstanceFactory",
		_replicationService = "UnitECSReplicationService",
		_syncService = "UnitGameObjectSyncService",
	})
end

-- Caches the team context used to assign the spawned unit to the appropriate team bucket.
function SpawnUnitCommand:Start(registry: any, _name: string)
	self._teamContext = registry:Get("TeamContext")
end

-- Spawns the unit entity, creates the model, links replication, and rolls back if any step fails.
function SpawnUnitCommand:Execute(request: SpawnUnitRequest): Result.Result<SpawnUnitResult>
	local entity: number? = nil

	return Result.Catch(function()
		-- Validate the request and allocate the authoritative entity first.
		local definition = Try(self._spawnPolicy:Check(request))
		local unitGuid = HttpService:GenerateGUID(false)

		-- Create the entity and model as one atomic server-side spawn operation.
		entity = self._entityFactory:CreateUnit(unitGuid, request, definition, os.clock())
		local model = self._instanceFactory:CreateUnitInstance(
			entity,
			request.UnitId,
			unitGuid,
			request.Faction,
			request.OwnerKind,
			request.OwnerId
		)

		-- Place the model, bind it back to the entity, and register replication/sync only after creation succeeds.
		ModelPlus.MoveToCFrame(model, request.SpawnCFrame)
		self._entityFactory:SetModelRef(entity, model)
		self._replicationService:RegisterUnitEntity(entity)
		self._syncService:RegisterEntity(entity, model)

		-- Assign the new unit to the team bucket that matches its faction or owner kind.
		local unitHandle = TeamTypes.BuildMemberHandle("Unit", unitGuid)
		if request.Faction == "Enemy" then
			Try(self._teamContext:AssignMemberToEnemyTeam(unitHandle))
		elseif request.OwnerKind == "Player" then
			local ownerUserId = tonumber(request.OwnerId)
			Ensure(ownerUserId ~= nil and ownerUserId > 0, "InvalidOwnerId", Errors.INVALID_OWNER_ID, {
				OwnerId = request.OwnerId,
			})
			Try(self._teamContext:AssignMemberToPlayerTeam(ownerUserId, unitHandle))
		end

		return Ok({
			Entity = entity,
			UnitId = request.UnitId,
		})
	end, self:_Label(), function()
		if entity ~= nil then
			self._instanceFactory:DestroyInstance(entity)
			self._entityFactory:DeleteEntity(entity)
			self._entityFactory:FlushPendingDeletes()
		end
	end)
end

return SpawnUnitCommand
