--!strict
local DEFAULT_SCOPE_KEY = "*::*"

local MAX_ENTRIES_BY_SCOPE = table.freeze({
	["*::error"] = 200,
	["*::success"] = 250,
	["*::event"] = 100,
	["*::runtime"] = 100,
	["*::general"] = 100,
	[DEFAULT_SCOPE_KEY] = 100,
})

local function normalizeFilter(filterValue: string?): string?
	if filterValue == nil then
		return nil
	end

	local normalized = string.lower(filterValue)
	if normalized == "" or normalized == "all" then
		return nil
	end

	return normalized
end

local function buildScopeKey(context: string, category: string): string
	return string.lower(context) .. "::" .. string.lower(category)
end

local function resolveScopeLimit(context: string, category: string): number
	local normalizedContext = string.lower(context)
	local normalizedCategory = string.lower(category)

	local exactScopeKey = normalizedContext .. "::" .. normalizedCategory
	local contextWildcardKey = normalizedContext .. "::*"
	local categoryWildcardKey = "*::" .. normalizedCategory

	return MAX_ENTRIES_BY_SCOPE[exactScopeKey]
		or MAX_ENTRIES_BY_SCOPE[contextWildcardKey]
		or MAX_ENTRIES_BY_SCOPE[categoryWildcardKey]
		or MAX_ENTRIES_BY_SCOPE[DEFAULT_SCOPE_KEY]
		or 100
end

return table.freeze({
	DEFAULT_SCOPE_KEY = DEFAULT_SCOPE_KEY,
	MAX_ENTRIES_BY_SCOPE = MAX_ENTRIES_BY_SCOPE,
	normalizeFilter = normalizeFilter,
	buildScopeKey = buildScopeKey,
	resolveScopeLimit = resolveScopeLimit,
})
