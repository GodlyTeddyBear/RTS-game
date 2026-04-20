--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Registry = require(ReplicatedStorage.Utilities.Registry)
local Result = require(ReplicatedStorage.Utilities.Result)
local LogRetentionConfig = require(ReplicatedStorage.Contexts.Log.Config.LogRetentionConfig)
local BlinkServer = require(ReplicatedStorage.Network.Generated.LogSyncServer)
local LogSyncService = require(script.Parent.Infrastructure.Persistence.LogSyncService)

local DEVELOPER_USER_ID = 205423638

export type LogLevel = "info" | "debug" | "warn" | "error"
export type LogCategory = "general" | "event" | "success" | "error" | "runtime"

export type LogEntry = {
	id: number,
	timestamp: number,
	level: LogLevel,
	category: LogCategory,
	context: string,
	service: string,
	milestone: string?,
	message: string,
	errType: string?,
	traceback: string?,
	data: { [string]: any }?,
}

local LogContext = Knit.CreateService({
	Name = "LogContext",
	Client = {},
})

---
-- Knit Lifecycle
---

function LogContext:KnitInit()
	self._nextId = 1
	self._developerUserId = DEVELOPER_USER_ID

	local registry = Registry.new("Log")
	registry:Register("BlinkServer", BlinkServer)
	registry:Register("LogSyncService", LogSyncService.new(), "Infrastructure")
	registry:InitAll()
	self._logSyncService = registry:Get("LogSyncService")

	Result.SetLogger(function(level: string, label: string, err: any)
		self:_Push(level, label, err, nil)
	end)

	Result.SetSuccessLogger(function(label: string, message: string, data: { [string]: any }?)
		self:_Push("info", label, { message = message, data = data }, "success")
	end)

	Result.SetEventLogger(function(label: string, message: string, data: { [string]: any }?)
		self:_Push("debug", label, { message = message, data = data }, "event")
	end)
end

function LogContext:KnitStart()
	Players.PlayerAdded:Connect(function(player: Player)
		if player.UserId == self._developerUserId then
			self._logSyncService:HydrateDeveloper(player)
		end
	end)

	-- Hydrate if developer is already in the server
	local developerPlayer = Players:GetPlayerByUserId(self._developerUserId)
	if developerPlayer then
		self._logSyncService:HydrateDeveloper(developerPlayer)
	end
end

---
-- Internal
---

local CATEGORY_MAP: { [string]: LogCategory } = {
	event = "event",
	success = "success",
	runtime = "runtime",
	error = "error",
	general = "general",
}

local function normalizeCategory(level: LogLevel, err: any, category: string?): LogCategory
	local mappedCategory: LogCategory? = nil
	if category then
		mappedCategory = CATEGORY_MAP[string.lower(category)]
	end

	if mappedCategory then
		return mappedCategory
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

function LogContext:_Push(level: string, label: string, err: any, category: string?)
	-- Parse label into context and service (format: "Context:Service" or "Context.Client:Method")
	local context = label
	local service = label
	local colonPos = string.find(label, ":", 1, true)
	if colonPos then
		context = string.sub(label, 1, colonPos - 1)
		service = string.sub(label, colonPos + 1)
	end

	local syncEntry = {
		id = self._nextId,
		timestamp = DateTime.now().UnixTimestamp,
		level = level,
		category = normalizeCategory(level :: LogLevel, err, category),
		context = context,
		service = service,
		milestone = nil :: string?,
		message = err.message or tostring(err),
		errType = err.type :: string?,
		traceback = (err.data and err.data.traceback or err.traceback) :: string?,
		data = serializeData(err.data),
	}

	self._nextId += 1

	if self._logSyncService then
		self._logSyncService:Push(syncEntry)
	end
end

---
-- Client API
---

--- Clears all log entries. Only responds to the developer.
function LogContext.Client:ClearLogs(player: Player)
	if player.UserId ~= self.Server._developerUserId then
		return
	end
	self.Server._nextId = 1
	self.Server._logSyncService:Clear(nil, nil)
end

--- Clears log entries matching the given context/category scope. Only responds to the developer.
function LogContext.Client:ClearLogsByScope(player: Player, context: string?, category: string?)
	if player.UserId ~= self.Server._developerUserId then
		return
	end

	local normalizedContext = LogRetentionConfig.normalizeFilter(context)
	local normalizedCategory = LogRetentionConfig.normalizeFilter(category)
	if normalizedContext == nil and normalizedCategory == nil then
		self:ClearLogs(player)
		return
	end

	self.Server._logSyncService:Clear(normalizedContext, normalizedCategory)
end

return LogContext
