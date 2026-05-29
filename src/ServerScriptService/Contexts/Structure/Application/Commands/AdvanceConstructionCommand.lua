--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)
local StructureSpecs = require(script.Parent.Parent.Parent.StructureDomain.Specs.StructureSpecs)
local StructureTypes = require(ReplicatedStorage.Contexts.Structure.Types.StructureTypes)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ensure = Result.Ensure
local Try = Result.Try

type TConstructionContributionResult = StructureTypes.TConstructionContributionResult

local AdvanceConstructionCommand = {}
AdvanceConstructionCommand.__index = AdvanceConstructionCommand
setmetatable(AdvanceConstructionCommand, BaseCommand)

function AdvanceConstructionCommand.new()
	local self = BaseCommand.new("Structure", "AdvanceConstruction")
	return setmetatable(self, AdvanceConstructionCommand)
end

function AdvanceConstructionCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_entityContext = "EntityContext",
		_readService = "StructureEntityReadService",
	})
end

function AdvanceConstructionCommand:Execute(entity: number, workAmount: number): Result.Result<TConstructionContributionResult>
	return Result.Catch(function()
		Ensure(type(entity) == "number", "EntityNotFound", Errors.ENTITY_NOT_FOUND)
		Ensure(self._readService:IsPlaced(entity), "EntityNotFound", Errors.ENTITY_NOT_FOUND, { Entity = entity })
		Ensure(StructureSpecs.HasValidConstructionWorkAmount(workAmount), "InvalidConstructionWorkAmount", Errors.INVALID_CONSTRUCTION_WORK_AMOUNT, {
			Entity = entity,
			WorkAmount = workAmount,
		})
		Ensure(self._readService:IsUnderConstruction(entity), "StructureAlreadyCompleted", Errors.STRUCTURE_ALREADY_COMPLETED, {
			Entity = entity,
		})

		local current = self._readService:GetConstruction(entity)
		Ensure(type(current) == "table", "EntityNotFound", Errors.ENTITY_NOT_FOUND, { Entity = entity })

		local nextProgress = {
			CurrentWork = math.min(current.RequiredWork, current.CurrentWork + workAmount),
			RequiredWork = current.RequiredWork,
		}
		Try(self._entityContext:Set(entity, "Construction", nextProgress, "Structure"))
		Try(self._entityContext:Add(entity, "DirtyTag", "Entity"))

		local didComplete = nextProgress.CurrentWork >= nextProgress.RequiredWork
		if didComplete then
			Try(self._entityContext:Remove(entity, "UnderConstructionTag", "Structure"))
			Try(self._entityContext:Add(entity, "OperationalTag", "Structure"))
		end

		return Result.Ok({
			Completed = not self._readService:IsUnderConstruction(entity),
			Percent = self._readService:GetConstructionPercent(entity),
			JustCompleted = didComplete,
		} :: TConstructionContributionResult)
	end, "Structure:AdvanceConstructionCommand")
end

return AdvanceConstructionCommand
