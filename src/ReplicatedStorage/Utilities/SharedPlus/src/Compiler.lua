--!strict

local Handle = require(script.Parent.Handle)
local Schema = require(script.Parent.Schema)
local Types = require(script.Parent.Types)

type TCompiledHandle = Types.TCompiledHandle
type TCompiledSchema = Types.TCompiledSchema
type THandle = Types.THandle
type THandleConfig = Types.THandleConfig
type TPacket = Types.TPacket
type TParsedSchema = Types.TParsedSchema
type TRawSchema = Types.TRawSchema

local Compiler = {}

local CompiledHandle = {}
CompiledHandle.__index = CompiledHandle

local function _CreateCompiledHandle(parsedSchema: TParsedSchema, handleConfig: THandleConfig?): TCompiledHandle
	local self = setmetatable({}, CompiledHandle) :: any
	self._handle = Handle.new(parsedSchema, handleConfig)
	return self
end

function Compiler.Compile(schema: TRawSchema | TParsedSchema, _config: any?): TCompiledSchema
	local parsedSchema = Schema.Parse(schema)

	local compiledSchema = {} :: any

	function compiledSchema.new(handleConfig: THandleConfig?): TCompiledHandle
		return _CreateCompiledHandle(parsedSchema, handleConfig)
	end

	function compiledSchema:NewHandle(handleConfig: THandleConfig?): TCompiledHandle
		return _CreateCompiledHandle(parsedSchema, handleConfig)
	end

	compiledSchema.Schema = parsedSchema

	return table.freeze(compiledSchema)
end

function CompiledHandle:BeginWrite()
	self._handle:BeginWrite()
end

function CompiledHandle:WritePacket(packet: TPacket)
	assert(type(packet) == "table", "SharedPlus compiled WritePacket requires a packet table")

	local scalarPacket = packet.Scalars
	if scalarPacket ~= nil then
		assert(type(scalarPacket) == "table", "SharedPlus packet Scalars must be a table")
		for fieldName, value in scalarPacket do
			self._handle:SetScalar(fieldName, value)
		end
	end

	local arrayPacket = packet.Arrays
	if arrayPacket ~= nil then
		assert(type(arrayPacket) == "table", "SharedPlus packet Arrays must be a table")
		for fieldName, values in arrayPacket do
			self._handle:WriteArray(fieldName, values)
		end
	end

	local opsPacket = packet.Ops
	if opsPacket == nil then
		return
	end

	assert(type(opsPacket) == "table", "SharedPlus packet Ops must be a table")

	local incrementPacket = opsPacket.Increment
	if incrementPacket ~= nil then
		assert(type(incrementPacket) == "table", "SharedPlus packet Ops.Increment must be a table")
		for fieldName, delta in incrementPacket do
			self._handle:IncrementScalar(fieldName, delta)
		end
	end

	local clearPacket = opsPacket.Clear
	if clearPacket ~= nil then
		assert(type(clearPacket) == "table", "SharedPlus packet Ops.Clear must be a table")
		for fieldName, shouldClear in clearPacket do
			if shouldClear == true then
				self._handle:ResetField(fieldName)
			end
		end
	end
end

function CompiledHandle:Finalize(basePacket: TPacket?): SharedTable
	return self._handle:Finalize(basePacket)
end

function CompiledHandle:GetRoot(): SharedTable
	return self._handle:GetRoot()
end

function CompiledHandle:Destroy()
	self._handle:Destroy()
end

return table.freeze(Compiler)
