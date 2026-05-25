--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local StructureSpecs = require(script.Parent.Parent.Parent.StructureDomain.Specs.StructureSpecs)
local StructureTypes = require(ReplicatedStorage.Contexts.Structure.Types.StructureTypes)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ensure = Result.Ensure

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
		_factory = "StructureEntityFactory",
	})
end

function AdvanceConstructionCommand:Execute(entity: number, workAmount: number): Result.Result<TConstructionContributionResult>
	return Result.Catch(function()
		-- Validate the contribution request before mutating structure lifecycle state.
		Ensure(type(entity) == "number", "EntityNotFound", Errors.ENTITY_NOT_FOUND)
		Ensure(self._factory:IsPlaced(entity), "EntityNotFound", Errors.ENTITY_NOT_FOUND, {
			Entity = entity,
		})
		Ensure(
			StructureSpecs.HasValidConstructionWorkAmount(workAmount),
			"InvalidConstructionWorkAmount",
			Errors.INVALID_CONSTRUCTION_WORK_AMOUNT,
			{
				Entity = entity,
				WorkAmount = workAmount,
			}
		)
		Ensure(
			self._factory:IsUnderConstruction(entity),
			"StructureAlreadyCompleted",
			Errors.STRUCTURE_ALREADY_COMPLETED,
			{
				Entity = entity,
			}
		)

		-- Apply work first, then flip lifecycle tags only when the threshold is reached.
		local progress = self._factory:AdvanceConstructionWork(entity, workAmount)
		Ensure(progress ~= nil, "EntityNotFound", Errors.ENTITY_NOT_FOUND, {
			Entity = entity,
		})

		local didComplete = progress.CurrentWork >= progress.RequiredWork
		if didComplete then
			self._factory:ActivateStructure(entity)
		end

		return Result.Ok({
			Completed = not self._factory:IsUnderConstruction(entity),
			Percent = self._factory:GetConstructionPercent(entity),
			JustCompleted = didComplete,
		} :: TConstructionContributionResult)
	end, "Structure:AdvanceConstructionCommand")
end

return AdvanceConstructionCommand
