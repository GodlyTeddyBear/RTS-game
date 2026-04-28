--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseECSEntityFactory = require(ReplicatedStorage.Utilities.BaseECSEntityFactory)
local MiningTypes = require(ReplicatedStorage.Contexts.Mining.Types.MiningTypes)

type TExtractorRecord = MiningTypes.TExtractorRecord
type TResourceNodeRecord = MiningTypes.TResourceNodeRecord
type TOwnerComponent = MiningTypes.TOwnerComponent
type TResourceComponent = MiningTypes.TResourceComponent
type TTimingComponent = MiningTypes.TTimingComponent
type TInstanceRefComponent = MiningTypes.TInstanceRefComponent
type TResourceNodeComponent = MiningTypes.TResourceNodeComponent
type TNodeInstanceComponent = MiningTypes.TNodeInstanceComponent

--[=[
    @class MiningEntityFactory
    Owns creation and lookup for mining extractor and resource-node ECS entities.
    @server
]=]
local MiningEntityFactory = {}
MiningEntityFactory.__index = MiningEntityFactory
setmetatable(MiningEntityFactory, { __index = BaseECSEntityFactory })

-- Creates the Mining entity factory wrapper around the shared ECS base factory.
--[=[
    Creates the Mining entity factory wrapper around the shared ECS base factory.
    @within MiningEntityFactory
    @return MiningEntityFactory -- The new factory instance.
]=]
function MiningEntityFactory.new()
	return setmetatable(BaseECSEntityFactory.new("Mining"), MiningEntityFactory)
end

-- Returns the registry name that supplies the mining component and tag ids.
function MiningEntityFactory:_GetComponentRegistryName(): string
	return "MiningComponentRegistry"
end

-- Verifies that the mining component registry populated every component and tag required by this factory.
function MiningEntityFactory:_OnInit(_registry: any, _name: string, _componentRegistry: any)
	assert(
		self._components ~= nil
			and self._components.OwnerComponent ~= nil
			and self._components.ResourceComponent ~= nil
			and self._components.TimingComponent ~= nil
			and self._components.InstanceRefComponent ~= nil
			and self._components.ResourceNodeComponent ~= nil
			and self._components.NodeInstanceComponent ~= nil
			and self._components.ExtractorActiveTag ~= nil
			and self._components.ResourceNodeTag ~= nil,
		"MiningEntityFactory: missing MiningComponentRegistry components"
	)
end

-- Creates a mining extractor entity from the supplied record.
--[=[
    Creates a mining extractor entity from the supplied record.
    @within MiningEntityFactory
    @param record TExtractorRecord -- The validated extractor record.
    @return number -- The created entity id.
]=]
function MiningEntityFactory:CreateExtractor(record: TExtractorRecord): number
	local components = self:GetComponentsOrThrow()
	local entity = self:_CreateEntity()

	self:_Set(entity, components.OwnerComponent, {
		UserId = record.ownerUserId,
	} :: TOwnerComponent)

	self:_Set(entity, components.ResourceComponent, {
		ResourceType = record.resourceType,
		AmountPerCycle = record.amountPerCycle,
	} :: TResourceComponent)

	self:_Set(entity, components.TimingComponent, {
		IntervalSeconds = record.intervalSeconds,
		ElapsedSeconds = 0,
	} :: TTimingComponent)

	self:_Set(entity, components.InstanceRefComponent, {
		InstanceId = record.instanceId,
	} :: TInstanceRefComponent)

	self:_Add(entity, components.ExtractorActiveTag)
	return entity
end

-- Creates a resource-node entity from the supplied record.
--[=[
    Creates a mining resource-node entity from the supplied record.
    @within MiningEntityFactory
    @param record TResourceNodeRecord -- The validated resource-node record.
    @return number -- The created entity id.
]=]
function MiningEntityFactory:CreateResourceNode(record: TResourceNodeRecord): number
	local components = self:GetComponentsOrThrow()
	local entity = self:_CreateEntity()

	self:_Set(entity, components.ResourceNodeComponent, {
		NodeId = record.nodeId,
		ResourceType = record.resourceType,
	} :: TResourceNodeComponent)

	self:_Set(entity, components.NodeInstanceComponent, {
		Instance = record.instance,
	} :: TNodeInstanceComponent)

	self:_Add(entity, components.ResourceNodeTag)
	return entity
end

-- Returns the owner component for an extractor entity, if present.
--[=[
    Reads the owner component for an extractor entity.
    @within MiningEntityFactory
    @param entity number -- The entity id to read.
    @return TOwnerComponent? -- The owner component, if present.
]=]
function MiningEntityFactory:GetOwner(entity: number): TOwnerComponent?
	local components = self:GetComponentsOrThrow()
	return self:_Get(entity, components.OwnerComponent)
end

-- Returns the resource component for an extractor entity, if present.
--[=[
    Reads the resource component for an extractor entity.
    @within MiningEntityFactory
    @param entity number -- The entity id to read.
    @return TResourceComponent? -- The resource component, if present.
]=]
function MiningEntityFactory:GetResource(entity: number): TResourceComponent?
	local components = self:GetComponentsOrThrow()
	return self:_Get(entity, components.ResourceComponent)
end

-- Returns the timing component for an extractor entity, if present.
--[=[
    Reads the timing component for an extractor entity.
    @within MiningEntityFactory
    @param entity number -- The entity id to read.
    @return TTimingComponent? -- The timing component, if present.
]=]
function MiningEntityFactory:GetTiming(entity: number): TTimingComponent?
	local components = self:GetComponentsOrThrow()
	return self:_Get(entity, components.TimingComponent)
end

-- Updates the stored elapsed cycle time for an extractor entity.
--[=[
    Updates the elapsed cycle time for an extractor entity.
    @within MiningEntityFactory
    @param entity number -- The entity id to update.
    @param elapsedSeconds number -- The elapsed time to store.
]=]
function MiningEntityFactory:SetElapsedSeconds(entity: number, elapsedSeconds: number)
	local timing = self:GetTiming(entity)
	if timing == nil then
		return
	end

	local components = self:GetComponentsOrThrow()
	self:_Set(entity, components.TimingComponent, {
		IntervalSeconds = timing.IntervalSeconds,
		ElapsedSeconds = elapsedSeconds,
	} :: TTimingComponent)
end

-- Returns every active extractor entity id.
--[=[
    Returns the entity ids for all active extractors.
    @within MiningEntityFactory
    @return { number } -- The active extractor entity ids.
]=]
function MiningEntityFactory:QueryActiveEntities(): { number }
	local components = self:GetComponentsOrThrow()
	return self:CollectQuery(components.ExtractorActiveTag)
end

-- Returns the resource-node component for a node entity, if present.
--[=[
    Reads the resource-node component for a node entity.
    @within MiningEntityFactory
    @param entity number -- The entity id to read.
    @return TResourceNodeComponent? -- The resource-node component, if present.
]=]
function MiningEntityFactory:GetResourceNode(entity: number): TResourceNodeComponent?
	local components = self:GetComponentsOrThrow()
	return self:_Get(entity, components.ResourceNodeComponent)
end

-- Returns the backing BasePart for a resource-node entity, if present.
--[=[
    Reads the backing `BasePart` for a resource-node entity.
    @within MiningEntityFactory
    @param entity number -- The entity id to read.
    @return BasePart? -- The backing part, if present.
]=]
function MiningEntityFactory:GetNodeInstance(entity: number): BasePart?
	local components = self:GetComponentsOrThrow()
	local nodeInstance = self:_Get(entity, components.NodeInstanceComponent) :: TNodeInstanceComponent?
	return if nodeInstance == nil then nil else nodeInstance.Instance
end

-- Returns every resource-node entity id.
--[=[
    Returns the entity ids for all registered resource nodes.
    @within MiningEntityFactory
    @return { number } -- The resource-node entity ids.
]=]
function MiningEntityFactory:QueryResourceNodes(): { number }
	local components = self:GetComponentsOrThrow()
	return self:CollectQuery(components.ResourceNodeTag)
end

-- Returns the resource-node entity ids that match a resource type.
--[=[
    Returns the resource-node entity ids that match the supplied resource type.
    @within MiningEntityFactory
    @param resourceType string -- The resource type to match.
    @return { number } -- The matching resource-node entity ids.
]=]
function MiningEntityFactory:QueryResourceNodesByType(resourceType: string): { number }
	local matches = {}
	for _, entity in ipairs(self:QueryResourceNodes()) do
		local resourceNode = self:GetResourceNode(entity)
		if resourceNode ~= nil and resourceNode.ResourceType == resourceType then
			table.insert(matches, entity)
		end
	end
	return matches
end

-- Finds a resource-node entity by its backing instance, if one is registered.
--[=[
    Finds the resource-node entity that owns the supplied `BasePart`.
    @within MiningEntityFactory
    @param instance BasePart -- The backing resource part.
    @return number? -- The matching entity id, if present.
]=]
function MiningEntityFactory:FindResourceNodeByInstance(instance: BasePart): number?
	for _, entity in ipairs(self:QueryResourceNodes()) do
		local nodeInstance = self:GetNodeInstance(entity)
		if nodeInstance == instance then
			return entity
		end
	end

	return nil
end

-- Marks an entity for destruction after removing mining tags that would keep it in active queries.
--[=[
    Marks a mining entity for destruction.
    @within MiningEntityFactory
    @param entity number? -- The entity id to delete.
]=]
function MiningEntityFactory:DeleteEntity(entity: number?)
	if entity == nil then
		return
	end

	local components = self:GetComponentsOrThrow()
	if self:_Has(entity, components.ExtractorActiveTag) then
		self:_Remove(entity, components.ExtractorActiveTag)
	end

	if self:_Has(entity, components.ResourceNodeTag) then
		self:_Remove(entity, components.ResourceNodeTag)
	end

	self:MarkForDestruction(entity)
end

-- Marks every active mining entity for destruction.
--[=[
    Marks all mining entities for destruction.
    @within MiningEntityFactory
]=]
function MiningEntityFactory:DeleteAll()
	local allEntities = {}
	-- Collect both extractor and resource-node entities before deleting so each entity is processed once.
	for _, entity in ipairs(self:QueryActiveEntities()) do
		table.insert(allEntities, entity)
	end
	for _, entity in ipairs(self:QueryResourceNodes()) do
		table.insert(allEntities, entity)
	end

	-- Defer the actual deletion to the base factory so the queue flush stays centralized.
	for _, entity in ipairs(allEntities) do
		self:DeleteEntity(entity)
	end
end

-- Flushes the deferred destruction queue.
--[=[
    Flushes the queued mining entity deletions.
    @within MiningEntityFactory
    @return boolean -- Whether the flush succeeded.
]=]
function MiningEntityFactory:FlushPendingDeletes(): boolean
	return self:FlushDestructionQueue()
end

return MiningEntityFactory
