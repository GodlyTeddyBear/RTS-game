--!strict

local GroupedCache = require(script.GroupedCache)
local KeyedCache = require(script.KeyedCache)
local Types = require(script.Types)
local ValueCache = require(script.ValueCache)

export type TValueCacheConfig<T> = Types.TValueCacheConfig<T>
export type TValueCacheMeta = Types.TValueCacheMeta
export type TValueCache<T> = Types.TValueCache<T>

export type TMapCacheConfig<TKey, TValue> = Types.TMapCacheConfig<TKey, TValue>
export type TEntryMeta = Types.TEntryMeta
export type TMapCache<TKey, TValue> = Types.TMapCache<TKey, TValue>

export type TGroupConfig<TKey> = Types.TGroupConfig<TKey>
export type TGroupedMapConfig<TKey, TValue> = Types.TGroupedMapConfig<TKey, TValue>
export type TGroupMeta = Types.TGroupMeta
export type TGroupedEntryMeta = Types.TGroupedEntryMeta
export type TGroupedMapCache<TKey, TValue> = Types.TGroupedMapCache<TKey, TValue>

local CachePlus = {}

function CachePlus.Value<T>(config: Types.TValueCacheConfig<T>): Types.TValueCache<T>
	return ValueCache.new(config)
end

function CachePlus.Map<TKey, TValue>(config: Types.TMapCacheConfig<TKey, TValue>): Types.TMapCache<TKey, TValue>
	return KeyedCache.new(config)
end

function CachePlus.GroupedMap<TKey, TValue>(
	config: Types.TGroupedMapConfig<TKey, TValue>
): Types.TGroupedMapCache<TKey, TValue>
	return GroupedCache.new(config)
end

return table.freeze(CachePlus)
