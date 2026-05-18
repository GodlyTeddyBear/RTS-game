--!strict

export type TValueCacheMeta = {
	HasValue: boolean,
	IsDirty: boolean,
	LastResolvedTime: number?,
	ExpiresAt: number?,
}

export type TEntryMeta = TValueCacheMeta

export type TGroupMeta = {
	HasValue: boolean,
	IsDirty: boolean,
	LastResolvedTime: number?,
	ExpiresAt: number?,
}

export type TGroupedEntryMeta = TValueCacheMeta & {
	Groups: { [string]: TGroupMeta },
}

export type TValueCacheConfig<T> = {
	Resolver: (previousValue: T?) -> T,
	TtlSeconds: number?,
	Clock: (() -> number)?,
}

export type TValueCache<T> = {
	Get: (self: TValueCache<T>) -> T,
	GetWithTime: (self: TValueCache<T>, currentTime: number) -> T,
	Peek: (self: TValueCache<T>) -> T?,
	HasValue: (self: TValueCache<T>) -> boolean,
	Set: (self: TValueCache<T>, value: T, currentTime: number?) -> (),
	MarkDirty: (self: TValueCache<T>) -> (),
	Clear: (self: TValueCache<T>) -> (),
	Inspect: (self: TValueCache<T>) -> TValueCacheMeta,
}

export type TMapCacheConfig<TKey, TValue> = {
	Resolver: (key: TKey, previousValue: TValue?) -> TValue,
	TtlSeconds: number?,
	Clock: (() -> number)?,
}

export type TMapCache<TKey, TValue> = {
	Get: (self: TMapCache<TKey, TValue>, key: TKey) -> TValue,
	GetWithTime: (self: TMapCache<TKey, TValue>, key: TKey, currentTime: number) -> TValue,
	Peek: (self: TMapCache<TKey, TValue>, key: TKey) -> TValue?,
	Has: (self: TMapCache<TKey, TValue>, key: TKey) -> boolean,
	Set: (self: TMapCache<TKey, TValue>, key: TKey, value: TValue, currentTime: number?) -> (),
	MarkDirty: (self: TMapCache<TKey, TValue>, key: TKey) -> (),
	MarkAllDirty: (self: TMapCache<TKey, TValue>) -> (),
	Clear: (self: TMapCache<TKey, TValue>, key: TKey) -> (),
	ClearAll: (self: TMapCache<TKey, TValue>) -> (),
	Inspect: (self: TMapCache<TKey, TValue>, key: TKey) -> TEntryMeta?,
}

export type TGroupConfig<TKey> = {
	Resolver: (key: TKey, previousFacts: { [string]: any }?) -> { [string]: any },
	TtlSeconds: number?,
}

export type TGroupedMapConfig<TKey, TValue> = {
	Groups: { [string]: TGroupConfig<TKey> },
	BuildValue: (key: TKey, mergedFacts: { [string]: any }, previousValue: TValue?) -> TValue,
	EntryTtlSeconds: number?,
	Clock: (() -> number)?,
}

export type TGroupedMapCache<TKey, TValue> = {
	Resolve: (self: TGroupedMapCache<TKey, TValue>, key: TKey) -> TValue,
	ResolveWithTime: (self: TGroupedMapCache<TKey, TValue>, key: TKey, currentTime: number) -> TValue,
	Peek: (self: TGroupedMapCache<TKey, TValue>, key: TKey) -> TValue?,
	Has: (self: TGroupedMapCache<TKey, TValue>, key: TKey) -> boolean,
	MarkDirty: (self: TGroupedMapCache<TKey, TValue>, key: TKey) -> (),
	MarkGroupDirty: (self: TGroupedMapCache<TKey, TValue>, key: TKey, groupName: string) -> (),
	MarkAllGroupsDirty: (self: TGroupedMapCache<TKey, TValue>, key: TKey) -> (),
	Clear: (self: TGroupedMapCache<TKey, TValue>, key: TKey) -> (),
	ClearAll: (self: TGroupedMapCache<TKey, TValue>) -> (),
	Inspect: (self: TGroupedMapCache<TKey, TValue>, key: TKey) -> TGroupedEntryMeta?,
}

local Types = {}

return Types
