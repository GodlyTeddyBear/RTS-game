--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Schema = require(script.Parent.Schema)
local SharedOps = require(script.Parent.SharedOps)
local Staging = require(script.Parent.Staging)
local TableRecycler = require(ReplicatedStorage.Utilities.TableRecycler)
local Types = require(script.Parent.Types)

type THandle = Types.THandle
type THandleConfig = Types.THandleConfig
type TParsedArrayField = Types.TParsedArrayField
type TParsedSchema = Types.TParsedSchema
type TRawSchema = Types.TRawSchema

local Handle = {}
Handle.__index = Handle

local function _ApplyScalar(root: SharedTable, fieldName: string, value: any)
	SharedTable.update(root, fieldName, function()
		return SharedOps.NormalizeValue(value)
	end)
end

local function _CreateRecycler(config: THandleConfig?): any
	return TableRecycler.new({
		Strict = true,
		DebugName = if config ~= nil and config.RecyclerDebugName ~= nil
			then config.RecyclerDebugName
			else "SharedPlus.Handle",
	})
end

function Handle.new(schema: TRawSchema | TParsedSchema, config: THandleConfig?): THandle
	local parsedSchema = Schema.Parse(schema)
	local root = SharedTable.new()

	local self = setmetatable({}, Handle) :: any
	self._destroyed = false
	self._writeActive = false
	self._schema = parsedSchema
	self._root = root
	self._recycler = _CreateRecycler(config)
	self._children = {}
	self._scalarValues = {}
	self._arrayCounts = {}
	self._pendingScalarValues = nil
	self._touchedArrayFieldNames = nil
	self._touchedArrayLookup = nil
	self._pendingArrayCounts = nil

	for _, fieldName in ipairs(parsedSchema.ScalarFieldNames) do
		local fieldConfig = parsedSchema.ScalarFields[fieldName]
		self._scalarValues[fieldName] = fieldConfig.Default
		_ApplyScalar(root, fieldName, fieldConfig.Default)
	end

	for _, fieldName in ipairs(parsedSchema.ArrayFieldNames) do
		local fieldConfig = parsedSchema.ArrayFields[fieldName]
		local child = SharedTable.new()
		self._children[fieldName] = child
		self._arrayCounts[fieldName] = 0
		_ApplyScalar(root, fieldName, child)
		_ApplyScalar(root, fieldConfig.CountFieldName, 0)
	end

	return self
end

function Handle:BeginWrite()
	self:_AssertAlive()
	assert(not self._writeActive, "SharedPlus.Handle:BeginWrite cannot start a new write while another write is active")
	self:_ReleaseCycleScratch()

	self._pendingScalarValues = self._recycler:AcquireMap()
	self._touchedArrayFieldNames = self._recycler:AcquireArray()
	self._touchedArrayLookup = self._recycler:AcquireMap()
	self._pendingArrayCounts = self._recycler:AcquireMap()
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

	local fieldConfig = self:_BeginArrayFieldRewrite(fieldName)
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

	local child = self._children[fieldName]
	assert(child ~= nil, `SharedPlus.Handle:WriteArray("{fieldName}") child SharedTable is missing`)
	assert(self._pendingArrayCounts ~= nil, "SharedPlus handle is missing pending array state")

	local count = 0
	for index, value in ipairs(resolvedArray) do
		count = index
		child[index] = SharedOps.NormalizeValue(value)
	end

	self._pendingArrayCounts[fieldName] = count
	return count
end

function Handle:Append(fieldName: string, value: any): number
	self:_AssertWriteActive("Append")
	self:_EnsureArrayFieldRewrite(fieldName)

	local child = self._children[fieldName]
	assert(child ~= nil, `SharedPlus.Handle:Append("{fieldName}") child SharedTable is missing`)
	assert(self._pendingArrayCounts ~= nil, "SharedPlus handle is missing pending array state")

	local nextIndex = (self._pendingArrayCounts[fieldName] or 0) + 1
	child[nextIndex] = SharedOps.NormalizeValue(value)
	self._pendingArrayCounts[fieldName] = nextIndex
	return nextIndex
end

function Handle:SetIndex(fieldName: string, index: number, value: any): number
	self:_AssertWriteActive("SetIndex")
	assert(type(index) == "number" and index % 1 == 0 and index >= 1, "SharedPlus.Handle:SetIndex requires a positive integer index")
	self:_EnsureArrayFieldRewrite(fieldName)

	local child = self._children[fieldName]
	assert(child ~= nil, `SharedPlus.Handle:SetIndex("{fieldName}") child SharedTable is missing`)
	assert(self._pendingArrayCounts ~= nil, "SharedPlus handle is missing pending array state")

	child[index] = SharedOps.NormalizeValue(value)
	local currentCount = self._pendingArrayCounts[fieldName] or 0
	if index > currentCount then
		self._pendingArrayCounts[fieldName] = index
	end
	return self._pendingArrayCounts[fieldName]
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
	self:_BeginArrayFieldRewrite(fieldName)
end

function Handle:Finalize(): SharedTable
	self:_AssertWriteActive("Finalize")

	local pendingScalarValues = self._pendingScalarValues
	assert(pendingScalarValues ~= nil, "SharedPlus handle is missing pending scalar state")
	for fieldName, value in pendingScalarValues do
		self._scalarValues[fieldName] = value
		_ApplyScalar(self._root, fieldName, value)
	end

	local touchedArrayFieldNames = self._touchedArrayFieldNames
	local pendingArrayCounts = self._pendingArrayCounts
	assert(touchedArrayFieldNames ~= nil and pendingArrayCounts ~= nil, "SharedPlus handle is missing pending array state")
	for _, fieldName in ipairs(touchedArrayFieldNames) do
		local fieldConfig = self._schema.ArrayFields[fieldName]
		local count = pendingArrayCounts[fieldName] or 0
		self._arrayCounts[fieldName] = count
		_ApplyScalar(self._root, fieldConfig.CountFieldName, count)
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
		_ApplyScalar(self._root, fieldName, defaultValue)
	end

	for _, fieldName in ipairs(self._schema.ArrayFieldNames) do
		local child = self._children[fieldName]
		local fieldConfig = self._schema.ArrayFields[fieldName]
		SharedTable.clear(child)
		self._arrayCounts[fieldName] = 0
		_ApplyScalar(self._root, fieldConfig.CountFieldName, 0)
	end

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

function Handle:_BeginArrayFieldRewrite(fieldName: string): TParsedArrayField
	local fieldConfig = self._schema.ArrayFields[fieldName]
	assert(fieldConfig ~= nil, `SharedPlus.Handle array field "{fieldName}" is not declared`)
	assert(
		self._touchedArrayFieldNames ~= nil and self._touchedArrayLookup ~= nil and self._pendingArrayCounts ~= nil,
		"SharedPlus handle is missing pending array state"
	)

	if not self._touchedArrayLookup[fieldName] then
		self._touchedArrayLookup[fieldName] = true
		self._touchedArrayFieldNames[#self._touchedArrayFieldNames + 1] = fieldName
	end

	local child = self._children[fieldName]
	assert(child ~= nil, `SharedPlus.Handle array field "{fieldName}" child SharedTable is missing`)
	SharedTable.clear(child)
	self._pendingArrayCounts[fieldName] = 0

	return fieldConfig
end

function Handle:_EnsureArrayFieldRewrite(fieldName: string): TParsedArrayField
	local fieldConfig = self._schema.ArrayFields[fieldName]
	assert(fieldConfig ~= nil, `SharedPlus.Handle array field "{fieldName}" is not declared`)
	assert(
		self._touchedArrayFieldNames ~= nil and self._touchedArrayLookup ~= nil and self._pendingArrayCounts ~= nil,
		"SharedPlus handle is missing pending array state"
	)

	if self._touchedArrayLookup[fieldName] then
		return fieldConfig
	end

	return self:_BeginArrayFieldRewrite(fieldName)
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

	if self._pendingArrayCounts ~= nil then
		local didRelease, releaseError = self._recycler:ReleaseMap(self._pendingArrayCounts)
		assert(didRelease, releaseError)
		self._pendingArrayCounts = nil
	end
end

return table.freeze(Handle)
