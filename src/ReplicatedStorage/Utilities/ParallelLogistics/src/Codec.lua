--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Sera = require(ReplicatedStorage.Utilities.Sera)
local Envelope = require(script.Parent.Envelope)

local Codec = {}

local function _FormatError(jobName: string, operationName: string, message: string): string
	return `ParallelLogistics "{jobName}" {operationName} failed: {message}`
end

local function _SerializeSchema(jobName: string, operationName: string, schema: any, value: { [string]: any }): (buffer?, string?)
	local encodedBuffer, serializeError = Sera.Serialize(schema, value)
	if encodedBuffer == nil then
		return nil, _FormatError(jobName, operationName, `schema failure: {serializeError}`)
	end

	return encodedBuffer, nil
end

local function _DeserializeSchema(
	jobName: string,
	operationName: string,
	schema: any,
	sourceBuffer: buffer,
	offset: number
): ({ [string]: any }?, number?, string?)
	local didDeserialize, decodedValue, nextOffset = pcall(Sera.Deserialize, schema, sourceBuffer, offset)
	if not didDeserialize then
		return nil, nil, _FormatError(jobName, operationName, `decode overflow/underflow: {tostring(decodedValue)}`)
	end

	return decodedValue, nextOffset, nil
end

local function _CopyPayloadWithHeader(
	headerWriter: (buffer, number, number) -> number,
	headerSize: number,
	jobVersion: number,
	payloadBuffer: buffer
): buffer
	local payloadLength = buffer.len(payloadBuffer)
	local targetBuffer = buffer.create(headerSize + payloadLength)
	local payloadOffset = headerWriter(targetBuffer, 0, jobVersion)
	buffer.copy(targetBuffer, payloadOffset, payloadBuffer, 0, payloadLength)
	return targetBuffer
end

local function _ValidateBaseEnvelope(
	jobName: string,
	operationName: string,
	header: { [string]: number },
	expectedJobVersion: number
): string?
	if header.TransportFormatVersion ~= Envelope.GetTransportFormatVersion() then
		return _FormatError(
			jobName,
			operationName,
			`version mismatch: expected transport format {Envelope.GetTransportFormatVersion()}, received {header.TransportFormatVersion}`
		)
	end

	if header.JobVersion ~= expectedJobVersion then
		return _FormatError(
			jobName,
			operationName,
			`version mismatch: expected job version {expectedJobVersion}, received {header.JobVersion}`
		)
	end

	return nil
end

function Codec.EncodeArgs(compiledJob: { [string]: any }, args: { [string]: any }): (buffer?, string?)
	local payloadBuffer, payloadError = _SerializeSchema(compiledJob.Name, "EncodeArgs", compiledJob.Schemas.Args, args)
	if payloadBuffer == nil then
		return nil, payloadError
	end

	return _CopyPayloadWithHeader(Envelope.WriteArgsHeader, Envelope.GetArgsHeaderSize(), compiledJob.Version, payloadBuffer), nil
end

function Codec.DecodeArgs(
	compiledJob: { [string]: any },
	argsBuffer: buffer,
	offset: number?
): ({ [string]: any }?, number?, string?)
	local resolvedOffset = if offset == nil then 0 else offset
	if typeof(argsBuffer) ~= "buffer" then
		return nil, nil, _FormatError(compiledJob.Name, "DecodeArgs", "malformed envelope: expected a buffer")
	end

	local header, payloadOffset, headerError = Envelope.ReadArgsHeader(argsBuffer, resolvedOffset)
	if header == nil then
		return nil, nil, _FormatError(compiledJob.Name, "DecodeArgs", headerError :: string)
	end

	local versionError = _ValidateBaseEnvelope(compiledJob.Name, "DecodeArgs", header, compiledJob.Version)
	if versionError ~= nil then
		return nil, nil, versionError
	end

	return _DeserializeSchema(compiledJob.Name, "DecodeArgs", compiledJob.Schemas.Args, argsBuffer, payloadOffset :: number)
end

function Codec.EncodeResultRow(compiledJob: { [string]: any }, row: { [string]: any }): (buffer?, string?)
	local payloadBuffer, payloadError = _SerializeSchema(compiledJob.Name, "EncodeResultRow", compiledJob.Schemas.Result, row)
	if payloadBuffer == nil then
		return nil, payloadError
	end

	return _CopyPayloadWithHeader(
		Envelope.WriteResultRowHeader,
		Envelope.GetResultRowHeaderSize(),
		compiledJob.Version,
		payloadBuffer
	), nil
end

function Codec.DecodeResultRow(
	compiledJob: { [string]: any },
	rowBuffer: buffer,
	offset: number?
): ({ [string]: any }?, number?, string?)
	local resolvedOffset = if offset == nil then 0 else offset
	if typeof(rowBuffer) ~= "buffer" then
		return nil, nil, _FormatError(compiledJob.Name, "DecodeResultRow", "malformed envelope: expected a buffer")
	end

	local header, payloadOffset, headerError = Envelope.ReadResultRowHeader(rowBuffer, resolvedOffset)
	if header == nil then
		return nil, nil, _FormatError(compiledJob.Name, "DecodeResultRow", headerError :: string)
	end

	local versionError = _ValidateBaseEnvelope(compiledJob.Name, "DecodeResultRow", header, compiledJob.Version)
	if versionError ~= nil then
		return nil, nil, versionError
	end

	return _DeserializeSchema(compiledJob.Name, "DecodeResultRow", compiledJob.Schemas.Result, rowBuffer, payloadOffset :: number)
end

function Codec.EncodeResultBatch(compiledJob: { [string]: any }, rows: { { [string]: any } }): (buffer?, string?)
	if type(rows) ~= "table" then
		return nil, _FormatError(compiledJob.Name, "EncodeResultBatch", "schema failure: expected an array of rows")
	end

	local rowCount = #rows
	local headerSize = Envelope.GetResultBatchHeaderSize()
	local payloadSize = 0

	-- Validate every row and determine the final payload size.
	for rowIndex, row in ipairs(rows) do
		local rowBuffer, rowError = _SerializeSchema(
			compiledJob.Name,
			`EncodeResultBatch row #{rowIndex}`,
			compiledJob.Schemas.Result,
			row
		)
		if rowBuffer == nil then
			return nil, rowError
		end

		local rowSize = buffer.len(rowBuffer)
		payloadSize += rowSize
	end

	local batchBuffer = buffer.create(headerSize + payloadSize)
	local cursor = Envelope.WriteResultBatchHeader(batchBuffer, 0, compiledJob.Version, rowCount)

	-- Write each row in order using the compiled result schema.
	for rowIndex, row in ipairs(rows) do
		local nextCursor, pushError = Sera.Push(compiledJob.Schemas.Result, row, batchBuffer, cursor)
		if nextCursor == nil then
			return nil, _FormatError(
				compiledJob.Name,
				`EncodeResultBatch row #{rowIndex}`,
				`schema failure: {pushError}`
			)
		end

		cursor = nextCursor
	end

	return batchBuffer, nil
end

function Codec.DecodeResultBatch(
	compiledJob: { [string]: any },
	batchBuffer: buffer,
	offset: number?
): ({ { [string]: any } }?, number?, string?)
	local resolvedOffset = if offset == nil then 0 else offset
	if typeof(batchBuffer) ~= "buffer" then
		return nil, nil, _FormatError(compiledJob.Name, "DecodeResultBatch", "malformed envelope: expected a buffer")
	end

	local header, cursor, headerError = Envelope.ReadResultBatchHeader(batchBuffer, resolvedOffset)
	if header == nil then
		return nil, nil, _FormatError(compiledJob.Name, "DecodeResultBatch", headerError :: string)
	end

	local versionError = _ValidateBaseEnvelope(compiledJob.Name, "DecodeResultBatch", header, compiledJob.Version)
	if versionError ~= nil then
		return nil, nil, versionError
	end

	local rowCount = header.RowCount
	local rows = table.create(rowCount)

	-- Decode exactly the row count advertised by the envelope.
	for rowIndex = 1, rowCount do
		local row, nextCursor, rowError = _DeserializeSchema(
			compiledJob.Name,
			`DecodeResultBatch row #{rowIndex}`,
			compiledJob.Schemas.Result,
			batchBuffer,
			cursor :: number
		)
		if row == nil then
			return nil, nil, rowError
		end

		rows[rowIndex] = row
		cursor = nextCursor
	end

	return rows, cursor, nil
end

return table.freeze(Codec)
