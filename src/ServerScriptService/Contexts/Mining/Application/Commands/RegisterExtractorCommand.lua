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

local RegisterExtractorCommand = {}
RegisterExtractorCommand.__index = RegisterExtractorCommand

function RegisterExtractorCommand.new()
	return setmetatable({}, RegisterExtractorCommand)
end

function RegisterExtractorCommand:Init(registry: any, _name: string)
	self._factory = registry:Get("MiningEntityFactory")
end

function RegisterExtractorCommand:Execute(record: StructureRecord): Result.Result<number?>
	Ensure(type(record) == "table", "InvalidExtractorRecord", Errors.INVALID_EXTRACTOR_RECORD)

	if record.structureType ~= MiningConfig.EXTRACTOR_STRUCTURE_TYPE then
		return Ok(nil)
	end

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

	local extractorRecord: TExtractorRecord = {
		instanceId = record.instanceId,
		ownerUserId = record.ownerUserId,
		resourceType = record.resourceType :: string,
		intervalSeconds = MiningConfig.BASE_RATE_SECONDS,
		amountPerCycle = MiningConfig.BASE_AMOUNT_PER_CYCLE,
	}

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
