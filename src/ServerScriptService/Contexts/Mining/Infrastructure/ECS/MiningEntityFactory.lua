--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseECSEntityFactory = require(ReplicatedStorage.Utilities.BaseECSEntityFactory)
local MiningTypes = require(ReplicatedStorage.Contexts.Mining.Types.MiningTypes)

type TExtractorRecord = MiningTypes.TExtractorRecord
type TOwnerComponent = MiningTypes.TOwnerComponent
type TResourceComponent = MiningTypes.TResourceComponent
type TTimingComponent = MiningTypes.TTimingComponent
type TInstanceRefComponent = MiningTypes.TInstanceRefComponent

local MiningEntityFactory = {}
MiningEntityFactory.__index = MiningEntityFactory
setmetatable(MiningEntityFactory, { __index = BaseECSEntityFactory })

function MiningEntityFactory.new()
	return setmetatable(BaseECSEntityFactory.new("Mining"), MiningEntityFactory)
end

function MiningEntityFactory:_GetComponentRegistryName(): string
	return "MiningComponentRegistry"
end

function MiningEntityFactory:_OnInit(_registry: any, _name: string, _componentRegistry: any)
	assert(
		self._components ~= nil
			and self._components.OwnerComponent ~= nil
			and self._components.ResourceComponent ~= nil
			and self._components.TimingComponent ~= nil
			and self._components.InstanceRefComponent ~= nil
			and self._components.ActiveTag ~= nil,
		"MiningEntityFactory: missing MiningComponentRegistry components"
	)
end

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

	self:_Add(entity, components.ActiveTag)
	return entity
end

function MiningEntityFactory:GetOwner(entity: number): TOwnerComponent?
	local components = self:GetComponentsOrThrow()
	return self:_Get(entity, components.OwnerComponent)
end

function MiningEntityFactory:GetResource(entity: number): TResourceComponent?
	local components = self:GetComponentsOrThrow()
	return self:_Get(entity, components.ResourceComponent)
end

function MiningEntityFactory:GetTiming(entity: number): TTimingComponent?
	local components = self:GetComponentsOrThrow()
	return self:_Get(entity, components.TimingComponent)
end

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

function MiningEntityFactory:QueryActiveEntities(): { number }
	local components = self:GetComponentsOrThrow()
	return self:CollectQuery(components.ActiveTag)
end

function MiningEntityFactory:DeleteEntity(entity: number?)
	if entity == nil then
		return
	end

	local components = self:GetComponentsOrThrow()
	if self:_Has(entity, components.ActiveTag) then
		self:_Remove(entity, components.ActiveTag)
	end

	self:MarkForDestruction(entity)
end

function MiningEntityFactory:DeleteAll()
	for _, entity in ipairs(self:QueryActiveEntities()) do
		self:DeleteEntity(entity)
	end
end

function MiningEntityFactory:FlushPendingDeletes(): boolean
	return self:FlushDestructionQueue()
end

return MiningEntityFactory
