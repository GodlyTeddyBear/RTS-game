--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local PlacementTypes = require(ReplicatedStorage.Contexts.Placement.Types.PlacementTypes)

local Ok = Result.Ok
local Try = Result.Try

type StructureRecord = PlacementTypes.StructureRecord

--[=[
	@class RegisterStructureCommand
	Creates structure entities from validated placement records.
	@server
]=]
local RegisterStructureCommand = {}
RegisterStructureCommand.__index = RegisterStructureCommand

--[=[
	Creates a new registration command wrapper.
	@within RegisterStructureCommand
	@return RegisterStructureCommand -- The new command instance.
]=]
function RegisterStructureCommand.new()
	return setmetatable({}, RegisterStructureCommand)
end

--[=[
	Resolves the policy and entity factory for structure registration.
	@within RegisterStructureCommand
	@param registry any -- The dependency registry for this context.
	@param _name string -- The registered module name.
]=]
function RegisterStructureCommand:Init(registry: any, _name: string)
	self._policy = registry:Get("RegisterStructurePolicy")
	self._factory = registry:Get("StructureEntityFactory")
end

--[=[
	Validates the record and creates the structure entity.
	@within RegisterStructureCommand
	@param record StructureRecord -- The placement record to register.
	@return Result.Result<number> -- The ECS entity id for the new structure.
]=]
function RegisterStructureCommand:Execute(record: StructureRecord): Result.Result<number>
	return Result.Catch(function()
		-- Resolve the canonical structure data before mutating the ECS world.
		local resolved = Try(self._policy:Check(record))

		-- Create the entity only after the record has been proven valid.
		local entity = self._factory:CreateStructure(resolved)

		-- Emit a milestone for traceability when a structure becomes active.
		Result.MentionSuccess("Structure:RegisterStructureCommand", "Registered structure entity", {
			instanceId = resolved.instanceId,
			structureType = resolved.structureType,
			entity = entity,
		})

		return Ok(entity)
	end, "Structure:RegisterStructureCommand")
end

return RegisterStructureCommand
