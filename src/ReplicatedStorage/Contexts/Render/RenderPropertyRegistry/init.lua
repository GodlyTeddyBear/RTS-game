--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RenderConfig = require(ReplicatedStorage.Contexts.Render.Config.RenderConfig)
local PropertyDefinitions = require(script.Definitions)

local OPTIONAL_VALUE_STATE_ABSENT = 0

local BOOLEAN_STATE_BY_VALUE = table.freeze({
	[false] = 1,
	[true] = 2,
})

local BOOLEAN_VALUE_BY_STATE = table.freeze({
	[1] = false,
	[2] = true,
})

export type TRenderPropertyDescriptor = {
	Key: string,
	RuntimeColumn: string,
	DeltaColumn: string,
	BootstrapWireField: string,
	DeltaWireField: string,
	BootstrapWireType: string,
	DeltaWireType: string,
	IsEnabled: () -> boolean,
	SupportsInstance: (instance: Instance) -> boolean,
	Read: (instance: Instance) -> any?,
	ApplyServer: (instance: Instance, value: any?) -> (),
	ApplyClient: (instance: Instance, value: any?) -> (),
	EncodeColumn: (valuesByIndex: { [number]: any }, count: number) -> { [number]: any },
	DecodeColumn: (encodedValuesByIndex: { [number]: any }, count: number) -> { [number]: any },
	ValidateLogicalColumn: (valuesByIndex: { [number]: any }, count: number, label: string) -> string?,
}

export type TRenderPropertyDefinition = {
	DesiredValue: any?,
}

export type TRenderPropertyDefinitions = {
	[string]: TRenderPropertyDefinition,
}

type TInferredCodec = {
	BootstrapWireType: string,
	DeltaWireType: string,
	WireSuffix: string,
	ValidateLogicalColumn: (valuesByIndex: { [number]: any }, count: number, label: string) -> string?,
	EncodeColumn: (valuesByIndex: { [number]: any }, count: number) -> { [number]: any },
	DecodeColumn: (encodedValuesByIndex: { [number]: any }, count: number) -> { [number]: any },
}

local function _WrapOptionalEncodedColumn(valuesByIndex: { [number]: any }, count: number): { Count: number, ValuesByIndex: { [number]: any } }
	return {
		Count = count,
		ValuesByIndex = valuesByIndex,
	}
end

local function _UnwrapOptionalEncodedColumn(encodedValuesByIndex: any): ({ [number]: any }, number?)
	if type(encodedValuesByIndex) == "table"
		and type(encodedValuesByIndex.Count) == "number"
		and type(encodedValuesByIndex.ValuesByIndex) == "table"
	then
		return encodedValuesByIndex.ValuesByIndex, encodedValuesByIndex.Count
	end

	return encodedValuesByIndex, nil
end

local function _ValidateOptionalBooleanColumn(valuesByIndex: { [number]: any }, count: number, label: string): string?
	for index = 1, count do
		local value = valuesByIndex[index]
		if value ~= nil and type(value) ~= "boolean" then
			return `{label}[{index}] is invalid`
		end
	end

	return nil
end

local function _EncodeOptionalBooleanColumn(valuesByIndex: { [number]: any }, count: number): { [number]: any }
	local encodedValuesByIndex = table.create(count)
	for index = 1, count do
		local value = valuesByIndex[index]
		if value == nil then
			encodedValuesByIndex[index] = OPTIONAL_VALUE_STATE_ABSENT
		else
			local encodedValue = BOOLEAN_STATE_BY_VALUE[value]
			assert(encodedValue ~= nil, "RenderPropertyRegistry: boolean codec received unsupported value")
			encodedValuesByIndex[index] = encodedValue
		end
	end

	return encodedValuesByIndex
end

local function _DecodeOptionalBooleanColumn(encodedValuesByIndex: { [number]: any }, count: number): { [number]: any }
	local valuesByIndex = {}
	for index = 1, count do
		local encodedValue = encodedValuesByIndex[index]
		local decodedValue = BOOLEAN_VALUE_BY_STATE[encodedValue]
		if decodedValue == nil then
			valuesByIndex[index] = nil
		else
			valuesByIndex[index] = decodedValue
		end
	end

	return valuesByIndex
end

local function _ValidateOptionalNumberColumn(valuesByIndex: { [number]: any }, count: number, label: string): string?
	for index = 1, count do
		local value = valuesByIndex[index]
		if value ~= nil and type(value) ~= "number" then
			return `{label}[{index}] is invalid`
		end
	end

	return nil
end

local function _ValidateOptionalStringColumn(valuesByIndex: { [number]: any }, count: number, label: string): string?
	for index = 1, count do
		local value = valuesByIndex[index]
		if value ~= nil and type(value) ~= "string" then
			return `{label}[{index}] is invalid`
		end
	end

	return nil
end

local function _ValidateOptionalColor3Column(valuesByIndex: { [number]: any }, count: number, label: string): string?
	for index = 1, count do
		local value = valuesByIndex[index]
		if value ~= nil and typeof(value) ~= "Color3" then
			return `{label}[{index}] is invalid`
		end
	end

	return nil
end

local function _EncodeIdentityColumn(valuesByIndex: { [number]: any }, count: number): { [number]: any }
	return _WrapOptionalEncodedColumn(valuesByIndex, count) :: any
end

local function _DecodeIdentityColumn(encodedValuesByIndex: { [number]: any }, count: number): { [number]: any }
	local wrappedValuesByIndex, wrappedCount = _UnwrapOptionalEncodedColumn(encodedValuesByIndex)
	if wrappedCount ~= nil then
		count = wrappedCount
		encodedValuesByIndex = wrappedValuesByIndex :: any
	end

	local valuesByIndex = table.create(count)
	for index = 1, count do
		valuesByIndex[index] = encodedValuesByIndex[index]
	end

	return valuesByIndex
end

local function _BuildIdentityCodec(
	wireType: string,
	validateLogicalColumn: (valuesByIndex: { [number]: any }, count: number, label: string) -> string?
): TInferredCodec
	return {
		BootstrapWireType = wireType,
		DeltaWireType = wireType,
		WireSuffix = "ValuesByIndex",
		ValidateLogicalColumn = validateLogicalColumn,
		EncodeColumn = _EncodeIdentityColumn,
		DecodeColumn = _DecodeIdentityColumn,
	}
end

local function _BuildOptionalEnumCodec(enumType: any): TInferredCodec
	local enumItemsByValue = {}
	for _, enumItem in ipairs(enumType:GetEnumItems()) do
		enumItemsByValue[enumItem.Value] = enumItem
	end

	local function validateLogicalColumn(valuesByIndex: { [number]: any }, count: number, label: string): string?
		for index = 1, count do
			local value = valuesByIndex[index]
			if value ~= nil then
				if typeof(value) ~= "EnumItem" then
					return `{label}[{index}] is invalid`
				end
				if (value :: EnumItem).EnumType ~= enumType then
					return `{label}[{index}] must belong to {tostring(enumType)}`
				end
			end
		end

		return nil
	end

	local function encodeColumn(valuesByIndex: { [number]: any }, count: number): { [number]: any }
		local encodedValuesByIndex = {}
		for index = 1, count do
			local value = valuesByIndex[index]
			if value ~= nil then
				encodedValuesByIndex[index] = (value :: EnumItem).Value
			end
		end

		return _WrapOptionalEncodedColumn(encodedValuesByIndex, count) :: any
	end

	local function decodeColumn(encodedValuesByIndex: { [number]: any }, count: number): { [number]: any }
		local wrappedValuesByIndex, wrappedCount = _UnwrapOptionalEncodedColumn(encodedValuesByIndex)
		if wrappedCount ~= nil then
			count = wrappedCount
			encodedValuesByIndex = wrappedValuesByIndex :: any
		end

		local valuesByIndex = table.create(count)
		for index = 1, count do
			local encodedValue = encodedValuesByIndex[index]
			if encodedValue ~= nil then
				valuesByIndex[index] = enumItemsByValue[encodedValue]
			end
		end

		return valuesByIndex
	end

	return {
		BootstrapWireType = "OptionalUint16Array16",
		DeltaWireType = "OptionalUint16Array16",
		WireSuffix = "ValuesByIndex",
		ValidateLogicalColumn = validateLogicalColumn,
		EncodeColumn = encodeColumn,
		DecodeColumn = decodeColumn,
	}
end

local BOOLEAN_CODEC = {
		BootstrapWireType = "Uint8Array16",
		DeltaWireType = "Uint8Array16",
		WireSuffix = "StatesByIndex",
		ValidateLogicalColumn = _ValidateOptionalBooleanColumn,
		EncodeColumn = _EncodeOptionalBooleanColumn,
		DecodeColumn = _DecodeOptionalBooleanColumn,
	} :: TInferredCodec

local CODECS_BY_LUA_TYPE: { [string]: TInferredCodec } = {
	boolean = BOOLEAN_CODEC,
	number = _BuildIdentityCodec("OptionalFloat32Array16", _ValidateOptionalNumberColumn),
	string = _BuildIdentityCodec("OptionalString16Array16", _ValidateOptionalStringColumn),
	Color3 = _BuildIdentityCodec("OptionalColor3Array16", _ValidateOptionalColor3Column),
}

local SUPPORT_CACHE_BY_CLASS_NAME: { [string]: { [string]: boolean } } = {}

local function _BuildPropertyFieldNames(key: string, wireSuffix: string): {
	RuntimeColumn: string,
	DeltaColumn: string,
	BootstrapWireField: string,
	DeltaWireField: string,
}
	return {
		RuntimeColumn = `{key}ByIndex`,
		DeltaColumn = `Added{key}ByIndex`,
		BootstrapWireField = `{key}{wireSuffix}`,
		DeltaWireField = `Added{key}{wireSuffix}`,
	}
end

local function _ProbePropertySupport(instance: Instance, propertyKey: string): boolean
	local didRead = pcall(function()
		local _ = (instance :: any)[propertyKey]
	end)
	return didRead
end

local function _SupportsProperty(instance: Instance, propertyKey: string): boolean
	local className = instance.ClassName
	local supportByPropertyKey = SUPPORT_CACHE_BY_CLASS_NAME[className]
	if supportByPropertyKey == nil then
		supportByPropertyKey = {}
		SUPPORT_CACHE_BY_CLASS_NAME[className] = supportByPropertyKey
	end

	local cachedSupport = supportByPropertyKey[propertyKey]
	if cachedSupport ~= nil then
		return cachedSupport
	end

	local didSupport = _ProbePropertySupport(instance, propertyKey)
	supportByPropertyKey[propertyKey] = didSupport
	return didSupport
end

local function _InferCodecFromDesiredValue(desiredValue: any): TInferredCodec
	if typeof(desiredValue) == "EnumItem" then
		return _BuildOptionalEnumCodec((desiredValue :: EnumItem).EnumType)
	end

	local inferredCodec = CODECS_BY_LUA_TYPE[typeof(desiredValue)]
	assert(
		inferredCodec ~= nil,
		`RenderPropertyRegistry: unsupported desired value type "{typeof(desiredValue)}"`
	)
	return inferredCodec
end

local function _CreateDescriptor(propertyKey: string, definition: TRenderPropertyDefinition): TRenderPropertyDescriptor
	assert(type(propertyKey) == "string" and propertyKey ~= "", "RenderPropertyRegistry: property key is required")
	assert(type(definition) == "table", `RenderPropertyRegistry: definition for "{propertyKey}" must be a table`)

	local desiredValue = definition.DesiredValue
	assert(desiredValue ~= nil, `RenderPropertyRegistry: definition for "{propertyKey}" is missing DesiredValue`)
	local inferredCodec = _InferCodecFromDesiredValue(desiredValue)

	local fieldNames = _BuildPropertyFieldNames(propertyKey, inferredCodec.WireSuffix)

	return table.freeze({
		Key = propertyKey,
		RuntimeColumn = fieldNames.RuntimeColumn,
		DeltaColumn = fieldNames.DeltaColumn,
		BootstrapWireField = fieldNames.BootstrapWireField,
		DeltaWireField = fieldNames.DeltaWireField,
		BootstrapWireType = inferredCodec.BootstrapWireType,
		DeltaWireType = inferredCodec.DeltaWireType,
		IsEnabled = function(): boolean
			return (RenderConfig.TrackedRenderProperties :: any)[propertyKey] == true
		end,
		SupportsInstance = function(instance: Instance): boolean
			return _SupportsProperty(instance, propertyKey)
		end,
		Read = function(instance: Instance): any?
			if (RenderConfig.TrackedRenderProperties :: any)[propertyKey] ~= true then
				return nil
			end
			if not _SupportsProperty(instance, propertyKey) then
				return nil
			end

			local didRead, value = pcall(function()
				return (instance :: any)[propertyKey]
			end)
			if not didRead then
				return nil
			end

			return value
		end,
		ApplyServer = function(instance: Instance, _value: any?)
			if (RenderConfig.TrackedRenderProperties :: any)[propertyKey] ~= true then
				return
			end
			if not _SupportsProperty(instance, propertyKey) then
				return
			end

			pcall(function()
				(instance :: any)[propertyKey] = desiredValue
			end)
		end,
		ApplyClient = function(instance: Instance, value: any?)
			if (RenderConfig.TrackedRenderProperties :: any)[propertyKey] ~= true then
				return
			end
			if not _SupportsProperty(instance, propertyKey) then
				return
			end
			if value == nil then
				return
			end

			pcall(function()
				(instance :: any)[propertyKey] = value
			end)
		end,
		EncodeColumn = inferredCodec.EncodeColumn,
		DecodeColumn = inferredCodec.DecodeColumn,
		ValidateLogicalColumn = inferredCodec.ValidateLogicalColumn,
	})
end

local function _BuildDescriptors(
	definitions: TRenderPropertyDefinitions
): ({ TRenderPropertyDescriptor }, { [string]: TRenderPropertyDescriptor })
	local propertyKeys = {}
	for propertyKey in definitions do
		table.insert(propertyKeys, propertyKey)
	end
	table.sort(propertyKeys)

	local descriptors = table.create(#propertyKeys)
	local descriptorsByKey = {}

	for index, propertyKey in ipairs(propertyKeys) do
		assert(descriptorsByKey[propertyKey] == nil, `RenderPropertyRegistry: duplicate property key "{propertyKey}"`)
		local definition = definitions[propertyKey]
		if definition.DesiredValue == nil then
			continue
		end

		local descriptor = _CreateDescriptor(propertyKey, definition)
		table.insert(descriptors, descriptor)
		descriptorsByKey[descriptor.Key] = descriptor
	end

	return table.freeze(descriptors), table.freeze(descriptorsByKey)
end

local Descriptors, DescriptorsByKey = _BuildDescriptors(PropertyDefinitions)

local RenderPropertyRegistry = {
	CodecsByLuaType = table.freeze(CODECS_BY_LUA_TYPE),
	Definitions = table.freeze(PropertyDefinitions),
	Descriptors = Descriptors,
	DescriptorsByKey = DescriptorsByKey,
}

function RenderPropertyRegistry.GetDescriptors(): { TRenderPropertyDescriptor }
	return Descriptors
end

function RenderPropertyRegistry.GetDescriptorByKey(key: string): TRenderPropertyDescriptor?
	return DescriptorsByKey[key]
end

return table.freeze(RenderPropertyRegistry)
