--!strict

local Codec = require(script.Codec)
local Envelope = require(script.Envelope)
local Schema = require(script.Schema)
local Types = require(script.Types)

export type TSeraSchema = Types.TSeraSchema
export type TSharedSchema = Types.TSharedSchema
export type TJobDefinition = Types.TJobDefinition
export type TEnvelopeInfo = Types.TEnvelopeInfo
export type TCompiledJobSchemas = Types.TCompiledJobSchemas
export type TCompiledJob = Types.TCompiledJob

local ParallelLogistics = {}

local CompiledJob = {}
CompiledJob.__index = CompiledJob

function ParallelLogistics.DefineJob(definition: TJobDefinition): TCompiledJob
	local compiledDefinition = Schema.CompileJobDefinition(definition, Envelope.CreateEnvelopeInfo())
	local self = setmetatable({}, CompiledJob)
	self._definition = compiledDefinition
	return self :: any
end

function CompiledJob:EncodeArgs(args: { [string]: any }): (buffer?, string?)
	return Codec.EncodeArgs(self._definition, args)
end

function CompiledJob:DecodeArgs(argsBuffer: buffer, offset: number?): ({ [string]: any }?, number?, string?)
	return Codec.DecodeArgs(self._definition, argsBuffer, offset)
end

function CompiledJob:EncodeResultRow(row: { [string]: any }): (buffer?, string?)
	return Codec.EncodeResultRow(self._definition, row)
end

function CompiledJob:DecodeResultRow(rowBuffer: buffer, offset: number?): ({ [string]: any }?, number?, string?)
	return Codec.DecodeResultRow(self._definition, rowBuffer, offset)
end

function CompiledJob:EncodeResultBatch(rows: { { [string]: any } }): (buffer?, string?)
	return Codec.EncodeResultBatch(self._definition, rows)
end

function CompiledJob:DecodeResultBatch(batchBuffer: buffer, offset: number?): ({ { [string]: any } }?, number?, string?)
	return Codec.DecodeResultBatch(self._definition, batchBuffer, offset)
end

function CompiledJob:GetName(): string
	return self._definition.Name
end

function CompiledJob:GetVersion(): number
	return self._definition.Version
end

function CompiledJob:GetSchemas(): TCompiledJobSchemas
	return self._definition.Schemas
end

function CompiledJob:GetEnvelopeInfo(): TEnvelopeInfo
	return self._definition.EnvelopeInfo
end

return table.freeze(ParallelLogistics)
