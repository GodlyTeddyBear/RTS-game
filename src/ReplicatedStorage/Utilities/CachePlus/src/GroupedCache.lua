--!strict

local Records = require(script.Parent.Records)
local TableRecycler = require(script.Parent.Parent.Parent.TableRecycler)
local Types = require(script.Parent.Types)
local Validation = require(script.Parent.Validation)

type TGroupedRecord<T> = Records.TGroupedRecord<T>
type TGroupRecord = Records.TGroupRecord

local GroupedCache = {}

local function _ResolveCurrentTime(clock: (() -> number)?): number
	if clock ~= nil then
		return clock()
	end

	return os.clock()
end

local function _CreateGroupRecord(recycler: TableRecycler.TTableRecyclerHandle): TGroupRecord
	return Records.CreateGroupRecord(recycler:AcquireMap())
end

local function _CreateGroupedEntry<TValue>(recycler: TableRecycler.TTableRecyclerHandle): TGroupedRecord<TValue>
	return Records.CreateGroupedRecord(recycler:AcquireMap(), recycler:AcquireMap())
end

local function _GetOrCreateEntry<TKey, TValue>(
	recycler: TableRecycler.TTableRecyclerHandle,
	recordsByKey: { [TKey]: TGroupedRecord<TValue> },
	key: TKey
): TGroupedRecord<TValue>
	local record = recordsByKey[key]
	if record ~= nil then
		return record
	end

	record = _CreateGroupedEntry(recycler)
	recordsByKey[key] = record
	return record
end

local function _GetOrCreateGroupRecord<TValue>(
	recycler: TableRecycler.TTableRecyclerHandle,
	record: TGroupedRecord<TValue>,
	groupName: string
): TGroupRecord
	local groupRecord = record.Groups[groupName]
	if groupRecord ~= nil then
		return groupRecord
	end

	groupRecord = _CreateGroupRecord(recycler)
	record.Groups[groupName] = groupRecord
	return groupRecord
end

local function _MergeFacts(groups: { [string]: TGroupRecord }): { [string]: any }
	local mergedFacts = {}

	for _, groupRecord in pairs(groups) do
		for factName, factValue in pairs(groupRecord.Facts) do
			mergedFacts[factName] = factValue
		end
	end

	return mergedFacts
end

local function _ResetEntryForRecycle<TValue>(record: TGroupedRecord<TValue>)
	for _, groupRecord in pairs(record.Groups) do
		Records.ResetGroupRecordForRecycle(groupRecord)
	end

	Records.ResetGroupedRecordForRecycle(record)
end

function GroupedCache.new<TKey, TValue>(
	config: Types.TGroupedMapConfig<TKey, TValue>
): Types.TGroupedMapCache<TKey, TValue>
	Validation.ValidateGroupedMapConfig(config)

	local recordsByKey: { [TKey]: TGroupedRecord<TValue> } = {}
	local recycler = TableRecycler.new({
		Strict = true,
		DebugName = "CachePlus.GroupedCache",
	})
	local groups = config.Groups
	local buildValue = config.BuildValue
	local entryTtlSeconds = config.EntryTtlSeconds
	local clock = config.Clock

	local cache = {}

	function cache:Resolve(key: TKey): TValue
		return cache:ResolveWithTime(key, _ResolveCurrentTime(clock))
	end

	function cache:ResolveWithTime(key: TKey, currentTime: number): TValue
		Validation.AssertTime(currentTime)

		local record = _GetOrCreateEntry(recycler, recordsByKey, key)
		local anyGroupRefreshed = false

		for groupName, groupConfig in pairs(groups) do
			local groupRecord = _GetOrCreateGroupRecord(recycler, record, groupName)
			if Records.ShouldRefreshGroup(groupRecord, groupConfig.TtlSeconds, currentTime) then
				local previousFacts = if groupRecord.HasValue then groupRecord.Facts else nil
				local nextFacts = groupConfig.Resolver(key, previousFacts)
				Records.TouchGroupRecord(groupRecord, nextFacts, currentTime)
				anyGroupRefreshed = true
			end
		end

		local mergedFacts = _MergeFacts(record.Groups)
		local shouldRefreshEntry = anyGroupRefreshed or Records.ShouldRefresh(record, entryTtlSeconds, currentTime)
		if shouldRefreshEntry then
			local previousValue = if record.HasValue then record.Value else nil
			local nextValue = buildValue(key, mergedFacts, previousValue)
			Records.TouchRecord(record, nextValue, currentTime)
		end

		return record.Value :: TValue
	end

	function cache:Peek(key: TKey): TValue?
		local record = recordsByKey[key]
		if record == nil or not record.HasValue then
			return nil
		end

		return record.Value
	end

	function cache:Has(key: TKey): boolean
		local record = recordsByKey[key]
		return record ~= nil and record.HasValue
	end

	function cache:MarkDirty(key: TKey)
		local record = recordsByKey[key]
		if record == nil then
			return
		end

		record.IsDirty = true
	end

	function cache:MarkGroupDirty(key: TKey, groupName: string)
		Validation.AssertGroupName(groupName)
		assert(groups[groupName] ~= nil, string.format("Unknown CachePlus group: %s", groupName))

		local record = recordsByKey[key]
		if record == nil then
			return
		end

		local groupRecord = _GetOrCreateGroupRecord(recycler, record, groupName)
		groupRecord.IsDirty = true
	end

	function cache:MarkAllGroupsDirty(key: TKey)
		local record = recordsByKey[key]
		if record == nil then
			return
		end

		for groupName in pairs(groups) do
			local groupRecord = _GetOrCreateGroupRecord(recycler, record, groupName)
			groupRecord.IsDirty = true
		end
	end

	function cache:Clear(key: TKey)
		local record = recordsByKey[key]
		if record == nil then
			return
		end

		recordsByKey[key] = nil
		_ResetEntryForRecycle(record)
		local didRelease, releaseError = recycler:ReleaseMap(record)
		assert(didRelease, releaseError)
	end

	function cache:ClearAll()
		local key, record = next(recordsByKey)
		while key ~= nil and record ~= nil do
			recordsByKey[key] = nil
			_ResetEntryForRecycle(record)
			local didRelease, releaseError = recycler:ReleaseMap(record)
			assert(didRelease, releaseError)
			key, record = next(recordsByKey)
		end

		table.clear(recordsByKey)
	end

	function cache:Inspect(key: TKey): Types.TGroupedEntryMeta?
		local record = recordsByKey[key]
		if record == nil then
			return nil
		end

		return Records.BuildGroupedEntryMeta(record, entryTtlSeconds, groups)
	end

	return table.freeze(cache) :: any
end

return table.freeze(GroupedCache)
