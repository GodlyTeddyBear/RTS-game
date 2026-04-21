--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Janitor = require(ReplicatedStorage.Packages.Janitor)
local TargetSchema = require(ReplicatedStorage.Contexts.Targeting.Config.TargetSchema)

--[=[
	Maintains an insertion-ordered index of tagged instances for fast target lookups.

	Subscribes to CollectionService tags that pass `TargetSchema.IsTargetTag` and indexes
	each instance by its `TargetType` / `TargetId` attributes and its full tag set.
	Stale (un-parented) instances are lazily evicted during queries.
	@class TargetIndexService
	@client
]=]
local TargetIndexService = {}
TargetIndexService.__index = TargetIndexService

--[=[
	@interface TTargetRecord
	@within TargetIndexService
	.Instance Instance -- The indexed Roblox instance
	.TargetId string -- Value of the `TargetId` attribute on the instance
	.TargetType string -- Value of the `TargetType` attribute on the instance
	.Tags { [string]: boolean } -- Set of all target tags currently on the instance
	.Order number -- Monotonically increasing insertion counter used for ordering
]=]
type TTargetRecord = {
	Instance: Instance,
	TargetId: string,
	TargetType: string,
	Tags: { [string]: boolean },
	Order: number,
}

--[=[
	Creates a new, unstarted `TargetIndexService` instance.
	@within TargetIndexService
	@return TargetIndexService -- The new service instance
]=]
function TargetIndexService.new()
	local self = setmetatable({}, TargetIndexService)
	self._janitor = Janitor.new()
	self._tagConnections = {} :: { [string]: { Added: RBXScriptConnection, Removed: RBXScriptConnection } }
	self._recordsByInstance = {} :: { [Instance]: TTargetRecord }
	self._insertionOrder = {} :: { Instance }
	self._nextOrder = 1
	return self
end

--[=[
	Starts the service, subscribes to all current target tags, and begins polling for new tags every 2 seconds.
	@within TargetIndexService
]=]
function TargetIndexService:Start()
	self:_RefreshTagSubscriptions()

	self._janitor:Add(
		task.spawn(function()
			while true do
				task.wait(2)
				self:_RefreshTagSubscriptions()
			end
		end),
		true
	)
end

--[=[
	Returns the first indexed instance matching both `targetType` and `targetId`, in insertion order.
	@within TargetIndexService
	@param targetType string -- The `TargetType` attribute value to match
	@param targetId string -- The `TargetId` attribute value to match
	@return Instance? -- The first matching live instance, or `nil` if none found
]=]
function TargetIndexService:FindFirstByTypeAndId(targetType: string, targetId: string): Instance?
	local result: Instance? = nil
	self:_IterateLiveRecords(function(instance, record)
		if result then
			return
		end
		if record.TargetType == targetType and record.TargetId == targetId then
			result = instance
		end
	end)
	return result
end

--[=[
	Returns all indexed instances matching both `targetType` and `targetId`, in insertion order.
	@within TargetIndexService
	@param targetType string -- The `TargetType` attribute value to match
	@param targetId string -- The `TargetId` attribute value to match
	@return { Instance } -- All matching live instances (may be empty)
]=]
function TargetIndexService:FindAllByTypeAndId(targetType: string, targetId: string): { Instance }
	local results = {}
	self:_IterateLiveRecords(function(instance, record)
		if record.TargetType == targetType and record.TargetId == targetId then
			table.insert(results, instance)
		end
	end)
	return results
end

--[=[
	Returns the first indexed instance carrying the given CollectionService tag, in insertion order.
	@within TargetIndexService
	@param tag string -- The CollectionService tag to match
	@return Instance? -- The first matching live instance, or `nil` if none found
]=]
function TargetIndexService:FindFirstByTag(tag: string): Instance?
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
	Returns all indexed instances carrying the given CollectionService tag, in insertion order.
	@within TargetIndexService
	@param tag string -- The CollectionService tag to match
	@return { Instance } -- All matching live instances (may be empty)
]=]
function TargetIndexService:FindAllByTag(tag: string): { Instance }
	local results = {}
	self:_IterateLiveRecords(function(instance, record)
		if record.Tags[tag] then
			table.insert(results, instance)
		end
	end)
	return results
end

--[=[
	Returns all indexed instances that carry at least one tag starting with `prefix`.
	@within TargetIndexService
	@param prefix string -- The tag prefix to match against
	@return { Instance } -- All matching live instances (may be empty)
]=]
function TargetIndexService:FindAllByTagPrefix(prefix: string): { Instance }
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
	Returns the first indexed instance whose Roblox attribute `attributeName` equals `attributeValue`.
	@within TargetIndexService
	@param attributeName string -- The Roblox attribute name to inspect
	@param attributeValue any -- The value to match
	@return Instance? -- The first matching live instance, or `nil` if none found
]=]
function TargetIndexService:FindFirstByAttribute(attributeName: string, attributeValue: any): Instance?
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
	Returns all indexed instances whose Roblox attribute `attributeName` equals `attributeValue`.
	@within TargetIndexService
	@param attributeName string -- The Roblox attribute name to inspect
	@param attributeValue any -- The value to match
	@return { Instance } -- All matching live instances (may be empty)
]=]
function TargetIndexService:FindAllByAttribute(attributeName: string, attributeValue: any): { Instance }
	local results = {}
	self:_IterateLiveRecords(function(instance, _)
		if instance:GetAttribute(attributeName) == attributeValue then
			table.insert(results, instance)
		end
	end)
	return results
end

-- Iterates all live records in insertion order, evicting stale (un-parented) instances lazily.
function TargetIndexService:_IterateLiveRecords(callback: (Instance, TTargetRecord) -> ())
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

function TargetIndexService:_RefreshTagSubscriptions()
	for _, tag in CollectionService:GetAllTags() do
		if TargetSchema.IsTargetTag(tag) and not self._tagConnections[tag] then
			self:_SubscribeToTag(tag)
		end
	end
end

function TargetIndexService:_SubscribeToTag(tag: string)
	local added = CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance)
		self:_OnTagAdded(tag, instance)
	end)
	local removed = CollectionService:GetInstanceRemovedSignal(tag):Connect(function(instance)
		self:_OnTagRemoved(tag, instance)
	end)
	self._tagConnections[tag] = { Added = added, Removed = removed }
	self:_BackfillExistingInstances(tag)
end

function TargetIndexService:_BackfillExistingInstances(tag: string)
	for _, instance in CollectionService:GetTagged(tag) do
		self:_OnTagAdded(tag, instance)
	end
end

function TargetIndexService:_OnTagAdded(tag: string, instance: Instance)
	local targetType = instance:GetAttribute(TargetSchema.ATTR_TARGET_TYPE)
	local targetId = instance:GetAttribute(TargetSchema.ATTR_TARGET_ID)
	if type(targetType) ~= "string" or type(targetId) ~= "string" then
		return
	end

	local record = self._recordsByInstance[instance]
	if not record then
		record = {
			Instance = instance,
			TargetId = targetId,
			TargetType = targetType,
			Tags = {},
			Order = self._nextOrder,
		}
		self._recordsByInstance[instance] = record
		self._nextOrder += 1
		table.insert(self._insertionOrder, instance)
	end

	record.Tags[tag] = true
end

function TargetIndexService:_OnTagRemoved(tag: string, instance: Instance)
	local record = self._recordsByInstance[instance]
	if not record then
		return
	end

	record.Tags[tag] = nil
	if not self:_RecordHasTargetTags(record) then
		self:_UnindexInstance(instance)
	end
end

function TargetIndexService:_RecordHasTargetTags(record: TTargetRecord): boolean
	for existingTag in record.Tags do
		if TargetSchema.IsTargetTag(existingTag) then
			return true
		end
	end
	return false
end

-- Removes the record lookup; the instance remains in _insertionOrder and is
-- evicted lazily on the next traversal that encounters it without a parent.
function TargetIndexService:_UnindexInstance(instance: Instance)
	self._recordsByInstance[instance] = nil
end

return TargetIndexService
