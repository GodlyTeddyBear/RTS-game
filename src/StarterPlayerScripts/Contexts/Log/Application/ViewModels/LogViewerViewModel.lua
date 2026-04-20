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
	data: { [string]: any }?,
}

export type TFilterOption = {
	value: string,
	label: string,
	count: number,
}

export type TFilterState = {
	level: string,
	category: string,
	context: string,
}

export type TLogViewerViewData = {
	filteredLogs: { LogEntry },
	levelOptions: { TFilterOption },
	categoryOptions: { TFilterOption },
	contextOptions: { TFilterOption },
}

local LogViewerViewModel = {}

local LEVEL_ORDER = { "info", "debug", "warn", "error" }
local CATEGORY_PRIORITY = {
	event = 1,
	success = 2,
	error = 3,
	runtime = 4,
	general = 5,
}

local function normalizeCategory(category: string?): string
	if category == nil or category == "" then
		return "general"
	end
	return string.lower(category)
end

local function normalizeFilter(value: string): string
	if value == "All" then
		return "all"
	end
	return string.lower(value)
end

local function toDisplayLabel(value: string): string
	if value == "all" then
		return "All"
	end
	return string.upper(string.sub(value, 1, 1)) .. string.sub(value, 2)
end

local function matchesFilter(entryValue: string, activeFilter: string): boolean
	return activeFilter == "all" or entryValue == activeFilter
end

local function countWhere(logs: { LogEntry }, predicate: (LogEntry) -> boolean): number
	local count = 0
	for _, entry in ipairs(logs) do
		if predicate(entry) then
			count += 1
		end
	end
	return count
end

local function buildLevelOptions(logs: { LogEntry }, categoryFilter: string, contextFilter: string): { TFilterOption }
	local options: { TFilterOption } = {
		{
			value = "all",
			label = "All",
			count = countWhere(logs, function(entry)
				return matchesFilter(normalizeCategory(entry.category), categoryFilter)
					and matchesFilter(string.lower(entry.context), contextFilter)
			end),
		},
	}

	for _, level in ipairs(LEVEL_ORDER) do
		table.insert(options, {
			value = level,
			label = toDisplayLabel(level),
			count = countWhere(logs, function(entry)
				return string.lower(entry.level) == level
					and matchesFilter(normalizeCategory(entry.category), categoryFilter)
					and matchesFilter(string.lower(entry.context), contextFilter)
			end),
		})
	end

	return options
end

local function buildCategoryOptions(logs: { LogEntry }, levelFilter: string, contextFilter: string): { TFilterOption }
	local categorySet: { [string]: boolean } = {}
	for _, entry in ipairs(logs) do
		categorySet[normalizeCategory(entry.category)] = true
	end

	local categories: { string } = {}
	for category in categorySet do
		table.insert(categories, category)
	end

	table.sort(categories, function(a, b)
		local priorityA = CATEGORY_PRIORITY[a] or math.huge
		local priorityB = CATEGORY_PRIORITY[b] or math.huge
		if priorityA == priorityB then
			return a < b
		end
		return priorityA < priorityB
	end)

	local options: { TFilterOption } = {
		{
			value = "all",
			label = "All",
			count = countWhere(logs, function(entry)
				return matchesFilter(string.lower(entry.level), levelFilter)
					and matchesFilter(string.lower(entry.context), contextFilter)
			end),
		},
	}

	for _, category in ipairs(categories) do
		table.insert(options, {
			value = category,
			label = toDisplayLabel(category),
			count = countWhere(logs, function(entry)
				return matchesFilter(string.lower(entry.level), levelFilter)
					and normalizeCategory(entry.category) == category
					and matchesFilter(string.lower(entry.context), contextFilter)
			end),
		})
	end

	return options
end

local function buildContextOptions(logs: { LogEntry }, levelFilter: string, categoryFilter: string): { TFilterOption }
	local contextSet: { [string]: boolean } = {}
	for _, entry in ipairs(logs) do
		contextSet[string.lower(entry.context)] = true
	end

	local contexts: { string } = {}
	for context in contextSet do
		table.insert(contexts, context)
	end
	table.sort(contexts)

	local options: { TFilterOption } = {
		{
			value = "all",
			label = "All",
			count = countWhere(logs, function(entry)
				return matchesFilter(string.lower(entry.level), levelFilter)
					and matchesFilter(normalizeCategory(entry.category), categoryFilter)
			end),
		},
	}

	for _, context in ipairs(contexts) do
		table.insert(options, {
			value = context,
			label = toDisplayLabel(context),
			count = countWhere(logs, function(entry)
				return matchesFilter(string.lower(entry.level), levelFilter)
					and matchesFilter(normalizeCategory(entry.category), categoryFilter)
					and string.lower(entry.context) == context
			end),
		})
	end

	return options
end

function LogViewerViewModel.build(logs: { LogEntry }, filters: TFilterState): TLogViewerViewData
	local levelFilter = normalizeFilter(filters.level)
	local categoryFilter = normalizeFilter(filters.category)
	local contextFilter = normalizeFilter(filters.context)

	local filteredLogs = {}
	for _, entry in ipairs(logs) do
		if matchesFilter(string.lower(entry.level), levelFilter)
			and matchesFilter(normalizeCategory(entry.category), categoryFilter)
			and matchesFilter(string.lower(entry.context), contextFilter)
		then
			table.insert(filteredLogs, entry)
		end
	end

	return {
		filteredLogs = filteredLogs,
		levelOptions = buildLevelOptions(logs, categoryFilter, contextFilter),
		categoryOptions = buildCategoryOptions(logs, levelFilter, contextFilter),
		contextOptions = buildContextOptions(logs, levelFilter, categoryFilter),
	}
end

return LogViewerViewModel
