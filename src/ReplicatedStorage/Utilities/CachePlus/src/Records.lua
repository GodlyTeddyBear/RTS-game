--!strict

local Types = require(script.Parent.Types)

type TValueCacheMeta = Types.TValueCacheMeta
type TGroupMeta = Types.TGroupMeta
type TGroupedEntryMeta = Types.TGroupedEntryMeta

export type TRecord<T> = {
	Value: T?,
	HasValue: boolean,
	IsDirty: boolean,
	LastResolvedTime: number?,
}

export type TGroupRecord = {
	Facts: { [string]: any },
	HasValue: boolean,
	IsDirty: boolean,
	LastResolvedTime: number?,
}

export type TGroupedRecord<T> = TRecord<T> & {
	Groups: { [string]: TGroupRecord },
}

local Records = {}

function Records.CreateRecord<T>(recordTable: { [any]: any }?): TRecord<T>
	local record = if recordTable ~= nil then recordTable else {}
	record.Value = nil
	record.HasValue = false
	record.IsDirty = true
	record.LastResolvedTime = nil
	return record :: any
end

function Records.CreateGroupRecord(recordTable: { [any]: any }?): TGroupRecord
	local record = if recordTable ~= nil then recordTable else {}
	record.Facts = {}
	record.HasValue = false
	record.IsDirty = true
	record.LastResolvedTime = nil
	return record :: any
end

function Records.CreateGroupedRecord<T>(
	recordTable: { [any]: any }?,
	groupsTable: { [any]: any }?
): TGroupedRecord<T>
	local record = if recordTable ~= nil then recordTable else {}
	record.Value = nil
	record.HasValue = false
	record.IsDirty = true
	record.LastResolvedTime = nil
	record.Groups = if groupsTable ~= nil then groupsTable else {}
	return record :: any
end

function Records.TouchRecord<T>(record: TRecord<T>, value: T, currentTime: number)
	record.Value = value
	record.HasValue = true
	record.IsDirty = false
	record.LastResolvedTime = currentTime
end

function Records.TouchGroupRecord(record: TGroupRecord, facts: { [string]: any }, currentTime: number)
	record.Facts = facts
	record.HasValue = true
	record.IsDirty = false
	record.LastResolvedTime = currentTime
end

function Records.ClearRecord<T>(record: TRecord<T>)
	record.Value = nil
	record.HasValue = false
	record.IsDirty = true
	record.LastResolvedTime = nil
end

function Records.ResetRecordForRecycle<T>(record: TRecord<T>)
	Records.ClearRecord(record)
end

function Records.ResetGroupRecordForRecycle(record: TGroupRecord)
	record.Facts = nil :: any
	record.HasValue = false
	record.IsDirty = true
	record.LastResolvedTime = nil
end

function Records.ResetGroupedRecordForRecycle<T>(record: TGroupedRecord<T>)
	record.Value = nil
	record.HasValue = false
	record.IsDirty = true
	record.LastResolvedTime = nil
end

function Records.GetExpiresAt(lastResolvedTime: number?, ttlSeconds: number?): number?
	if lastResolvedTime == nil or ttlSeconds == nil then
		return nil
	end

	return lastResolvedTime + ttlSeconds
end

function Records.HasExpired(lastResolvedTime: number?, ttlSeconds: number?, currentTime: number): boolean
	local expiresAt = Records.GetExpiresAt(lastResolvedTime, ttlSeconds)
	if expiresAt == nil then
		return false
	end

	return currentTime >= expiresAt
end

function Records.ShouldRefresh<T>(record: TRecord<T>, ttlSeconds: number?, currentTime: number): boolean
	if not record.HasValue then
		return true
	end

	if record.IsDirty then
		return true
	end

	return Records.HasExpired(record.LastResolvedTime, ttlSeconds, currentTime)
end

function Records.ShouldRefreshGroup(record: TGroupRecord, ttlSeconds: number?, currentTime: number): boolean
	if not record.HasValue then
		return true
	end

	if record.IsDirty then
		return true
	end

	return Records.HasExpired(record.LastResolvedTime, ttlSeconds, currentTime)
end

function Records.BuildEntryMeta<T>(record: TRecord<T>, ttlSeconds: number?): TValueCacheMeta
	return table.freeze({
		HasValue = record.HasValue,
		IsDirty = record.IsDirty,
		LastResolvedTime = record.LastResolvedTime,
		ExpiresAt = Records.GetExpiresAt(record.LastResolvedTime, ttlSeconds),
	})
end

function Records.BuildGroupMeta(record: TGroupRecord, ttlSeconds: number?): TGroupMeta
	return table.freeze({
		HasValue = record.HasValue,
		IsDirty = record.IsDirty,
		LastResolvedTime = record.LastResolvedTime,
		ExpiresAt = Records.GetExpiresAt(record.LastResolvedTime, ttlSeconds),
	})
end

function Records.BuildGroupedEntryMeta<T>(
	record: TGroupedRecord<T>,
	entryTtlSeconds: number?,
	groupConfigs: { [string]: { TtlSeconds: number? } }
): TGroupedEntryMeta
	local groupMeta = {}

	for groupName, groupRecord in pairs(record.Groups) do
		local groupConfig = groupConfigs[groupName]
		local ttlSeconds = if groupConfig ~= nil then groupConfig.TtlSeconds else nil
		groupMeta[groupName] = Records.BuildGroupMeta(groupRecord, ttlSeconds)
	end

	return table.freeze({
		HasValue = record.HasValue,
		IsDirty = record.IsDirty,
		LastResolvedTime = record.LastResolvedTime,
		ExpiresAt = Records.GetExpiresAt(record.LastResolvedTime, entryTtlSeconds),
		Groups = table.freeze(groupMeta),
	})
end

return table.freeze(Records)
