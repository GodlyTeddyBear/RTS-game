--!strict

export type TScalarFieldConfig = {
	Default: any?,
	AllowIncrement: boolean?,
}

export type TArrayFieldConfig = {
	CapacityHint: number?,
	FlattenInput: boolean?,
	CountFieldName: string?,
}

export type TRawSchema = {
	Scalars: { [string]: TScalarFieldConfig }?,
	Arrays: { [string]: TArrayFieldConfig }?,
}

export type TParsedScalarField = {
	Default: any?,
	AllowIncrement: boolean,
}

export type TParsedArrayField = {
	CapacityHint: number?,
	FlattenInput: boolean,
	CountFieldName: string,
}

export type TParsedSchema = {
	ScalarFields: { [string]: TParsedScalarField },
	ArrayFields: { [string]: TParsedArrayField },
	ScalarFieldNames: { string },
	ArrayFieldNames: { string },
}

export type THandleConfig = {
	RecyclerDebugName: string?,
}

export type TPacket = {
	Scalars: { [string]: any }?,
	Arrays: { [string]: { any } }?,
	Ops: {
		Increment: { [string]: number }?,
		Clear: { [string]: boolean }?,
	}?,
}

export type THandle = {
	BeginWrite: (self: THandle) -> (),
	SetScalar: (self: THandle, fieldName: string, value: any) -> (),
	IncrementScalar: (self: THandle, fieldName: string, delta: number?) -> number,
	WriteArray: (self: THandle, fieldName: string, sourceArray: { any }) -> number,
	Append: (self: THandle, fieldName: string, value: any) -> number,
	SetIndex: (self: THandle, fieldName: string, index: number, value: any) -> number,
	ResetField: (self: THandle, fieldName: string) -> (),
	Finalize: (self: THandle) -> SharedTable,
	GetRoot: (self: THandle) -> SharedTable,
	ClearAll: (self: THandle) -> SharedTable,
	Destroy: (self: THandle) -> (),
}

export type TCompiledHandle = {
	BeginWrite: (self: TCompiledHandle) -> (),
	WritePacket: (self: TCompiledHandle, packet: TPacket) -> (),
	Finalize: (self: TCompiledHandle) -> SharedTable,
	GetRoot: (self: TCompiledHandle) -> SharedTable,
	Destroy: (self: TCompiledHandle) -> (),
}

export type TCompiledSchema = {
	Schema: TParsedSchema,
	new: (handleConfig: THandleConfig?) -> TCompiledHandle,
	NewHandle: (self: TCompiledSchema, handleConfig: THandleConfig?) -> TCompiledHandle,
}

return table.freeze({})
