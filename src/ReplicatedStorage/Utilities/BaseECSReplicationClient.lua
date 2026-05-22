--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

require(ReplicatedStorage.Utilities.Replecs)
local JECS = require(ReplicatedStorage.Packages.JECS)

export type TReplicationPacketPayload = {
	Buffer: buffer,
	Variants: { { any } }?,
}

export type THandshakePayload = {
	Handshake: any,
}

export type TBootstrapPayload = {
	Handshake: any,
	Buffer: buffer,
	Variants: { { any } }?,
}

export type TSharedSchema = {
	sharedComponents: { any }?,
	sharedTags: { any }?,
	customIds: { any }?,
	serdes: { [any]: any }?,
	componentCustomHandlers: { [any]: (any) -> any }?,
}

export type TTransportCleanupTask = RBXScriptConnection | (() -> ()) | {
	Disconnect: ((self: any) -> ())?,
	Destroy: ((self: any) -> ())?,
} | nil

type TSchemaState = {
	SharedComponents: { [any]: true },
	SharedTags: { [any]: true },
	CustomIds: { [any]: true },
	Serdes: { [any]: any },
	ComponentCustomHandlers: { [any]: (any) -> any },
}

local MAX_PENDING_RELIABLE_PACKETS = 32
local MAX_PENDING_ENTITY_PACKETS = 32
local MAX_PENDING_UNRELIABLE_PACKETS = 64

local function _RunCleanupTask(cleanupTask: TTransportCleanupTask)
	if cleanupTask == nil then
		return
	end

	if type(cleanupTask) == "function" then
		cleanupTask()
		return
	end

	if typeof(cleanupTask) == "RBXScriptConnection" then
		cleanupTask:Disconnect()
		return
	end

	if type(cleanupTask) == "table" and type(cleanupTask.Disconnect) == "function" then
		cleanupTask:Disconnect()
		return
	end

	if type(cleanupTask) == "table" and type(cleanupTask.Destroy) == "function" then
		cleanupTask:Destroy()
	end
end

local function _AddSharedId(world: any, sharedComponent: any, componentId: any)
	if not world:has(componentId, sharedComponent) then
		world:add(componentId, sharedComponent)
	end
end

local function _RemoveSharedId(world: any, sharedComponent: any, componentId: any)
	if world:has(componentId, sharedComponent) then
		world:remove(componentId, sharedComponent)
	end
end

local function _CopyArray(values: { any }?): { any }?
	if values == nil then
		return nil
	end

	local copied = table.clone(values)
	table.freeze(copied)
	return copied
end

local function _GetEntityName(world: any, entity: any): string?
	local success, value = pcall(function()
		return world:get(entity, JECS.Name)
	end)
	if success and type(value) == "string" and value ~= "" then
		return value
	end

	return nil
end

local function _GetCustomIdIdentifier(customId: any): string?
	if type(customId) ~= "table" then
		return nil
	end

	local identifier = customId.identifier
	if type(identifier) == "string" and identifier ~= "" then
		return identifier
	end

	return nil
end

local function _CreateSchemaState(): TSchemaState
	return {
		SharedComponents = {},
		SharedTags = {},
		CustomIds = {},
		Serdes = {},
		ComponentCustomHandlers = {},
	}
end

local function _CreatePendingPacketState()
	return {
		Reliable = {},
		Entity = {},
		Unreliable = {},
	}
end

local BaseECSReplicationClient = {}
BaseECSReplicationClient.__index = BaseECSReplicationClient

function BaseECSReplicationClient.new(contextName: string)
	local self = setmetatable({}, BaseECSReplicationClient)
	self._contextName = contextName
	self._world = nil
	self._components = nil
	self._replecsLibrary = nil
	self._replecsClient = nil
	self._initialized = false
	self._started = false
	self._handshakeVerified = false
	self._hasReceivedFull = false
	self._bootstrapCompleted = false
	self._cleanupTasks = {}
	self._appliedSharedSchema = nil
	self._schemaState = _CreateSchemaState()
	self._lastHandshakeVerificationError = nil
	self._pendingPackets = _CreatePendingPacketState()
	return self
end

function BaseECSReplicationClient:Init()
	assert(not self._initialized, ("%sECSReplicationClient: Init called twice"):format(self._contextName))

	-- Build the mirror world and its Replecs client wrapper.
	self._world = self:_CreateWorld()
	assert(self._world ~= nil, ("%sECSReplicationClient: failed to create world"):format(self._contextName))

	self._replecsLibrary = self:_CreateReplecsLibrary()
	assert(self._replecsLibrary ~= nil, ("%sECSReplicationClient: missing Replecs library"):format(self._contextName))

	self._replecsClient = self._replecsLibrary.create_client(self._world)
	assert(self._replecsClient ~= nil, ("%sECSReplicationClient: failed to create Replecs client"):format(self._contextName))
	assert(type(self._replecsClient.init) == "function", ("%sECSReplicationClient: Replecs client missing init"):format(self._contextName))

	self._replecsClient:init(self._world)

	-- Let subclasses expose the component ids they want client code to read.
	self._components = self:_BuildComponents(self._world, self._replecsLibrary)
	assert(self._components ~= nil, ("%sECSReplicationClient: _BuildComponents returned nil"):format(self._contextName))
	self._initialized = true

	local sharedSchema = self:_GetSharedSchema()
	if sharedSchema ~= nil then
		self:ApplySharedSchema(sharedSchema)
	end

	self:_RegisterReplicatedSurface()
end

function BaseECSReplicationClient:Start()
	self:RequireReady()
	assert(not self._started, ("%sECSReplicationClient: Start called twice"):format(self._contextName))

	self:_TrackCleanup(self:_ConnectTransport())
	self:_OnStart()
	self._started = true
end

function BaseECSReplicationClient:RequireReady()
	assert(self._initialized, ("%sECSReplicationClient: used before Init"):format(self._contextName))
	assert(self._world ~= nil, ("%sECSReplicationClient: missing world"):format(self._contextName))
	assert(self._components ~= nil, ("%sECSReplicationClient: missing components"):format(self._contextName))
	assert(self._replecsLibrary ~= nil, ("%sECSReplicationClient: missing Replecs library"):format(self._contextName))
	assert(self._replecsClient ~= nil, ("%sECSReplicationClient: missing Replecs client"):format(self._contextName))
end

function BaseECSReplicationClient:GetWorldOrThrow()
	self:RequireReady()
	return self._world
end

function BaseECSReplicationClient:GetComponentsOrThrow()
	self:RequireReady()
	return self._components
end

function BaseECSReplicationClient:GetReplecsLibraryOrThrow()
	self:RequireReady()
	return self._replecsLibrary
end

function BaseECSReplicationClient:GetReplecsClientOrThrow()
	self:RequireReady()
	return self._replecsClient
end

function BaseECSReplicationClient:GetReplecsComponentsOrThrow()
	self:RequireReady()
	return self._replecsClient.components
end

function BaseECSReplicationClient:RegisterSharedComponent(componentId: any)
	self:RequireReady()
	_AddSharedId(self._world, self:GetReplecsComponentsOrThrow().shared, componentId)
	self._schemaState.SharedComponents[componentId] = true
end

function BaseECSReplicationClient:RegisterSharedTag(tagId: any)
	self:RequireReady()
	_AddSharedId(self._world, self:GetReplecsComponentsOrThrow().shared, tagId)
	self._schemaState.SharedTags[tagId] = true
end

function BaseECSReplicationClient:RemoveSharedComponent(componentId: any)
	self:RequireReady()
	_RemoveSharedId(self._world, self:GetReplecsComponentsOrThrow().shared, componentId)
	self._schemaState.SharedComponents[componentId] = nil
end

function BaseECSReplicationClient:RemoveSharedTag(tagId: any)
	self:RequireReady()
	_RemoveSharedId(self._world, self:GetReplecsComponentsOrThrow().shared, tagId)
	self._schemaState.SharedTags[tagId] = nil
end

function BaseECSReplicationClient:HandleHandshake(payload: THandshakePayload)
	self:RequireReady()
	if self._handshakeVerified or self._hasReceivedFull or self._bootstrapCompleted then
		self:ResetBootstrapState()
	end

	local verified, message = self:VerifyHandshake(payload.Handshake)
	assert(verified, ("%sECSReplicationClient: handshake verification failed: %s"):format(self._contextName, tostring(message)))
	self._handshakeVerified = true
end

function BaseECSReplicationClient:HandleFull(payload: TReplicationPacketPayload)
	self:RequireReady()
	assert(self._handshakeVerified, ("%sECSReplicationClient: received full payload before handshake"):format(self._contextName))
	self._replecsClient:apply_full(payload.Buffer, payload.Variants)
	self._hasReceivedFull = true
	self:_FlushPendingPackets()
	self:_FinalizeBootstrap()
end

function BaseECSReplicationClient:HandleBootstrap(payload: TBootstrapPayload): boolean
	self:RequireReady()
	self:HandleHandshake({
		Handshake = payload.Handshake,
	})
	self:HandleFull({
		Buffer = payload.Buffer,
		Variants = payload.Variants,
	})
	return true
end

function BaseECSReplicationClient:HandleReliable(payload: TReplicationPacketPayload)
	self:RequireReady()
	assert(self._handshakeVerified, ("%sECSReplicationClient: received reliable payload before handshake"):format(self._contextName))
	if not self._hasReceivedFull then
		self:_QueuePendingPacket("Reliable", payload)
		return
	end
	self._replecsClient:apply_updates(payload.Buffer, payload.Variants)
end

function BaseECSReplicationClient:HandleUnreliable(payload: TReplicationPacketPayload)
	self:RequireReady()
	assert(self._handshakeVerified, ("%sECSReplicationClient: received unreliable payload before handshake"):format(self._contextName))
	if not self._hasReceivedFull then
		self:_QueuePendingPacket("Unreliable", payload)
		return
	end
	self._replecsClient:apply_unreliable(payload.Buffer, payload.Variants)
end

function BaseECSReplicationClient:HandleEntity(payload: TReplicationPacketPayload)
	self:RequireReady()
	assert(self._handshakeVerified, ("%sECSReplicationClient: received entity payload before handshake"):format(self._contextName))
	if not self._hasReceivedFull then
		self:_QueuePendingPacket("Entity", payload)
		return
	end
	self._replecsClient:apply_entity(payload.Buffer, payload.Variants)
end

function BaseECSReplicationClient:GenerateHandshake()
	self:RequireReady()
	return self._replecsClient:generate_handshake()
end

function BaseECSReplicationClient:VerifyHandshake(handshake: any): (boolean, string?)
	self:RequireReady()
	local verified, message = self._replecsClient:verify_handshake(handshake)
	if verified then
		self._lastHandshakeVerificationError = nil
	else
		self._lastHandshakeVerificationError = message
	end
	return verified, message
end

function BaseECSReplicationClient:EncodeComponent(componentId: any): number
	self:RequireReady()
	return self._replecsClient:encode_component(componentId)
end

function BaseECSReplicationClient:DecodeComponent(encodedId: number): any
	self:RequireReady()
	return self._replecsClient:decode_component(encodedId)
end

function BaseECSReplicationClient:GetSharedCount(): number
	self:RequireReady()
	return self._replecsClient:get_shared_count()
end

function BaseECSReplicationClient:RegisterCustomId(customId: any)
	self:RequireReady()
	self._replecsClient:register_custom_id(customId)
	self._schemaState.CustomIds[customId] = true
end

function BaseECSReplicationClient:CreateCustomId(identifier: string, handler: ((any) -> any)?)
	self:RequireReady()
	return self._replecsLibrary.create_custom_id(identifier, handler)
end

function BaseECSReplicationClient:SetCustomIdHandler(customId: any, handler: (any) -> any)
	self:RequireReady()
	assert(type(customId) == "table" and type(customId.handle) == "function", "invalid Replecs custom id")
	customId:handle(handler)
end

function BaseECSReplicationClient:RegisterSerdes(componentId: any, serdes: any)
	self:RequireReady()
	self._replecsClient:set_serdes(componentId, serdes)
	self._schemaState.Serdes[componentId] = serdes
end

function BaseECSReplicationClient:RemoveSerdes(componentId: any)
	self:RequireReady()
	self._replecsClient:remove_serdes(componentId)
	self._schemaState.Serdes[componentId] = nil
end

function BaseECSReplicationClient:SetGlobalHandler(handler: (id: number) -> any)
	self:RequireReady()
	self._replecsClient:handle_global(handler)
end

function BaseECSReplicationClient:GetServerEntity(clientEntity: any): number?
	self:RequireReady()
	return self._replecsClient:get_server_entity(clientEntity)
end

function BaseECSReplicationClient:GetClientEntity(serverEntity: number): any
	self:RequireReady()
	return self._replecsClient:get_client_entity(serverEntity)
end

function BaseECSReplicationClient:RegisterEntity(clientEntity: any, serverEntity: number)
	self:RequireReady()
	self._replecsClient:register_entity(clientEntity, serverEntity)
end

function BaseECSReplicationClient:UnregisterEntity(clientEntity: any)
	self:RequireReady()
	self._replecsClient:unregister_entity(clientEntity)
end

function BaseECSReplicationClient:AfterReplication(callback: () -> ())
	self:RequireReady()
	self._replecsClient:after_replication(callback)
end

function BaseECSReplicationClient:Added(callback: (entity: any) -> ())
	self:RequireReady()
	return self._replecsClient:added(callback)
end

function BaseECSReplicationClient:OnAdded(callback: (entity: any) -> ())
	return self:Added(callback)
end

function BaseECSReplicationClient:Hook(action: string, relationOrEntity: any, callback: (...any) -> ())
	self:RequireReady()
	return self._replecsClient:hook(action, relationOrEntity, callback)
end

function BaseECSReplicationClient:Override(action: string, relationOrEntity: any, callback: (...any) -> ())
	self:RequireReady()
	return self._replecsClient:override(action, relationOrEntity, callback)
end

function BaseECSReplicationClient:ApplySharedSchema(schema: TSharedSchema)
	self:RequireReady()
	self:ValidateSharedSchema(schema)

	if schema.sharedComponents ~= nil then
		for _, componentId in ipairs(schema.sharedComponents) do
			self:RegisterSharedComponent(componentId)
		end
	end

	if schema.sharedTags ~= nil then
		for _, tagId in ipairs(schema.sharedTags) do
			self:RegisterSharedTag(tagId)
		end
	end

	if schema.customIds ~= nil then
		for _, customId in ipairs(schema.customIds) do
			self:RegisterCustomId(customId)
		end
	end

	if schema.serdes ~= nil then
		for componentId, serdes in schema.serdes do
			self:RegisterSerdes(componentId, serdes)
		end
	end

	if schema.componentCustomHandlers ~= nil then
		local world = self:GetWorldOrThrow()
		local customHandlerComponent = self:GetReplecsComponentsOrThrow().custom_handler
		for componentId, handler in schema.componentCustomHandlers do
			world:set(componentId, customHandlerComponent, handler)
			self._schemaState.ComponentCustomHandlers[componentId] = handler
		end
	end

	self._appliedSharedSchema = self:_SnapshotSharedSchema(schema)
	self:_OnSharedSchemaApplied(schema)
end

function BaseECSReplicationClient:ValidateSharedSchema(schema: TSharedSchema)
	self:RequireReady()
	assert(type(schema) == "table", "shared schema must be a table")

	local function validateSharedIds(entries: { any }?, entryName: string)
		if entries == nil then
			return
		end

		for index, entityId in ipairs(entries) do
			assert(entityId ~= nil, ("shared schema %s entry %d was nil"):format(entryName, index))
			local entityName = _GetEntityName(self._world, entityId)
			assert(entityName ~= nil, ("shared schema %s entry %d is missing JECS.Name"):format(entryName, index))
		end
	end

	validateSharedIds(schema.sharedComponents, "sharedComponents")
	validateSharedIds(schema.sharedTags, "sharedTags")

	if schema.customIds ~= nil then
		for index, customId in ipairs(schema.customIds) do
			assert(_GetCustomIdIdentifier(customId) ~= nil, ("shared schema customIds entry %d is invalid"):format(index))
		end
	end

	if schema.serdes ~= nil then
		for componentId, serdes in schema.serdes do
			local entityName = _GetEntityName(self._world, componentId)
			assert(entityName ~= nil, "shared schema serdes target is missing JECS.Name")
			assert(type(serdes) == "table", ("shared schema serdes for %s must be a table"):format(entityName))
			assert(type(serdes.serialize) == "function", ("shared schema serdes for %s is missing serialize"):format(entityName))
			assert(type(serdes.deserialize) == "function", ("shared schema serdes for %s is missing deserialize"):format(entityName))
		end
	end

	if schema.componentCustomHandlers ~= nil then
		for componentId, handler in schema.componentCustomHandlers do
			local entityName = _GetEntityName(self._world, componentId)
			assert(entityName ~= nil, "shared schema component custom handler target is missing JECS.Name")
			assert(type(handler) == "function", ("shared schema custom handler for %s must be a function"):format(entityName))
		end
	end

	self:_ValidateSharedSchema(schema)
end

function BaseECSReplicationClient:ForgetTrackedCustomId(customId: any)
	self:RequireReady()
	self._schemaState.CustomIds[customId] = nil
end

function BaseECSReplicationClient:RemoveRegisteredCustomId(customId: any)
	self:ForgetTrackedCustomId(customId)
end

function BaseECSReplicationClient:RemoveComponentCustomHandler(componentId: any)
	self:RequireReady()
	self._world:remove(componentId, self:GetReplecsComponentsOrThrow().custom_handler)
	self._schemaState.ComponentCustomHandlers[componentId] = nil
end

function BaseECSReplicationClient:GetAppliedSharedSchema(): TSharedSchema?
	self:RequireReady()
	return self._appliedSharedSchema
end

function BaseECSReplicationClient:HasAppliedSharedSchema(): boolean
	self:RequireReady()
	return self._appliedSharedSchema ~= nil
end

function BaseECSReplicationClient:GetSchemaSummary()
	self:RequireReady()

	local summary = {
		SharedComponents = {},
		SharedTags = {},
		CustomIds = {},
		Serdes = {},
		ComponentCustomHandlers = {},
		SharedComponentCount = 0,
		SharedTagCount = 0,
		CustomIdCount = 0,
		SerdesCount = 0,
		ComponentCustomHandlerCount = 0,
	}

	for componentId in self._schemaState.SharedComponents do
		table.insert(summary.SharedComponents, assert(_GetEntityName(self._world, componentId)))
	end
	for tagId in self._schemaState.SharedTags do
		table.insert(summary.SharedTags, assert(_GetEntityName(self._world, tagId)))
	end
	for customId in self._schemaState.CustomIds do
		table.insert(summary.CustomIds, assert(_GetCustomIdIdentifier(customId)))
	end
	for componentId in self._schemaState.Serdes do
		table.insert(summary.Serdes, assert(_GetEntityName(self._world, componentId)))
	end
	for componentId in self._schemaState.ComponentCustomHandlers do
		table.insert(summary.ComponentCustomHandlers, assert(_GetEntityName(self._world, componentId)))
	end

	table.sort(summary.SharedComponents)
	table.sort(summary.SharedTags)
	table.sort(summary.CustomIds)
	table.sort(summary.Serdes)
	table.sort(summary.ComponentCustomHandlers)

	summary.SharedComponentCount = #summary.SharedComponents
	summary.SharedTagCount = #summary.SharedTags
	summary.CustomIdCount = #summary.CustomIds
	summary.SerdesCount = #summary.Serdes
	summary.ComponentCustomHandlerCount = #summary.ComponentCustomHandlers

	return table.freeze(summary)
end

function BaseECSReplicationClient:GetLastHandshakeVerificationError(): string?
	self:RequireReady()
	return self._lastHandshakeVerificationError
end

function BaseECSReplicationClient:DescribeSharedSchemaMismatch(handshake: any)
	self:RequireReady()

	local summary = self:GetSchemaSummary()
	local handshakeComponents = if type(handshake) == "table" and type(handshake.components) == "table" then handshake.components else {}
	local handshakeCustomIds = if type(handshake) == "table" and type(handshake.custom_ids) == "table" then handshake.custom_ids else {}
	local handshakeSerdes = if type(handshake) == "table" and type(handshake.serdes) == "table" then handshake.serdes else {}

	local expectedComponents = {}
	for _, name in ipairs(summary.SharedComponents) do
		expectedComponents[name] = true
	end
	for _, name in ipairs(summary.SharedTags) do
		expectedComponents[name] = true
	end

	local missingComponents = {}
	local extraComponents = {}
	for name in expectedComponents do
		if handshakeComponents[name] ~= true then
			table.insert(missingComponents, name)
		end
	end
	for name in handshakeComponents do
		if expectedComponents[name] ~= true then
			table.insert(extraComponents, name)
		end
	end

	local expectedCustomIds = {}
	for _, name in ipairs(summary.CustomIds) do
		expectedCustomIds[name] = true
	end

	local missingCustomIds = {}
	local extraCustomIds = {}
	for name in expectedCustomIds do
		if handshakeCustomIds[name] ~= true then
			table.insert(missingCustomIds, name)
		end
	end
	for name in handshakeCustomIds do
		if expectedCustomIds[name] ~= true then
			table.insert(extraCustomIds, name)
		end
	end

	local expectedSerdes = {}
	for componentId, serdes in self._schemaState.Serdes do
		local entityName = assert(_GetEntityName(self._world, componentId))
		expectedSerdes[entityName] = {
			includes_variants = serdes.includes_variants or false,
			bytespan = serdes.bytespan,
		}
	end

	local missingSerdes = {}
	local extraSerdes = {}
	local mismatchedSerdes = {}
	for name, expectedInfo in expectedSerdes do
		if handshakeSerdes[name] == nil then
			table.insert(missingSerdes, name)
		else
			local handshakeInfo = handshakeSerdes[name]
			local receivedIncludesVariants = false
			local receivedBytespan = nil
			if type(handshakeInfo) == "table" then
				receivedIncludesVariants = handshakeInfo.includes_variants or false
				receivedBytespan = handshakeInfo.bytespan
			end
			if receivedIncludesVariants ~= expectedInfo.includes_variants or receivedBytespan ~= expectedInfo.bytespan then
				table.insert(mismatchedSerdes, table.freeze({
					Component = name,
					ExpectedIncludesVariants = expectedInfo.includes_variants,
					ReceivedIncludesVariants = receivedIncludesVariants,
					ExpectedBytespan = expectedInfo.bytespan,
					ReceivedBytespan = receivedBytespan,
				}))
			end
		end
	end
	for name in handshakeSerdes do
		if expectedSerdes[name] == nil then
			table.insert(extraSerdes, name)
		end
	end

	table.sort(missingComponents)
	table.sort(extraComponents)
	table.sort(missingCustomIds)
	table.sort(extraCustomIds)
	table.sort(missingSerdes)
	table.sort(extraSerdes)
	table.sort(mismatchedSerdes, function(left, right)
		return left.Component < right.Component
	end)

	return table.freeze({
		MissingComponents = table.freeze(missingComponents),
		ExtraComponents = table.freeze(extraComponents),
		MissingCustomIds = table.freeze(missingCustomIds),
		ExtraCustomIds = table.freeze(extraCustomIds),
		MissingSerdes = table.freeze(missingSerdes),
		ExtraSerdes = table.freeze(extraSerdes),
		MismatchedSerdes = table.freeze(mismatchedSerdes),
		LastVerificationError = self._lastHandshakeVerificationError,
	})
end

function BaseECSReplicationClient:HasVerifiedHandshake(): boolean
	return self._handshakeVerified
end

function BaseECSReplicationClient:HasReceivedFull(): boolean
	return self._hasReceivedFull
end

function BaseECSReplicationClient:HasCompletedBootstrap(): boolean
	return self._bootstrapCompleted
end

function BaseECSReplicationClient:IsStarted(): boolean
	return self._started
end

function BaseECSReplicationClient:ResetBootstrapState()
	self._handshakeVerified = false
	self._hasReceivedFull = false
	self._bootstrapCompleted = false
	self._pendingPackets = _CreatePendingPacketState()
end

function BaseECSReplicationClient:Destroy()
	if not self._initialized and self._replecsClient == nil then
		return
	end

	self:_OnDestroy()

	for _, cleanupTask in ipairs(self._cleanupTasks) do
		_RunCleanupTask(cleanupTask)
	end
	table.clear(self._cleanupTasks)

	if self._replecsClient ~= nil and self._replecsClient.inited ~= nil then
		self._replecsClient:destroy()
	end

	self._world = nil
	self._components = nil
	self._replecsLibrary = nil
	self._replecsClient = nil
	self._initialized = false
	self._started = false
	self:ResetBootstrapState()
	self._appliedSharedSchema = nil
	self._schemaState = _CreateSchemaState()
	self._lastHandshakeVerificationError = nil
end

function BaseECSReplicationClient:_CreateWorld()
	return JECS.World.new()
end

function BaseECSReplicationClient:_CreateReplecsLibrary()
	return require(ReplicatedStorage.Utilities.Replecs)
end

function BaseECSReplicationClient:_BuildComponents(_world: any, _replecsLibrary: any)
	error(("%sECSReplicationClient must implement _BuildComponents"):format(self._contextName))
end

function BaseECSReplicationClient:_SnapshotSharedSchema(schema: TSharedSchema): TSharedSchema
	local snapshot = {
		sharedComponents = _CopyArray(schema.sharedComponents),
		sharedTags = _CopyArray(schema.sharedTags),
		customIds = _CopyArray(schema.customIds),
		serdes = if schema.serdes ~= nil then table.clone(schema.serdes) else nil,
		componentCustomHandlers = if schema.componentCustomHandlers ~= nil then table.clone(schema.componentCustomHandlers) else nil,
	}
	return table.freeze(snapshot)
end

function BaseECSReplicationClient:_GetSharedSchema(): TSharedSchema?
	return nil
end

function BaseECSReplicationClient:_ValidateSharedSchema(_schema: TSharedSchema)
	return
end

function BaseECSReplicationClient:_OnSharedSchemaApplied(_schema: TSharedSchema)
	return
end

function BaseECSReplicationClient:_RegisterReplicatedSurface()
	return
end

function BaseECSReplicationClient:_ConnectTransport(): TTransportCleanupTask
	return nil
end

function BaseECSReplicationClient:_TrackCleanup(cleanupTask: TTransportCleanupTask)
	if cleanupTask == nil then
		return
	end

	table.insert(self._cleanupTasks, cleanupTask)
end

function BaseECSReplicationClient:_OnStart()
	return
end

function BaseECSReplicationClient:_OnDestroy()
	return
end

function BaseECSReplicationClient:_OnBootstrapCompleted()
	return
end

function BaseECSReplicationClient:_FinalizeBootstrap()
	if self._bootstrapCompleted then
		return
	end

	self._bootstrapCompleted = true
	self:_OnBootstrapCompleted()
end

function BaseECSReplicationClient:_QueuePendingPacket(queueName: "Reliable" | "Entity" | "Unreliable", payload: TReplicationPacketPayload)
	local queue = self._pendingPackets[queueName]

	if queueName == "Unreliable" then
		if #queue >= MAX_PENDING_UNRELIABLE_PACKETS then
			table.remove(queue, 1)
		end
		table.insert(queue, payload)
		return
	end

	local queueLimit = if queueName == "Reliable" then MAX_PENDING_RELIABLE_PACKETS else MAX_PENDING_ENTITY_PACKETS
	if #queue >= queueLimit then
		self:ResetBootstrapState()
		error(("%sECSReplicationClient: pending %s packet queue overflow before full snapshot"):format(self._contextName, string.lower(queueName)))
	end

	table.insert(queue, payload)
end

function BaseECSReplicationClient:_FlushPendingPackets()
	for _, payload in ipairs(self._pendingPackets.Reliable) do
		self._replecsClient:apply_updates(payload.Buffer, payload.Variants)
	end
	for _, payload in ipairs(self._pendingPackets.Entity) do
		self._replecsClient:apply_entity(payload.Buffer, payload.Variants)
	end
	for _, payload in ipairs(self._pendingPackets.Unreliable) do
		self._replecsClient:apply_unreliable(payload.Buffer, payload.Variants)
	end

	self._pendingPackets = _CreatePendingPacketState()
end

return BaseECSReplicationClient
