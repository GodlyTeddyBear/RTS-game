--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RenderTypes = require(script.Parent.Types.RenderTypes)
local Sera = require(ReplicatedStorage.Utilities.Sera)

type TRenderAccessoryBootstrapChunk = RenderTypes.TRenderAccessoryBootstrapChunk
type TRenderAccessoryDelta = RenderTypes.TRenderAccessoryDelta

local PAYLOAD_VERSION = 1

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

local StringArray16 = _BuildStringArray16Type("RenderAccessory.StringArray16")

local BootstrapChunkSchema = Sera.Schema({
	Version = Sera.Uint16,
	ChunkIndex = Sera.Uint16,
	ChunkCount = Sera.Uint16,
	Count = Sera.Uint16,
	AccessoryIdsByIndex = StringArray16,
	AccessoryNamesByIndex = StringArray16,
	ParentRenderIdsByIndex = StringArray16,
	VisualIdsByIndex = StringArray16,
})

local DeltaSchema = Sera.Schema({
	Version = Sera.Uint16,
	AddedCount = Sera.Uint16,
	AddedAccessoryIdsByIndex = StringArray16,
	AddedAccessoryNamesByIndex = StringArray16,
	AddedParentRenderIdsByIndex = StringArray16,
	AddedVisualIdsByIndex = StringArray16,
	RemovedAccessoryIds = StringArray16,
})

local RenderAccessoryTransportSchema = {
	PAYLOAD_VERSION = PAYLOAD_VERSION,
	BootstrapChunkSchema = BootstrapChunkSchema,
	DeltaSchema = DeltaSchema,
}

local function _ValidateStringArray(values: { string }, count: number, label: string): string?
	if type(values) ~= "table" then
		return `{label} is missing`
	end

	if #values ~= count then
		return `{label} length does not match Count`
	end

	for index = 1, count do
		local value = values[index]
		if type(value) ~= "string" or value == "" then
			return `{label}[{index}] is invalid`
		end
	end

	return nil
end

local function _ValidateBootstrapChunk(payload: TRenderAccessoryBootstrapChunk): string?
	local count = payload.Count
	local validations = {
		_ValidateStringArray(payload.AccessoryIdsByIndex, count, "AccessoryIdsByIndex"),
		_ValidateStringArray(payload.AccessoryNamesByIndex, count, "AccessoryNamesByIndex"),
		_ValidateStringArray(payload.ParentRenderIdsByIndex, count, "ParentRenderIdsByIndex"),
		_ValidateStringArray(payload.VisualIdsByIndex, count, "VisualIdsByIndex"),
	}

	for _, validation in ipairs(validations) do
		if validation ~= nil then
			return validation
		end
	end

	return nil
end

local function _ValidateDeltaAddGroup(payload: TRenderAccessoryDelta): string?
	local addedCount = payload.AddedCount
	if type(addedCount) ~= "number" then
		return "AddedCount is required when add payload is present"
	end

	local validations = {
		_ValidateStringArray(payload.AddedAccessoryIdsByIndex :: any, addedCount, "AddedAccessoryIdsByIndex"),
		_ValidateStringArray(payload.AddedAccessoryNamesByIndex :: any, addedCount, "AddedAccessoryNamesByIndex"),
		_ValidateStringArray(payload.AddedParentRenderIdsByIndex :: any, addedCount, "AddedParentRenderIdsByIndex"),
		_ValidateStringArray(payload.AddedVisualIdsByIndex :: any, addedCount, "AddedVisualIdsByIndex"),
	}

	for _, validation in ipairs(validations) do
		if validation ~= nil then
			return validation
		end
	end

	return nil
end

function RenderAccessoryTransportSchema.SerializeBootstrapChunk(
	payload: TRenderAccessoryBootstrapChunk
): (buffer?, string?)
	local validationError = _ValidateBootstrapChunk(payload)
	if validationError ~= nil then
		return nil, validationError
	end

	return Sera.Serialize(BootstrapChunkSchema, {
		Version = PAYLOAD_VERSION,
		ChunkIndex = payload.ChunkIndex,
		ChunkCount = payload.ChunkCount,
		Count = payload.Count,
		AccessoryIdsByIndex = payload.AccessoryIdsByIndex,
		AccessoryNamesByIndex = payload.AccessoryNamesByIndex,
		ParentRenderIdsByIndex = payload.ParentRenderIdsByIndex,
		VisualIdsByIndex = payload.VisualIdsByIndex,
	})
end

function RenderAccessoryTransportSchema.DeserializeBootstrapChunk(
	payloadBuffer: buffer
): (TRenderAccessoryBootstrapChunk?, string?)
	local didDeserialize, decodedPayload = pcall(Sera.Deserialize, BootstrapChunkSchema, payloadBuffer)
	if not didDeserialize then
		return nil, `bootstrap decode failure: {tostring(decodedPayload)}`
	end

	if decodedPayload.Version ~= PAYLOAD_VERSION then
		return nil, `bootstrap version mismatch: expected {PAYLOAD_VERSION}, received {tostring(decodedPayload.Version)}`
	end

	local logicalPayload: TRenderAccessoryBootstrapChunk = {
		Version = decodedPayload.Version,
		ChunkIndex = decodedPayload.ChunkIndex,
		ChunkCount = decodedPayload.ChunkCount,
		Count = decodedPayload.Count,
		AccessoryIdsByIndex = decodedPayload.AccessoryIdsByIndex,
		AccessoryNamesByIndex = decodedPayload.AccessoryNamesByIndex,
		ParentRenderIdsByIndex = decodedPayload.ParentRenderIdsByIndex,
		VisualIdsByIndex = decodedPayload.VisualIdsByIndex,
	}

	local validationError = _ValidateBootstrapChunk(logicalPayload)
	if validationError ~= nil then
		return nil, validationError
	end

	return logicalPayload, nil
end

function RenderAccessoryTransportSchema.SerializeDelta(payload: TRenderAccessoryDelta): (buffer?, string?)
	if payload.AddedAccessoryIdsByIndex ~= nil then
		local validationError = _ValidateDeltaAddGroup(payload)
		if validationError ~= nil then
			return nil, validationError
		end
	end

	if payload.RemovedAccessoryIds ~= nil then
		local removedValidationError =
			_ValidateStringArray(payload.RemovedAccessoryIds, #payload.RemovedAccessoryIds, "RemovedAccessoryIds")
		if removedValidationError ~= nil then
			return nil, removedValidationError
		end
	end

	local wirePayload = {
		Version = PAYLOAD_VERSION,
	}
	if payload.AddedAccessoryIdsByIndex ~= nil then
		wirePayload.AddedCount = payload.AddedCount
		wirePayload.AddedAccessoryIdsByIndex = payload.AddedAccessoryIdsByIndex
		wirePayload.AddedAccessoryNamesByIndex = payload.AddedAccessoryNamesByIndex
		wirePayload.AddedParentRenderIdsByIndex = payload.AddedParentRenderIdsByIndex
		wirePayload.AddedVisualIdsByIndex = payload.AddedVisualIdsByIndex
	end
	if payload.RemovedAccessoryIds ~= nil then
		wirePayload.RemovedAccessoryIds = payload.RemovedAccessoryIds
	end

	return Sera.DeltaSerialize(DeltaSchema, wirePayload)
end

function RenderAccessoryTransportSchema.DeserializeDelta(
	payloadBuffer: buffer
): (TRenderAccessoryDelta?, string?)
	local didDeserialize, decodedPayload = pcall(Sera.DeltaDeserialize, DeltaSchema, payloadBuffer)
	if not didDeserialize then
		return nil, `delta decode failure: {tostring(decodedPayload)}`
	end

	if decodedPayload.Version ~= PAYLOAD_VERSION then
		return nil, `delta version mismatch: expected {PAYLOAD_VERSION}, received {tostring(decodedPayload.Version)}`
	end

	local logicalPayload: TRenderAccessoryDelta = {
		Version = decodedPayload.Version,
	}

	if decodedPayload.AddedAccessoryIdsByIndex ~= nil then
		logicalPayload.AddedCount = decodedPayload.AddedCount
		logicalPayload.AddedAccessoryIdsByIndex = decodedPayload.AddedAccessoryIdsByIndex
		logicalPayload.AddedAccessoryNamesByIndex = decodedPayload.AddedAccessoryNamesByIndex
		logicalPayload.AddedParentRenderIdsByIndex = decodedPayload.AddedParentRenderIdsByIndex
		logicalPayload.AddedVisualIdsByIndex = decodedPayload.AddedVisualIdsByIndex

		local validationError = _ValidateDeltaAddGroup(logicalPayload)
		if validationError ~= nil then
			return nil, validationError
		end
	end

	if decodedPayload.RemovedAccessoryIds ~= nil then
		local removedValidationError =
			_ValidateStringArray(decodedPayload.RemovedAccessoryIds, #decodedPayload.RemovedAccessoryIds, "RemovedAccessoryIds")
		if removedValidationError ~= nil then
			return nil, removedValidationError
		end

		logicalPayload.RemovedAccessoryIds = decodedPayload.RemovedAccessoryIds
	end

	return logicalPayload, nil
end

return table.freeze(RenderAccessoryTransportSchema)
