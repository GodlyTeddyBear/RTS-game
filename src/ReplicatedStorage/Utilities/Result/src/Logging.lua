--!strict

export type ErrorLogger = (level: string, label: string, err: any) -> ()
export type MilestoneLogger = (label: string, message: string, data: { [string]: any }?) -> ()

local logger: ErrorLogger? = nil
local successLogger: MilestoneLogger? = nil
local eventLogger: MilestoneLogger? = nil

local function log(level: string, label: string, err: any)
	if logger then
		logger(level, label, err)
	else
		warn(("[" .. label .. "]"), err.type, err.message)
	end
end

local function SetLogger(fn: ErrorLogger)
	logger = fn
end

local function SetSuccessLogger(fn: MilestoneLogger)
	successLogger = fn
end

local function SetEventLogger(fn: MilestoneLogger)
	eventLogger = fn
end

local function MentionSuccess(label: string, message: string, data: { [string]: any }?)
	local currentSuccessLogger = successLogger
	if currentSuccessLogger then
		task.spawn(function()
			currentSuccessLogger(label, message, data)
		end)
	end
end

local function MentionEvent(label: string, message: string, data: { [string]: any }?)
	local currentEventLogger = eventLogger
	if currentEventLogger then
		task.spawn(function()
			currentEventLogger(label, message, data)
		end)
	end
end

local function MentionError(label: string, message: string, data: { [string]: any }?, errType: string?)
	task.spawn(function()
		log("warn", label, {
			type = errType or "MentionError",
			message = message,
			data = data,
		})
	end)
end

return table.freeze({
	log = log,
	SetLogger = SetLogger,
	SetSuccessLogger = SetSuccessLogger,
	SetEventLogger = SetEventLogger,
	MentionSuccess = MentionSuccess,
	MentionEvent = MentionEvent,
	MentionError = MentionError,
})
