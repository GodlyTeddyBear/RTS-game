--!strict

local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")

local Parallelizer = require(ServerStorage.Utilities.Parallelizer)
local RowDefaults = require(script.Parent.RowDefaults)
local Validation = require(script.Parent.Validation)

local OPERATIONS_FOLDER_NAME = "Operations"
local OPERATION_CONFIG_JSON_ATTRIBUTE_NAME = "ParallelQueryOperationConfigJson"

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
		local defaults = RowDefaults.BuildFlatDefaults(schema)

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
				local values = RowDefaults.BuildPackedValues(schema, defaults, row)
				_AssertRowMatchesSchema(schema, values, definition.Name)
				return values
			end,
			definition.CacheLocalMemory == true
		)
	end
end

return table.freeze(Bootstrap)
