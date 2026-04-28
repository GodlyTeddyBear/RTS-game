--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MiningConfig = require(ReplicatedStorage.Contexts.Mining.Config.MiningConfig)
local BaseCommand = require(ReplicatedStorage.Utilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)

local MiningSpecs = require(script.Parent.Parent.Parent.MiningDomain.Specs.MiningSpecs)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok = Result.Ok
local Try = Result.Try
local Ensure = Result.Ensure

--[=[
    @class GatherResourceCommand
    Validates manual gather requests and routes successful gathers into the economy context.
    @server
]=]
local GatherResourceCommand = {}
GatherResourceCommand.__index = GatherResourceCommand
setmetatable(GatherResourceCommand, BaseCommand)

-- Creates the manual-gather command wrapper.
--[=[
    Creates the gather-resource command wrapper.
    @within GatherResourceCommand
    @return GatherResourceCommand -- The new command instance.
]=]
function GatherResourceCommand.new()
	local self = BaseCommand.new("Mining", "GatherResourceCommand")
	return setmetatable(self, GatherResourceCommand)
end

-- Resolves the mining interaction service during init.
--[=[
    Resolves the mining interaction service during init.
    @within GatherResourceCommand
    @param registry any -- The dependency registry for this context.
    @param _name string -- The registered module name.
]=]
function GatherResourceCommand:Init(registry: any, _name: string)
	self:_RequireDependency(registry, "_interactionService", "ResourceGatherInteractionService")
end

-- Resolves the economy context once external services are available.
--[=[
    Resolves the economy context once external services are available.
    @within GatherResourceCommand
    @param registry any -- The dependency registry for this context.
    @param _name string -- The registered module name.
]=]
function GatherResourceCommand:Start(registry: any, _name: string)
	self:_RequireDependency(registry, "_economyContext", "EconomyContext")
end

-- Validates the click request and awards manual gather resources when the cooldown allows it.
--[=[
    Validates the click request and awards manual gather resources when the cooldown allows it.
    @within GatherResourceCommand
    @param player Player -- The player requesting the gather.
    @param resourcePart BasePart -- The clicked resource part.
    @return Result.Result<nil> -- Whether the gather request completed.
]=]
function GatherResourceCommand:Execute(player: Player, resourcePart: BasePart): Result.Result<nil>
	-- Validate the caller and resource node before any interaction lookup.
	Ensure(typeof(player) == "Instance" and player:IsA("Player"), "InvalidPlayer", Errors.INVALID_PLAYER)
	Ensure(MiningSpecs.HasValidResourceNodePart(resourcePart), "InvalidResourceNode", Errors.INVALID_RESOURCE_NODE)

	-- Resolve the canonical node record so the economy grant uses the registered resource type.
	local _entity, resourceNode = self._interactionService:GetResourceNodeForPart(resourcePart)
	Ensure(resourceNode ~= nil, "UnregisteredResourceNode", Errors.UNREGISTERED_RESOURCE_NODE, {
		PartName = resourcePart.Name,
		PartPath = resourcePart:GetFullName(),
	})
	Ensure(MiningSpecs.IsKnownResourceType(resourceNode.ResourceType), "UnknownResourceNodeType", Errors.UNKNOWN_RESOURCE_NODE_TYPE, {
		ResourceType = resourceNode.ResourceType,
	})
	Ensure(MiningSpecs.HasValidAmount(MiningConfig.MANUAL_GATHER_AMOUNT), "InvalidAmount", Errors.INVALID_AMOUNT)

	-- Reject gathers that are still inside the cooldown window.
	local now = os.clock()
	if not self._interactionService:CanGather(player, resourcePart, now) then
		return Ok(nil)
	end

	-- Grant the configured amount and then record the gather timestamp.
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
