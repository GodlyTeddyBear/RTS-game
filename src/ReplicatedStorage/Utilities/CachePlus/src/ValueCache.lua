--!strict

local Records = require(script.Parent.Records)
local Types = require(script.Parent.Types)
local Validation = require(script.Parent.Validation)

type TRecord<T> = Records.TRecord<T>

local ValueCache = {}

local function _ResolveCurrentTime(clock: (() -> number)?): number
	if clock ~= nil then
		return clock()
	end

	return os.clock()
end

function ValueCache.new<T>(config: Types.TValueCacheConfig<T>): Types.TValueCache<T>
	Validation.ValidateValueConfig(config)

	local record: TRecord<T> = Records.CreateRecord()
	local resolver = config.Resolver
	local ttlSeconds = config.TtlSeconds
	local clock = config.Clock

	local cache = {}

	function cache:Get(): T
		return cache:GetWithTime(_ResolveCurrentTime(clock))
	end

	function cache:GetWithTime(currentTime: number): T
		Validation.AssertTime(currentTime)

		if Records.ShouldRefresh(record, ttlSeconds, currentTime) then
			local previousValue = if record.HasValue then record.Value else nil
			local nextValue = resolver(previousValue)
			Records.TouchRecord(record, nextValue, currentTime)
		end

		return record.Value :: T
	end

	function cache:Peek(): T?
		if not record.HasValue then
			return nil
		end

		return record.Value
	end

	function cache:HasValue(): boolean
		return record.HasValue
	end

	function cache:Set(value: T, currentTime: number?)
		local resolvedCurrentTime = currentTime
		if resolvedCurrentTime == nil then
			resolvedCurrentTime = _ResolveCurrentTime(clock)
		else
			Validation.AssertTime(resolvedCurrentTime)
		end

		Records.TouchRecord(record, value, resolvedCurrentTime)
	end

	function cache:MarkDirty()
		record.IsDirty = true
	end

	function cache:Clear()
		Records.ClearRecord(record)
	end

	function cache:Inspect(): Types.TValueCacheMeta
		return Records.BuildEntryMeta(record, ttlSeconds)
	end

	return table.freeze(cache) :: any
end

return table.freeze(ValueCache)
