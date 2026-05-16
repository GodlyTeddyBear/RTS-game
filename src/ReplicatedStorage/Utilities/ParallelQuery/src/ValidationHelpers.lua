--!strict

local Types = require(script.Parent.Types)
local Validation = require(script.Parent.Validation)

type TMemoryFieldValidationResult = Types.TMemoryFieldValidationResult
type TRowFieldValidationResult = Types.TRowFieldValidationResult
type TResultField = Types.TResultField
type TSchemaRowValidationMode = Types.TSchemaRowValidationMode
type TSchemaRowValidationResult = Types.TSchemaRowValidationResult
type TSchemaRowsValidationResult = Types.TSchemaRowsValidationResult

local ValidationHelpers = {}

local function _Pass(): TRowFieldValidationResult
	return {
		IsValid = true,
		FieldName = nil,
		Reason = nil,
	}
end

local function _Fail(fieldName: string?, reason: string): TRowFieldValidationResult
	return {
		IsValid = false,
		FieldName = fieldName,
		Reason = reason,
	}
end

local function _FailMemory(fieldName: string?, reason: string): TMemoryFieldValidationResult
	return {
		IsValid = false,
		FieldName = fieldName,
		Reason = reason,
	}
end

local function _PassMemory(): TMemoryFieldValidationResult
	return {
		IsValid = true,
		FieldName = nil,
		Reason = nil,
	}
end

function ValidationHelpers.RequireNumberFields(
	row: { [string]: any }?,
	fieldNames: { string }
): TRowFieldValidationResult
	if type(row) ~= "table" then
		return _Fail(nil, "MissingRow")
	end

	for _, fieldName in ipairs(fieldNames) do
		if type(row[fieldName]) ~= "number" then
			return _Fail(fieldName, "ExpectedNumber")
		end
	end

	return _Pass()
end

function ValidationHelpers.RequireIntegerFields(
	row: { [string]: any }?,
	fieldNames: { string }
): TRowFieldValidationResult
	local numberCheck = ValidationHelpers.RequireNumberFields(row, fieldNames)
	if not numberCheck.IsValid then
		return numberCheck
	end

	for _, fieldName in ipairs(fieldNames) do
		local value = (row :: { [string]: any })[fieldName]
		if value % 1 ~= 0 then
			return _Fail(fieldName, "ExpectedInteger")
		end
	end

	return _Pass()
end

function ValidationHelpers.RequireIndexFields(
	row: { [string]: any }?,
	fieldNames: { string },
	maxIndex: number?
): TRowFieldValidationResult
	local integerCheck = ValidationHelpers.RequireIntegerFields(row, fieldNames)
	if not integerCheck.IsValid then
		return integerCheck
	end

	for _, fieldName in ipairs(fieldNames) do
		local value = (row :: { [string]: any })[fieldName]
		if value < 1 then
			return _Fail(fieldName, "ExpectedPositiveIndex")
		end
		if maxIndex ~= nil and value > maxIndex then
			return _Fail(fieldName, "IndexOutOfBounds")
		end
	end

	return _Pass()
end

function ValidationHelpers.RequireMemoryFields(
	memory: SharedTable?,
	fieldNames: { string }
): TMemoryFieldValidationResult
	if memory == nil then
		return _FailMemory(nil, "MissingMemory")
	end
	if typeof(memory) ~= "SharedTable" then
		return _FailMemory(nil, "ExpectedSharedTable")
	end

	for _, fieldName in ipairs(fieldNames) do
		if memory[fieldName] == nil then
			return _FailMemory(fieldName, "MissingField")
		end
	end

	return _PassMemory()
end

function ValidationHelpers.RequireSharedTableFields(
	memory: SharedTable?,
	fieldNames: { string }
): TMemoryFieldValidationResult
	local memoryCheck = ValidationHelpers.RequireMemoryFields(memory, fieldNames)
	if not memoryCheck.IsValid then
		return memoryCheck
	end

	for _, fieldName in ipairs(fieldNames) do
		if typeof((memory :: SharedTable)[fieldName]) ~= "SharedTable" then
			return _FailMemory(fieldName, "ExpectedSharedTableField")
		end
	end

	return _PassMemory()
end

function ValidationHelpers.ValidateRowAgainstSchema(
	row: { [string]: any }?,
	schema: { TResultField },
	mode: TSchemaRowValidationMode?,
	rowIndex: number?
): TSchemaRowValidationResult
	if type(row) ~= "table" then
		return {
			IsValid = false,
			FieldName = nil,
			Reason = "MissingRow",
			RowIndex = rowIndex,
		}
	end

	local resolvedMode: TSchemaRowValidationMode = if mode ~= nil then mode else "Full"
	for _, field in ipairs(schema) do
		local value = row[field.Name]
		if value == nil then
			return {
				IsValid = false,
				FieldName = field.Name,
				Reason = "MissingField",
				RowIndex = rowIndex,
			}
		end

		if resolvedMode == "RequiredOnly" then
			continue
		end

		local ok, err = pcall(function()
			Validation.AssertRowFieldMatchesSchema(field, value, "ParallelQuery.ValidateRowAgainstSchema")
		end)
		if not ok then
			return {
				IsValid = false,
				FieldName = field.Name,
				Reason = tostring(err),
				RowIndex = rowIndex,
			}
		end
	end

	return {
		IsValid = true,
		FieldName = nil,
		Reason = nil,
		RowIndex = rowIndex,
	}
end

function ValidationHelpers.ValidateRowsAgainstSchema(
	rows: { [number]: { [string]: any } },
	schema: { TResultField },
	mode: TSchemaRowValidationMode?
): TSchemaRowsValidationResult
	local invalidRowCount = 0
	local firstInvalidRowIndex = nil
	local firstInvalidFieldName = nil
	local firstInvalidReason = nil

	for rowIndex, row in ipairs(rows) do
		local validationResult = ValidationHelpers.ValidateRowAgainstSchema(row, schema, mode, rowIndex)
		if validationResult.IsValid then
			continue
		end

		invalidRowCount += 1
		if firstInvalidRowIndex == nil then
			firstInvalidRowIndex = rowIndex
			firstInvalidFieldName = validationResult.FieldName
			firstInvalidReason = validationResult.Reason
		end
	end

	return {
		IsValid = invalidRowCount == 0,
		InvalidRowCount = invalidRowCount,
		FirstInvalidRowIndex = firstInvalidRowIndex,
		FirstInvalidFieldName = firstInvalidFieldName,
		Reason = firstInvalidReason,
	}
end

return table.freeze(ValidationHelpers)
