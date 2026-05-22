--!strict

--[=[
    @class BaseECSReplicationService
    Shared server-side ECS replication base that wires a context world into a
    Replecs server, owns shared schema registration, and exposes bootstrap and
    packet flush helpers for concrete contexts.

    Flow: resolve ECS dependencies -> create the Replecs server -> register the
    replicated surface -> validate and apply shared schema -> hydrate players
    and flush entity packets through the concrete transport hooks.
    @server
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

type TRegistry = {
	Get: (self: any, name: string) -> any,
}

type TSchemaState = {
	SharedComponents: { [any]: true },
	SharedTags: { [any]: true },
	CustomIds: { [any]: true },
	Serdes: { [any]: any },
	ComponentCustomHandlers: { [any]: (any) -> any },
}

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

local BaseECSReplicationService = {}
BaseECSReplicationService.__index = BaseECSReplicationService

-- Lifecycle
--- Creates a new base replication service for a named context.
--- @within BaseECSReplicationService
--- @param contextName string -- The owning context name used in assertions and diagnostics.
--- @return BaseECSReplicationService -- The new service instance.
function BaseECSReplicationService.new(contextName: string)
	local self = setmetatable({}, BaseECSReplicationService)
	self._contextName = contextName
	self._world = nil
	self._components = nil
	self._entityFactory = nil
	self._replecsLibrary = nil
	self._replecsServer = nil
	self._initialized = false
	self._connections = {}
	self._replicatedEntities = {}
	self._appliedSharedSchema = nil
	self._schemaState = _CreateSchemaState()
	self._lastHandshakeVerificationError = nil
	return self
end

--- Resolves the ECS runtime, Replecs server, and shared schema for this context.
--- @within BaseECSReplicationService
--- @param registry any -- The context registry.
--- @param name string -- The registered context name.
function BaseECSReplicationService:Init(registry: TRegistry, name: string)
	assert(not self._initialized, ("%sECSReplicationService: Init called twice"):format(self._contextName))

	-- Resolve the context-owned ECS dependencies.
	self._world = self:_ResolveWorld(registry)
	assert(self._world ~= nil, ("%sECSReplicationService: missing World"):format(self._contextName))

	local componentRegistryName = self:_GetComponentRegistryName()
	assert(
		type(componentRegistryName) == "string" and componentRegistryName ~= "",
		("%sECSReplicationService: missing component registry name"):format(self._contextName)
	)
	local componentRegistry = registry:Get(componentRegistryName)
	assert(
		componentRegistry ~= nil and type(componentRegistry.GetComponents) == "function",
		("%sECSReplicationService: missing %s"):format(self._contextName, componentRegistryName)
	)
	self._components = componentRegistry:GetComponents()
	assert(self._components ~= nil, ("%sECSReplicationService: %s returned nil components"):format(self._contextName, componentRegistryName))

	local entityFactoryName = self:_GetEntityFactoryName()
	assert(
		type(entityFactoryName) == "string" and entityFactoryName ~= "",
		("%sECSReplicationService: missing entity factory name"):format(self._contextName)
	)
	self._entityFactory = registry:Get(entityFactoryName)
	assert(self._entityFactory ~= nil, ("%sECSReplicationService: missing %s"):format(self._contextName, entityFactoryName))

	-- Create the transport-agnostic Replecs server for this context world.
	self._replecsLibrary = self:_CreateReplecsLibrary()
	assert(self._replecsLibrary ~= nil, ("%sECSReplicationService: missing Replecs library"):format(self._contextName))

	self._replecsServer = self._replecsLibrary.create_server(self._world)
	assert(self._replecsServer ~= nil, ("%sECSReplicationService: failed to create Replecs server"):format(self._contextName))
	assert(type(self._replecsServer.init) == "function", ("%sECSReplicationService: Replecs server missing init"):format(self._contextName))

	self._replecsServer:init(self._world)
	self._initialized = true

	self:_OnInit(registry, name)
	self:_RegisterReplicatedSurface(registry)

	local sharedSchema = self:_GetSharedSchema()
	if sharedSchema ~= nil then
		self:ApplySharedSchema(sharedSchema)
	end
end

--- Asserts that the service has been initialized and its core dependencies exist.
--- @within BaseECSReplicationService
function BaseECSReplicationService:RequireReady()
	assert(self._initialized, ("%sECSReplicationService: used before Init"):format(self._contextName))
	assert(self._world ~= nil, ("%sECSReplicationService: missing world"):format(self._contextName))
	assert(self._components ~= nil, ("%sECSReplicationService: missing components"):format(self._contextName))
	assert(self._entityFactory ~= nil, ("%sECSReplicationService: missing entity factory"):format(self._contextName))
	assert(self._replecsLibrary ~= nil, ("%sECSReplicationService: missing Replecs library"):format(self._contextName))
	assert(self._replecsServer ~= nil, ("%sECSReplicationService: missing Replecs server"):format(self._contextName))
end

--- Returns the active ECS world after initialization.
--- @within BaseECSReplicationService
function BaseECSReplicationService:GetWorldOrThrow()
	self:RequireReady()
	return self._world
end

--- Returns the registered component table after initialization.
--- @within BaseECSReplicationService
function BaseECSReplicationService:GetComponentsOrThrow()
	self:RequireReady()
	return self._components
end

--- Returns the entity factory used by the context.
--- @within BaseECSReplicationService
function BaseECSReplicationService:GetEntityFactoryOrThrow()
	self:RequireReady()
	return self._entityFactory
end

function BaseECSReplicationService:GetReplecsLibraryOrThrow()
	self:RequireReady()
	return self._replecsLibrary
end

function BaseECSReplicationService:GetReplecsServerOrThrow()
	self:RequireReady()
	return self._replecsServer
end

function BaseECSReplicationService:GetReplecsComponentsOrThrow()
	self:RequireReady()
	return self._replecsServer.components
end

function BaseECSReplicationService:RegisterSharedComponent(componentId: any)
	self:RequireReady()
	_AddSharedId(self._world, self:GetReplecsComponentsOrThrow().shared, componentId)
	self._schemaState.SharedComponents[componentId] = true
end

function BaseECSReplicationService:RegisterSharedTag(tagId: any)
	self:RequireReady()
	_AddSharedId(self._world, self:GetReplecsComponentsOrThrow().shared, tagId)
	self._schemaState.SharedTags[tagId] = true
end

function BaseECSReplicationService:RemoveSharedComponent(componentId: any)
	self:RequireReady()
	_RemoveSharedId(self._world, self:GetReplecsComponentsOrThrow().shared, componentId)
	self._schemaState.SharedComponents[componentId] = nil
end

function BaseECSReplicationService:RemoveSharedTag(tagId: any)
	self:RequireReady()
	_RemoveSharedId(self._world, self:GetReplecsComponentsOrThrow().shared, tagId)
	self._schemaState.SharedTags[tagId] = nil
end

function BaseECSReplicationService:RegisterCustomId(customId: any)
	self:RequireReady()
	self._replecsServer:register_custom_id(customId)
	self._schemaState.CustomIds[customId] = true
end

function BaseECSReplicationService:CreateCustomId(identifier: string, handler: ((any) -> any)?)
	self:RequireReady()
	return self._replecsLibrary.create_custom_id(identifier, handler)
end

function BaseECSReplicationService:SetCustomIdHandler(customId: any, handler: (any) -> any)
	self:RequireReady()
	assert(type(customId) == "table" and type(customId.handle) == "function", "invalid Replecs custom id")
	customId:handle(handler)
end

function BaseECSReplicationService:RegisterSerdes(componentId: any, serdes: any)
	self:RequireReady()
	self._replecsServer:set_serdes(componentId, serdes)
	self._schemaState.Serdes[componentId] = serdes
end

function BaseECSReplicationService:RemoveSerdes(componentId: any)
	self:RequireReady()
	self._replecsServer:remove_serdes(componentId)
	self._schemaState.Serdes[componentId] = nil
end

function BaseECSReplicationService:RegisterNetworkedEntity(entity: number, filter: any?)
	self:RequireReady()
	self._replecsServer:set_networked(entity, filter)
	self._replicatedEntities[entity] = true
end

function BaseECSReplicationService:RegisterReliableComponent(entity: number, componentId: any, filter: any?)
	self:RequireReady()
	self._replecsServer:set_reliable(entity, componentId, filter)
end

function BaseECSReplicationService:RegisterUnreliableComponent(entity: number, componentId: any, filter: any?)
	self:RequireReady()
	self._replecsServer:set_unreliable(entity, componentId, filter)
end

function BaseECSReplicationService:RegisterPair(entity: number, pairId: any, filter: any?)
	self:RequireReady()
	self._replecsServer:set_pair(entity, pairId, filter)
end

function BaseECSReplicationService:RegisterRelation(entity: number, relationId: any, filter: any?)
	self:RequireReady()
	self._replecsServer:set_relation(entity, relationId, filter)
end

function BaseECSReplicationService:SetGlobalId(entity: number, id: number)
	self:RequireReady()
	self._world:set(entity, self:GetReplecsComponentsOrThrow().global, id)
end

function BaseECSReplicationService:RemoveGlobalId(entity: number)
	self:RequireReady()
	self._world:remove(entity, self:GetReplecsComponentsOrThrow().global)
end

function BaseECSReplicationService:SetComponentCustomHandler(componentId: any, handler: (any) -> any)
	self:RequireReady()
	self._world:set(componentId, self:GetReplecsComponentsOrThrow().custom_handler, handler)
	self._schemaState.ComponentCustomHandlers[componentId] = handler
end

function BaseECSReplicationService:RemoveComponentCustomHandler(componentId: any)
	self:RequireReady()
	self._world:remove(componentId, self:GetReplecsComponentsOrThrow().custom_handler)
	self._schemaState.ComponentCustomHandlers[componentId] = nil
end

function BaseECSReplicationService:SetCustomHandler(entity: number, handlerOrCustomId: any)
	self:RequireReady()
	self._replecsServer:set_custom(entity, handlerOrCustomId)
end

function BaseECSReplicationService:RemoveCustomHandler(entity: number)
	self:RequireReady()
	self._replecsServer:remove_custom(entity)
end

function BaseECSReplicationService:StopReplicatingEntity(entity: number, keepState: boolean?)
	self:RequireReady()
	self._replecsServer:stop_networked(entity, keepState)
	self._replicatedEntities[entity] = nil
end

function BaseECSReplicationService:StopReliableComponent(entity: number, componentId: any, keepState: boolean?)
	self:RequireReady()
	self._replecsServer:stop_reliable(entity, componentId, keepState)
end

function BaseECSReplicationService:StopUnreliableComponent(entity: number, componentId: any, keepState: boolean?)
	self:RequireReady()
	self._replecsServer:stop_unreliable(entity, componentId, keepState)
end

function BaseECSReplicationService:StopPair(entity: number, pairId: any, keepState: boolean?)
	self:RequireReady()
	self._replecsServer:stop_pair(entity, pairId, keepState)
end

function BaseECSReplicationService:StopRelation(entity: number, relationId: any, keepState: boolean?)
	self:RequireReady()
	self._replecsServer:stop_relation(entity, relationId, keepState)
end

--- Applies a shared schema to the server world and tracks the applied snapshot.
--- @within BaseECSReplicationService
function BaseECSReplicationService:ApplySharedSchema(schema: TSharedSchema)
	self:RequireReady()
	self:ValidateSharedSchema(schema)

	if schema.sharedComponents ~= nil then
		-- Register shared components first so the world matches the negotiated schema.
		for _, componentId in ipairs(schema.sharedComponents) do
			self:RegisterSharedComponent(componentId)
		end
	end

	if schema.sharedTags ~= nil then
		-- Register shared tags alongside shared components for the same handshake surface.
		for _, tagId in ipairs(schema.sharedTags) do
			self:RegisterSharedTag(tagId)
		end
	end

	if schema.customIds ~= nil then
		-- Track custom ids before any packets rely on them.
		for _, customId in ipairs(schema.customIds) do
			self:RegisterCustomId(customId)
		end
	end

	if schema.serdes ~= nil then
		-- Install component-specific serializers after the ids have been registered.
		for componentId, serdes in schema.serdes do
			self:RegisterSerdes(componentId, serdes)
		end
	end

	if schema.componentCustomHandlers ~= nil then
		-- Apply custom handler components last so the world has every dependency in place.
		for componentId, handler in schema.componentCustomHandlers do
			self:SetComponentCustomHandler(componentId, handler)
		end
	end

	self._appliedSharedSchema = self:_SnapshotSharedSchema(schema)
	self:_OnSharedSchemaApplied(schema)
end

--- Validates a shared schema before it is applied to the world.
--- @within BaseECSReplicationService
function BaseECSReplicationService:ValidateSharedSchema(schema: TSharedSchema)
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

function BaseECSReplicationService:ForgetTrackedCustomId(customId: any)
	self:RequireReady()
	self._schemaState.CustomIds[customId] = nil
end

function BaseECSReplicationService:RemoveRegisteredCustomId(customId: any)
	self:ForgetTrackedCustomId(customId)
end

function BaseECSReplicationService:GetAppliedSharedSchema(): TSharedSchema?
	self:RequireReady()
	return self._appliedSharedSchema
end

function BaseECSReplicationService:HasAppliedSharedSchema(): boolean
	self:RequireReady()
	return self._appliedSharedSchema ~= nil
end

--- Returns a sorted, frozen summary of the tracked shared schema state.
--- @within BaseECSReplicationService
function BaseECSReplicationService:GetSchemaSummary()
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

--- Returns the last handshake verification error, if one was recorded.
--- @within BaseECSReplicationService
function BaseECSReplicationService:GetLastHandshakeVerificationError(): string?
	self:RequireReady()
	return self._lastHandshakeVerificationError
end

--- Describes the differences between the tracked shared schema and a handshake payload.
--- @within BaseECSReplicationService
function BaseECSReplicationService:DescribeSharedSchemaMismatch(handshake: any)
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
	-- Compare the negotiated serdes shape against the tracked world configuration.
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

function BaseECSReplicationService:GenerateHandshake()
	self:RequireReady()
	return self._replecsServer:generate_handshake()
end

function BaseECSReplicationService:VerifyHandshake(handshake: any): (boolean, string?)
	self:RequireReady()
	local verified, message = self._replecsServer:verify_handshake(handshake)
	if verified then
		self._lastHandshakeVerificationError = nil
	else
		self._lastHandshakeVerificationError = message
	end
	return verified, message
end

function BaseECSReplicationService:EncodeComponent(componentId: any): number
	self:RequireReady()
	return self._replecsServer:encode_component(componentId)
end

function BaseECSReplicationService:DecodeComponent(encodedId: number): any
	self:RequireReady()
	return self._replecsServer:decode_component(encodedId)
end

function BaseECSReplicationService:GetSharedCount(): number
	self:RequireReady()
	return self._replecsServer:get_shared_count()
end

function BaseECSReplicationService:MarkPlayerReady(player: Player)
	self:RequireReady()
	self._replecsServer:mark_player_ready(player)
end

function BaseECSReplicationService:IsPlayerReady(player: Player): boolean
	self:RequireReady()
	return self._replecsServer:is_player_ready(player)
end

function BaseECSReplicationService:AddPlayerAlias(player: Player, alias: any)
	self:RequireReady()
	self._replecsServer:add_player_alias(player, alias)
end

function BaseECSReplicationService:RemovePlayerAlias(alias: any)
	self:RequireReady()
	self._replecsServer:remove_player_alias(alias)
end

--- Builds the bootstrap payload for a valid player.
--- @within BaseECSReplicationService
function BaseECSReplicationService:BuildBootstrapPayload(player: Player): TBootstrapPayload?
	if not self._initialized then
		return nil
	end
	if not self:_IsPlayerValid(player) then
		return nil
	end

	local server = self:GetReplecsServerOrThrow()
	local packetBuffer, packetVariants = server:get_full(player)

	return {
		Handshake = server:generate_handshake(),
		Buffer = packetBuffer,
		Variants = packetVariants,
	}
end

--- Sends the bootstrap payload to a player when the player is valid.
--- @within BaseECSReplicationService
function BaseECSReplicationService:SendBootstrapPayload(player: Player): boolean
	local payload = self:BuildBootstrapPayload(player)
	if payload == nil then
		return false
	end

	self:_SendBootstrap(player, payload)
	return true
end

function BaseECSReplicationService:CompleteBootstrap(player: Player): boolean
	if not self._initialized then
		return false
	end
	if not self:_IsPlayerValid(player) then
		return false
	end

	self:GetReplecsServerOrThrow():mark_player_ready(player)
	return true
end

--- Hydrates a single player by sending its bootstrap payload.
--- @within BaseECSReplicationService
function BaseECSReplicationService:HydratePlayer(player: Player): boolean
	return self:SendBootstrapPayload(player)
end

--- Hydrates every valid player currently in the server.
--- @within BaseECSReplicationService
function BaseECSReplicationService:HydrateAllPlayers()
	if not self._initialized then
		return
	end

	for _, player in ipairs(self:_GetPlayers()) do
		self:HydratePlayer(player)
	end
end

--- Collects and sends entity-scoped packets for a single entity.
--- @within BaseECSReplicationService
function BaseECSReplicationService:CollectEntityPackets(entity: number): number
	if not self._initialized then
		return 0
	end

	local packetCount = 0
	-- Forward each generated packet to the concrete transport hook.
	for player, packetBuffer, packetVariants in self:GetReplecsServerOrThrow():collect_entity(entity) do
		self:_SendEntity(player, {
			Buffer = packetBuffer,
			Variants = packetVariants,
		})
		packetCount += 1
	end

	return packetCount
end

--- Flushes the reliable packet queue through the concrete transport hook.
--- @within BaseECSReplicationService
function BaseECSReplicationService:FlushReliable()
	if not self._initialized then
		return
	end

	-- Emit the buffered reliable packets without mutating the server world.
	for player, packetBuffer, packetVariants in self:GetReplecsServerOrThrow():collect_updates() do
		self:_SendReliable(player, {
			Buffer = packetBuffer,
			Variants = packetVariants,
		})
	end
end

--- Flushes the unreliable packet queue through the concrete transport hook.
--- @within BaseECSReplicationService
function BaseECSReplicationService:FlushUnreliable()
	if not self._initialized then
		return
	end

	-- Emit the buffered unreliable packets without mutating the server world.
	for player, packetBuffer, packetVariants in self:GetReplecsServerOrThrow():collect_unreliable() do
		self:_SendUnreliable(player, {
			Buffer = packetBuffer,
			Variants = packetVariants,
		})
	end
end

--- Tears down the replication server and clears all cached state.
--- @within BaseECSReplicationService
function BaseECSReplicationService:Destroy()
	if not self._initialized and self._replecsServer == nil then
		return
	end

	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end
	table.clear(self._connections)

	self:_OnDestroy()

	if self._replecsServer ~= nil and self._replecsServer.inited ~= nil then
		self._replecsServer:destroy()
	end

	self._world = nil
	self._components = nil
	self._entityFactory = nil
	self._replecsLibrary = nil
	self._replecsServer = nil
	self._initialized = false
	table.clear(self._replicatedEntities)
	self._appliedSharedSchema = nil
	self._schemaState = _CreateSchemaState()
	self._lastHandshakeVerificationError = nil
end

function BaseECSReplicationService:_GetComponentRegistryName(): string
	error(("%sECSReplicationService must implement _GetComponentRegistryName"):format(self._contextName))
end

function BaseECSReplicationService:_GetEntityFactoryName(): string
	error(("%sECSReplicationService must implement _GetEntityFactoryName"):format(self._contextName))
end

function BaseECSReplicationService:_ResolveWorld(registry: TRegistry)
	return registry:Get("World")
end

function BaseECSReplicationService:_CreateReplecsLibrary()
	return require(ReplicatedStorage.Utilities.Replecs)
end

function BaseECSReplicationService:_OnInit(_registry: TRegistry, _name: string)
	return
end

function BaseECSReplicationService:_SnapshotSharedSchema(schema: TSharedSchema): TSharedSchema
	local snapshot = {
		sharedComponents = _CopyArray(schema.sharedComponents),
		sharedTags = _CopyArray(schema.sharedTags),
		customIds = _CopyArray(schema.customIds),
		serdes = if schema.serdes ~= nil then table.clone(schema.serdes) else nil,
		componentCustomHandlers = if schema.componentCustomHandlers ~= nil then table.clone(schema.componentCustomHandlers) else nil,
	}
	return table.freeze(snapshot)
end

function BaseECSReplicationService:_GetSharedSchema(): TSharedSchema?
	return nil
end

function BaseECSReplicationService:_ValidateSharedSchema(_schema: TSharedSchema)
	return
end

function BaseECSReplicationService:_OnSharedSchemaApplied(_schema: TSharedSchema)
	return
end

function BaseECSReplicationService:_RegisterReplicatedSurface(_registry: TRegistry)
	return
end

function BaseECSReplicationService:_SendHandshake(_player: Player, _payload: THandshakePayload)
	return
end

function BaseECSReplicationService:_SendFull(_player: Player, _payload: TReplicationPacketPayload)
	return
end

function BaseECSReplicationService:_SendBootstrap(_player: Player, _payload: TBootstrapPayload)
	error(("%sECSReplicationService must implement _SendBootstrap"):format(self._contextName))
end

function BaseECSReplicationService:_SendReliable(_player: Player, _payload: TReplicationPacketPayload)
	return
end

function BaseECSReplicationService:_SendUnreliable(_player: Player, _payload: TReplicationPacketPayload)
	return
end

function BaseECSReplicationService:_SendEntity(_player: Player, _payload: TReplicationPacketPayload)
	return
end

function BaseECSReplicationService:_GetPlayers(): { Player }
	return Players:GetPlayers()
end

function BaseECSReplicationService:_IsPlayerValid(player: Player): boolean
	return typeof(player) == "Instance"
		and player:IsA("Player")
		and player.Parent == Players
end

function BaseECSReplicationService:_TrackConnection(connection: RBXScriptConnection?)
	if connection == nil then
		return
	end

	table.insert(self._connections, connection)
end

function BaseECSReplicationService:_OnDestroy()
	return
end

return BaseECSReplicationService
