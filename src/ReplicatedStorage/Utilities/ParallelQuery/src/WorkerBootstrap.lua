--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Parallelizer = require(ReplicatedStorage.Utilities.Parallelizer)
local Validation = require(ReplicatedStorage.Utilities.ParallelQuery.src.Validation)

local OPERATIONS_FOLDER_NAME = "Operations"
local OPERATION_CONFIG_JSON_ATTRIBUTE_NAME = "ParallelQueryOperationConfigJson"

local function _BuildDefaults(schema)
	local defaults = table.create(#schema)

	for index, field in ipairs(schema) do
		local value

		if field.Type == "boolean" then
			value = false
		elseif field.Type == "string" then
			value = ""
		elseif field.Type == "vector2" then
			value = Vector2.zero
		elseif field.Type == "vector2i16" then
			value = Vector2int16.new(0, 0)
		elseif field.Type == "vector3" then
			value = Vector3.zero
		elseif field.Type == "vector3i16" then
			value = Vector3int16.new(0, 0, 0)
		elseif field.Type == "cframe" or field.Type == "cframef32" or field.Type == "cframe18" then
			value = CFrame.identity
		elseif field.Type == "color3" or field.Type == "color3b16" then
			value = Color3.new(0, 0, 0)
		elseif field.Type == "buffer" then
			value = buffer.create(field.Length or 0)
		else
			value = 0
		end

		defaults[index] = value
	end

	return defaults
end

local function _BuildResponseRow(schema, defaults, row)
	local values = table.create(#schema)

	for index, field in ipairs(schema) do
		local value = row[field.Name]
		if value == nil then
			value = row[index]
		end
		if value == nil then
			value = defaults[index]
		end

		values[index] = value
	end

	return values
end

local function _AssertRowMatchesSchema(schema, values, operationName: string)
	for index, field in ipairs(schema) do
		Validation.AssertRowFieldMatchesSchema(field, values[index], operationName)
	end
end

local function _ReportFailure(
	failureBindable: BindableEvent?,
	taskId: number,
	message: string,
	tracebackMessage: string
)
	if failureBindable == nil then
		return
	end

	failureBindable:Fire(taskId, message, tracebackMessage)
end

local Bootstrap = {}

local function _DecodeOperationConfig(operationModule: ModuleScript): any?
	local encodedOperationConfig = operationModule:GetAttribute(OPERATION_CONFIG_JSON_ATTRIBUTE_NAME)
	if type(encodedOperationConfig) ~= "string" or encodedOperationConfig == "" then
		return nil
	end

	return HttpService:JSONDecode(encodedOperationConfig)
end

function Bootstrap.RegisterOperations(workerScript: Script)
	local actor = workerScript:GetActor()
	if actor == nil then
		return
	end

	local operationsFolder = workerScript:FindFirstChild(OPERATIONS_FOLDER_NAME)
	assert(
		operationsFolder ~= nil and operationsFolder:IsA("Folder"),
		"ParallelQuery worker is missing its Operations folder"
	)

	for _, operationModule in ipairs(operationsFolder:GetChildren()) do
		if not operationModule:IsA("ModuleScript") then
			continue
		end

		local definition = require(operationModule)
		local operationConfig = _DecodeOperationConfig(operationModule)
		local schema = Validation.ResolveSchema(definition, operationConfig)
		local defaults = _BuildDefaults(schema)

		Parallelizer.ListenToTask(
			actor,
			definition.Name,
			function(
				taskId: number,
				memory: SharedTable?,
				logicalWorkCount: number,
				failureBindable: BindableEvent?,
				...
			)
				local packedArgs = table.pack(...)

				if taskId > logicalWorkCount then
					return defaults
				end

				local errorMessage: string? = nil
				local ok, rowOrTraceback = xpcall(function()
					return definition.Execute(taskId, memory, table.unpack(packedArgs, 1, packedArgs.n))
				end, function(err)
					errorMessage = tostring(err)
					return debug.traceback(errorMessage, 2)
				end)

				if not ok then
					_ReportFailure(failureBindable, taskId, errorMessage or tostring(rowOrTraceback), rowOrTraceback)
					return defaults
				end

				local row = rowOrTraceback
				assert(type(row) == "table", `ParallelQuery operation "{definition.Name}" must return a table row`)
				local values = _BuildResponseRow(schema, defaults, row)
				_AssertRowMatchesSchema(schema, values, definition.Name)
				return values
			end,
			definition.CacheLocalMemory == true
		)
	end
end

return table.freeze(Bootstrap)
