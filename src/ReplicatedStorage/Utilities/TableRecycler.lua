--!strict

local DEFAULT_MAX_FREE_ARRAYS_PER_POOL = 128
local DEFAULT_MAX_FREE_MAPS_PER_POOL = 128

type TTableKind = "Array" | "Map"

export type TGlobalConfig = {
	MaxFreeArraysPerPool: number?,
	MaxFreeMapsPerPool: number?,
}

export type TLocalConfig = {
	Strict: boolean?,
	DebugName: string?,
	DefaultArrayCapacityHint: number?,
}

export type TReconcileSupplyRequest = {
	Arrays: number?,
	Maps: number?,
}

export type TGlobalStats = {
	Destroyed: boolean,
	FreeArrayCount: number,
	FreeMapCount: number,
	TrackedTableCount: number,
	ActiveBorrowCount: number,
	HandleCount: number,
}

export type TLocalStats = {
	DebugName: string?,
	Destroyed: boolean,
	OwnedTableCount: number,
}

export type TTableRecyclerHandle = {
	_destroyed: boolean,
	_strict: boolean,
	_debugName: string?,
	_defaultArrayCapacityHint: number?,
	_ownedTables: { [any]: boolean },

	AcquireArray: (self: TTableRecyclerHandle, capacityHint: number?) -> { any },
	AcquireMap: (self: TTableRecyclerHandle) -> { [any]: any },
	ReleaseArray: (self: TTableRecyclerHandle, tbl: { any }) -> (boolean, string?),
	ReleaseMap: (self: TTableRecyclerHandle, tbl: { [any]: any }) -> (boolean, string?),
	Release: (self: TTableRecyclerHandle, tbl: any) -> (boolean, string?),
	GetStats: (self: TTableRecyclerHandle) -> TLocalStats,
	Destroy: (self: TTableRecyclerHandle) -> (boolean, string?),
}

local KIND_BY_TABLE = setmetatable({}, { __mode = "k" })
local IS_ACTIVE_BY_TABLE = setmetatable({}, { __mode = "k" })
local OWNER_BY_TABLE = setmetatable({}, { __mode = "k" })

local _globalDestroyed = false
local _maxFreeArraysPerPool = DEFAULT_MAX_FREE_ARRAYS_PER_POOL
local _maxFreeMapsPerPool = DEFAULT_MAX_FREE_MAPS_PER_POOL
local _freeArrays: { { any } } = {}
local _freeMaps: { { [any]: any } } = {}
local _trackedTables: { [any]: boolean } = {}
local _registeredHandles = setmetatable({}, { __mode = "k" })

local TableRecycler = {}

local TableRecyclerHandle = {}
TableRecyclerHandle.__index = TableRecyclerHandle

local function _ResolvePositiveInteger(configuredValue: number?, defaultValue: number): number
	if type(configuredValue) ~= "number" or configuredValue < 0 then
		return defaultValue
	end

	return math.floor(configuredValue)
end

local function _AssertGlobalAlive()
	assert(not _globalDestroyed, "TableRecycler global storage has already been destroyed")
end

local function _AssertHandleAlive(self: TTableRecyclerHandle)
	assert(not self._destroyed, "TableRecycler handle has already been destroyed")
end

local function _Fail(self: TTableRecyclerHandle, message: string, level: number?): (boolean, string?)
	if self._strict then
		error(message, level or 2)
	end

	return false, message
end

local function _IsPositiveInteger(value: any): boolean
	return type(value) == "number" and value >= 1 and value % 1 == 0
end

local function _InferTableKind(tbl: { [any]: any }): TTableKind
	local numericKeyCount = 0
	local maxNumericKey = 0

	for key in tbl do
		if not _IsPositiveInteger(key) then
			return "Map"
		end

		numericKeyCount += 1
		if key > maxNumericKey then
			maxNumericKey = key
		end
	end

	if numericKeyCount == 0 or numericKeyCount == maxNumericKey then
		return "Array"
	end

	return "Map"
end

local function _CreateTable(kind: TTableKind, capacityHint: number?): any
	if kind == "Array" then
		local resolvedCapacityHint = if type(capacityHint) == "number" and capacityHint > 0
			then math.floor(capacityHint)
			else 0
		return table.create(resolvedCapacityHint)
	end

	return {}
end

local function _GetFreeList(kind: TTableKind): { any }
	if kind == "Array" then
		return _freeArrays
	end

	return _freeMaps
end

local function _GetFreeListLimit(kind: TTableKind): number
	if kind == "Array" then
		return _maxFreeArraysPerPool
	end

	return _maxFreeMapsPerPool
end

local function _TrackGlobally(tbl: any, kind: TTableKind)
	_trackedTables[tbl] = true
	KIND_BY_TABLE[tbl] = kind
end

local function _ForgetGlobally(tbl: any)
	_trackedTables[tbl] = nil
	KIND_BY_TABLE[tbl] = nil
	IS_ACTIVE_BY_TABLE[tbl] = nil
	OWNER_BY_TABLE[tbl] = nil
end

local function _CountOwnedTables(ownedTables: { [any]: boolean }): number
	local count = 0
	for _ in ownedTables do
		count += 1
	end
	return count
end

local function _AcquireFromGlobal(self: TTableRecyclerHandle, kind: TTableKind, capacityHint: number?): any
	_AssertGlobalAlive()
	_AssertHandleAlive(self)

	local freeList = _GetFreeList(kind)
	local tbl = freeList[#freeList]
	if tbl ~= nil then
		freeList[#freeList] = nil
	else
		tbl = _CreateTable(kind, capacityHint)
		_TrackGlobally(tbl, kind)
	end

	IS_ACTIVE_BY_TABLE[tbl] = true
	OWNER_BY_TABLE[tbl] = self
	self._ownedTables[tbl] = true
	return tbl
end

local function _TrimFreeList(kind: TTableKind)
	local freeList = _GetFreeList(kind)
	local freeListLimit = _GetFreeListLimit(kind)

	while #freeList > freeListLimit do
		local tbl = freeList[#freeList]
		freeList[#freeList] = nil
		if tbl ~= nil then
			_ForgetGlobally(tbl)
		end
	end
end

local function _CountRegisteredHandles(): number
	local count = 0
	for _ in _registeredHandles do
		count += 1
	end
	return count
end

local function _HasActiveBorrows(): boolean
	for tbl in _trackedTables do
		if IS_ACTIVE_BY_TABLE[tbl] then
			return true
		end
	end

	return false
end

local function _ReleaseStoredTable(self: TTableRecyclerHandle, tbl: any, trackedKind: TTableKind)
	table.clear(tbl)
	self._ownedTables[tbl] = nil
	OWNER_BY_TABLE[tbl] = nil
	IS_ACTIVE_BY_TABLE[tbl] = false

	local freeList = _GetFreeList(trackedKind)
	local freeListLimit = _GetFreeListLimit(trackedKind)
	if #freeList < freeListLimit then
		freeList[#freeList + 1] = tbl
		return
	end

	_ForgetGlobally(tbl)
end

local function _CollectReleaseGraph(
	self: TTableRecyclerHandle,
	tbl: any,
	expectedKind: TTableKind?,
	releaseGraph: { [any]: boolean }
): (boolean, string?)
	if releaseGraph[tbl] == true then
		return true
	end

	local trackedKind = KIND_BY_TABLE[tbl]
	if trackedKind == nil then
		return _Fail(self, "TableRecycler: cannot release an unknown table", 2)
	end

	if expectedKind ~= nil then
		if trackedKind ~= expectedKind then
			return _Fail(self, `TableRecycler: expected a {expectedKind} table but received {trackedKind}`, 2)
		end
	end

	if OWNER_BY_TABLE[tbl] ~= self then
		return _Fail(self, "TableRecycler: handle cannot release a table it does not own", 2)
	end

	if not IS_ACTIVE_BY_TABLE[tbl] then
		return _Fail(self, "TableRecycler: cannot release an inactive table", 2)
	end

	releaseGraph[tbl] = true

	for _, value in tbl do
		if type(value) == "table" then
			local childKind = KIND_BY_TABLE[value]
			if childKind == nil then
				return _Fail(self, "TableRecycler: nested foreign tables cannot be recycled", 2)
			end

			if OWNER_BY_TABLE[value] ~= self then
				return _Fail(self, "TableRecycler: nested table is owned by another handle", 2)
			end

			if not IS_ACTIVE_BY_TABLE[value] then
				return _Fail(
					self,
					"TableRecycler: nested tracked tables must be active and owned by the releasing handle",
					2
				)
			end

			local didCollect, collectError = _CollectReleaseGraph(self, value, childKind, releaseGraph)
			if not didCollect then
				return false, collectError
			end
		end
	end

	return true
end

local function _HasExternalActiveReference(target: any, releaseGraph: { [any]: boolean }): boolean
	for candidate in _trackedTables do
		if IS_ACTIVE_BY_TABLE[candidate] and not releaseGraph[candidate] then
			for _, value in candidate do
				if value == target then
					return true
				end
			end
		end
	end

	return false
end

local function _ValidateReleaseGraphReferences(
	self: TTableRecyclerHandle,
	releaseGraph: { [any]: boolean }
): (boolean, string?)
	for tbl in releaseGraph do
		if _HasExternalActiveReference(tbl, releaseGraph) then
			return _Fail(
				self,
				"TableRecycler: cannot deep-release a table that is still referenced by another active parent",
				2
			)
		end
	end

	return true
end

local function _ReleaseCollectedGraph(
	self: TTableRecyclerHandle,
	tbl: any,
	releaseGraph: { [any]: boolean },
	releasedTables: { [any]: boolean }
)
	if releasedTables[tbl] == true then
		return
	end

	releasedTables[tbl] = true

	for _, value in tbl do
		if type(value) == "table" and releaseGraph[value] == true then
			_ReleaseCollectedGraph(self, value, releaseGraph, releasedTables)
		end
	end

	local trackedKind = KIND_BY_TABLE[tbl]
	assert(trackedKind ~= nil, "TableRecycler: tracked release graph lost kind metadata")
	_ReleaseStoredTable(self, tbl, trackedKind)
end

local function _ReleaseToGlobal(self: TTableRecyclerHandle, tbl: any, expectedKind: TTableKind?): (boolean, string?)
	_AssertGlobalAlive()
	_AssertHandleAlive(self)

	local releaseGraph = {}
	local didCollect, collectError = _CollectReleaseGraph(self, tbl, expectedKind, releaseGraph)
	if not didCollect then
		return false, collectError
	end

	local isReferenceSafe, referenceError = _ValidateReleaseGraphReferences(self, releaseGraph)
	if not isReferenceSafe then
		return false, referenceError
	end

	_ReleaseCollectedGraph(self, tbl, releaseGraph, {})
	return true
end

local function _ClearGlobalState()
	for tbl in _trackedTables do
		_ForgetGlobally(tbl)
	end

	table.clear(_trackedTables)
	table.clear(_freeArrays)
	table.clear(_freeMaps)
end

function TableRecycler.ConfigureGlobal(config: TGlobalConfig?)
	if type(config) ~= "table" then
		config = nil
	end

	_maxFreeArraysPerPool = _ResolvePositiveInteger(
		if config ~= nil then config.MaxFreeArraysPerPool else nil,
		DEFAULT_MAX_FREE_ARRAYS_PER_POOL
	)
	_maxFreeMapsPerPool = _ResolvePositiveInteger(
		if config ~= nil then config.MaxFreeMapsPerPool else nil,
		DEFAULT_MAX_FREE_MAPS_PER_POOL
	)
	_TrimFreeList("Array")
	_TrimFreeList("Map")
	_globalDestroyed = false
end

function TableRecycler.ReconcileSupply(request: TReconcileSupplyRequest)
	_AssertGlobalAlive()
	assert(type(request) == "table", "TableRecycler.ReconcileSupply expects a request table")

	local targetArrayCount = math.min(
		_ResolvePositiveInteger(request.Arrays, #_freeArrays),
		_maxFreeArraysPerPool
	)
	local targetMapCount = math.min(
		_ResolvePositiveInteger(request.Maps, #_freeMaps),
		_maxFreeMapsPerPool
	)

	while #_freeArrays < targetArrayCount do
		local tbl = _CreateTable("Array", nil)
		_TrackGlobally(tbl, "Array")
		IS_ACTIVE_BY_TABLE[tbl] = false
		_freeArrays[#_freeArrays + 1] = tbl
	end

	while #_freeMaps < targetMapCount do
		local tbl = _CreateTable("Map", nil)
		_TrackGlobally(tbl, "Map")
		IS_ACTIVE_BY_TABLE[tbl] = false
		_freeMaps[#_freeMaps + 1] = tbl
	end
end

function TableRecycler.ResetGlobal()
	assert(not _HasActiveBorrows(), "TableRecycler: cannot reset global storage while handles still own active tables")
	_ClearGlobalState()
	_globalDestroyed = false
end

function TableRecycler.DestroyGlobal()
	if _globalDestroyed then
		return
	end

	assert(not _HasActiveBorrows(), "TableRecycler: cannot destroy global storage while handles still own active tables")
	_ClearGlobalState()
	_globalDestroyed = true
end

function TableRecycler.GetGlobalStats(): TGlobalStats
	local activeBorrowCount = 0
	local trackedTableCount = 0

	for tbl in _trackedTables do
		trackedTableCount += 1
		if IS_ACTIVE_BY_TABLE[tbl] == true then
			activeBorrowCount += 1
		end
	end

	return {
		Destroyed = _globalDestroyed,
		FreeArrayCount = #_freeArrays,
		FreeMapCount = #_freeMaps,
		TrackedTableCount = trackedTableCount,
		ActiveBorrowCount = activeBorrowCount,
		HandleCount = _CountRegisteredHandles(),
	}
end

function TableRecycler.InferKind(tbl: { [any]: any }): TTableKind
	assert(type(tbl) == "table", "TableRecycler.InferKind expects a table")
	return _InferTableKind(tbl)
end

function TableRecycler.new(localConfig: TLocalConfig?): TTableRecyclerHandle
	local config = if type(localConfig) == "table" then localConfig else nil

	local self = setmetatable({}, TableRecyclerHandle)
	self._destroyed = false
	self._strict = if config ~= nil and config.Strict ~= nil then config.Strict else true
	self._debugName = if config ~= nil then config.DebugName else nil
	self._defaultArrayCapacityHint = if config ~= nil then config.DefaultArrayCapacityHint else nil
	self._ownedTables = {}
	_registeredHandles[self] = true
	return self
end

function TableRecyclerHandle:AcquireArray(capacityHint: number?): { any }
	local resolvedCapacityHint = capacityHint
	if resolvedCapacityHint == nil then
		resolvedCapacityHint = self._defaultArrayCapacityHint
	end

	return _AcquireFromGlobal(self, "Array", resolvedCapacityHint)
end

function TableRecyclerHandle:AcquireMap(): { [any]: any }
	return _AcquireFromGlobal(self, "Map", nil)
end

function TableRecyclerHandle:ReleaseArray(tbl: { any }): (boolean, string?)
	return _ReleaseToGlobal(self, tbl, "Array")
end

function TableRecyclerHandle:ReleaseMap(tbl: { [any]: any }): (boolean, string?)
	return _ReleaseToGlobal(self, tbl, "Map")
end

function TableRecyclerHandle:Release(tbl: any): (boolean, string?)
	return _ReleaseToGlobal(self, tbl, nil)
end

function TableRecyclerHandle:GetStats(): TLocalStats
	return {
		DebugName = self._debugName,
		Destroyed = self._destroyed,
		OwnedTableCount = _CountOwnedTables(self._ownedTables),
	}
end

function TableRecyclerHandle:Destroy(): (boolean, string?)
	if self._destroyed then
		return true
	end

	local ownedTableCount = _CountOwnedTables(self._ownedTables)
	if ownedTableCount > 0 then
		return _Fail(self, "TableRecycler: cannot destroy a handle that still owns active tables", 2)
	end

	self._destroyed = true
	_registeredHandles[self] = nil
	return true
end

return TableRecycler
