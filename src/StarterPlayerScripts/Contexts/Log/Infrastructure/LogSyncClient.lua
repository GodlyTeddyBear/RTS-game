--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SharedAtoms = require(ReplicatedStorage.Contexts.Log.Sync.SharedAtoms)
local BlinkClient = require(ReplicatedStorage.Network.Generated.LogSyncClient)
local LogRetentionConfig = require(ReplicatedStorage.Contexts.Log.Config.LogRetentionConfig)

--[[
	Client-Side Log Sync

	Subscribes to Blink SyncLog events and maintains a local Charm atom of
	log entries. Handles both "entry" (append) and "clear" (scoped removal)
	variants. Developer-only — only the server fires to this player.
]]

type LogEntry = SharedAtoms.LogEntry
type LogsAtom = typeof(SharedAtoms.CreateClientAtom())

type LogSyncClientInstance = {
	_atom: LogsAtom,
	_idsByScope: { [string]: { number } },
	_onLogsChanged: (({ LogEntry }) -> ())?,
}

type LogSyncClientClass = typeof(setmetatable(
	{} :: LogSyncClientInstance,
	{} :: { __index: any }
))

local LogSyncClient = {}
LogSyncClient.__index = LogSyncClient

local function removeEntryById(entries: { LogEntry }, entryId: number): { LogEntry }
	local retained = table.create(#entries)
	for _, entry in ipairs(entries) do
		if entry.id ~= entryId then
			table.insert(retained, entry)
		end
	end
	return retained
end

local function normalizeIncomingEntry(entry: LogEntry): LogEntry
	if entry.source ~= nil then
		return entry
	end

	local normalizedEntry = table.clone(entry) :: any
	normalizedEntry.source = "server"
	return normalizedEntry
end

function LogSyncClient.new(onLogsChanged: (({ LogEntry }) -> ())?): LogSyncClientClass
	local self: LogSyncClientInstance = {
		_atom = SharedAtoms.CreateClientAtom(),
		_idsByScope = {},
		_onLogsChanged = onLogsChanged,
	}
	return setmetatable(self, LogSyncClient) :: any
end

function LogSyncClient:_notifyLogsChanged()
	local currentLogs = (self :: LogSyncClientInstance)._atom()
	local onLogsChanged = (self :: LogSyncClientInstance)._onLogsChanged
	if onLogsChanged then
		onLogsChanged(table.clone(currentLogs))
	end
end

function LogSyncClient:Start()
	BlinkClient.SyncLog.On(function(event: BlinkClient.LogEvent)
		if event.type == "entry" then
			local entryData = (event :: { type: "entry", data: BlinkClient.LogEntry }).data
			self:_applyEntry(entryData)
		elseif event.type == "clear" then
			local clearData = (event :: { type: "clear", data: BlinkClient.ClearSignal }).data
			self:_applyClear(clearData.context, clearData.category)
		end
	end)
end

function LogSyncClient:_applyEntry(entry: LogEntry)
	local self_ = self :: LogSyncClientInstance
	local normalizedEntry = normalizeIncomingEntry(entry)
	self_._atom(function(current: { LogEntry })
		local updated = table.clone(current)
		table.insert(updated, normalizedEntry)

		local scopeKey = LogRetentionConfig.buildScopeKey(normalizedEntry.context, normalizedEntry.category)
		local scopedIds = self_._idsByScope[scopeKey]
		if not scopedIds then
			scopedIds = {}
			self_._idsByScope[scopeKey] = scopedIds
		end
		table.insert(scopedIds, normalizedEntry.id)

		local maxEntries = LogRetentionConfig.resolveScopeLimit(normalizedEntry.context, normalizedEntry.category)
		while #scopedIds > maxEntries do
			local staleId = table.remove(scopedIds, 1)
			updated = removeEntryById(updated, staleId)
		end

		return updated
	end)
	self:_notifyLogsChanged()
end

function LogSyncClient:_applyClear(contextFilter: string?, categoryFilter: string?)
	local self_ = self :: LogSyncClientInstance
	local normalizedContext = LogRetentionConfig.normalizeFilter(contextFilter)
	local normalizedCategory = LogRetentionConfig.normalizeFilter(categoryFilter)

	if normalizedContext == nil and normalizedCategory == nil then
		self_._idsByScope = {}
		self_._atom({} :: { LogEntry })
		self:_notifyLogsChanged()
		return
	end

	self_._atom(function(current: { LogEntry })
		local retained: { LogEntry } = table.create(#current)
		for _, entry in ipairs(current) do
			local matchesContext = normalizedContext == nil or string.lower(entry.context) == normalizedContext
			local matchesCategory = normalizedCategory == nil or string.lower(entry.category) == normalizedCategory
			if not (matchesContext and matchesCategory) then
				table.insert(retained, entry)
			end
		end

		local newIdsByScope: { [string]: { number } } = {}
		for _, entry in ipairs(retained) do
			local scopeKey = LogRetentionConfig.buildScopeKey(entry.context, entry.category)
			local ids = newIdsByScope[scopeKey]
			if not ids then
				ids = {}
				newIdsByScope[scopeKey] = ids
			end
			table.insert(ids, entry.id)
		end
		self_._idsByScope = newIdsByScope

		return retained
	end)
	self:_notifyLogsChanged()
end

function LogSyncClient:GetLogsAtom(): LogsAtom
	return (self :: LogSyncClientInstance)._atom
end

return LogSyncClient
