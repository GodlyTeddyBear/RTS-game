--!strict

local DEFAULT_REFRESH_INTERVAL_SECONDS = 0.2

type TTargetState = {
	TargetEntity: number?,
	TargetKind: string?,
	TargetPosition: Vector3?,
}

type TCheapFactGroupRecord = {
	Facts: { [string]: any },
	LastRefreshTime: number,
	IsDirty: boolean,
}

type TCheapFactGroupDefinition = {
	RefreshIntervalSeconds: number?,
	BuildFacts: () -> { [string]: any },
}

type TCacheRecord = {
	FactSnapshot: { [string]: any },
	CheapFactGroups: { [string]: TCheapFactGroupRecord },
	CachedTargetEntity: number?,
	CachedTargetKind: string?,
	LastRefreshTime: number,
	IsDirty: boolean,
	LastKnownActorPosition: Vector3?,
	LastKnownTargetPosition: Vector3?,
}

type TResolveOptions = {
	DefaultCheapFactGroupRefreshIntervalSeconds: number?,
	RefreshIntervalSeconds: number?,
	CheapFactGroups: { [string]: TCheapFactGroupDefinition },
	ValidateCachedTarget: (cachedTargetState: TTargetState, cheapFacts: { [string]: any }) -> TTargetState?,
	ReacquireTarget: (cheapFacts: { [string]: any }) -> TTargetState?,
	BuildFactSnapshot: (cheapFacts: { [string]: any }, targetState: TTargetState) -> { [string]: any },
	GetActorPosition: ((cheapFacts: { [string]: any }) -> Vector3?)?,
}

local RuntimeFactCache = {}

local function _BuildEmptyRecord(): TCacheRecord
	return {
		FactSnapshot = {},
		CheapFactGroups = {},
		CachedTargetEntity = nil,
		CachedTargetKind = nil,
		LastRefreshTime = 0,
		IsDirty = true,
		LastKnownActorPosition = nil,
		LastKnownTargetPosition = nil,
	}
end

local function _GetOrCreateRecord(cacheByKey: { [any]: TCacheRecord }, key: any): TCacheRecord
	local record = cacheByKey[key]
	if record ~= nil then
		return record
	end

	record = _BuildEmptyRecord()
	cacheByKey[key] = record
	return record
end

function RuntimeFactCache.GetRecord(cacheByKey: { [any]: TCacheRecord }, key: any): TCacheRecord?
	return cacheByKey[key]
end

local function _GetOrCreateCheapFactGroupRecord(
	record: TCacheRecord,
	groupName: string
): TCheapFactGroupRecord
	local groupRecord = record.CheapFactGroups[groupName]
	if groupRecord ~= nil then
		return groupRecord
	end

	groupRecord = {
		Facts = {},
		LastRefreshTime = 0,
		IsDirty = true,
	}
	record.CheapFactGroups[groupName] = groupRecord
	return groupRecord
end

local function _NormalizeTargetState(targetState: TTargetState?): TTargetState
	if targetState == nil then
		return {
			TargetEntity = nil,
			TargetKind = nil,
			TargetPosition = nil,
		}
	end

	return {
		TargetEntity = targetState.TargetEntity,
		TargetKind = targetState.TargetKind,
		TargetPosition = targetState.TargetPosition,
	}
end

local function _MergeCheapFactGroups(cheapFactGroups: { [string]: TCheapFactGroupRecord }): { [string]: any }
	local mergedFacts = {}

	for _, groupRecord in pairs(cheapFactGroups) do
		for factName, factValue in pairs(groupRecord.Facts) do
			mergedFacts[factName] = factValue
		end
	end

	return mergedFacts
end

function RuntimeFactCache.Resolve(
	cacheByKey: { [any]: TCacheRecord },
	key: any,
	currentTime: number?,
	options: TResolveOptions
): { [string]: any }
	local record = _GetOrCreateRecord(cacheByKey, key)
	local refreshInterval = options.RefreshIntervalSeconds or DEFAULT_REFRESH_INTERVAL_SECONDS
	local resolvedCurrentTime = if type(currentTime) == "number" then currentTime else os.clock()

	for groupName, groupDefinition in pairs(options.CheapFactGroups) do
		local groupRecord = _GetOrCreateCheapFactGroupRecord(record, groupName)
		local cheapRefreshInterval = groupDefinition.RefreshIntervalSeconds
			or options.DefaultCheapFactGroupRefreshIntervalSeconds
			or options.RefreshIntervalSeconds
			or DEFAULT_REFRESH_INTERVAL_SECONDS
		local shouldRefreshCheap = groupRecord.IsDirty
			or (resolvedCurrentTime - groupRecord.LastRefreshTime) >= cheapRefreshInterval

		if shouldRefreshCheap then
			groupRecord.Facts = groupDefinition.BuildFacts()
			groupRecord.LastRefreshTime = resolvedCurrentTime
			groupRecord.IsDirty = false
		end
	end

	local cheapFacts = _MergeCheapFactGroups(record.CheapFactGroups)

	local cachedTargetState = {
		TargetEntity = record.CachedTargetEntity,
		TargetKind = record.CachedTargetKind,
		TargetPosition = record.LastKnownTargetPosition,
	}
	local validatedTargetState = _NormalizeTargetState(options.ValidateCachedTarget(cachedTargetState, cheapFacts))
	local targetIsValid = validatedTargetState.TargetKind ~= nil
	local shouldRefresh = record.IsDirty
		or (resolvedCurrentTime - record.LastRefreshTime) >= refreshInterval
		or (record.CachedTargetKind ~= nil and not targetIsValid)

	if shouldRefresh then
		if not targetIsValid then
			validatedTargetState = _NormalizeTargetState(options.ReacquireTarget(cheapFacts))
		end

		record.LastRefreshTime = resolvedCurrentTime
		record.IsDirty = false
	end

	record.CachedTargetEntity = validatedTargetState.TargetEntity
	record.CachedTargetKind = validatedTargetState.TargetKind
	record.LastKnownTargetPosition = validatedTargetState.TargetPosition
	record.LastKnownActorPosition = if options.GetActorPosition ~= nil then options.GetActorPosition(cheapFacts) else nil
	record.FactSnapshot = options.BuildFactSnapshot(cheapFacts, validatedTargetState)

	return record.FactSnapshot
end

function RuntimeFactCache.MarkDirty(cacheByKey: { [any]: TCacheRecord }, key: any)
	local record = cacheByKey[key]
	if record == nil then
		return
	end

	record.IsDirty = true
end

function RuntimeFactCache.MarkCheapFactGroupDirty(cacheByKey: { [any]: TCacheRecord }, key: any, groupName: string)
	local record = cacheByKey[key]
	if record == nil then
		return
	end

	local groupRecord = _GetOrCreateCheapFactGroupRecord(record, groupName)
	groupRecord.IsDirty = true
end

function RuntimeFactCache.MarkAllCheapFactGroupsDirty(cacheByKey: { [any]: TCacheRecord }, key: any)
	local record = cacheByKey[key]
	if record == nil then
		return
	end

	for _, groupRecord in pairs(record.CheapFactGroups) do
		groupRecord.IsDirty = true
	end
end

function RuntimeFactCache.Clear(cacheByKey: { [any]: TCacheRecord }, key: any)
	cacheByKey[key] = nil
end

return table.freeze(RuntimeFactCache)
