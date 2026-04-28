--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local MiningConfig = require(ReplicatedStorage.Contexts.Mining.Config.MiningConfig)
local MiningTypes = require(ReplicatedStorage.Contexts.Mining.Types.MiningTypes)
local PlacementTypes = require(ReplicatedStorage.Contexts.Placement.Types.PlacementTypes)
local MiningSpecs = require(script.Parent.Parent.Parent.MiningDomain.Specs.MiningSpecs)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok = Result.Ok
local Ensure = Result.Ensure

type StructureRecord = PlacementTypes.StructureRecord
type TExtractorRecord = MiningTypes.TExtractorRecord

--[=[
    @class RegisterExtractorCommand
    Validates extractor placement records and creates mining extractor entities.
    @server
]=]
local RegisterExtractorCommand = {}
RegisterExtractorCommand.__index = RegisterExtractorCommand

-- Creates the command wrapper.
--[=[
    Creates the register-extractor command wrapper.
    @within RegisterExtractorCommand
    @return RegisterExtractorCommand -- The new command instance.
]=]
function RegisterExtractorCommand.new()
	return setmetatable({}, RegisterExtractorCommand)
end

-- Resolves the mining entity factory during init.
--[=[
    Resolves the mining entity factory during init.
    @within RegisterExtractorCommand
    @param registry any -- The dependency registry for this context.
    @param _name string -- The registered module name.
]=]
function RegisterExtractorCommand:Init(registry: any, _name: string)
	self._factory = registry:Get("MiningEntityFactory")
end

-- Validates a placement record and registers an extractor when the structure matches the mining extractor type.
--[=[
    Validates a placement record and registers an extractor when the structure matches the mining extractor type.
    @within RegisterExtractorCommand
    @param record StructureRecord -- The placement record to validate.
    @return Result.Result<number?> -- The created entity id, or `nil` when the structure is ignored.
]=]
function RegisterExtractorCommand:Execute(record: StructureRecord): Result.Result<number?>
	-- Reject malformed placement records before any mining-specific checks run.
	Ensure(type(record) == "table", "InvalidExtractorRecord", Errors.INVALID_EXTRACTOR_RECORD)

	-- Ignore non-extractor structures so the placement stream can include unrelated build types.
	if record.structureType ~= MiningConfig.EXTRACTOR_STRUCTURE_TYPE then
		return Ok(nil)
	end

	-- Validate the record fields before creating the ECS payload.
	Ensure(MiningSpecs.HasValidOwner(record.ownerUserId), "InvalidOwner", Errors.INVALID_OWNER, {
		ownerUserId = record.ownerUserId,
	})
	Ensure(MiningSpecs.HasValidInstanceId(record.instanceId), "InvalidInstanceId", Errors.INVALID_INSTANCE_ID, {
		instanceId = record.instanceId,
	})
	Ensure(MiningSpecs.HasValidResourceType(record.resourceType), "InvalidResourceType", Errors.INVALID_RESOURCE_TYPE, {
		resourceType = record.resourceType,
	})
	Ensure(MiningSpecs.HasValidInterval(MiningConfig.BASE_RATE_SECONDS), "InvalidInterval", Errors.INVALID_INTERVAL)
	Ensure(MiningSpecs.HasValidAmount(MiningConfig.BASE_AMOUNT_PER_CYCLE), "InvalidAmount", Errors.INVALID_AMOUNT)

	-- Build the immutable extractor payload that the factory expects.
	local extractorRecord: TExtractorRecord = {
		instanceId = record.instanceId,
		ownerUserId = record.ownerUserId,
		resourceType = record.resourceType :: string,
		intervalSeconds = MiningConfig.BASE_RATE_SECONDS,
		amountPerCycle = MiningConfig.BASE_AMOUNT_PER_CYCLE,
	}

	-- Register the entity and emit a success mention for observability.
	local entity = self._factory:CreateExtractor(extractorRecord)
	Result.MentionSuccess("Mining:RegisterExtractorCommand", "Registered extractor entity", {
		Entity = entity,
		InstanceId = record.instanceId,
		OwnerUserId = record.ownerUserId,
		ResourceType = record.resourceType,
	})

	return Ok(entity)
end

return RegisterExtractorCommand
