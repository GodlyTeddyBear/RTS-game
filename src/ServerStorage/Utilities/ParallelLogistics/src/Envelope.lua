--!strict

local TRANSPORT_FORMAT_VERSION = 1

local U16_BYTES = 2
local U32_BYTES = 4

local ARGS_HEADER_SIZE = U16_BYTES + U16_BYTES
local RESULT_ROW_HEADER_SIZE = U16_BYTES + U16_BYTES
local RESULT_BATCH_HEADER_SIZE = U16_BYTES + U16_BYTES + U32_BYTES

local Envelope = {}

local function _ValidateReadableRange(sourceBuffer: buffer, offset: number, requiredBytes: number): boolean
	return offset >= 0 and requiredBytes >= 0 and (offset + requiredBytes) <= buffer.len(sourceBuffer)
end

function Envelope.GetTransportFormatVersion(): number
	return TRANSPORT_FORMAT_VERSION
end

function Envelope.GetArgsHeaderSize(): number
	return ARGS_HEADER_SIZE
end

function Envelope.GetResultRowHeaderSize(): number
	return RESULT_ROW_HEADER_SIZE
end

function Envelope.GetResultBatchHeaderSize(): number
	return RESULT_BATCH_HEADER_SIZE
end

function Envelope.CreateEnvelopeInfo(): { [string]: number }
	return table.freeze({
		TransportFormatVersion = TRANSPORT_FORMAT_VERSION,
		ArgsHeaderSize = ARGS_HEADER_SIZE,
		ResultRowHeaderSize = RESULT_ROW_HEADER_SIZE,
		ResultBatchHeaderSize = RESULT_BATCH_HEADER_SIZE,
	})
end

function Envelope.WriteArgsHeader(targetBuffer: buffer, offset: number, jobVersion: number): number
	buffer.writeu16(targetBuffer, offset, TRANSPORT_FORMAT_VERSION)
	buffer.writeu16(targetBuffer, offset + U16_BYTES, jobVersion)
	return offset + ARGS_HEADER_SIZE
end

function Envelope.WriteResultRowHeader(targetBuffer: buffer, offset: number, jobVersion: number): number
	buffer.writeu16(targetBuffer, offset, TRANSPORT_FORMAT_VERSION)
	buffer.writeu16(targetBuffer, offset + U16_BYTES, jobVersion)
	return offset + RESULT_ROW_HEADER_SIZE
end

function Envelope.WriteResultBatchHeader(targetBuffer: buffer, offset: number, jobVersion: number, rowCount: number): number
	buffer.writeu16(targetBuffer, offset, TRANSPORT_FORMAT_VERSION)
	buffer.writeu16(targetBuffer, offset + U16_BYTES, jobVersion)
	buffer.writeu32(targetBuffer, offset + U16_BYTES + U16_BYTES, rowCount)
	return offset + RESULT_BATCH_HEADER_SIZE
end

function Envelope.ReadArgsHeader(sourceBuffer: buffer, offset: number): ({ [string]: number }?, number?, string?)
	if not _ValidateReadableRange(sourceBuffer, offset, ARGS_HEADER_SIZE) then
		return nil, nil, "Malformed args envelope: truncated header"
	end

	return {
		TransportFormatVersion = buffer.readu16(sourceBuffer, offset),
		JobVersion = buffer.readu16(sourceBuffer, offset + U16_BYTES),
	}, offset + ARGS_HEADER_SIZE, nil
end

function Envelope.ReadResultRowHeader(sourceBuffer: buffer, offset: number): ({ [string]: number }?, number?, string?)
	if not _ValidateReadableRange(sourceBuffer, offset, RESULT_ROW_HEADER_SIZE) then
		return nil, nil, "Malformed result-row envelope: truncated header"
	end

	return {
		TransportFormatVersion = buffer.readu16(sourceBuffer, offset),
		JobVersion = buffer.readu16(sourceBuffer, offset + U16_BYTES),
	}, offset + RESULT_ROW_HEADER_SIZE, nil
end

function Envelope.ReadResultBatchHeader(sourceBuffer: buffer, offset: number): ({ [string]: number }?, number?, string?)
	if not _ValidateReadableRange(sourceBuffer, offset, RESULT_BATCH_HEADER_SIZE) then
		return nil, nil, "Malformed result-batch envelope: truncated header"
	end

	return {
		TransportFormatVersion = buffer.readu16(sourceBuffer, offset),
		JobVersion = buffer.readu16(sourceBuffer, offset + U16_BYTES),
		RowCount = buffer.readu32(sourceBuffer, offset + U16_BYTES + U16_BYTES),
	}, offset + RESULT_BATCH_HEADER_SIZE, nil
end

return table.freeze(Envelope)
