--!strict


type LogEntry = {
	id: number,
	timestamp: number,
	level: string,
	category: string,
	context: string,
	service: string,
	milestone: string?,
	message: string,
	errType: string?,
	traceback: string?,
	data: string?,
}

export type TLogEntryViewData = {
	id: number,
	displayTime: string,
	levelTag: string,
	levelColor: Color3,
	label: string,
	message: string,
	errType: string?,
	hasTraceback: boolean,
	traceback: string?,
	hasData: boolean,
	dataDisplay: string?,
}

local LEVEL_COLORS: { [string]: Color3 } = {
	info  = Color3.fromRGB(100, 200, 255),
	debug = Color3.fromRGB(180, 180, 180),
	warn  = Color3.fromRGB(255, 200, 80),
	error = Color3.fromRGB(255, 80,  80),
}

local function prettyJson(raw: string): string
	local result = {}
	local indent = 0
	local i = 1
	local len = #raw
	local inString = false

	while i <= len do
		local ch = raw:sub(i, i)

		if ch == '"' and raw:sub(i - 1, i - 1) ~= "\\" then
			inString = not inString
			table.insert(result, ch)
		elseif inString then
			table.insert(result, ch)
		elseif ch == "{" or ch == "[" then
			indent += 1
			table.insert(result, ch .. "\n" .. string.rep("  ", indent))
		elseif ch == "}" or ch == "]" then
			indent -= 1
			table.insert(result, "\n" .. string.rep("  ", indent) .. ch)
		elseif ch == "," then
			table.insert(result, ",\n" .. string.rep("  ", indent))
		elseif ch == ":" then
			table.insert(result, ": ")
		elseif ch ~= " " and ch ~= "\t" and ch ~= "\n" and ch ~= "\r" then
			table.insert(result, ch)
		end

		i += 1
	end

	return table.concat(result)
end

local LogEntryViewModel = {}

local function formatTime(seconds: number): string
	local dateTime = DateTime.fromUnixTimestamp(seconds)
	return dateTime:FormatLocalTime("HH:mm:ss", "en-us")
end

function LogEntryViewModel.fromEntry(entry: LogEntry): TLogEntryViewData
	local displayTime = formatTime(entry.timestamp)
	local levelTag = "[" .. string.upper(entry.level) .. "]"
	local levelColor = LEVEL_COLORS[entry.level] or Color3.fromRGB(180, 180, 180)

	local label = entry.context .. ":" .. entry.service
	if entry.milestone then
		label = label .. ":" .. entry.milestone
	end

	local hasTraceback = entry.traceback ~= nil and entry.traceback ~= ""
	local hasData = entry.data ~= nil

	local dataDisplay: string? = nil
	if hasData and entry.data then
		dataDisplay = prettyJson(entry.data)
	end

	return {
		id           = entry.id,
		displayTime  = displayTime,
		levelTag     = levelTag,
		levelColor   = levelColor,
		label        = label,
		message      = entry.message,
		errType      = entry.errType,
		hasTraceback = hasTraceback,
		traceback    = entry.traceback,
		hasData      = hasData,
		dataDisplay  = dataDisplay,
	}
end

return LogEntryViewModel
