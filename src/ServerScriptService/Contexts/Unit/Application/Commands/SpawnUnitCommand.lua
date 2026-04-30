--!strict

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseCommand = require(ReplicatedStorage.Utilities.BaseApplication.BaseCommand)
local ModelPlus = require(ReplicatedStorage.Utilities.ModelPlus)
local Result = require(ReplicatedStorage.Utilities.Result)
local UnitTypes = require(ReplicatedStorage.Contexts.Unit.Types.UnitTypes)

type SpawnUnitRequest = UnitTypes.SpawnUnitRequest
type SpawnUnitResult = UnitTypes.SpawnUnitResult

local Ok = Result.Ok
local Try = Result.Try

local SpawnUnitCommand = {}
SpawnUnitCommand.__index = SpawnUnitCommand
setmetatable(SpawnUnitCommand, BaseCommand)

function SpawnUnitCommand.new()
	local self = BaseCommand.new("Unit", "SpawnUnit")
	return setmetatable(self, SpawnUnitCommand)
end

function SpawnUnitCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_spawnPolicy = "UnitSpawnPolicy",
		_entityFactory = "UnitEntityFactory",
		_instanceFactory = "UnitInstanceFactory",
		_syncService = "UnitGameObjectSyncService",
	})
end

function SpawnUnitCommand:Execute(request: SpawnUnitRequest): Result.Result<SpawnUnitResult>
	local entity: number? = nil

	return Result.Catch(function()
		local definition = Try(self._spawnPolicy:Check(request))
		local unitGuid = HttpService:GenerateGUID(false)

		entity = self._entityFactory:CreateUnit(unitGuid, request, definition, os.clock())
		local model = self._instanceFactory:CreateUnitInstance(
			entity,
			request.UnitId,
			unitGuid,
			request.Faction,
			request.OwnerKind,
			request.OwnerId
		)

		ModelPlus.MoveToCFrame(model, request.SpawnCFrame)
		self._entityFactory:SetModelRef(entity, model)
		self._syncService:RegisterEntity(entity, model)

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
