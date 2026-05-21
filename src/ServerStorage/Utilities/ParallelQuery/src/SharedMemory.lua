--!strict

local Types = require(script.Parent.Types)

type TSharedMemoryScalar = Types.TSharedMemoryScalar
type TSharedMemoryArray = Types.TSharedMemoryArray
type TSharedMemoryFieldValue = Types.TSharedMemoryFieldValue

local ALLOWED_SCALAR_TYPES = {
	boolean = true,
	number = true,
	string = true,
	buffer = true,
	Vector2 = true,
	Vector3 = true,
	CFrame = true,
	Color3 = true,
	UDim = true,
	UDim2 = true,
}

local SharedMemory = {}

local function _IsScalarValue(value: any): boolean
	return ALLOWED_SCALAR_TYPES[typeof(value)] == true
end

local function _AssertArrayValue(fieldName: string, value: any)
	assert(type(value) == "table", `ParallelQuery.BuildSharedMemory("{fieldName}") array fields must be tables`)

	local expectedIndex = 1
	for index, item in ipairs(value) do
		assert(index == expectedIndex, `ParallelQuery.BuildSharedMemory("{fieldName}") arrays must be contiguous`)
		assert(
			_IsScalarValue(item),
			`ParallelQuery.BuildSharedMemory("{fieldName}") array item #{index} has unsupported type "{typeof(item)}"`
		)
		expectedIndex += 1
	end

	for key in pairs(value) do
		assert(
			type(key) == "number" and key % 1 == 0 and key >= 1 and key < expectedIndex,
			`ParallelQuery.BuildSharedMemory("{fieldName}") only supports array-like child tables`
		)
	end
end

local function _BuildArrayMemory(fieldName: string, values: TSharedMemoryArray): SharedTable
	_AssertArrayValue(fieldName, values)

	local arrayMemory = SharedTable.new()
	for index, item in ipairs(values) do
		arrayMemory[index] = item :: TSharedMemoryScalar
	end
	return arrayMemory
end

function SharedMemory.Build(fields: { [string]: TSharedMemoryFieldValue }): SharedTable
	assert(type(fields) == "table", "ParallelQuery.BuildSharedMemory requires a root field table")

	local memory = SharedTable.new()
	for fieldName, value in fields do
		assert(type(fieldName) == "string" and fieldName ~= "", "ParallelQuery.BuildSharedMemory field names must be non-empty strings")

		if _IsScalarValue(value) then
			memory[fieldName] = value :: TSharedMemoryScalar
		else
			assert(
				type(value) == "table",
				`ParallelQuery.BuildSharedMemory("{fieldName}") has unsupported type "{typeof(value)}"`
			)
			memory[fieldName] = _BuildArrayMemory(fieldName, value :: TSharedMemoryArray)
		end
	end

	return memory
end

return table.freeze(SharedMemory)
