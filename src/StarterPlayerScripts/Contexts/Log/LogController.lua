--!strict
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local SharedAtoms = require(ReplicatedStorage.Contexts.Log.Sync.SharedAtoms)
local LogRetentionConfig = require(ReplicatedStorage.Contexts.Log.Config.LogRetentionConfig)
local Knit = require(ReplicatedStorage.Packages.Knit)
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local Result = require(ReplicatedStorage.Utilities.Result)
local LogSyncClient = require(script.Parent.Infrastructure.LogSyncClient)
local CommandSyncClient = require(script.Parent.Infrastructure.CommandSyncClient)

local DEVELOPER_USER_ID = 205423638

type LogEntry = SharedAtoms.LogEntry
type LogsAtom = typeof(SharedAtoms.CreateClientAtom())
type ClearFilters = {
	source: string,
	context: string?,
	category: string?,
}

local LogController = Knit.CreateController({
	Name = "LogController",
})

local function removeEntryById(entries: { LogEntry }, entryId: number): { LogEntry }
	local retained = table.create(#entries)
	for _, entry in ipairs(entries) do
		if entry.id ~= entryId then
			table.insert(retained, entry)
		end
	end
	return retained
end

local function sourcePriority(source: "client" | "server"): number
	if source == "server" then
		return 1
	end
	return 2
end

local function cloneLogs(logs: { LogEntry }): { LogEntry }
	local cloned = table.create(#logs)
	for index, entry in ipairs(logs) do
		cloned[index] = entry
	end
	return cloned
end

local function normalizeCategory(level: string, err: any, category: string?): string
	if category then
		return string.lower(category)
	end

	if err and (err :: any).isDefect then
		return "runtime"
	end

	if level == "warn" or level == "error" then
		return "error"
	end

	return "general"
end

local function serializeData(data: { [string]: any }?): string?
	if data == nil then
		return nil
	end

	local ok, encoded = pcall(HttpService.JSONEncode, HttpService, data)
	return if ok then encoded else nil
end

local function parseLabel(label: string): (string, string)
	local context = label
	local service = label
	local colonPos = string.find(label, ":", 1, true)
	if colonPos then
		context = string.sub(label, 1, colonPos - 1)
		service = string.sub(label, colonPos + 1)
	end
	return context, service
end

function LogController:KnitInit()
	self._player = Players.LocalPlayer
	self._serverLogs = {} :: { LogEntry }
	self._clientLogs = {} :: { LogEntry }
	self._clientIdsByScope = {} :: { [string]: { number } }
	self._nextClientLogId = 1
	self._mergedLogsAtom = SharedAtoms.CreateClientAtom()
	self._syncClient = LogSyncClient.new(function(serverLogs: { LogEntry })
		self:_setServerLogs(serverLogs)
	end)

	if self._player.UserId == DEVELOPER_USER_ID then
		Result.SetLogger(function(level: string, label: string, err: any)
			self:_pushClientLog(level, label, err, nil)
		end)

		Result.SetSuccessLogger(function(label: string, message: string, data: { [string]: any }?)
			self:_pushClientLog("info", label, { message = message, data = data }, "success")
		end)

		Result.SetEventLogger(function(label: string, message: string, data: { [string]: any }?)
			self:_pushClientLog("debug", label, { message = message, data = data }, "event")
		end)
	end
end

function LogController:KnitStart()
	self._syncClient:Start()

	if self._player.UserId == DEVELOPER_USER_ID then
		CommandSyncClient.Initialize()
		self:_mountDevTools()
	end
end

function LogController:_mountDevTools()
	local LogViewerScreen = require(script.Parent.Presentation.Templates.LogViewerScreen)
	local playerGui = self._player:WaitForChild("PlayerGui")
	local logViewerGui: ScreenGui? = nil
	local logViewerRoot: any = nil
	local isVisible = false

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end

		if input.KeyCode ~= Enum.KeyCode.Backquote then
			return
		end

		if not logViewerGui then
			logViewerGui, logViewerRoot = self:_createLogViewerGui(playerGui)
		end

		isVisible = not isVisible
		logViewerGui.Enabled = isVisible

		if isVisible then
			CommandSyncClient.Initialize()
			logViewerRoot:render(e(LogViewerScreen, {
				logsAtom = self:GetLogsAtom(),
				onClearAll = function(sourceFilter: string)
					self:ClearLogs(sourceFilter)
				end,
				onClearFiltered = function(filters: ClearFilters)
					self:ClearLogsByScope(filters)
				end,
			}))
		else
			logViewerRoot:render(nil)
		end
	end)
end

function LogController:_createLogViewerGui(playerGui: Instance): (ScreenGui, any)
	local gui = Instance.new("ScreenGui")
	gui.Name = "LogViewer"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 100
	gui.Enabled = false
	gui.Parent = playerGui

	local root = ReactRoblox.createRoot(gui)
	return gui, root
end

function LogController:GetLogsAtom()
	return self._mergedLogsAtom :: LogsAtom
end

function LogController:_setServerLogs(serverLogs: { LogEntry })
	self._serverLogs = cloneLogs(serverLogs)
	self:_refreshMergedLogs()
end

function LogController:_refreshMergedLogs()
	local mergedLogs = table.create(#self._serverLogs + #self._clientLogs)

	for _, entry in ipairs(self._serverLogs) do
		table.insert(mergedLogs, entry)
	end

	for _, entry in ipairs(self._clientLogs) do
		table.insert(mergedLogs, entry)
	end

	table.sort(mergedLogs, function(a: LogEntry, b: LogEntry)
		if a.timestamp ~= b.timestamp then
			return a.timestamp < b.timestamp
		end

		local sourceOrderA = sourcePriority(a.source)
		local sourceOrderB = sourcePriority(b.source)
		if sourceOrderA ~= sourceOrderB then
			return sourceOrderA < sourceOrderB
		end

		return a.id < b.id
	end)

	self._mergedLogsAtom(mergedLogs)
end

function LogController:_pushClientLog(level: string, label: string, err: any, category: string?)
	local context, service = parseLabel(label)
	local entry = {
		id = self._nextClientLogId,
		timestamp = DateTime.now().UnixTimestamp,
		level = level,
		category = normalizeCategory(level, err, category),
		source = "client" :: "client",
		context = context,
		service = service,
		milestone = nil :: string?,
		message = err.message or tostring(err),
		errType = err.type :: string?,
		traceback = (err.data and err.data.traceback or err.traceback) :: string?,
		data = serializeData(err.data),
	}

	self._nextClientLogId += 1
	self:_appendClientEntry(entry)
end

function LogController:_appendClientEntry(entry: LogEntry)
	table.insert(self._clientLogs, entry)

	local scopeKey = LogRetentionConfig.buildScopeKey(entry.context, entry.category)
	local scopedIds = self._clientIdsByScope[scopeKey]
	if not scopedIds then
		scopedIds = {}
		self._clientIdsByScope[scopeKey] = scopedIds
	end
	table.insert(scopedIds, entry.id)

	local maxEntries = LogRetentionConfig.resolveScopeLimit(entry.context, entry.category)
	while #scopedIds > maxEntries do
		local staleId = table.remove(scopedIds, 1)
		self._clientLogs = removeEntryById(self._clientLogs, staleId)
	end

	self:_refreshMergedLogs()
end

function LogController:_clearClientLogs(contextFilter: string?, categoryFilter: string?)
	local normalizedContext = LogRetentionConfig.normalizeFilter(contextFilter)
	local normalizedCategory = LogRetentionConfig.normalizeFilter(categoryFilter)

	if normalizedContext == nil and normalizedCategory == nil then
		self._clientLogs = {}
		self._clientIdsByScope = {}
		self:_refreshMergedLogs()
		return
	end

	local retained: { LogEntry } = table.create(#self._clientLogs)
	for _, entry in ipairs(self._clientLogs) do
		local matchesContext = normalizedContext == nil or string.lower(entry.context) == normalizedContext
		local matchesCategory = normalizedCategory == nil or string.lower(entry.category) == normalizedCategory
		if not (matchesContext and matchesCategory) then
			table.insert(retained, entry)
		end
	end

	self._clientLogs = retained

	local rebuiltIdsByScope = {} :: { [string]: { number } }
	for _, entry in ipairs(self._clientLogs) do
		local scopeKey = LogRetentionConfig.buildScopeKey(entry.context, entry.category)
		local ids = rebuiltIdsByScope[scopeKey]
		if not ids then
			ids = {}
			rebuiltIdsByScope[scopeKey] = ids
		end
		table.insert(ids, entry.id)
	end

	self._clientIdsByScope = rebuiltIdsByScope
	self:_refreshMergedLogs()
end

function LogController:ClearLogs(sourceFilter: string)
	local includesClient = sourceFilter == "all" or sourceFilter == "client"
	local includesServer = sourceFilter == "all" or sourceFilter == "server"

	if includesClient then
		self:_clearClientLogs(nil, nil)
	end

	if includesServer then
		local logContext = Knit.GetService("LogContext")
		logContext:ClearLogs()
	end
end

function LogController:ClearLogsByScope(filters: ClearFilters)
	local sourceFilter = filters.source
	local includesClient = sourceFilter == "all" or sourceFilter == "client"
	local includesServer = sourceFilter == "all" or sourceFilter == "server"

	if includesClient then
		self:_clearClientLogs(filters.context, filters.category)
	end

	if includesServer then
		local logContext = Knit.GetService("LogContext")
		logContext:ClearLogsByScope(filters.context, filters.category)
	end
end

return LogController
