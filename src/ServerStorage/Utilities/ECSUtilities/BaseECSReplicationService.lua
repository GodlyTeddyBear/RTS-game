--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Replecs = require(ReplicatedStorage.Packages.Replecs)

type TRegistry = {
	Get: (self: any, name: string) -> any,
}

type TPayload = {
	Buffer: buffer,
	Variants: { { any } }?,
}

local function _AddSharedId(world: any, sharedComponent: any, id: any)
	if not world:has(id, sharedComponent) then
		world:add(id, sharedComponent)
	end
end

local BaseECSReplicationService = {}
BaseECSReplicationService.__index = BaseECSReplicationService

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
	return self
end

function BaseECSReplicationService:Init(registry: TRegistry, name: string)
	assert(not self._initialized, ("%sECSReplicationService: Init called twice"):format(self._contextName))

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

	self._replecsLibrary = self:_CreateReplecsLibrary()
	self._replecsServer = self:_CreateReplecsServer(self._world)
	assert(self._replecsServer ~= nil, ("%sECSReplicationService: failed to create Replecs server"):format(self._contextName))
	assert(type(self._replecsServer.init) == "function", ("%sECSReplicationService: Replecs server missing init"):format(self._contextName))

	self._replecsServer:init(self._world)

	self:_OnInit(registry, name)
	self:_RegisterReplicatedSurface(registry)

	self._initialized = true
end

function BaseECSReplicationService:RequireReady()
	assert(self._initialized, ("%sECSReplicationService: used before Init"):format(self._contextName))
	assert(self._world ~= nil, ("%sECSReplicationService: missing World"):format(self._contextName))
	assert(self._components ~= nil, ("%sECSReplicationService: missing components"):format(self._contextName))
	assert(self._entityFactory ~= nil, ("%sECSReplicationService: missing entity factory"):format(self._contextName))
	assert(self._replecsServer ~= nil, ("%sECSReplicationService: missing Replecs server"):format(self._contextName))
end

function BaseECSReplicationService:GetWorldOrThrow()
	self:RequireReady()
	return self._world
end

function BaseECSReplicationService:GetComponentsOrThrow()
	self:RequireReady()
	return self._components
end

function BaseECSReplicationService:GetEntityFactoryOrThrow()
	self:RequireReady()
	return self._entityFactory
end

function BaseECSReplicationService:GetReplecsServerOrThrow()
	self:RequireReady()
	return self._replecsServer
end

function BaseECSReplicationService:RegisterSharedComponent(componentId: any)
	self:RequireReady()
	_AddSharedId(self._world, self._replecsServer.components.shared, componentId)
end

function BaseECSReplicationService:RegisterSharedTag(tagId: any)
	self:RequireReady()
	_AddSharedId(self._world, self._replecsServer.components.shared, tagId)
end

function BaseECSReplicationService:RegisterSerdes(componentId: any, serdes: any)
	self:RequireReady()
	self._replecsServer:set_serdes(componentId, serdes)
end

function BaseECSReplicationService:RegisterCustomId(customId: any)
	self:RequireReady()
	self._replecsServer:register_custom_id(customId)
end

function BaseECSReplicationService:RegisterNetworkedEntity(entity: number, memberFilter: any?)
	self:RequireReady()
	self._replecsServer:set_networked(entity, memberFilter)
	self._replicatedEntities[entity] = true
end

function BaseECSReplicationService:RegisterReliableComponent(entity: number, componentId: any, memberFilter: any?)
	self:RequireReady()
	self._replecsServer:set_reliable(entity, componentId, memberFilter)
end

function BaseECSReplicationService:RegisterUnreliableComponent(entity: number, componentId: any, memberFilter: any?)
	self:RequireReady()
	self._replecsServer:set_unreliable(entity, componentId, memberFilter)
end

function BaseECSReplicationService:RegisterRelation(entity: number, relationId: any, memberFilter: any?)
	self:RequireReady()
	self._replecsServer:set_relation(entity, relationId, memberFilter)
end

function BaseECSReplicationService:StopReplicatingEntity(entity: number, keepState: boolean?)
	self:RequireReady()
	self._replecsServer:stop_networked(entity, keepState)
	self._replicatedEntities[entity] = nil
end

function BaseECSReplicationService:HydratePlayer(player: Player)
	if not self._initialized then
		return
	end
	if not self:_IsPlayerValid(player) then
		return
	end

	local server = self:GetReplecsServerOrThrow()

	-- Send handshake metadata before the first full snapshot.
	self:_SendHandshake(player, {
		Handshake = server:generate_handshake(),
	})

	-- Send the full snapshot for this client session.
	local fullBuffer, fullVariants = server:get_full(player)
	self:_SendFull(player, {
		Buffer = fullBuffer,
		Variants = fullVariants,
	})

	server:mark_player_ready(player)
end

function BaseECSReplicationService:HydrateAllPlayers()
	if not self._initialized then
		return
	end

	for _, player in ipairs(self:_GetPlayers()) do
		self:HydratePlayer(player)
	end
end

function BaseECSReplicationService:FlushReliable()
	if not self._initialized then
		return
	end

	for player, packetBuffer, packetVariants in self:GetReplecsServerOrThrow():collect_updates() do
		self:_SendReliable(player, {
			Buffer = packetBuffer,
			Variants = packetVariants,
		})
	end
end

function BaseECSReplicationService:FlushUnreliable()
	if not self._initialized then
		return
	end

	for player, packetBuffer, packetVariants in self:GetReplecsServerOrThrow():collect_unreliable() do
		self:_SendUnreliable(player, {
			Buffer = packetBuffer,
			Variants = packetVariants,
		})
	end
end

function BaseECSReplicationService:Destroy()
	if not self._initialized and self._replecsServer == nil then
		return
	end

	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end
	table.clear(self._connections)

	self:_OnDestroy()

	local replecsServer = self._replecsServer
	if replecsServer ~= nil and replecsServer.inited ~= nil then
		replecsServer:destroy()
	end

	self._world = nil
	self._components = nil
	self._entityFactory = nil
	self._replecsLibrary = nil
	self._replecsServer = nil
	self._initialized = false
	table.clear(self._replicatedEntities)
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
	return Replecs
end

function BaseECSReplicationService:_CreateReplecsServer(world: any)
	return self:_CreateReplecsLibrary().create_server(world)
end

function BaseECSReplicationService:_OnInit(_registry: TRegistry, _name: string)
	return
end

function BaseECSReplicationService:_RegisterReplicatedSurface(_registry: TRegistry)
	return
end

function BaseECSReplicationService:_SendHandshake(_player: Player, _handshakePayload: { Handshake: any })
	return
end

function BaseECSReplicationService:_SendFull(_player: Player, _fullPayload: TPayload)
	return
end

function BaseECSReplicationService:_SendReliable(_player: Player, _reliablePayload: TPayload)
	return
end

function BaseECSReplicationService:_SendUnreliable(_player: Player, _unreliablePayload: TPayload)
	return
end

function BaseECSReplicationService:_OnDestroy()
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

return BaseECSReplicationService
