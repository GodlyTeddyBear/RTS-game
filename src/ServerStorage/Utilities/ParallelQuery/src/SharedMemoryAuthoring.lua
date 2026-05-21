--!strict

local SharedMemory = require(script.Parent.SharedMemory)
local Types = require(script.Parent.Types)

type TSharedMemoryFieldMap = Types.TSharedMemoryFieldMap
type TSharedMemoryScalar = Types.TSharedMemoryScalar
type TSharedMemorySnapshotBuilder = Types.TSharedMemorySnapshotBuilder

local SharedMemoryAuthoring = {}

local function _CloneFieldMap(fields: TSharedMemoryFieldMap): TSharedMemoryFieldMap
	local clonedFields = {}

	for fieldName, value in fields do
		if type(value) == "table" then
			local clonedArray = table.clone(value)
			clonedFields[fieldName] = clonedArray
		else
			clonedFields[fieldName] = value
		end
	end

	return clonedFields
end

local function _GetOrCreateArrayField(builder: TSharedMemorySnapshotBuilder, fieldName: string): { [number]: TSharedMemoryScalar }
	local currentField = builder.Fields[fieldName]
	if currentField == nil then
		local values = {}
		builder.Fields[fieldName] = values
		builder.ArrayLengths[fieldName] = 0
		return values
	end

	assert(type(currentField) == "table", `ParallelQuery.SharedMemoryAuthoring field "{fieldName}" is already a scalar field`)
	return currentField :: { [number]: TSharedMemoryScalar }
end

function SharedMemoryAuthoring.CreateSnapshotBuilder(): TSharedMemorySnapshotBuilder
	return {
		Fields = {},
		ArrayLengths = {},
	}
end

function SharedMemoryAuthoring.SetScalar(
	builder: TSharedMemorySnapshotBuilder,
	fieldName: string,
	value: TSharedMemoryScalar
)
	assert(type(fieldName) == "string" and fieldName ~= "", "ParallelQuery.SharedMemoryAuthoring.SetScalar requires a field name")
	assert(type(value) ~= "table", `ParallelQuery.SharedMemoryAuthoring.SetScalar("{fieldName}") requires a scalar value`)

	builder.Fields[fieldName] = value
	builder.ArrayLengths[fieldName] = nil
end

function SharedMemoryAuthoring.PushArrayValue(
	builder: TSharedMemorySnapshotBuilder,
	fieldName: string,
	value: TSharedMemoryScalar
)
	assert(type(fieldName) == "string" and fieldName ~= "", "ParallelQuery.SharedMemoryAuthoring.PushArrayValue requires a field name")
	assert(type(value) ~= "table", `ParallelQuery.SharedMemoryAuthoring.PushArrayValue("{fieldName}") requires a scalar value`)

	local arrayField = _GetOrCreateArrayField(builder, fieldName)
	local nextIndex = (builder.ArrayLengths[fieldName] or 0) + 1
	arrayField[nextIndex] = value
	builder.ArrayLengths[fieldName] = nextIndex
end

function SharedMemoryAuthoring.SetArrayValues(
	builder: TSharedMemorySnapshotBuilder,
	fieldName: string,
	values: { [number]: TSharedMemoryScalar }
)
	assert(type(fieldName) == "string" and fieldName ~= "", "ParallelQuery.SharedMemoryAuthoring.SetArrayValues requires a field name")
	assert(type(values) == "table", `ParallelQuery.SharedMemoryAuthoring.SetArrayValues("{fieldName}") requires an array table`)

	local clonedValues = table.clone(values)
	builder.Fields[fieldName] = clonedValues
	builder.ArrayLengths[fieldName] = #clonedValues
end

function SharedMemoryAuthoring.AppendRow(
	builder: TSharedMemorySnapshotBuilder,
	row: { [string]: TSharedMemoryScalar }
)
	assert(type(row) == "table", "ParallelQuery.SharedMemoryAuthoring.AppendRow requires a row table")

	for fieldName, value in row do
		SharedMemoryAuthoring.PushArrayValue(builder, fieldName, value)
	end
end

function SharedMemoryAuthoring.BuildFieldMap(builder: TSharedMemorySnapshotBuilder): TSharedMemoryFieldMap
	return _CloneFieldMap(builder.Fields)
end

function SharedMemoryAuthoring.BuildSharedMemory(builder: TSharedMemorySnapshotBuilder): SharedTable
	return SharedMemory.Build(SharedMemoryAuthoring.BuildFieldMap(builder))
end

return table.freeze(SharedMemoryAuthoring)
