--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseCommand = require(ReplicatedStorage.Utilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok = Result.Ok
local Ensure = Result.Ensure

local DespawnUnitCommand = {}
DespawnUnitCommand.__index = DespawnUnitCommand
setmetatable(DespawnUnitCommand, BaseCommand)

function DespawnUnitCommand.new()
	local self = BaseCommand.new("Unit", "DespawnUnit")
	return setmetatable(self, DespawnUnitCommand)
end

function DespawnUnitCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_entityFactory = "UnitEntityFactory",
		_instanceFactory = "UnitInstanceFactory",
	})
end

function DespawnUnitCommand:Execute(entity: number): Result.Result<boolean>
	return Result.Catch(function()
		Ensure(type(entity) == "number" and self._entityFactory:IsActive(entity), "InvalidEntity", Errors.INVALID_ENTITY)

		self._instanceFactory:DestroyInstance(entity)
		local deleted = self._entityFactory:DeleteEntity(entity)
		self._entityFactory:FlushPendingDeletes()

		return Ok(deleted)
	end, self:_Label())
end

return DespawnUnitCommand
