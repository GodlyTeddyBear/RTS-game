--!strict

local SharedOps = {}

local function _AssertSharedTable(sharedTable: SharedTable, context: string)
	assert(typeof(sharedTable) == "SharedTable", `{context} requires a SharedTable`)
end

local function _NormalizeSharedValue(value: any): any
	if type(value) == "table" and typeof(value) ~= "SharedTable" then
		return SharedTable.new(value)
	end

	return value
end

local function _AssertNonNestedArrayValue(value: any, context: string)
	assert(type(value) ~= "table" or typeof(value) == "SharedTable", `{context} only supports flat array values`)
end

local function _AssertContiguousArray(values: { any }, context: string)
	assert(type(values) == "table", `{context} requires a table`)

	local expectedIndex = 1
	for index, value in ipairs(values) do
		assert(index == expectedIndex, `{context} arrays must be contiguous`)
		_AssertNonNestedArrayValue(value, context)
		expectedIndex += 1
	end

	for key in pairs(values) do
		assert(
			type(key) == "number" and key % 1 == 0 and key >= 1 and key < expectedIndex,
			`{context} only supports array-like tables`
		)
	end
end

function SharedOps.NormalizeValue(value: any): any
	return _NormalizeSharedValue(value)
end

function SharedOps.CreateRoot(initialFields: { [string]: any }?): SharedTable
	local root = SharedTable.new()
	if initialFields == nil then
		return root
	end

	SharedOps.ReplaceFields(root, initialFields)
	return root
end

function SharedOps.Clone(sharedTable: SharedTable, deep: boolean?): SharedTable
	_AssertSharedTable(sharedTable, "SharedPlus.Clone")
	return SharedTable.clone(sharedTable, deep == true)
end

function SharedOps.Clear(sharedTable: SharedTable)
	_AssertSharedTable(sharedTable, "SharedPlus.Clear")
	SharedTable.clear(sharedTable)
end

function SharedOps.Size(sharedTable: SharedTable): number
	_AssertSharedTable(sharedTable, "SharedPlus.Size")
	return SharedTable.size(sharedTable)
end

function SharedOps.ReplaceFields(sharedTable: SharedTable, fields: { [string]: any })
	_AssertSharedTable(sharedTable, "SharedPlus.ReplaceFields")
	assert(type(fields) == "table", "SharedPlus.ReplaceFields requires a field table")

	for fieldName, value in fields do
		assert(type(fieldName) == "string" and fieldName ~= "", "SharedPlus.ReplaceFields field names must be non-empty strings")
		SharedTable.update(sharedTable, fieldName, function()
			return _NormalizeSharedValue(value)
		end)
	end
end

function SharedOps.IncrementField(sharedTable: SharedTable, fieldName: string, delta: number?): number
	_AssertSharedTable(sharedTable, "SharedPlus.IncrementField")
	assert(type(fieldName) == "string" and fieldName ~= "", "SharedPlus.IncrementField requires a field name")

	local resolvedDelta = if delta == nil then 1 else delta
	assert(type(resolvedDelta) == "number", "SharedPlus.IncrementField delta must be a number")

	local currentValue = sharedTable[fieldName]
	if currentValue == nil then
		SharedTable.update(sharedTable, fieldName, function(value)
			if value == nil then
				return resolvedDelta
			end

			assert(type(value) == "number", `SharedPlus.IncrementField("{fieldName}") requires a numeric field`)
			return value + resolvedDelta
		end)
		return 0
	end

	assert(type(currentValue) == "number", `SharedPlus.IncrementField("{fieldName}") requires a numeric field`)
	return SharedTable.increment(sharedTable, fieldName, resolvedDelta)
end

function SharedOps.ClearArray(sharedTable: SharedTable, fieldName: string, countFieldName: string?): SharedTable
	_AssertSharedTable(sharedTable, "SharedPlus.ClearArray")
	assert(type(fieldName) == "string" and fieldName ~= "", "SharedPlus.ClearArray requires a field name")

	local child = sharedTable[fieldName]
	if typeof(child) ~= "SharedTable" then
		child = SharedTable.new()
		SharedTable.update(sharedTable, fieldName, function()
			return child
		end)
	end

	SharedTable.clear(child)

	if countFieldName ~= nil then
		SharedTable.update(sharedTable, countFieldName, function()
			return 0
		end)
	end

	return child
end

function SharedOps.ReplaceArray(
	sharedTable: SharedTable,
	fieldName: string,
	values: { any },
	countFieldName: string?
): SharedTable
	local context = `SharedPlus.ReplaceArray("{fieldName}")`
	_AssertContiguousArray(values, context)

	local child = SharedOps.ClearArray(sharedTable, fieldName, countFieldName)
	local count = 0

	for index, value in ipairs(values) do
		count = index
		child[index] = _NormalizeSharedValue(value)
	end

	if countFieldName ~= nil then
		SharedTable.update(sharedTable, countFieldName, function()
			return count
		end)
	end

	return child
end

return table.freeze(SharedOps)
