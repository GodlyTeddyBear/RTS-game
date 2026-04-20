--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SharedAtoms = require(ReplicatedStorage.Contexts.Log.Sync.SharedAtoms)
local LogRetentionConfig = require(ReplicatedStorage.Contexts.Log.Config.LogRetentionConfig)

--[[
	Log Sync Service

	Owns the server-side log atom and pushes log events to the developer client
	via Blink. Does not extend BaseSyncService because logs are global (not
	per-player) — only the developer player receives them.

	Atom shape: { LogEntry } — flat list of all entries, trimmed by retention config.
]]

local DEVELOPER_USER_ID = 205423638

local LogSyncService = {}
LogSyncService.__index = LogSyncService

export type LogEntry = SharedAtoms.LogEntry

local function deepClone(tbl: any): any
	if type(tbl) ~= "table" then
		return tbl
	end
	local clone = {}
	for key, value in pairs(tbl) do
		clone[key] = deepClone(value)
	end
	return clone
end

local function removeEntryById(entries: { LogEntry }, entryId: number): { LogEntry }
	local retained = table.create(#entries)
	for _, entry in ipairs(entries) do
		if entry.id ~= entryId then
			table.insert(retained, entry)
		end
	end
	return retained
end

function LogSyncService.new()
	return setmetatable({}, LogSyncService)
end

function LogSyncService:Init(registry: any)
	self._blinkServer = registry:Get("BlinkServer")
	self._atom = SharedAtoms.CreateServerAtom()
	self._idsByScope = {} :: { [string]: { number } }
end

--- Appends an entry to the atom, enforces retention, and fires Blink to the developer.
function LogSyncService:Push(entry: LogEntry)
	local scopeKey = LogRetentionConfig.buildScopeKey(entry.context, entry.category)

	self._atom(function(current: { LogEntry })
		local updated = table.clone(current)
		table.insert(updated, entry)

		local scopedIds = self._idsByScope[scopeKey]
		if not scopedIds then
			scopedIds = {}
			self._idsByScope[scopeKey] = scopedIds
		end
		table.insert(scopedIds, entry.id)

		local maxEntries = LogRetentionConfig.resolveScopeLimit(entry.context, entry.category)
		while #scopedIds > maxEntries do
			local staleId = table.remove(scopedIds, 1)
			updated = removeEntryById(updated, staleId)
		end

		return updated
	end)

	local developerPlayer = Players:GetPlayerByUserId(DEVELOPER_USER_ID)
	if developerPlayer then
		self._blinkServer.SyncLog.Fire(developerPlayer, {
			type = "entry",
			data = entry,
		})
	end
end

--- Clears entries matching the optional scope filters and fires a Blink clear signal.
function LogSyncService:Clear(contextFilter: string?, categoryFilter: string?)
	local normalizedContext = LogRetentionConfig.normalizeFilter(contextFilter)
	local normalizedCategory = LogRetentionConfig.normalizeFilter(categoryFilter)

	self._atom(function(current: { LogEntry })
		if normalizedContext == nil and normalizedCategory == nil then
			table.clear(self._idsByScope)
			return {}
		end

		local retained = table.create(#current)
		for _, entry in ipairs(current) do
			local matchesContext = normalizedContext == nil or string.lower(entry.context) == normalizedContext
			local matchesCategory = normalizedCategory == nil or string.lower(entry.category) == normalizedCategory
			if not (matchesContext and matchesCategory) then
				table.insert(retained, entry)
			end
		end

		-- Rebuild idsByScope from retained entries
		local newIdsByScope = {} :: { [string]: { number } }
		for _, entry in ipairs(retained) do
			local scopeKey = LogRetentionConfig.buildScopeKey(entry.context, entry.category)
			local ids = newIdsByScope[scopeKey]
			if not ids then
				ids = {}
				newIdsByScope[scopeKey] = ids
			end
			table.insert(ids, entry.id)
		end
		self._idsByScope = newIdsByScope

		return retained
	end)

	local developerPlayer = Players:GetPlayerByUserId(DEVELOPER_USER_ID)
	if developerPlayer then
		self._blinkServer.SyncLog.Fire(developerPlayer, {
			type = "clear",
			data = {
				context = normalizedContext,
				category = normalizedCategory,
			},
		})
	end
end

--- Returns a deep clone of all current entries for hydration on connect.
function LogSyncService:GetEntriesReadOnly(): { LogEntry }
	return deepClone(self._atom())
end

--- Fires the full entry list to the developer player for initial hydration.
function LogSyncService:HydrateDeveloper(player: Player)
	local entries = self:GetEntriesReadOnly()
	for _, entry in ipairs(entries) do
		self._blinkServer.SyncLog.Fire(player, {
			type = "entry",
			data = entry,
		})
	end
end

return LogSyncService
