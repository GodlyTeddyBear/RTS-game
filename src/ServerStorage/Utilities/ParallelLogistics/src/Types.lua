--!strict

export type TSeraSchema = {
	Numeric: { any },
	String: { [string]: any },
}

export type TSharedSchema = {
	Scalars: { [string]: any }?,
	Arrays: { [string]: any }?,
}

export type TJobDefinition = {
	Name: string,
	Version: number,
	ArgsSchema: TSeraSchema,
	ResultSchema: TSeraSchema,
	SharedSchema: TSharedSchema?,
}

export type TEnvelopeInfo = {
	TransportFormatVersion: number,
	ArgsHeaderSize: number,
	ResultRowHeaderSize: number,
	ResultBatchHeaderSize: number,
}

export type TCompiledJobSchemas = {
	Args: TSeraSchema,
	Result: TSeraSchema,
	Shared: TSharedSchema?,
}

export type TCompiledJob = {
	EncodeArgs: (self: TCompiledJob, args: { [string]: any }) -> (buffer?, string?),
	DecodeArgs: (self: TCompiledJob, argsBuffer: buffer, offset: number?) -> ({ [string]: any }?, number?, string?),
	EncodeResultRow: (self: TCompiledJob, row: { [string]: any }) -> (buffer?, string?),
	DecodeResultRow: (self: TCompiledJob, rowBuffer: buffer, offset: number?) -> ({ [string]: any }?, number?, string?),
	EncodeResultBatch: (self: TCompiledJob, rows: { { [string]: any } }) -> (buffer?, string?),
	DecodeResultBatch: (self: TCompiledJob, batchBuffer: buffer, offset: number?) -> ({ { [string]: any } }?, number?, string?),
	GetName: (self: TCompiledJob) -> string,
	GetVersion: (self: TCompiledJob) -> number,
	GetSchemas: (self: TCompiledJob) -> TCompiledJobSchemas,
	GetEnvelopeInfo: (self: TCompiledJob) -> TEnvelopeInfo,
}

return table.freeze({})
