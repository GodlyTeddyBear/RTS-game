--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RenderPropertyRegistry = require(script.Parent.RenderPropertyRegistry)
local RenderTypes = require(script.Parent.Types.RenderTypes)
local Sera = require(ReplicatedStorage.Utilities.Sera)

type TRenderPropertyDescriptor = RenderPropertyRegistry.TRenderPropertyDescriptor
type TRenderRegistryBootstrapChunk = RenderTypes.TRenderRegistryBootstrapChunk
type TRenderRegistryDelta = RenderTypes.TRenderRegistryDelta

local PAYLOAD_VERSION = 1
local PROPERTY_DESCRIPTORS = RenderPropertyRegistry.GetDescriptors()

local function _GetContiguousArrayLength(values: { [any]: any }, label: string): number
	local maxIndex = 0
	local keyCount = 0

	for key in values do
		assert(type(key) == "number", `{label} must use numeric keys`)
		assert(key % 1 == 0 and key >= 1, `{label} must use positive integer keys`)
		keyCount += 1
		if key > maxIndex then
			maxIndex = key
		end
	end

	assert(keyCount == maxIndex, `{label} must be contiguous`)
	return maxIndex
end

local function _BuildStringArray16Type(typeName: string)
	return table.freeze({
		Name = typeName,
		Ser = function(targetBuffer: buffer, offset: number, values: { string }): number
			assert(type(values) == "table", `${typeName} expects a table`)
			local count = _GetContiguousArrayLength(values, typeName)
			assert(count <= 65535, `${typeName} exceeded Uint16 capacity`)

			offset = Sera.Uint16.Ser(targetBuffer, offset, count)
			for index = 1, count do
				offset = Sera.String16.Ser(targetBuffer, offset, values[index])
			end

			return offset
		end,
		Des = function(sourceBuffer: buffer, offset: number): ({ string }, number)
			local count
			count, offset = Sera.Uint16.Des(sourceBuffer, offset)

			local values = table.create(count)
			for index = 1, count do
				values[index], offset = Sera.String16.Des(sourceBuffer, offset)
			end

			return values, offset
		end,
	})
end

local function _BuildUint8Array16Type(typeName: string)
	return table.freeze({
		Name = typeName,
		Ser = function(targetBuffer: buffer, offset: number, values: { number }): number
			assert(type(values) == "table", `${typeName} expects a table`)
			local count = _GetContiguousArrayLength(values, typeName)
			assert(count <= 65535, `${typeName} exceeded Uint16 capacity`)

			offset = Sera.Uint16.Ser(targetBuffer, offset, count)
			for index = 1, count do
				offset = Sera.Uint8.Ser(targetBuffer, offset, values[index])
			end

			return offset
		end,
		Des = function(sourceBuffer: buffer, offset: number): ({ number }, number)
			local count
			count, offset = Sera.Uint16.Des(sourceBuffer, offset)

			local values = table.create(count)
			for index = 1, count do
				values[index], offset = Sera.Uint8.Des(sourceBuffer, offset)
			end

			return values, offset
		end,
	})
end

local function _BuildOptionalArray16Type(typeName: string, scalarType: any)
	return table.freeze({
		Name = typeName,
		Ser = function(targetBuffer: buffer, offset: number, values: { [number]: any }): number
			assert(type(values) == "table", `${typeName} expects a table`)
			local sparseValues = values
			local count = values.Count
			if count ~= nil then
				assert(type(count) == "number", `${typeName}.Count must be a number`)
				assert(type(values.ValuesByIndex) == "table", `${typeName}.ValuesByIndex must be a table`)
				sparseValues = values.ValuesByIndex
			else
				count = _GetContiguousArrayLength(values, typeName)
			end
			assert(count <= 65535, `${typeName} exceeded Uint16 capacity`)

			offset = Sera.Uint16.Ser(targetBuffer, offset, count)
			for index = 1, count do
				local value = sparseValues[index]
				if value == nil then
					offset = Sera.Uint8.Ser(targetBuffer, offset, 0)
				else
					offset = Sera.Uint8.Ser(targetBuffer, offset, 1)
					offset = scalarType.Ser(targetBuffer, offset, value)
				end
			end

			return offset
		end,
		Des = function(sourceBuffer: buffer, offset: number): ({ [number]: any }, number)
			local count
			count, offset = Sera.Uint16.Des(sourceBuffer, offset)

			local values = {}
			for index = 1, count do
				local state
				state, offset = Sera.Uint8.Des(sourceBuffer, offset)
				if state == 0 then
				else
					values[index], offset = scalarType.Des(sourceBuffer, offset)
				end
			end

			return {
				Count = count,
				ValuesByIndex = values,
			}, offset
		end,
	})
end

local WIRE_TYPES = table.freeze({
	StringArray16 = _BuildStringArray16Type("Render.StringArray16"),
	Uint8Array16 = _BuildUint8Array16Type("Render.Uint8Array16"),
	OptionalColor3Array16 = _BuildOptionalArray16Type("Render.OptionalColor3Array16", Sera.Color3),
	OptionalFloat32Array16 = _BuildOptionalArray16Type("Render.OptionalFloat32Array16", Sera.Float32),
	OptionalString16Array16 = _BuildOptionalArray16Type("Render.OptionalString16Array16", Sera.String16),
	OptionalUint16Array16 = _BuildOptionalArray16Type("Render.OptionalUint16Array16", Sera.Uint16),
})

local function _GetWireType(typeName: string)
	local wireType = (WIRE_TYPES :: any)[typeName]
	assert(wireType ~= nil, `RenderTransportSchema: missing wire type "{typeName}"`)
	return wireType
end

local function _BuildBootstrapSchemaFields(): { [string]: any }
	local schemaFields = {
		ChunkCount = Sera.Uint16,
		ChunkIndex = Sera.Uint16,
		Count = Sera.Uint16,
		IdsByIndex = WIRE_TYPES.StringArray16,
		Version = Sera.Uint16,
	}

	for _, descriptor: TRenderPropertyDescriptor in ipairs(PROPERTY_DESCRIPTORS) do
		schemaFields[descriptor.BootstrapWireField] = _GetWireType(descriptor.BootstrapWireType)
	end

	return schemaFields
end

local function _BuildDeltaSchemaFields(): { [string]: any }
	local schemaFields = {
		AddedCount = Sera.Uint16,
		AddedIdsByIndex = WIRE_TYPES.StringArray16,
		RemovedIds = WIRE_TYPES.StringArray16,
		Version = Sera.Uint16,
	}

	for _, descriptor: TRenderPropertyDescriptor in ipairs(PROPERTY_DESCRIPTORS) do
		schemaFields[descriptor.DeltaWireField] = _GetWireType(descriptor.DeltaWireType)
	end

	return schemaFields
end

local BootstrapChunkSchema = Sera.Schema(_BuildBootstrapSchemaFields())
local DeltaSchema = Sera.Schema(_BuildDeltaSchemaFields())

local RenderTransportSchema = {
	PAYLOAD_VERSION = PAYLOAD_VERSION,
	BootstrapChunkSchema = BootstrapChunkSchema,
	DeltaSchema = DeltaSchema,
}

local function _InitializeLogicalPropertyColumns(logicalPayload: any, mode: "Bootstrap" | "Delta")
	for _, descriptor: TRenderPropertyDescriptor in ipairs(PROPERTY_DESCRIPTORS) do
		local columnName = if mode == "Bootstrap" then descriptor.RuntimeColumn else descriptor.DeltaColumn
		logicalPayload[columnName] = {}
	end
end

local function _ValidateIdsByIndex(idsByIndex: { string }, count: number, label: string): string?
	if #idsByIndex ~= count then
		return `{label} length does not match Count`
	end

	for index = 1, count do
		local id = idsByIndex[index]
		if type(id) ~= "string" or id == "" then
			return `{label}[{index}] is invalid`
		end
	end

	return nil
end

local function _ValidatePropertyColumns(payload: any, count: number, mode: "Bootstrap" | "Delta"): string?
	for _, descriptor: TRenderPropertyDescriptor in ipairs(PROPERTY_DESCRIPTORS) do
		local logicalColumnName = if mode == "Bootstrap" then descriptor.RuntimeColumn else descriptor.DeltaColumn
		local valuesByIndex = payload[logicalColumnName]
		if valuesByIndex == nil then
			return `{logicalColumnName} is missing`
		end

		local validationError = descriptor.ValidateLogicalColumn(valuesByIndex, count, logicalColumnName)
		if validationError ~= nil then
			return validationError
		end
	end

	return nil
end

local function _BuildBaseBootstrapPayload(payload: TRenderRegistryBootstrapChunk): { [string]: any }
	return {
		Version = PAYLOAD_VERSION,
		ChunkIndex = payload.ChunkIndex,
		ChunkCount = payload.ChunkCount,
		Count = payload.Count,
		IdsByIndex = payload.IdsByIndex,
	}
end

local function _BuildBaseDeltaPayload(payload: TRenderRegistryDelta): { [string]: any }
	local deltaPayload = {
		Version = PAYLOAD_VERSION,
	}

	if payload.AddedIdsByIndex ~= nil then
		deltaPayload.AddedCount = payload.AddedCount
		deltaPayload.AddedIdsByIndex = payload.AddedIdsByIndex
	end

	if payload.RemovedIds ~= nil then
		deltaPayload.RemovedIds = payload.RemovedIds
	end

	return deltaPayload
end

local function _ApplyPropertyWireEncoding(
	logicalPayload: any,
	wirePayload: { [string]: any },
	count: number,
	mode: "Bootstrap" | "Delta"
)
	for _, descriptor: TRenderPropertyDescriptor in ipairs(PROPERTY_DESCRIPTORS) do
		local logicalColumnName = if mode == "Bootstrap" then descriptor.RuntimeColumn else descriptor.DeltaColumn
		local wireFieldName = if mode == "Bootstrap" then descriptor.BootstrapWireField else descriptor.DeltaWireField
		wirePayload[wireFieldName] = descriptor.EncodeColumn(logicalPayload[logicalColumnName], count)
	end
end

local function _ApplyPropertyWireDecoding(
	wirePayload: { [string]: any },
	logicalPayload: any,
	count: number,
	mode: "Bootstrap" | "Delta"
): string?
	for _, descriptor: TRenderPropertyDescriptor in ipairs(PROPERTY_DESCRIPTORS) do
		local logicalColumnName = if mode == "Bootstrap" then descriptor.RuntimeColumn else descriptor.DeltaColumn
		local wireFieldName = if mode == "Bootstrap" then descriptor.BootstrapWireField else descriptor.DeltaWireField
		local encodedValuesByIndex = wirePayload[wireFieldName]
		if type(encodedValuesByIndex) ~= "table" then
			return `{wireFieldName} is missing`
		end

		local encodedCount = encodedValuesByIndex.Count
		if encodedCount ~= nil then
			if encodedCount ~= count then
				return `{wireFieldName} length does not match Count`
			end
		elseif #encodedValuesByIndex ~= count then
			return `{wireFieldName} length does not match Count`
		end

		logicalPayload[logicalColumnName] = descriptor.DecodeColumn(encodedValuesByIndex, count)
	end

	return nil
end

local function _HasDeltaAddGroup(decodedPayload: { [string]: any }): boolean
	if decodedPayload.AddedIdsByIndex ~= nil or decodedPayload.AddedCount ~= nil then
		return true
	end

	for _, descriptor: TRenderPropertyDescriptor in ipairs(PROPERTY_DESCRIPTORS) do
		if decodedPayload[descriptor.DeltaWireField] ~= nil then
			return true
		end
	end

	return false
end

function RenderTransportSchema.SerializeBootstrapChunk(payload: TRenderRegistryBootstrapChunk): (buffer?, string?)
	local idValidationError = _ValidateIdsByIndex(payload.IdsByIndex, payload.Count, "IdsByIndex")
	if idValidationError ~= nil then
		return nil, idValidationError
	end

	local propertyValidationError = _ValidatePropertyColumns(payload :: any, payload.Count, "Bootstrap")
	if propertyValidationError ~= nil then
		return nil, propertyValidationError
	end

	local wirePayload = _BuildBaseBootstrapPayload(payload)
	_ApplyPropertyWireEncoding(payload :: any, wirePayload, payload.Count, "Bootstrap")

	return Sera.Serialize(BootstrapChunkSchema, wirePayload)
end

function RenderTransportSchema.DeserializeBootstrapChunk(payloadBuffer: buffer): (TRenderRegistryBootstrapChunk?, string?)
	local didDeserialize, decodedPayload = pcall(Sera.Deserialize, BootstrapChunkSchema, payloadBuffer)
	if not didDeserialize then
		return nil, `bootstrap decode failure: {tostring(decodedPayload)}`
	end

	if decodedPayload.Version ~= PAYLOAD_VERSION then
		return nil, `bootstrap version mismatch: expected {PAYLOAD_VERSION}, received {tostring(decodedPayload.Version)}`
	end

	local idValidationError = _ValidateIdsByIndex(decodedPayload.IdsByIndex, decodedPayload.Count, "IdsByIndex")
	if idValidationError ~= nil then
		return nil, idValidationError
	end

	local logicalPayload: TRenderRegistryBootstrapChunk = {
		Version = decodedPayload.Version,
		ChunkIndex = decodedPayload.ChunkIndex,
		ChunkCount = decodedPayload.ChunkCount,
		Count = decodedPayload.Count,
		IdsByIndex = decodedPayload.IdsByIndex,
	}
	_InitializeLogicalPropertyColumns(logicalPayload :: any, "Bootstrap")

	local propertyDecodeError =
		_ApplyPropertyWireDecoding(decodedPayload, logicalPayload :: any, decodedPayload.Count, "Bootstrap")
	if propertyDecodeError ~= nil then
		return nil, propertyDecodeError
	end

	return logicalPayload, nil
end

function RenderTransportSchema.SerializeDelta(payload: TRenderRegistryDelta): (buffer?, string?)
	local addedIdsByIndex = payload.AddedIdsByIndex
	if addedIdsByIndex ~= nil then
		local addedCount = payload.AddedCount
		if type(addedCount) ~= "number" then
			return nil, "AddedCount is required when AddedIdsByIndex is present"
		end

		local idValidationError = _ValidateIdsByIndex(addedIdsByIndex, addedCount, "AddedIdsByIndex")
		if idValidationError ~= nil then
			return nil, idValidationError
		end

		local propertyValidationError = _ValidatePropertyColumns(payload :: any, addedCount, "Delta")
		if propertyValidationError ~= nil then
			return nil, propertyValidationError
		end
	end

	if payload.RemovedIds ~= nil then
		local removedIdValidationError = _ValidateIdsByIndex(payload.RemovedIds, #payload.RemovedIds, "RemovedIds")
		if removedIdValidationError ~= nil then
			return nil, removedIdValidationError
		end
	end

	local wirePayload = _BuildBaseDeltaPayload(payload)
	if payload.AddedIdsByIndex ~= nil then
		_ApplyPropertyWireEncoding(payload :: any, wirePayload, payload.AddedCount :: number, "Delta")
	end

	return Sera.DeltaSerialize(DeltaSchema, wirePayload)
end

function RenderTransportSchema.DeserializeDelta(payloadBuffer: buffer): (TRenderRegistryDelta?, string?)
	local didDeserialize, decodedPayload = pcall(Sera.DeltaDeserialize, DeltaSchema, payloadBuffer)
	if not didDeserialize then
		return nil, `delta decode failure: {tostring(decodedPayload)}`
	end

	if decodedPayload.Version ~= PAYLOAD_VERSION then
		return nil, `delta version mismatch: expected {PAYLOAD_VERSION}, received {tostring(decodedPayload.Version)}`
	end

	local logicalPayload: TRenderRegistryDelta = {
		Version = decodedPayload.Version,
	}

	if _HasDeltaAddGroup(decodedPayload) then
		local addedIdsByIndex = decodedPayload.AddedIdsByIndex
		local addedCount = decodedPayload.AddedCount

		if type(addedCount) ~= "number" then
			return nil, "delta AddedCount missing for add payload"
		end
		if type(addedIdsByIndex) ~= "table" then
			return nil, "delta AddedIdsByIndex missing for add payload"
		end

		local idValidationError = _ValidateIdsByIndex(addedIdsByIndex, addedCount, "AddedIdsByIndex")
		if idValidationError ~= nil then
			return nil, idValidationError
		end

		logicalPayload.AddedCount = addedCount
		logicalPayload.AddedIdsByIndex = addedIdsByIndex
		_InitializeLogicalPropertyColumns(logicalPayload :: any, "Delta")

		local propertyDecodeError =
			_ApplyPropertyWireDecoding(decodedPayload, logicalPayload :: any, addedCount, "Delta")
		if propertyDecodeError ~= nil then
			return nil, propertyDecodeError
		end
	end

	if decodedPayload.RemovedIds ~= nil then
		local removedIds = decodedPayload.RemovedIds
		local removedIdValidationError = _ValidateIdsByIndex(removedIds, #removedIds, "RemovedIds")
		if removedIdValidationError ~= nil then
			return nil, removedIdValidationError
		end
		logicalPayload.RemovedIds = removedIds
	end

	return logicalPayload, nil
end

return table.freeze(RenderTransportSchema)
