--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MiningConfig = require(ReplicatedStorage.Contexts.Mining.Config.MiningConfig)
local Result = require(ReplicatedStorage.Utilities.Result)

local MiningSpecs = require(script.Parent.Parent.Parent.MiningDomain.Specs.MiningSpecs)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok = Result.Ok
local Try = Result.Try
local Ensure = Result.Ensure

local GatherResourceCommand = {}
GatherResourceCommand.__index = GatherResourceCommand

function GatherResourceCommand.new()
	return setmetatable({}, GatherResourceCommand)
end

function GatherResourceCommand:Init(registry: any, _name: string)
	self._interactionService = registry:Get("ResourceGatherInteractionService")
end

function GatherResourceCommand:Start(registry: any, _name: string)
	self._economyContext = registry:Get("EconomyContext")
end

function GatherResourceCommand:Execute(player: Player, resourcePart: BasePart): Result.Result<nil>
	Ensure(typeof(player) == "Instance" and player:IsA("Player"), "InvalidPlayer", Errors.INVALID_PLAYER)
	Ensure(MiningSpecs.HasValidResourceNodePart(resourcePart), "InvalidResourceNode", Errors.INVALID_RESOURCE_NODE)

	local _entity, resourceNode = self._interactionService:GetResourceNodeForPart(resourcePart)
	Ensure(resourceNode ~= nil, "UnregisteredResourceNode", Errors.UNREGISTERED_RESOURCE_NODE, {
		PartName = resourcePart.Name,
		PartPath = resourcePart:GetFullName(),
	})
	Ensure(MiningSpecs.IsKnownResourceType(resourceNode.ResourceType), "UnknownResourceNodeType", Errors.UNKNOWN_RESOURCE_NODE_TYPE, {
		ResourceType = resourceNode.ResourceType,
	})
	Ensure(MiningSpecs.HasValidAmount(MiningConfig.MANUAL_GATHER_AMOUNT), "InvalidAmount", Errors.INVALID_AMOUNT)

	local now = os.clock()
	if not self._interactionService:CanGather(player, resourcePart, now) then
		return Ok(nil)
	end

	Try(self._economyContext:AddResource(player, resourceNode.ResourceType, MiningConfig.MANUAL_GATHER_AMOUNT))
	self._interactionService:MarkGathered(player, resourcePart, now)

	Result.MentionSuccess("Mining:GatherResourceCommand", "Gathered manual resource", {
		UserId = player.UserId,
		ResourceType = resourceNode.ResourceType,
		Amount = MiningConfig.MANUAL_GATHER_AMOUNT,
	})

	return Ok(nil)
end

return GatherResourceCommand
