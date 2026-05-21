--!strict

local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")

local Parallelizer = require(ServerStorage.Utilities.Parallelizer)

local Types = require(script.Parent.Types)

type TResultField = Types.TResultField
type TFieldType = Types.TFieldType
type TOperationDefinition = Types.TOperationDefinition
type TParallelQueryConfig = Types.TParallelQueryConfig
type TRunRequest = Types.TRunRequest

local DataType = Parallelizer.DataType

local TYPE_TO_PACKET = {
	u8 = DataType.u8,
	u16 = DataType.u16,
	u32 = DataType.u32,
	i8 = DataType.i8,
	i16 = DataType.i16,
	i32 = DataType.i32,
	f32 = DataType.f32,
	f64 = DataType.f64,
	boolean = DataType.bool,
	vector2 = DataType.vector2,
	vector2i16 = DataType.vector2i16,
	vector3 = DataType.vector3,
	vector3i16 = DataType.vector3i16,
	cframe = DataType.cframe,
	cframef32 = DataType.cframef32,
	cframe18 = DataType.cframe18,
	color3 = DataType.color3,
	color3b16 = DataType.color3b16,
} :: { [TFieldType]: any }

local ALLOWED_ARGUMENT_TYPES = {
	boolean = true,
	number = true,
	buffer = true,
	Vector2 = true,
	Vector3 = true,
	CFrame = true,
	Color3 = true,
	UDim = true,
	UDim2 = true,
} :: { [string]: boolean }

local Validation = {}

local function _AssertName(name: string, label: string)
	assert(name ~= "", `{label} must not be empty`)
	assert(not name:match("%-parallelizer%-internal%-def$"), `{label} cannot end with "-parallelizer-internal-def"`)
	assert(not name:match("%-parallelizer%-internal%-mem$"), `{label} cannot end with "-parallelizer-internal-mem"`)
end

local function _AssertLength(field: TResultField)
	if field.Type == "string" then
		assert(
			type(field.Length) == "number" and field.Length > 0 and field.Length % 1 == 0,
			`Schema field "{field.Name}" requires a positive integer Length`
		)
	else
		assert(field.Length == nil, `Schema field "{field.Name}" does not support Length`)
	end
end

local function _AssertIntegerRange(value: number, minValue: number, maxValue: number, label: string)
	assert(value % 1 == 0, `{label} must be an integer`)
	assert(value >= minValue and value <= maxValue, `{label} must be between {minValue} and {maxValue}`)
end

function Validation.AssertConfig(config: TParallelQueryConfig)
	assert(type(config) == "table", "ParallelQuery.new requires a config table")
	assert(
		type(config.ActorCount) == "number" and config.ActorCount > 0 and config.ActorCount % 1 == 0,
		"ParallelQuery ActorCount must be a positive integer"
	)
	assert(
		type(config.Operations) == "table" and #config.Operations > 0,
		"ParallelQuery requires at least one operation ModuleScript"
	)
	if config.Name ~= nil then
		_AssertName(config.Name, "ParallelQuery name")
	end
	if config.ActorParent ~= nil then
		assert(typeof(config.ActorParent) == "Instance", "ParallelQuery ActorParent must be an Instance")
	end
	if config.OperationConfigs ~= nil then
		assert(type(config.OperationConfigs) == "table", "ParallelQuery OperationConfigs must be a table when provided")
	end
end

function Validation.AssertOperationModule(operationModule: ModuleScript, definition: TOperationDefinition)
	assert(operationModule:IsA("ModuleScript"), "ParallelQuery operations must be ModuleScripts")
	assert(type(definition) == "table", `Operation module "{operationModule.Name}" must return a table`)
	assert(type(definition.Name) == "string", `Operation module "{operationModule.Name}" must define Name`)
	_AssertName(definition.Name, "ParallelQuery operation name")
	assert(type(definition.Execute) == "function", `Operation "{definition.Name}" must define Execute`)
	assert(
		(type(definition.ResultSchema) == "table" and #definition.ResultSchema > 0)
			or type(definition.GetResultSchema) == "function",
		`Operation "{definition.Name}" must define a non-empty ResultSchema or GetResultSchema`
	)
	if definition.GetResultSchema ~= nil then
		assert(
			type(definition.GetResultSchema) == "function",
			`Operation "{definition.Name}" GetResultSchema must be a function when provided`
		)
	end
	if definition.CacheLocalMemory ~= nil then
		assert(
			type(definition.CacheLocalMemory) == "boolean",
			`Operation "{definition.Name}" CacheLocalMemory must be boolean when provided`
		)
	end
	if definition.InitialLocalMemory ~= nil then
		assert(
			typeof(definition.InitialLocalMemory) == "SharedTable",
			`Operation "{definition.Name}" InitialLocalMemory must be a SharedTable when provided`
		)
	end
end

function Validation.ResolveSchema(definition: TOperationDefinition, operationConfig: any?): { TResultField }
	local schema = if type(definition.GetResultSchema) == "function"
		then definition.GetResultSchema(operationConfig)
		else definition.ResultSchema

	assert(type(schema) == "table" and #schema > 0, `Operation "{definition.Name}" resolved an empty ResultSchema`)
	return schema :: { TResultField }
end

function Validation.AssertSchema(schema: { TResultField }, operationName: string)
	local seenNames = {}
	for index, field in ipairs(schema) do
		assert(type(field) == "table", `Operation "{operationName}" schema field #{index} must be a table`)
		assert(
			type(field.Name) == "string" and field.Name ~= "",
			`Operation "{operationName}" schema field #{index} requires Name`
		)
		assert(type(field.Type) == "string", `Operation "{operationName}" schema field "{field.Name}" requires Type`)
		assert(seenNames[field.Name] == nil, `Operation "{operationName}" has duplicate schema field "{field.Name}"`)
		seenNames[field.Name] = true
		_AssertLength(field)
		assert(field.Type ~= "buffer", `Operation "{operationName}" may not use buffer result fields`)
		assert(
			TYPE_TO_PACKET[field.Type] ~= nil or field.Type == "string",
			`Operation "{operationName}" uses unsupported field type "{field.Type}"`
		)
	end
end

function Validation.BuildPacketDefinition(schema: { TResultField }): { any }
	local packetDefinition = table.create(#schema)
	for _, field in ipairs(schema) do
		if field.Type == "string" then
			table.insert(packetDefinition, DataType.str(field.Length :: number))
		else
			table.insert(packetDefinition, TYPE_TO_PACKET[field.Type])
		end
	end
	return packetDefinition
end

function Validation.AssertRowFieldMatchesSchema(field: TResultField, value: any, operationName: string)
	local label = `Operation "{operationName}" field "{field.Name}"`
	if field.Type == "boolean" then
		assert(type(value) == "boolean", `{label} must be boolean`)
		return
	end

	if field.Type == "string" then
		assert(type(value) == "string", `{label} must be string`)
		assert(#value <= (field.Length :: number), `{label} exceeds max length {field.Length}`)
		return
	end

	if field.Type == "u8" then
		assert(type(value) == "number", `{label} must be number`)
		_AssertIntegerRange(value, 0, 255, label)
		return
	end
	if field.Type == "u16" then
		assert(type(value) == "number", `{label} must be number`)
		_AssertIntegerRange(value, 0, 65535, label)
		return
	end
	if field.Type == "u32" then
		assert(type(value) == "number", `{label} must be number`)
		_AssertIntegerRange(value, 0, 4294967295, label)
		return
	end
	if field.Type == "i8" then
		assert(type(value) == "number", `{label} must be number`)
		_AssertIntegerRange(value, -128, 127, label)
		return
	end
	if field.Type == "i16" then
		assert(type(value) == "number", `{label} must be number`)
		_AssertIntegerRange(value, -32768, 32767, label)
		return
	end
	if field.Type == "i32" then
		assert(type(value) == "number", `{label} must be number`)
		_AssertIntegerRange(value, -2147483648, 2147483647, label)
		return
	end
	if field.Type == "f32" or field.Type == "f64" then
		assert(type(value) == "number", `{label} must be number`)
		return
	end
	if field.Type == "vector2" then
		assert(typeof(value) == "Vector2", `{label} must be Vector2`)
		return
	end
	if field.Type == "vector2i16" then
		assert(typeof(value) == "Vector2int16", `{label} must be Vector2int16`)
		return
	end
	if field.Type == "vector3" then
		assert(typeof(value) == "Vector3", `{label} must be Vector3`)
		return
	end
	if field.Type == "vector3i16" then
		assert(typeof(value) == "Vector3int16", `{label} must be Vector3int16`)
		return
	end
	if field.Type == "cframe" or field.Type == "cframef32" or field.Type == "cframe18" then
		assert(typeof(value) == "CFrame", `{label} must be CFrame`)
		return
	end
	if field.Type == "color3" or field.Type == "color3b16" then
		assert(typeof(value) == "Color3", `{label} must be Color3`)
		return
	end

	error(`{label} uses unsupported field type "{field.Type}"`)
end

function Validation.AssertRunRequest(request: TRunRequest, operationName: string)
	assert(type(request) == "table", `ParallelQuery:Run("{operationName}") requires a request table`)
	assert(
		type(request.WorkCount) == "number" and request.WorkCount >= 0 and request.WorkCount % 1 == 0,
		`ParallelQuery:Run("{operationName}") WorkCount must be a non-negative integer`
	)
	if request.BatchSize ~= nil then
		assert(
			type(request.BatchSize) == "number" and request.BatchSize > 0 and request.BatchSize % 1 == 0,
			`ParallelQuery:Run("{operationName}") BatchSize must be a positive integer`
		)
	end
	if request.Arguments ~= nil then
		assert(
			type(request.Arguments) == "table",
			`ParallelQuery:Run("{operationName}") Arguments must be an array when provided`
		)
	end
	if request.TimeoutSeconds ~= nil then
		assert(
			type(request.TimeoutSeconds) == "number" and request.TimeoutSeconds > 0,
			`ParallelQuery:Run("{operationName}") TimeoutSeconds must be a positive number`
		)
	end
	if (request :: any).LocalMemory ~= nil then
		error(
			`ParallelQuery:Run("{operationName}") no longer accepts request.LocalMemory; call SetLocalMemory("{operationName}", sharedMemory) before running cached-memory operations`,
			2
		)
	end
end

function Validation.AssertArguments(argumentsList: { any }, operationName: string)
	for index, value in ipairs(argumentsList) do
		local valueType = typeof(value)
		assert(
			ALLOWED_ARGUMENT_TYPES[valueType] == true,
			`ParallelQuery:Run("{operationName}") argument #{index} has unsupported type "{valueType}"`
		)
	end
end

function Validation.AssertSharedMemory(sharedMemory: SharedTable, operationName: string)
	assert(
		typeof(sharedMemory) == "SharedTable",
		`ParallelQuery:SetLocalMemory("{operationName}") requires a SharedTable`
	)
end

function Validation.AssertOperationConfigEncodable(operationName: string, operationConfig: any)
	local ok, err = pcall(function()
		HttpService:JSONEncode(operationConfig)
	end)
	assert(ok, `ParallelQuery operation "{operationName}" config must be JSON-encodable: {tostring(err)}`)
end

return table.freeze(Validation)
