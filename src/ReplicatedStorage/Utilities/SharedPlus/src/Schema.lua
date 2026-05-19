--!strict

local Types = require(script.Parent.Types)

type TScalarFieldConfig = Types.TScalarFieldConfig
type TArrayFieldConfig = Types.TArrayFieldConfig
type TRawSchema = Types.TRawSchema
type TParsedArrayField = Types.TParsedArrayField
type TParsedScalarField = Types.TParsedScalarField
type TParsedSchema = Types.TParsedSchema

local RESERVED_PACKET_KEYS = {
	Scalars = true,
	Arrays = true,
	Ops = true,
}

local Schema = {}

local function _AssertFieldName(fieldName: string, context: string)
	assert(type(fieldName) == "string" and fieldName ~= "", `{context} field names must be non-empty strings`)
	assert(not RESERVED_PACKET_KEYS[fieldName], `{context} field name "{fieldName}" is reserved`)
end

local function _CollectSortedKeys(source: { [string]: any }): { string }
	local keys = {}
	for key in source do
		keys[#keys + 1] = key
	end
	table.sort(keys)
	return keys
end

local function _ResolveCountFieldName(fieldName: string, config: TArrayFieldConfig): string
	local countFieldName = config.CountFieldName
	if countFieldName == nil then
		return `{fieldName}Count`
	end

	assert(
		type(countFieldName) == "string" and countFieldName ~= "",
		`SharedPlus schema array field "{fieldName}" CountFieldName must be a non-empty string`
	)
	return countFieldName
end

function Schema.Parse(schema: TRawSchema | TParsedSchema): TParsedSchema
	assert(type(schema) == "table", "SharedPlus schema must be a table")

	if (schema :: any).ScalarFields ~= nil and (schema :: any).ArrayFields ~= nil then
		return schema :: TParsedSchema
	end

	local rawSchema = schema :: TRawSchema
	local rawScalars = if rawSchema.Scalars ~= nil then rawSchema.Scalars else {}
	local rawArrays = if rawSchema.Arrays ~= nil then rawSchema.Arrays else {}

	assert(type(rawScalars) == "table", "SharedPlus schema Scalars must be a table when provided")
	assert(type(rawArrays) == "table", "SharedPlus schema Arrays must be a table when provided")

	local parsedScalarFields = {} :: { [string]: TParsedScalarField }
	local parsedArrayFields = {} :: { [string]: TParsedArrayField }
	local usedCountFieldNames = {}

	for fieldName, config in rawScalars do
		_AssertFieldName(fieldName, "SharedPlus schema Scalars")
		assert(type(config) == "table", `SharedPlus scalar field "{fieldName}" config must be a table`)

		parsedScalarFields[fieldName] = {
			Default = config.Default,
			AllowIncrement = config.AllowIncrement == true,
		}
	end

	for fieldName, config in rawArrays do
		_AssertFieldName(fieldName, "SharedPlus schema Arrays")
		assert(type(config) == "table", `SharedPlus array field "{fieldName}" config must be a table`)

		local countFieldName = _ResolveCountFieldName(fieldName, config)
		assert(
			parsedScalarFields[countFieldName] == nil and parsedArrayFields[countFieldName] == nil,
			`SharedPlus array field "{fieldName}" count field "{countFieldName}" collides with another declared field`
		)
		assert(
			not RESERVED_PACKET_KEYS[countFieldName],
			`SharedPlus array field "{fieldName}" count field "{countFieldName}" is reserved`
		)
		assert(
			usedCountFieldNames[countFieldName] == nil,
			`SharedPlus array field "{fieldName}" count field "{countFieldName}" collides with another array count field`
		)

		usedCountFieldNames[countFieldName] = true
		parsedArrayFields[fieldName] = {
			CapacityHint = config.CapacityHint,
			FlattenInput = config.FlattenInput == true,
			CountFieldName = countFieldName,
		}
	end

	return {
		ScalarFields = parsedScalarFields,
		ArrayFields = parsedArrayFields,
		ScalarFieldNames = _CollectSortedKeys(parsedScalarFields),
		ArrayFieldNames = _CollectSortedKeys(parsedArrayFields),
	}
end

return table.freeze(Schema)
