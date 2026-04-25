--!strict

local Logging = {}

function Logging.Apply(Result: any): (level: string, label: string, err: any) -> ()
	local logger: ((level: string, label: string, err: any) -> ())? = nil
	local successLogger: ((label: string, message: string, data: { [string]: any }?) -> ())? = nil
	local eventLogger: ((label: string, message: string, data: { [string]: any }?) -> ())? = nil

	local function log(level: string, label: string, err: any)
		if logger then
			logger(level, label, err)
		else
			warn(("[" .. label .. "]"), err.type, err.message)
		end
	end

	--[=[
		Registers the error log handler used by `Catch` and `MentionError`.
		@within Result
	]=]
	function Result.SetLogger(fn: (level: string, label: string, err: any) -> ())
		logger = fn
	end

	--[=[
		Registers the success milestone log handler.
		@within Result
	]=]
	function Result.SetSuccessLogger(fn: (label: string, message: string, data: { [string]: any }?) -> ())
		successLogger = fn
	end

	--[=[
		Registers the event milestone log handler.
		@within Result
	]=]
	function Result.SetEventLogger(fn: (label: string, message: string, data: { [string]: any }?) -> ())
		eventLogger = fn
	end

	--[=[
		Records a success milestone if a success logger is registered.
		@within Result
	]=]
	function Result.MentionSuccess(label: string, message: string, data: { [string]: any }?)
		local currentSuccessLogger = successLogger
		if currentSuccessLogger then
			task.spawn(function()
				currentSuccessLogger(label, message, data)
			end)
		end
	end

	--[=[
		Records an event milestone if an event logger is registered.
		@within Result
	]=]
	function Result.MentionEvent(label: string, message: string, data: { [string]: any }?)
		local currentEventLogger = eventLogger
		if currentEventLogger then
			task.spawn(function()
				currentEventLogger(label, message, data)
			end)
		end
	end

	--[=[
		Records an issue through the standard error logger without returning a Result.
		@within Result
	]=]
	function Result.MentionError(label: string, message: string, data: { [string]: any }?, errType: string?)
		task.spawn(function()
			log("warn", label, {
				type = errType or "MentionError",
				message = message,
				data = data,
			})
		end)
	end

	return log
end

return Logging
