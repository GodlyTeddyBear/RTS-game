--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Sera = require(ReplicatedStorage.Utilities.Sera)
local Envelope = require(ReplicatedStorage.Utilities.ParallelLogistics.src.Envelope)

type TPayloadScalarType =
	"u8"
	| "u16"
	| "u32"
	| "i8"
	| "i16"
	| "i32"
	| "f32"
	| "f64"
	| "boolean"
	| "string8"
	| "string16"
	| "string32"
	| "vector3"
	| "cframe"
	| "lossyCFrame"
	| "color3"

type TPayloadSchemaDescriptorField = {
	Name: string,
	TypeName: TPayloadScalarType,
}

type TPayloadSchemaDescriptor = {
	Scalars: { TPayloadSchemaDescriptorField },
	Arrays: { TPayloadSchemaDescriptorField },
}

type TTypeInfo = {
	Name: TPayloadScalarType,
	Ser: (buffer, number, any) -> number,
	Des: (buffer, number) -> (any, number),
}

local TYPE_INFO_BY_NAME = table.freeze({
	u8 = Sera.Uint8,
	u16 = Sera.Uint16,
	u32 = Sera.Uint32,
	i8 = Sera.Int8,
	i16 = Sera.Int16,
	i32 = Sera.Int32,
	f32 = Sera.Float32,
	f64 = Sera.Float64,
	boolean = Sera.Boolean,
	string8 = Sera.String8,
	string16 = Sera.String16,
	string32 = Sera.String32,
	vector3 = Sera.Vector3,
	cframe = Sera.CFrame,
	lossyCFrame = Sera.LossyCFrame,
	color3 = Sera.Color3,
}) :: { [TPayloadScalarType]: TTypeInfo }

local FIXED_SIZE_BY_NAME = table.freeze({
	u8 = 1,
	u16 = 2,
	u32 = 4,
	i8 = 1,
	i16 = 2,
	i32 = 4,
	f32 = 4,
	f64 = 8,
	boolean = 1,
	vector3 = 12,
	cframe = 48,
	lossyCFrame = 28,
	color3 = 3,
}) :: { [string]: number }

local STRING_PREFIX_SIZE_BY_NAME = table.freeze({
	string8 = 1,
	string16 = 2,
	string32 = 4,
}) :: { [string]: number }

local ARRAY_LENGTH_BYTES = 4

local function _FormatError(jobName: string, operationName: string, message: string): string
	return `ParallelRunner payload "{jobName}" {operationName} failed: {message}`
end

local function _BuildUnexpectedFieldLookup(descriptor: TPayloadSchemaDescriptor): { [string]: true }
	local lookup = {}

	for _, field in ipairs(descriptor.Scalars) do
		lookup[field.Name] = true
	end

	for _, field in ipairs(descriptor.Arrays) do
		lookup[field.Name] = true
	end

	return table.freeze(lookup)
end

local function _BuildTypeInfo(typeName: TPayloadScalarType): TTypeInfo
	local typeInfo = TYPE_INFO_BY_NAME[typeName]
	assert(typeInfo ~= nil, `ParallelRunner payload uses unsupported type "{typeName}"`)
	return typeInfo
end

local function _GetOrderedFieldNames(record: { [string]: any }, label: string): { string }
	local fieldNames = {}

	for fieldName in record do
		assert(type(fieldName) == "string" and fieldName ~= "", `{label} field names must be non-empty strings`)
		table.insert(fieldNames, fieldName)
	end

	table.sort(fieldNames)
	return fieldNames
end

local function _GetContiguousArrayLength(values: { [any]: any }, label: string): number
	local maxIndex = 0
	local keyCount = 0

	for key in values do
		assert(type(key) == "number", `{label} arrays only support numeric keys`)
		assert(key % 1 == 0 and key >= 1, `{label} arrays must use positive integer keys`)
		keyCount += 1
		if key > maxIndex then
			maxIndex = key
		end
	end

	assert(keyCount == maxIndex, `{label} arrays must be contiguous`)
	return maxIndex
end

local function _AssertIntegerRange(value: number, minValue: number, maxValue: number, label: string)
	assert(value % 1 == 0, `{label} must be an integer`)
	assert(value >= minValue and value <= maxValue, `{label} must be in range [{minValue}, {maxValue}]`)
end

local function _AssertValueMatchesType(typeName: TPayloadScalarType, value: any, label: string)
	if typeName == "boolean" then
		assert(type(value) == "boolean", `{label} must be boolean`)
		return
	end

	if typeName == "string8" then
		assert(type(value) == "string", `{label} must be string`)
		assert(#value <= 255, `{label} exceeds max length 255`)
		return
	end
	if typeName == "string16" then
		assert(type(value) == "string", `{label} must be string`)
		assert(#value <= 65535, `{label} exceeds max length 65535`)
		return
	end
	if typeName == "string32" then
		assert(type(value) == "string", `{label} must be string`)
		assert(#value <= 4294967295, `{label} exceeds max length 4294967295`)
		return
	end

	if typeName == "u8" then
		assert(type(value) == "number", `{label} must be number`)
		_AssertIntegerRange(value, 0, 255, label)
		return
	end
	if typeName == "u16" then
		assert(type(value) == "number", `{label} must be number`)
		_AssertIntegerRange(value, 0, 65535, label)
		return
	end
	if typeName == "u32" then
		assert(type(value) == "number", `{label} must be number`)
		_AssertIntegerRange(value, 0, 4294967295, label)
		return
	end
	if typeName == "i8" then
		assert(type(value) == "number", `{label} must be number`)
		_AssertIntegerRange(value, -128, 127, label)
		return
	end
	if typeName == "i16" then
		assert(type(value) == "number", `{label} must be number`)
		_AssertIntegerRange(value, -32768, 32767, label)
		return
	end
	if typeName == "i32" then
		assert(type(value) == "number", `{label} must be number`)
		_AssertIntegerRange(value, -2147483648, 2147483647, label)
		return
	end

	if typeName == "f32" or typeName == "f64" then
		assert(type(value) == "number", `{label} must be number`)
		return
	end

	if typeName == "vector3" then
		assert(typeof(value) == "Vector3", `{label} must be Vector3`)
		return
	end
	if typeName == "cframe" or typeName == "lossyCFrame" then
		assert(typeof(value) == "CFrame", `{label} must be CFrame`)
		return
	end
	if typeName == "color3" then
		assert(typeof(value) == "Color3", `{label} must be Color3`)
		return
	end

	error(`{label} uses unsupported type "{typeName}"`)
end

local function _MeasureValue(typeName: TPayloadScalarType, value: any): number
	local fixedSize = FIXED_SIZE_BY_NAME[typeName]
	if fixedSize ~= nil then
		return fixedSize
	end

	local prefixSize = STRING_PREFIX_SIZE_BY_NAME[typeName]
	if prefixSize ~= nil then
		return prefixSize + #value
	end

	error(`ParallelRunner payload cannot measure unsupported type "{typeName}"`)
end

local CompiledPayloadCodec = {}
CompiledPayloadCodec.__index = CompiledPayloadCodec

function CompiledPayloadCodec:GetDescriptor(): TPayloadSchemaDescriptor
	return self._descriptor
end

function CompiledPayloadCodec:Validate(payload: { [string]: any }): boolean
	assert(type(payload) == "table", "ParallelRunner payload requires a table")

	for fieldName in payload do
		assert(self._knownFieldNames[fieldName] == true, `ParallelRunner payload includes unknown field "{fieldName}"`)
	end

	for _, field in ipairs(self._descriptor.Scalars) do
		local value = payload[field.Name]
		assert(value ~= nil, `ParallelRunner payload is missing scalar field "{field.Name}"`)
		_AssertValueMatchesType(field.TypeName, value, `ParallelRunner payload scalar "{field.Name}"`)
	end

	for _, field in ipairs(self._descriptor.Arrays) do
		local value = payload[field.Name]
		assert(type(value) == "table", `ParallelRunner payload array "{field.Name}" must be a table`)

		local arrayLength = _GetContiguousArrayLength(value, `ParallelRunner payload array "{field.Name}"`)
		for index = 1, arrayLength do
			_AssertValueMatchesType(
				field.TypeName,
				(value :: { [number]: any })[index],
				`ParallelRunner payload array "{field.Name}" item #{index}`
			)
		end
	end

	return true
end

function CompiledPayloadCodec:Encode(payload: { [string]: any }): (buffer?, string?)
	local ok, validationError = pcall(function()
		self:Validate(payload)
	end)
	if not ok then
		return nil, _FormatError(self._jobName, "EncodePayload", tostring(validationError))
	end

	local payloadSize = 0

	for _, field in ipairs(self._descriptor.Scalars) do
		payloadSize += _MeasureValue(field.TypeName, payload[field.Name])
	end

	for _, field in ipairs(self._descriptor.Arrays) do
		local values = payload[field.Name] :: { [number]: any }
		local arrayLength = #values
		payloadSize += ARRAY_LENGTH_BYTES
		for index = 1, arrayLength do
			payloadSize += _MeasureValue(field.TypeName, values[index])
		end
	end

	local targetBuffer = buffer.create(Envelope.GetArgsHeaderSize() + payloadSize)
	local cursor = Envelope.WriteArgsHeader(targetBuffer, 0, self._jobVersion)

	for _, field in ipairs(self._descriptor.Scalars) do
		cursor = self._typeInfoByName[field.TypeName].Ser(targetBuffer, cursor, payload[field.Name])
	end

	for _, field in ipairs(self._descriptor.Arrays) do
		local values = payload[field.Name] :: { [number]: any }
		local arrayLength = #values
		buffer.writeu32(targetBuffer, cursor, arrayLength)
		cursor += ARRAY_LENGTH_BYTES
		for index = 1, arrayLength do
			cursor = self._typeInfoByName[field.TypeName].Ser(targetBuffer, cursor, values[index])
		end
	end

	return targetBuffer, nil
end

function CompiledPayloadCodec:Decode(sourceBuffer: buffer, offset: number?): ({ [string]: any }?, number?, string?)
	local resolvedOffset = if offset == nil then 0 else offset
	if typeof(sourceBuffer) ~= "buffer" then
		return nil, nil, _FormatError(self._jobName, "DecodePayload", "malformed envelope: expected a buffer")
	end

	local header, cursor, headerError = Envelope.ReadArgsHeader(sourceBuffer, resolvedOffset)
	if header == nil then
		return nil, nil, _FormatError(self._jobName, "DecodePayload", headerError :: string)
	end

	if header.TransportFormatVersion ~= Envelope.GetTransportFormatVersion() then
		return nil, nil, _FormatError(
			self._jobName,
			"DecodePayload",
			`version mismatch: expected transport format {Envelope.GetTransportFormatVersion()}, received {header.TransportFormatVersion}`
		)
	end

	if header.JobVersion ~= self._jobVersion then
		return nil, nil, _FormatError(
			self._jobName,
			"DecodePayload",
			`version mismatch: expected job version {self._jobVersion}, received {header.JobVersion}`
		)
	end

	local decodedPayload = {}
	local ok, decodeError = pcall(function()
		for _, field in ipairs(self._descriptor.Scalars) do
			local value
			value, cursor = self._typeInfoByName[field.TypeName].Des(sourceBuffer, cursor :: number)
			decodedPayload[field.Name] = value
		end

		for _, field in ipairs(self._descriptor.Arrays) do
			local arrayLength = buffer.readu32(sourceBuffer, cursor :: number)
			cursor += ARRAY_LENGTH_BYTES
			local values = table.create(arrayLength)
			for index = 1, arrayLength do
				local value
				value, cursor = self._typeInfoByName[field.TypeName].Des(sourceBuffer, cursor :: number)
				values[index] = value
			end
			decodedPayload[field.Name] = values
		end
	end)
	if not ok then
		return nil, nil, _FormatError(self._jobName, "DecodePayload", `decode overflow/underflow: {tostring(decodeError)}`)
	end

	return decodedPayload, cursor, nil
end

local PayloadCodec = {}

function PayloadCodec.BuildDescriptor(fieldsByName: { [string]: { Kind: "Scalar" | "Array", TypeName: TPayloadScalarType } }): TPayloadSchemaDescriptor
	assert(type(fieldsByName) == "table", "ParallelRunner payload schema must be a table")

	local descriptor = {
		Scalars = {},
		Arrays = {},
	}

	local fieldNames = _GetOrderedFieldNames(fieldsByName, "ParallelRunner payload schema")
	assert(#fieldNames > 0, "ParallelRunner payload schema must contain at least one field")

	for _, fieldName in ipairs(fieldNames) do
		local definition = fieldsByName[fieldName]
		assert(type(definition) == "table", `ParallelRunner payload field "{fieldName}" must define a field marker`)
		assert(
			definition.Kind == "Scalar" or definition.Kind == "Array",
			`ParallelRunner payload field "{fieldName}" must define a scalar or array kind`
		)

		local typeInfo = TYPE_INFO_BY_NAME[definition.TypeName]
		assert(typeInfo ~= nil, `ParallelRunner payload field "{fieldName}" uses unsupported type "{definition.TypeName}"`)

		local descriptorField: TPayloadSchemaDescriptorField = {
			Name = fieldName,
			TypeName = definition.TypeName,
		}

		if definition.Kind == "Scalar" then
			table.insert(descriptor.Scalars, descriptorField)
		else
			table.insert(descriptor.Arrays, descriptorField)
		end
	end

	return table.freeze({
		Scalars = table.freeze(descriptor.Scalars),
		Arrays = table.freeze(descriptor.Arrays),
	})
end

function PayloadCodec.CompileDescriptor(jobName: string, jobVersion: number, descriptor: TPayloadSchemaDescriptor)
	assert(type(jobName) == "string" and jobName ~= "", "ParallelRunner payload codec requires a non-empty jobName")
	assert(
		type(jobVersion) == "number" and jobVersion % 1 == 0 and jobVersion > 0,
		"ParallelRunner payload codec requires a positive integer jobVersion"
	)
	assert(type(descriptor) == "table", "ParallelRunner payload codec requires a descriptor")

	local self = setmetatable({}, CompiledPayloadCodec)
	self._jobName = jobName
	self._jobVersion = jobVersion
	self._descriptor = descriptor
	self._typeInfoByName = TYPE_INFO_BY_NAME
	self._knownFieldNames = _BuildUnexpectedFieldLookup(descriptor)
	return self
end

return table.freeze(PayloadCodec)
