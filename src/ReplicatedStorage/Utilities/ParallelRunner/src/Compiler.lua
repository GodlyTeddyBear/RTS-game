--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ParallelLogistics = require(ReplicatedStorage.Utilities.ParallelLogistics)
local Sera = require(ReplicatedStorage.Utilities.Sera)

local PayloadCodec = require(script.Parent.PayloadCodec)
local Types = require(script.Parent.Types)
local Validation = require(script.Parent.Validation)

type TAutoFieldMarker = Types.TAutoFieldMarker
type TCompiledJob = Types.TCompiledJob
type TDefineJobConfig = Types.TDefineJobConfig
type TMarkerScope = Types.TMarkerScope
type TPayloadScalarType = Types.TPayloadScalarType

local TYPE_MAP = table.freeze({
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
})

local function _BuildMarker(scope: TMarkerScope, typeName: string): TAutoFieldMarker
	assert(TYPE_MAP[typeName] ~= nil, `ParallelRunner.Compiler does not support marker type "{typeName}"`)

	return table.freeze({
		__ParallelRunnerMarker = true,
		MarkerScope = scope,
		TypeName = typeName,
	})
end

local function _BuildScope(scope: TMarkerScope)
	return table.freeze({
		u8 = function(): TAutoFieldMarker
			return _BuildMarker(scope, "u8")
		end,
		u16 = function(): TAutoFieldMarker
			return _BuildMarker(scope, "u16")
		end,
		u32 = function(): TAutoFieldMarker
			return _BuildMarker(scope, "u32")
		end,
		i8 = function(): TAutoFieldMarker
			return _BuildMarker(scope, "i8")
		end,
		i16 = function(): TAutoFieldMarker
			return _BuildMarker(scope, "i16")
		end,
		i32 = function(): TAutoFieldMarker
			return _BuildMarker(scope, "i32")
		end,
		f32 = function(): TAutoFieldMarker
			return _BuildMarker(scope, "f32")
		end,
		f64 = function(): TAutoFieldMarker
			return _BuildMarker(scope, "f64")
		end,
		boolean = function(): TAutoFieldMarker
			return _BuildMarker(scope, "boolean")
		end,
		string8 = function(): TAutoFieldMarker
			return _BuildMarker(scope, "string8")
		end,
		string16 = function(): TAutoFieldMarker
			return _BuildMarker(scope, "string16")
		end,
		string32 = function(): TAutoFieldMarker
			return _BuildMarker(scope, "string32")
		end,
		vector3 = function(): TAutoFieldMarker
			return _BuildMarker(scope, "vector3")
		end,
		cframe = function(): TAutoFieldMarker
			return _BuildMarker(scope, "cframe")
		end,
		lossyCFrame = function(): TAutoFieldMarker
			return _BuildMarker(scope, "lossyCFrame")
		end,
		color3 = function(): TAutoFieldMarker
			return _BuildMarker(scope, "color3")
		end,
	})
end

local function _IsArrayLike(value: { [any]: any }): boolean
	local numericCount = 0
	for key in value do
		if type(key) == "number" then
			numericCount += 1
		end
	end

	return numericCount > 0
end

local function _IsMarker(value: any, scope: TMarkerScope): boolean
	return type(value) == "table"
		and value.__ParallelRunnerMarker == true
		and value.MarkerScope == scope
		and type(value.TypeName) == "string"
end

local function _IsAnyMarker(value: any): boolean
	return type(value) == "table"
		and value.__ParallelRunnerMarker == true
		and (value.MarkerScope == "Arg" or value.MarkerScope == "Result")
		and type(value.TypeName) == "string"
end

local function _InferFieldType(fieldValue: any, label: string)
	local valueType = typeof(fieldValue)
	if valueType == "number" then
		return Sera.Float32
	end
	if valueType == "string" then
		return Sera.String16
	end
	if valueType == "boolean" then
		return Sera.Boolean
	end
	if valueType == "Vector3" then
		return Sera.Vector3
	end
	if valueType == "CFrame" then
		return Sera.LossyCFrame
	end
	if valueType == "Color3" then
		return Sera.Color3
	end

	error(`{label} has unsupported inferred value type "{valueType}"`, 0)
end

local function _MapMarkerTypeName(typeName: string, label: string): TPayloadScalarType
	assert(
		typeName == "u8"
			or typeName == "u16"
			or typeName == "u32"
			or typeName == "i8"
			or typeName == "i16"
			or typeName == "i32"
			or typeName == "f32"
			or typeName == "f64"
			or typeName == "boolean"
			or typeName == "string8"
			or typeName == "string16"
			or typeName == "string32"
			or typeName == "vector3"
			or typeName == "cframe"
			or typeName == "lossyCFrame"
			or typeName == "color3",
		`{label} marker type "{typeName}" is unsupported`
	)

	return typeName :: TPayloadScalarType
end

local function _InferPayloadType(fieldValue: any, label: string): TPayloadScalarType
	local valueType = typeof(fieldValue)
	if valueType == "number" then
		return "f32"
	end
	if valueType == "string" then
		return "string16"
	end
	if valueType == "boolean" then
		return "boolean"
	end
	if valueType == "Vector3" then
		return "vector3"
	end
	if valueType == "CFrame" then
		return "lossyCFrame"
	end
	if valueType == "Color3" then
		return "color3"
	end

	error(`{label} has unsupported inferred value type "{valueType}"`, 0)
end

local function _ResolveFieldType(fieldName: string, fieldValue: any, scope: TMarkerScope)
	local label = `ParallelRunner.Compiler {scope} field "{fieldName}"`
	if _IsMarker(fieldValue, scope) then
		local resolvedType = TYPE_MAP[(fieldValue :: TAutoFieldMarker).TypeName]
		assert(resolvedType ~= nil, `{label} marker type "{(fieldValue :: TAutoFieldMarker).TypeName}" is unsupported`)
		return resolvedType
	end

	if type(fieldValue) == "table" then
		error(`{label} must be a flat value or override marker; nested tables and arrays are unsupported`, 0)
	end

	return _InferFieldType(fieldValue, label)
end

local function _ResolvePayloadType(fieldName: string, fieldValue: any, labelPrefix: string): TPayloadScalarType
	if _IsAnyMarker(fieldValue) then
		return _MapMarkerTypeName((fieldValue :: TAutoFieldMarker).TypeName, `{labelPrefix} field "{fieldName}"`)
	end

	assert(type(fieldValue) ~= "table", `{labelPrefix} field "{fieldName}" nested tables are unsupported`)
	return _InferPayloadType(fieldValue, `{labelPrefix} field "{fieldName}"`)
end

local function _CompileRecord(record: { [string]: any }, scope: TMarkerScope, label: string)
	local schemaFields = {}
	local fieldCount = 0

	for fieldName, fieldValue in record do
		assert(type(fieldName) == "string" and fieldName ~= "", `{label} field names must be non-empty strings`)
		if type(fieldValue) == "table" and not _IsMarker(fieldValue, scope) then
			assert(not _IsArrayLike(fieldValue), `{label} field "{fieldName}" arrays are unsupported in v1`)
			error(`{label} field "{fieldName}" nested tables are unsupported in v1`, 0)
		end

		schemaFields[fieldName] = _ResolveFieldType(fieldName, fieldValue, scope)
		fieldCount += 1
	end

	assert(fieldCount > 0, `{label} must contain at least one field`)
	return Sera.Schema(schemaFields)
end

local function _CompilePayloadSchema(record: { [string]: any }, label: string)
	local payloadFields = {}
	local fieldCount = 0

	for fieldName, fieldValue in record do
		assert(type(fieldName) == "string" and fieldName ~= "", `{label} field names must be non-empty strings`)

		if type(fieldValue) == "table" and not _IsAnyMarker(fieldValue) then
			local arrayLength = #fieldValue
			assert(arrayLength == 1, `{label} field "{fieldName}" array schemas must contain exactly one item`)
			assert(next(fieldValue, 1) == nil, `{label} field "{fieldName}" array schemas must be contiguous`)
			payloadFields[fieldName] = {
				Kind = "Array",
				TypeName = _ResolvePayloadType(fieldName, fieldValue[1], label),
			}
			fieldCount += 1
			continue
		end

		payloadFields[fieldName] = {
			Kind = "Scalar",
			TypeName = _ResolvePayloadType(fieldName, fieldValue, label),
		}
		fieldCount += 1
	end

	assert(fieldCount > 0, `{label} must contain at least one field`)
	return PayloadCodec.BuildDescriptor(payloadFields)
end

local Compiler = {}

Compiler.Arg = _BuildScope("Arg")
Compiler.Result = _BuildScope("Result")

local CompiledRunnerJob = {}
CompiledRunnerJob.__index = CompiledRunnerJob

function Compiler.Compile(config: TDefineJobConfig): TCompiledJob
	Validation.AssertDefineJobConfig(config :: any)

	local argsSchema = _CompileRecord(config.Args, "Arg", `ParallelRunner.DefineJob("{config.Name}") Args`)
	local resultSchema = _CompileRecord(config.Results, "Result", `ParallelRunner.DefineJob("{config.Name}") Results`)
	local payloadSchemaDescriptor = nil
	local payloadCodec = nil
	if config.PayloadSchema ~= nil then
		payloadSchemaDescriptor =
			_CompilePayloadSchema(config.PayloadSchema, `ParallelRunner.DefineJob("{config.Name}") PayloadSchema`)
		payloadCodec = PayloadCodec.CompileDescriptor(config.Name, config.Version, payloadSchemaDescriptor)
	end

	local logisticsJob = ParallelLogistics.DefineJob({
		Name = config.Name,
		Version = config.Version,
		ArgsSchema = argsSchema,
		ResultSchema = resultSchema,
		SharedSchema = config.SharedSchema,
	})

	local self = setmetatable({}, CompiledRunnerJob)
	self._logisticsJob = logisticsJob
	self._payloadSchemaDescriptor = payloadSchemaDescriptor
	self._payloadCodec = payloadCodec
	return self :: any
end

function Compiler.DefineJob(config: TDefineJobConfig): TCompiledJob
	return Compiler.Compile(config)
end

function CompiledRunnerJob:EncodeArgs(args: { [string]: any }): (buffer?, string?)
	return self._logisticsJob:EncodeArgs(args)
end

function CompiledRunnerJob:DecodeArgs(argsBuffer: buffer, offset: number?): ({ [string]: any }?, number?, string?)
	return self._logisticsJob:DecodeArgs(argsBuffer, offset)
end

function CompiledRunnerJob:EncodeResultRow(row: { [string]: any }): (buffer?, string?)
	return self._logisticsJob:EncodeResultRow(row)
end

function CompiledRunnerJob:DecodeResultRow(rowBuffer: buffer, offset: number?): ({ [string]: any }?, number?, string?)
	return self._logisticsJob:DecodeResultRow(rowBuffer, offset)
end

function CompiledRunnerJob:EncodeResultBatch(rows: { { [string]: any } }): (buffer?, string?)
	return self._logisticsJob:EncodeResultBatch(rows)
end

function CompiledRunnerJob:DecodeResultBatch(
	batchBuffer: buffer,
	offset: number?
): ({ { [string]: any } }?, number?, string?)
	return self._logisticsJob:DecodeResultBatch(batchBuffer, offset)
end

function CompiledRunnerJob:GetName(): string
	return self._logisticsJob:GetName()
end

function CompiledRunnerJob:GetVersion(): number
	return self._logisticsJob:GetVersion()
end

function CompiledRunnerJob:GetSchemas()
	return self._logisticsJob:GetSchemas()
end

function CompiledRunnerJob:GetEnvelopeInfo()
	return self._logisticsJob:GetEnvelopeInfo()
end

function CompiledRunnerJob:GetPayloadSchemaDescriptor()
	return self._payloadSchemaDescriptor
end

function CompiledRunnerJob:GetPayloadCodec()
	return self._payloadCodec
end

return table.freeze(Compiler)
