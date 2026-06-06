--!strict

local function _FreezeDeep(value: any, visited: { [any]: boolean }): any
	if type(value) ~= "table" or visited[value] then
		return value
	end

	visited[value] = true
	for key, nestedValue in value do
		_FreezeDeep(key, visited)
		_FreezeDeep(nestedValue, visited)
	end
	if not table.isfrozen(value) then
		table.freeze(value)
	end
	return value
end

local function FreezeDeep<T>(value: T): T
	return _FreezeDeep(value, {}) :: T
end

return FreezeDeep
