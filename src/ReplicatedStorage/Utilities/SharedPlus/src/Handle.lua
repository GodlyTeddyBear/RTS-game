--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Schema = require(script.Parent.Schema)
local SharedOps = require(script.Parent.SharedOps)
local Staging = require(script.Parent.Staging)
local TableRecycler = require(ReplicatedStorage.Utilities.TableRecycler)
local Types = require(script.Parent.Types)

type THandle = Types.THandle
type THandleConfig = Types.THandleConfig
type TPacket = Types.TPacket
type TParsedArrayField = Types.TParsedArrayField
type TParsedSchema = Types.TParsedSchema
type TRawSchema = Types.TRawSchema

local Handle = {}
Handle.__index = Handle

type TArrayState = {
	Values: { [number]: any },
	Count: number,
}

local function _BuildNormalizedArray(values: { any }): ({ any }, number)
	local normalizedArray = table.create(#values)
	local count = 0
	for index, value in ipairs(values) do
		count = index
		normalizedArray[index] = SharedOps.NormalizeValue(value)
	end

	return normalizedArray, count
end

local function _CreateRecycler(config: THandleConfig?): any
	return TableRecycler.new({
		Strict = true,
		DebugName = if config ~= nil and config.RecyclerDebugName ~= nil
			then config.RecyclerDebugName
			else "SharedPlus.Handle",
	})
end

local function _BuildRootSharedTable(
	parsedSchema: TParsedSchema,
	scalarValues: { [string]: any },
	arrayStates: { [string]: TArrayState }
): SharedTable
	local rootFields = {}

	for _, fieldName in ipairs(parsedSchema.ScalarFieldNames) do
		rootFields[fieldName] = SharedOps.NormalizeValue(scalarValues[fieldName])
	end

	for _, fieldName in ipairs(parsedSchema.ArrayFieldNames) do
		local fieldConfig = parsedSchema.ArrayFields[fieldName]
		local arrayState = arrayStates[fieldName]
		local values = if arrayState ~= nil then arrayState.Values else {}
		local count = if arrayState ~= nil then arrayState.Count else 0
		rootFields[fieldName] = SharedTable.new(values)
		rootFields[fieldConfig.CountFieldName] = count
	end

	return SharedTable.new(rootFields)
end

local function _ApplyPacketScalars(rootFields: { [string]: any }, scalarPacket: { [string]: any }?)
	if scalarPacket == nil then
		return
	end

	assert(type(scalarPacket) == "table", "SharedPlus.Handle:Finalize base packet Scalars must be a table")
	for fieldName, value in scalarPacket do
		rootFields[fieldName] = SharedOps.NormalizeValue(value)
	end
end

local function _ApplyPacketArrays(
	parsedSchema: TParsedSchema,
	rootFields: { [string]: any },
	arrayPacket: { [string]: { any } }?
)
	if arrayPacket == nil then
		return
	end

	assert(type(arrayPacket) == "table", "SharedPlus.Handle:Finalize base packet Arrays must be a table")
	for fieldName, values in arrayPacket do
		local fieldConfig = parsedSchema.ArrayFields[fieldName]
		assert(fieldConfig ~= nil, `SharedPlus.Handle:Finalize base packet array field "{fieldName}" is not declared`)
		assert(type(values) == "table", `SharedPlus.Handle:Finalize base packet array field "{fieldName}" must be a table`)
		Staging.AssertFlatArray(values, `SharedPlus.Handle:Finalize("{fieldName}")`)
		local normalizedArray, count = _BuildNormalizedArray(values)
		rootFields[fieldName] = SharedTable.new(normalizedArray)
		rootFields[fieldConfig.CountFieldName] = count
	end
end

local function _CreateEmptyArrayState(): TArrayState
	return {
		Values = {},
		Count = 0,
	}
end

local function _BuildRootSharedTableWithBasePacket(
	parsedSchema: TParsedSchema,
	basePacket: TPacket,
	pendingScalarValues: { [string]: any },
	pendingArrayStates: { [string]: TArrayState },
	touchedArrayFieldNames: { string }
): SharedTable
	local rootFields = {}
	_ApplyPacketScalars(rootFields, basePacket.Scalars)
	_ApplyPacketArrays(parsedSchema, rootFields, basePacket.Arrays)
	_ApplyPacketScalars(rootFields, pendingScalarValues)

	for _, fieldName in ipairs(touchedArrayFieldNames) do
		local fieldConfig = parsedSchema.ArrayFields[fieldName]
		local arrayState = pendingArrayStates[fieldName]
		local resolvedArrayState = if arrayState ~= nil then arrayState else _CreateEmptyArrayState()
		rootFields[fieldName] = SharedTable.new(resolvedArrayState.Values)
		rootFields[fieldConfig.CountFieldName] = resolvedArrayState.Count
	end

	return SharedTable.new(rootFields)
end

local function _CloneArrayState(arrayState: TArrayState?): TArrayState
	if arrayState == nil then
		return _CreateEmptyArrayState()
	end

	return {
		Values = table.clone(arrayState.Values),
		Count = arrayState.Count,
	}
end

function Handle.new(schema: TRawSchema | TParsedSchema, config: THandleConfig?): THandle
	local parsedSchema = Schema.Parse(schema)

	local self = setmetatable({}, Handle) :: any
	self._destroyed = false
	self._writeActive = false
	self._schema = parsedSchema
	self._recycler = _CreateRecycler(config)
	self._scalarValues = {}
	self._arrayStates = {}
	self._pendingScalarValues = nil
	self._touchedArrayFieldNames = nil
	self._touchedArrayLookup = nil
	self._pendingArrayStates = nil

	for _, fieldName in ipairs(parsedSchema.ScalarFieldNames) do
		local fieldConfig = parsedSchema.ScalarFields[fieldName]
		self._scalarValues[fieldName] = fieldConfig.Default
	end

	for _, fieldName in ipairs(parsedSchema.ArrayFieldNames) do
		self._arrayStates[fieldName] = _CreateEmptyArrayState()
	end

	self._root = _BuildRootSharedTable(parsedSchema, self._scalarValues, self._arrayStates)

	return self
end

function Handle:BeginWrite()
	self:_AssertAlive()
	assert(not self._writeActive, "SharedPlus.Handle:BeginWrite cannot start a new write while another write is active")
	self:_ReleaseCycleScratch()

	self._pendingScalarValues = self._recycler:AcquireMap()
	self._touchedArrayFieldNames = self._recycler:AcquireArray()
	self._touchedArrayLookup = self._recycler:AcquireMap()
	self._pendingArrayStates = {}
	self._writeActive = true
end

function Handle:SetScalar(fieldName: string, value: any)
	self:_AssertWriteActive("SetScalar")

	local fieldConfig = self._schema.ScalarFields[fieldName]
	assert(fieldConfig ~= nil, `SharedPlus.Handle:SetScalar("{fieldName}") requires a declared scalar field`)
	assert(self._pendingScalarValues ~= nil, "SharedPlus handle is missing pending scalar state")
	self._pendingScalarValues[fieldName] = value
end

function Handle:IncrementScalar(fieldName: string, delta: number?): number
	self:_AssertWriteActive("IncrementScalar")

	local fieldConfig = self._schema.ScalarFields[fieldName]
	assert(fieldConfig ~= nil, `SharedPlus.Handle:IncrementScalar("{fieldName}") requires a declared scalar field`)
	assert(fieldConfig.AllowIncrement, `SharedPlus.Handle:IncrementScalar("{fieldName}") is not allowed by schema`)

	local resolvedDelta = if delta == nil then 1 else delta
	assert(type(resolvedDelta) == "number", "SharedPlus.Handle:IncrementScalar delta must be a number")
	assert(self._pendingScalarValues ~= nil, "SharedPlus handle is missing pending scalar state")

	local currentValue = self._pendingScalarValues[fieldName]
	if currentValue == nil then
		currentValue = self._scalarValues[fieldName]
	end

	assert(type(currentValue) == "number", `SharedPlus.Handle:IncrementScalar("{fieldName}") requires a numeric field`)
	self._pendingScalarValues[fieldName] = currentValue + resolvedDelta
	return currentValue
end

function Handle:WriteArray(fieldName: string, sourceArray: { any }): number
	self:_AssertWriteActive("WriteArray")

	local fieldConfig = self:_MarkArrayFieldRewrite(fieldName)
	local resolvedArray = sourceArray
	if fieldConfig.FlattenInput then
		resolvedArray = Staging.FlattenNestedArray(
			self._recycler,
			sourceArray,
			`SharedPlus.Handle:WriteArray("{fieldName}")`
		)
	else
		Staging.AssertFlatArray(sourceArray, `SharedPlus.Handle:WriteArray("{fieldName}")`)
	end

	assert(self._pendingArrayStates ~= nil, "SharedPlus handle is missing pending array state")
	local normalizedArray, count = _BuildNormalizedArray(resolvedArray)
	self._pendingArrayStates[fieldName] = {
		Values = normalizedArray,
		Count = count,
	}
	return count
end

function Handle:Append(fieldName: string, value: any): number
	self:_AssertWriteActive("Append")
	local arrayState = self:_EnsureArrayFieldRewrite(fieldName)
	local nextIndex = arrayState.Count + 1
	arrayState.Values[nextIndex] = SharedOps.NormalizeValue(value)
	arrayState.Count = nextIndex
	return nextIndex
end

function Handle:SetIndex(fieldName: string, index: number, value: any): number
	self:_AssertWriteActive("SetIndex")
	assert(type(index) == "number" and index % 1 == 0 and index >= 1, "SharedPlus.Handle:SetIndex requires a positive integer index")
	local arrayState = self:_EnsureArrayFieldRewrite(fieldName)

	arrayState.Values[index] = SharedOps.NormalizeValue(value)
	if index > arrayState.Count then
		arrayState.Count = index
	end
	return arrayState.Count
end

function Handle:ResetField(fieldName: string)
	self:_AssertWriteActive("ResetField")

	local scalarFieldConfig = self._schema.ScalarFields[fieldName]
	if scalarFieldConfig ~= nil then
		assert(self._pendingScalarValues ~= nil, "SharedPlus handle is missing pending scalar state")
		self._pendingScalarValues[fieldName] = scalarFieldConfig.Default
		return
	end

	local arrayFieldConfig = self._schema.ArrayFields[fieldName]
	assert(arrayFieldConfig ~= nil, `SharedPlus.Handle:ResetField("{fieldName}") requires a declared field`)
	self:_MarkArrayFieldRewrite(fieldName)
	assert(self._pendingArrayStates ~= nil, "SharedPlus handle is missing pending array state")
	self._pendingArrayStates[fieldName] = _CreateEmptyArrayState()
end

function Handle:Finalize(basePacket: TPacket?): SharedTable
	self:_AssertWriteActive("Finalize")

	local pendingScalarValues = self._pendingScalarValues
	assert(pendingScalarValues ~= nil, "SharedPlus handle is missing pending scalar state")
	for fieldName, value in pendingScalarValues do
		self._scalarValues[fieldName] = value
	end

	local touchedArrayFieldNames = self._touchedArrayFieldNames
	local pendingArrayStates = self._pendingArrayStates
	assert(touchedArrayFieldNames ~= nil and pendingArrayStates ~= nil, "SharedPlus handle is missing pending array state")
	for _, fieldName in ipairs(touchedArrayFieldNames) do
		local arrayState = pendingArrayStates[fieldName]
		if arrayState == nil then
			arrayState = _CreateEmptyArrayState()
		end
		self._arrayStates[fieldName] = arrayState
	end

	if basePacket ~= nil then
		assert(type(basePacket) == "table", "SharedPlus.Handle:Finalize base packet must be a table")
		self._root = _BuildRootSharedTableWithBasePacket(
			self._schema,
			basePacket,
			pendingScalarValues,
			pendingArrayStates,
			touchedArrayFieldNames
		)
	else
		self._root = _BuildRootSharedTable(self._schema, self._scalarValues, self._arrayStates)
	end
	self._writeActive = false
	self:_ReleaseCycleScratch()
	return self._root
end

function Handle:GetRoot(): SharedTable
	self:_AssertAlive()
	return self._root
end

function Handle:ClearAll(): SharedTable
	self:_AssertAlive()
	self._writeActive = false
	self:_ReleaseCycleScratch()

	for _, fieldName in ipairs(self._schema.ScalarFieldNames) do
		local defaultValue = self._schema.ScalarFields[fieldName].Default
		self._scalarValues[fieldName] = defaultValue
	end

	for _, fieldName in ipairs(self._schema.ArrayFieldNames) do
		self._arrayStates[fieldName] = _CreateEmptyArrayState()
	end

	self._root = _BuildRootSharedTable(self._schema, self._scalarValues, self._arrayStates)
	return self._root
end

function Handle:Destroy()
	if self._destroyed then
		return
	end

	self._destroyed = true
	self._writeActive = false
	self:_ReleaseCycleScratch()

	local didDestroyRecycler, destroyRecyclerError = self._recycler:Destroy()
	assert(didDestroyRecycler, destroyRecyclerError)
end

function Handle:_AssertAlive()
	assert(not self._destroyed, "SharedPlus handle has already been destroyed")
end

function Handle:_AssertWriteActive(methodName: string)
	self:_AssertAlive()
	assert(self._writeActive, `SharedPlus.Handle:{methodName} requires BeginWrite() before mutation`)
end

function Handle:_MarkArrayFieldRewrite(fieldName: string): TParsedArrayField
	local fieldConfig = self._schema.ArrayFields[fieldName]
	assert(fieldConfig ~= nil, `SharedPlus.Handle array field "{fieldName}" is not declared`)
	assert(self._touchedArrayFieldNames ~= nil and self._touchedArrayLookup ~= nil, "SharedPlus handle is missing pending array state")

	if not self._touchedArrayLookup[fieldName] then
		self._touchedArrayLookup[fieldName] = true
		self._touchedArrayFieldNames[#self._touchedArrayFieldNames + 1] = fieldName
	end

	return fieldConfig
end

function Handle:_EnsureArrayFieldRewrite(fieldName: string): TArrayState
	self:_MarkArrayFieldRewrite(fieldName)
	assert(self._pendingArrayStates ~= nil, "SharedPlus handle is missing pending array state")

	local existingPendingState = self._pendingArrayStates[fieldName]
	if existingPendingState ~= nil then
		return existingPendingState
	end

	local pendingState = _CloneArrayState(self._arrayStates[fieldName])
	self._pendingArrayStates[fieldName] = pendingState
	return pendingState
end

function Handle:_ReleaseCycleScratch()
	if self._pendingScalarValues ~= nil then
		local didRelease, releaseError = self._recycler:ReleaseMap(self._pendingScalarValues)
		assert(didRelease, releaseError)
		self._pendingScalarValues = nil
	end

	if self._touchedArrayFieldNames ~= nil then
		local didRelease, releaseError = self._recycler:ReleaseArray(self._touchedArrayFieldNames)
		assert(didRelease, releaseError)
		self._touchedArrayFieldNames = nil
	end

	if self._touchedArrayLookup ~= nil then
		local didRelease, releaseError = self._recycler:ReleaseMap(self._touchedArrayLookup)
		assert(didRelease, releaseError)
		self._touchedArrayLookup = nil
	end

	if self._pendingArrayStates ~= nil then
		table.clear(self._pendingArrayStates)
		self._pendingArrayStates = nil
	end
end

return table.freeze(Handle)
