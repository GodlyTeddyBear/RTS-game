--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Janitor = require(ReplicatedStorage.Packages.Janitor)
local ECSIdentitySchema = require(ReplicatedStorage.Utilities.ECS.Reveal.ECSIdentitySchema)

export type ECSDiscoveryRecord = {
	Instance: Instance,
	EntityId: string,
	EntityType: string,
	Tags: { [string]: boolean },
	Order: number,
}

type TConnectionPair = {
	Added: RBXScriptConnection,
	Removed: RBXScriptConnection,
}

export type TCollectionServiceLike = {
	GetAllTags: (self: any) -> { string },
	GetTagged: (self: any, tag: string) -> { Instance },
	GetInstanceAddedSignal: (self: any, tag: string) -> RBXScriptSignal,
	GetInstanceRemovedSignal: (self: any, tag: string) -> RBXScriptSignal,
}

export type TSchemaLike = {
	ATTR_ENTITY_ID: string,
	ATTR_ENTITY_TYPE: string,
	DEFAULT_NAMESPACE: string,
	IsEntityTag: (tag: string, namespace: string?) -> boolean,
}

export type TConfig = {
	CollectionService: TCollectionServiceLike?,
	Schema: TSchemaLike?,
	Namespace: string?,
	PollIntervalSeconds: number?,
	EnableTagPolling: boolean?,
}

--[=[
	Client-side index for discovering revealed ECS instances via tags and attributes.
	Preferred access: `require(ReplicatedStorage.Utilities.ECS).DiscoveryIndexService`.
	@class ClientECSDiscoveryIndexService
	@client
]=]
local ClientECSDiscoveryIndexService = {}
ClientECSDiscoveryIndexService.__index = ClientECSDiscoveryIndexService

function ClientECSDiscoveryIndexService.new(config: TConfig?)
	local resolvedConfig = config or {}
	local self = setmetatable({}, ClientECSDiscoveryIndexService)

	self._janitor = Janitor.new()
	self._service = resolvedConfig.CollectionService or CollectionService
	self._schema = resolvedConfig.Schema or ECSIdentitySchema
	self._namespace = resolvedConfig.Namespace or self._schema.DEFAULT_NAMESPACE
	self._pollIntervalSeconds = resolvedConfig.PollIntervalSeconds or 2
	self._enableTagPolling = if resolvedConfig.EnableTagPolling == nil then true else resolvedConfig.EnableTagPolling

	self._tagConnections = {} :: { [string]: TConnectionPair }
	self._recordsByInstance = {} :: { [Instance]: ECSDiscoveryRecord }
	self._insertionOrder = {} :: { Instance }
	self._nextOrder = 1
	self._isRunning = false
	return self
end

function ClientECSDiscoveryIndexService:Start()
	if self._isRunning then
		return
	end
	self._isRunning = true
	self:_RefreshTagSubscriptions()

	if not self._enableTagPolling then
		return
	end

	self._janitor:Add(
		task.spawn(function()
			while self._isRunning do
				task.wait(self._pollIntervalSeconds)
				self:_RefreshTagSubscriptions()
			end
		end),
		true
	)
end

function ClientECSDiscoveryIndexService:Destroy()
	self._isRunning = false
	for _, connectionPair in self._tagConnections do
		connectionPair.Added:Disconnect()
		connectionPair.Removed:Disconnect()
	end
	table.clear(self._tagConnections)
	self._janitor:Destroy()
end

function ClientECSDiscoveryIndexService:FindFirstByTypeAndId(entityType: string, entityId: string): Instance?
	local result: Instance? = nil
	self:_IterateLiveRecords(function(instance, record)
		if result then
			return
		end
		if record.EntityType == entityType and record.EntityId == entityId then
			result = instance
		end
	end)
	return result
end

function ClientECSDiscoveryIndexService:FindAllByTypeAndId(entityType: string, entityId: string): { Instance }
	local results = {}
	self:_IterateLiveRecords(function(instance, record)
		if record.EntityType == entityType and record.EntityId == entityId then
			table.insert(results, instance)
		end
	end)
	return results
end

function ClientECSDiscoveryIndexService:FindFirstByTag(tag: string): Instance?
	local result: Instance? = nil
	self:_IterateLiveRecords(function(instance, record)
		if result then
			return
		end
		if record.Tags[tag] then
			result = instance
		end
	end)
	return result
end

function ClientECSDiscoveryIndexService:FindAllByTag(tag: string): { Instance }
	local results = {}
	self:_IterateLiveRecords(function(instance, record)
		if record.Tags[tag] then
			table.insert(results, instance)
		end
	end)
	return results
end

function ClientECSDiscoveryIndexService:FindAllByTagPrefix(prefix: string): { Instance }
	local results = {}
	self:_IterateLiveRecords(function(instance, record)
		for candidateTag in record.Tags do
			if string.sub(candidateTag, 1, #prefix) == prefix then
				table.insert(results, instance)
				break
			end
		end
	end)
	return results
end

function ClientECSDiscoveryIndexService:FindFirstByAttribute(attributeName: string, attributeValue: any): Instance?
	local result: Instance? = nil
	self:_IterateLiveRecords(function(instance, _)
		if result then
			return
		end
		if instance:GetAttribute(attributeName) == attributeValue then
			result = instance
		end
	end)
	return result
end

function ClientECSDiscoveryIndexService:FindAllByAttribute(attributeName: string, attributeValue: any): { Instance }
	local results = {}
	self:_IterateLiveRecords(function(instance, _)
		if instance:GetAttribute(attributeName) == attributeValue then
			table.insert(results, instance)
		end
	end)
	return results
end

function ClientECSDiscoveryIndexService:_IterateLiveRecords(callback: (Instance, ECSDiscoveryRecord) -> ())
	for _, instance in self._insertionOrder do
		local record = self._recordsByInstance[instance]
		if record then
			if instance.Parent then
				callback(instance, record)
			else
				self:_UnindexInstance(instance)
			end
		end
	end
end

function ClientECSDiscoveryIndexService:_RefreshTagSubscriptions()
	for _, tag in self._service:GetAllTags() do
		if self._schema.IsEntityTag(tag, self._namespace) and not self._tagConnections[tag] then
			self:_SubscribeToTag(tag)
		end
	end
end

function ClientECSDiscoveryIndexService:_SubscribeToTag(tag: string)
	local added = self._service:GetInstanceAddedSignal(tag):Connect(function(instance)
		self:_OnTagAdded(tag, instance)
	end)
	local removed = self._service:GetInstanceRemovedSignal(tag):Connect(function(instance)
		self:_OnTagRemoved(tag, instance)
	end)
	self._tagConnections[tag] = { Added = added, Removed = removed }

	for _, instance in self._service:GetTagged(tag) do
		self:_OnTagAdded(tag, instance)
	end
end

function ClientECSDiscoveryIndexService:_OnTagAdded(tag: string, instance: Instance)
	local entityType = instance:GetAttribute(self._schema.ATTR_ENTITY_TYPE)
	local entityId = instance:GetAttribute(self._schema.ATTR_ENTITY_ID)
	if type(entityType) ~= "string" or type(entityId) ~= "string" then
		return
	end

	local record = self._recordsByInstance[instance]
	if not record then
		record = {
			Instance = instance,
			EntityType = entityType,
			EntityId = entityId,
			Tags = {},
			Order = self._nextOrder,
		}
		self._recordsByInstance[instance] = record
		self._nextOrder += 1
		table.insert(self._insertionOrder, instance)
	end

	record.Tags[tag] = true
end

function ClientECSDiscoveryIndexService:_OnTagRemoved(tag: string, instance: Instance)
	local record = self._recordsByInstance[instance]
	if not record then
		return
	end

	record.Tags[tag] = nil
	if not self:_RecordHasScopedTags(record) then
		self:_UnindexInstance(instance)
	end
end

function ClientECSDiscoveryIndexService:_RecordHasScopedTags(record: ECSDiscoveryRecord): boolean
	for tag in record.Tags do
		if self._schema.IsEntityTag(tag, self._namespace) then
			return true
		end
	end
	return false
end

function ClientECSDiscoveryIndexService:_UnindexInstance(instance: Instance)
	self._recordsByInstance[instance] = nil
end

return ClientECSDiscoveryIndexService
