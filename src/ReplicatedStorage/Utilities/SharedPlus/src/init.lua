--!strict

local Compiler = require(script.Compiler)
local Handle = require(script.Handle)
local SharedOps = require(script.SharedOps)
local Types = require(script.Types)

export type TScalarFieldConfig = Types.TScalarFieldConfig
export type TArrayFieldConfig = Types.TArrayFieldConfig
export type TRawSchema = Types.TRawSchema
export type TParsedSchema = Types.TParsedSchema
export type THandleConfig = Types.THandleConfig
export type THandle = Types.THandle
export type TPacket = Types.TPacket
export type TCompiledHandle = Types.TCompiledHandle
export type TCompiledSchema = Types.TCompiledSchema

local SharedPlus = {}

SharedPlus.Handle = Handle
SharedPlus.Compiler = Compiler

function SharedPlus.CreateRoot(initialFields: { [string]: any }?): SharedTable
	return SharedOps.CreateRoot(initialFields)
end

function SharedPlus.Clone(sharedTable: SharedTable): SharedTable
	return SharedOps.Clone(sharedTable)
end

function SharedPlus.Clear(sharedTable: SharedTable)
	SharedOps.Clear(sharedTable)
end

function SharedPlus.Size(sharedTable: SharedTable): number
	return SharedOps.Size(sharedTable)
end

function SharedPlus.ReplaceFields(sharedTable: SharedTable, fields: { [string]: any })
	SharedOps.ReplaceFields(sharedTable, fields)
end

function SharedPlus.IncrementField(sharedTable: SharedTable, fieldName: string, delta: number?): number
	return SharedOps.IncrementField(sharedTable, fieldName, delta)
end

function SharedPlus.ReplaceArray(
	sharedTable: SharedTable,
	fieldName: string,
	values: { any },
	countFieldName: string?
): SharedTable
	return SharedOps.ReplaceArray(sharedTable, fieldName, values, countFieldName)
end

function SharedPlus.ClearArray(sharedTable: SharedTable, fieldName: string, countFieldName: string?): SharedTable
	return SharedOps.ClearArray(sharedTable, fieldName, countFieldName)
end

return table.freeze(SharedPlus)
