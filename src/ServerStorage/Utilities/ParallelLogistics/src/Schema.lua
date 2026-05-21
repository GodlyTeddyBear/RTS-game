--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SharedPlus = require(ReplicatedStorage.Utilities.SharedPlus)
local Types = require(script.Parent.Types)

type TCompiledJobSchemas = Types.TCompiledJobSchemas
type TEnvelopeInfo = Types.TEnvelopeInfo
type TJobDefinition = Types.TJobDefinition
type TSeraSchema = Types.TSeraSchema

local Schema = {}

local function _AssertName(name: string)
	assert(type(name) == "string" and name ~= "", "ParallelLogistics.DefineJob requires a non-empty Name")
end

local function _AssertVersion(version: number)
	assert(
		type(version) == "number" and version % 1 == 0 and version > 0 and version <= 65535,
		"ParallelLogistics.DefineJob requires Version to be a positive u16 integer"
	)
end

local function _AssertSeraSchema(schema: TSeraSchema?, label: string)
	assert(type(schema) == "table", `ParallelLogistics.DefineJob requires {label}`)
	assert(type(schema.Numeric) == "table", `ParallelLogistics.DefineJob {label} must be a Sera schema`)
	assert(type(schema.String) == "table", `ParallelLogistics.DefineJob {label} must be a Sera schema`)
end

local function _ResolveSharedSchema(sharedSchema: any): any?
	if sharedSchema == nil then
		return nil
	end

	assert(type(sharedSchema) == "table", "ParallelLogistics.DefineJob SharedSchema must be a table when provided")
	local compiledSharedSchema = SharedPlus.Compiler.Compile(sharedSchema)
	return compiledSharedSchema.Schema
end

function Schema.CompileJobDefinition(definition: TJobDefinition, envelopeInfo: TEnvelopeInfo): { [string]: any }
	assert(type(definition) == "table", "ParallelLogistics.DefineJob requires a definition table")

	_AssertName(definition.Name)
	_AssertVersion(definition.Version)
	_AssertSeraSchema(definition.ArgsSchema, "ArgsSchema")
	_AssertSeraSchema(definition.ResultSchema, "ResultSchema")

	local compiledSchemas: TCompiledJobSchemas = {
		Args = definition.ArgsSchema,
		Result = definition.ResultSchema,
		Shared = _ResolveSharedSchema(definition.SharedSchema),
	}

	return table.freeze({
		Name = definition.Name,
		Version = definition.Version,
		Schemas = compiledSchemas,
		EnvelopeInfo = envelopeInfo,
	})
end

return table.freeze(Schema)
