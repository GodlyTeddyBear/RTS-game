--!strict

local Types = require(script.Parent.Types)

type TFieldType = Types.TFieldType
type TResultField = Types.TResultField
type TRowFieldValidationResult = Types.TRowFieldValidationResult
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

local function _AssertIntegerRange(value: number, minValue: number, maxValue: number, label: string)
	assert(value % 1 == 0, `{label} must be an integer`)
	assert(value >= minValue and value <= maxValue, `{label} must be in range [{minValue}, {maxValue}]`)
end

local function _AssertRowFieldMatchesSchema(field: TResultField, value: any, labelContext: string)
	local label = `{labelContext} field "{field.Name}"`
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

	error(`{label} uses unsupported field type "{(field.Type :: TFieldType)}"`)
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
			_AssertRowFieldMatchesSchema(field, value, "ParallelRunner.ValidateRowAgainstSchema")
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
