--!strict

local Records = require(script.Parent.Records)
local Types = require(script.Parent.Types)
local Validation = require(script.Parent.Validation)

type TRecord<T> = Records.TRecord<T>

local KeyedCache = {}

local function _ResolveCurrentTime(clock: (() -> number)?): number
	if clock ~= nil then
		return clock()
	end

	return os.clock()
end

local function _GetOrCreateRecord<TKey, TValue>(recordsByKey: { [TKey]: TRecord<TValue> }, key: TKey): TRecord<TValue>
	local record = recordsByKey[key]
	if record ~= nil then
		return record
	end

	record = Records.CreateRecord()
	recordsByKey[key] = record
	return record
end

function KeyedCache.new<TKey, TValue>(config: Types.TMapCacheConfig<TKey, TValue>): Types.TMapCache<TKey, TValue>
	Validation.ValidateMapConfig(config)

	local recordsByKey: { [TKey]: TRecord<TValue> } = {}
	local resolver = config.Resolver
	local ttlSeconds = config.TtlSeconds
	local clock = config.Clock

	local cache = {}

	function cache:Get(key: TKey): TValue
		return cache:GetWithTime(key, _ResolveCurrentTime(clock))
	end

	function cache:GetWithTime(key: TKey, currentTime: number): TValue
		Validation.AssertTime(currentTime)

		local record = _GetOrCreateRecord(recordsByKey, key)
		if Records.ShouldRefresh(record, ttlSeconds, currentTime) then
			local previousValue = if record.HasValue then record.Value else nil
			local nextValue = resolver(key, previousValue)
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

	function cache:Set(key: TKey, value: TValue, currentTime: number?)
		local resolvedCurrentTime = currentTime
		if resolvedCurrentTime == nil then
			resolvedCurrentTime = _ResolveCurrentTime(clock)
		else
			Validation.AssertTime(resolvedCurrentTime)
		end

		local record = _GetOrCreateRecord(recordsByKey, key)
		Records.TouchRecord(record, value, resolvedCurrentTime)
	end

	function cache:MarkDirty(key: TKey)
		local record = recordsByKey[key]
		if record == nil then
			return
		end

		record.IsDirty = true
	end

	function cache:MarkAllDirty()
		for _, record in pairs(recordsByKey) do
			record.IsDirty = true
		end
	end

	function cache:Clear(key: TKey)
		recordsByKey[key] = nil
	end

	function cache:ClearAll()
		table.clear(recordsByKey)
	end

	function cache:Inspect(key: TKey): Types.TEntryMeta?
		local record = recordsByKey[key]
		if record == nil then
			return nil
		end

		return Records.BuildEntryMeta(record, ttlSeconds)
	end

	return table.freeze(cache) :: any
end

return table.freeze(KeyedCache)
