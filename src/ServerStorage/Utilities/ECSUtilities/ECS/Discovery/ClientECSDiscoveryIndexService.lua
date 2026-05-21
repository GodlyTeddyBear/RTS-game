--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Janitor = require(ReplicatedStorage.Packages.Janitor)
local ECSIdentitySchema = require(ReplicatedStorage.Utilities.ECS.Reveal.ECSIdentitySchema)

--[=[
	@interface ECSDiscoveryRecord
	@within ClientECSDiscoveryIndexService
	.Instance Instance -- Discovered instance.
	.EntityId string -- Scoped entity id recovered from attributes.
	.EntityType string -- Logical entity type recovered from attributes.
	.Tags { [string]: boolean } -- Tags currently associated with the instance.
	.Order number -- Stable insertion order used for deterministic iteration.
]=]
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

--[=[
	@interface TCollectionServiceLike
	@within ClientECSDiscoveryIndexService
	.GetAllTags () -> { string } -- Returns every tag currently registered in CollectionService.
	.GetTagged (tag: string) -> { Instance } -- Returns every instance already tagged with the given tag.
	.GetInstanceAddedSignal (tag: string) -> RBXScriptSignal -- Signal fired when an instance gains the tag.
	.GetInstanceRemovedSignal (tag: string) -> RBXScriptSignal -- Signal fired when an instance loses the tag.
]=]
export type TCollectionServiceLike = {
	GetAllTags: (self: any) -> { string },
	GetTagged: (self: any, tag: string) -> { Instance },
	GetInstanceAddedSignal: (self: any, tag: string) -> RBXScriptSignal,
	GetInstanceRemovedSignal: (self: any, tag: string) -> RBXScriptSignal,
}

--[=[
	@interface TSchemaLike
	@within ClientECSDiscoveryIndexService
	.ATTR_ENTITY_ID string -- Attribute used to recover the entity id.
	.ATTR_ENTITY_TYPE string -- Attribute used to recover the entity type.
	.DEFAULT_NAMESPACE string -- Default namespace used when no override is supplied.
	.IsEntityTag (tag: string, namespace: string?) -> boolean -- Checks whether a tag belongs to the ECS identity namespace.
]=]
export type TSchemaLike = {
	ATTR_ENTITY_ID: string,
	ATTR_ENTITY_TYPE: string,
	DEFAULT_NAMESPACE: string,
	IsEntityTag: (tag: string, namespace: string?) -> boolean,
}

--[=[
	@interface TConfig
	@within ClientECSDiscoveryIndexService
	.CollectionService TCollectionServiceLike? -- Optional service override used for tests.
	.Schema TSchemaLike? -- Optional identity schema override used to resolve tag and attribute names.
	.Namespace string? -- Optional namespace override used when matching entity tags.
	.PollIntervalSeconds number? -- Seconds between tag subscription refreshes.
	.EnableTagPolling boolean? -- Enables periodic tag discovery refreshes.
]=]
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
-- ── Types ──────────────────────────────────────────────────────────────────

local ClientECSDiscoveryIndexService = {}
ClientECSDiscoveryIndexService.__index = ClientECSDiscoveryIndexService

-- ── Public ─────────────────────────────────────────────────────────────────

--[=[
	Constructs a client-side discovery index.
	@within ClientECSDiscoveryIndexService
	@param config TConfig? -- Optional dependency and polling overrides.
	@return ClientECSDiscoveryIndexService -- New discovery index instance.
]=]
function ClientECSDiscoveryIndexService.new(config: TConfig?)
	-- Resolve dependencies and configuration overrides up front.
	local resolvedConfig = config or {}
	local self = setmetatable({}, ClientECSDiscoveryIndexService)

	-- Initialize runtime state and cached lookup tables.
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

--[=[
	Starts tracking ECS reveal tags on the client.
	@within ClientECSDiscoveryIndexService
]=]
function ClientECSDiscoveryIndexService:Start()
	-- Avoid duplicate watchers if the index is already running.
	if self._isRunning then
		return
	end

	-- Subscribe to existing tags before optionally starting the refresh loop.
	self._isRunning = true
	self:_RefreshTagSubscriptions()

	-- Skip the polling loop when the caller explicitly opts out.
	if not self._enableTagPolling then
		return
	end

	-- Keep tag subscriptions fresh when tags are registered after startup.
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

--[=[
	Stops tracking ECS reveal tags and clears all cached state.
	@within ClientECSDiscoveryIndexService
]=]
function ClientECSDiscoveryIndexService:Destroy()
	-- Stop the polling loop before tearing down connections.
	self._isRunning = false

	-- Disconnect tag subscriptions and drop the connection cache.
	for _, connectionPair in self._tagConnections do
		connectionPair.Added:Disconnect()
		connectionPair.Removed:Disconnect()
	end
	table.clear(self._tagConnections)
	self._janitor:Destroy()
end

--[=[
	Finds the first discovered instance for an entity type and id.
	@within ClientECSDiscoveryIndexService
	@param entityType string -- Logical entity type to match.
	@param entityId string -- Scoped entity id to match.
	@return Instance? -- First live instance that matches the lookup, if any.
]=]
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

--[=[
	Finds every discovered instance for an entity type and id.
	@within ClientECSDiscoveryIndexService
	@param entityType string -- Logical entity type to match.
	@param entityId string -- Scoped entity id to match.
	@return { Instance } -- All live instances that match the lookup.
]=]
function ClientECSDiscoveryIndexService:FindAllByTypeAndId(entityType: string, entityId: string): { Instance }
	local results = {}
	self:_IterateLiveRecords(function(instance, record)
		if record.EntityType == entityType and record.EntityId == entityId then
			table.insert(results, instance)
		end
	end)
	return results
end

--[=[
	Finds the first discovered instance that has a specific tag.
	@within ClientECSDiscoveryIndexService
	@param tag string -- Tag name to match.
	@return Instance? -- First live instance that has the tag, if any.
]=]
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

--[=[
	Finds every discovered instance that has a specific tag.
	@within ClientECSDiscoveryIndexService
	@param tag string -- Tag name to match.
	@return { Instance } -- All live instances that have the tag.
]=]
function ClientECSDiscoveryIndexService:FindAllByTag(tag: string): { Instance }
	local results = {}
	self:_IterateLiveRecords(function(instance, record)
		if record.Tags[tag] then
			table.insert(results, instance)
		end
	end)
	return results
end

--[=[
	Finds every discovered instance that has a tag with a given prefix.
	@within ClientECSDiscoveryIndexService
	@param prefix string -- Tag prefix to match.
	@return { Instance } -- All live instances that have a matching tag prefix.
]=]
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

--[=[
	Finds the first discovered instance with a matching attribute value.
	@within ClientECSDiscoveryIndexService
	@param attributeName string -- Attribute name to inspect.
	@param attributeValue any -- Attribute value to match.
	@return Instance? -- First live instance that matches the attribute lookup, if any.
]=]
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

--[=[
	Finds every discovered instance with a matching attribute value.
	@within ClientECSDiscoveryIndexService
	@param attributeName string -- Attribute name to inspect.
	@param attributeValue any -- Attribute value to match.
	@return { Instance } -- All live instances that match the attribute lookup.
]=]
function ClientECSDiscoveryIndexService:FindAllByAttribute(attributeName: string, attributeValue: any): { Instance }
	local results = {}
	self:_IterateLiveRecords(function(instance, _)
		if instance:GetAttribute(attributeName) == attributeValue then
			table.insert(results, instance)
		end
	end)
	return results
end

-- ── Private ────────────────────────────────────────────────────────────────

-- Keeps iteration deterministic while dropping stale records when instances are removed.
function ClientECSDiscoveryIndexService:_IterateLiveRecords(callback: (Instance, ECSDiscoveryRecord) -> ())
	-- Walk the insertion order so lookups return predictable results.
	for _, instance in self._insertionOrder do
		local record = self._recordsByInstance[instance]
		if record then
			if instance.Parent then
				callback(instance, record)
			else
				-- Remove records for destroyed or reparented-away instances on sight.
				self:_UnindexInstance(instance)
			end
		end
	end
end

-- Subscribes to any entity tags that already exist so late-created tags are not missed.
function ClientECSDiscoveryIndexService:_RefreshTagSubscriptions()
	for _, tag in self._service:GetAllTags() do
		if self._schema.IsEntityTag(tag, self._namespace) and not self._tagConnections[tag] then
			self:_SubscribeToTag(tag)
		end
	end
end

-- Listens for future additions and removals for a single entity tag.
function ClientECSDiscoveryIndexService:_SubscribeToTag(tag: string)
	-- Hook tag-added events so records appear as soon as the tag is replicated.
	local added = self._service:GetInstanceAddedSignal(tag):Connect(function(instance)
		self:_OnTagAdded(tag, instance)
	end)

	-- Hook tag-removed events so records disappear when the tag is cleared.
	local removed = self._service:GetInstanceRemovedSignal(tag):Connect(function(instance)
		self:_OnTagRemoved(tag, instance)
	end)
	self._tagConnections[tag] = { Added = added, Removed = removed }

	-- Backfill any instances that already have the tag before the subscription existed.
	for _, instance in self._service:GetTagged(tag) do
		self:_OnTagAdded(tag, instance)
	end
end

-- Indexes an instance once the reveal attributes are present.
function ClientECSDiscoveryIndexService:_OnTagAdded(tag: string, instance: Instance)
	-- Require both identity attributes before the instance is eligible for lookup.
	local entityType = instance:GetAttribute(self._schema.ATTR_ENTITY_TYPE)
	local entityId = instance:GetAttribute(self._schema.ATTR_ENTITY_ID)
	if type(entityType) ~= "string" or type(entityId) ~= "string" then
		return
	end

	-- Create the record lazily so repeated tag notifications reuse the same entry.
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

-- Removes a tag from the cached record and discards the record when no scoped tags remain.
function ClientECSDiscoveryIndexService:_OnTagRemoved(tag: string, instance: Instance)
	local record = self._recordsByInstance[instance]
	if not record then
		return
	end

	-- Drop the specific tag first so the remaining-tag check sees the new state.
	record.Tags[tag] = nil
	if not self:_RecordHasScopedTags(record) then
		self:_UnindexInstance(instance)
	end
end

-- Checks whether a record still has any ECS identity tags attached.
function ClientECSDiscoveryIndexService:_RecordHasScopedTags(record: ECSDiscoveryRecord): boolean
	for tag in record.Tags do
		if self._schema.IsEntityTag(tag, self._namespace) then
			return true
		end
	end
	return false
end

-- Removes the cached record for an instance without touching the instance itself.
function ClientECSDiscoveryIndexService:_UnindexInstance(instance: Instance)
	self._recordsByInstance[instance] = nil
end

return ClientECSDiscoveryIndexService
