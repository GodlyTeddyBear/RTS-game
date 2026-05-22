--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local JECS = require(ReplicatedStorage.Packages.JECS)
local BaseECSReplicationService = require(ServerStorage.Utilities.ECSUtilities.BaseECSReplicationService)

local function createStubServer(world: any)
	local sharedComponent = world:entity()
	local globalComponent = world:component()
	local customHandlerComponent = world:component()
	local stubServer = {
		components = {
			shared = sharedComponent,
			global = globalComponent,
			custom_handler = customHandlerComponent,
		},
		inited = false,
		InitCalls = 0,
		DestroyCalls = 0,
		Handshake = {
			components = {
				Health = true,
			},
			custom_ids = {},
			serdes = {},
		},
		SharedCount = 3,
		MarkedPlayers = {},
		PlayerAliases = {},
		SetNetworkedCalls = {},
		SetReliableCalls = {},
		SetUnreliableCalls = {},
		SetPairCalls = {},
		SetRelationCalls = {},
		SetCustomCalls = {},
		RegisterCustomIdCalls = {},
		SetSerdesCalls = {},
		RemoveSerdesCalls = {},
		StopNetworkedCalls = {},
		StopReliableCalls = {},
		StopUnreliableCalls = {},
		StopPairCalls = {},
		StopRelationCalls = {},
		CollectEntityPackets = {},
		CollectUpdatesPackets = {},
		CollectUnreliablePackets = {},
		FullBuffer = buffer.create(4),
		FullVariants = {
			{ "full" },
		},
	}

	function stubServer:init(_world: any)
		self.inited = true
		self.InitCalls += 1
	end

	function stubServer:destroy()
		self.inited = nil
		self.DestroyCalls += 1
	end

	function stubServer:set_networked(entity: number, filter: any?)
		table.insert(self.SetNetworkedCalls, {
			Entity = entity,
			Filter = filter,
		})
	end

	function stubServer:set_reliable(entity: number, componentId: any, filter: any?)
		table.insert(self.SetReliableCalls, {
			Entity = entity,
			ComponentId = componentId,
			Filter = filter,
		})
	end

	function stubServer:set_unreliable(entity: number, componentId: any, filter: any?)
		table.insert(self.SetUnreliableCalls, {
			Entity = entity,
			ComponentId = componentId,
			Filter = filter,
		})
	end

	function stubServer:set_pair(entity: number, pairId: any, filter: any?)
		table.insert(self.SetPairCalls, {
			Entity = entity,
			PairId = pairId,
			Filter = filter,
		})
	end

	function stubServer:set_relation(entity: number, relationId: any, filter: any?)
		table.insert(self.SetRelationCalls, {
			Entity = entity,
			RelationId = relationId,
			Filter = filter,
		})
	end

	function stubServer:set_custom(entity: number, handler: any)
		table.insert(self.SetCustomCalls, {
			Entity = entity,
			Handler = handler,
		})
	end

	function stubServer:remove_custom(entity: number)
		table.insert(self.SetCustomCalls, {
			Entity = entity,
			Removed = true,
		})
	end

	function stubServer:register_custom_id(customId: any)
		table.insert(self.RegisterCustomIdCalls, customId)
	end

	function stubServer:set_serdes(componentId: any, serdes: any)
		table.insert(self.SetSerdesCalls, {
			ComponentId = componentId,
			Serdes = serdes,
		})
	end

	function stubServer:remove_serdes(componentId: any)
		table.insert(self.RemoveSerdesCalls, componentId)
	end

	function stubServer:stop_networked(entity: number, keepState: boolean?)
		table.insert(self.StopNetworkedCalls, {
			Entity = entity,
			KeepState = keepState,
		})
	end

	function stubServer:stop_reliable(entity: number, componentId: any, keepState: boolean?)
		table.insert(self.StopReliableCalls, {
			Entity = entity,
			ComponentId = componentId,
			KeepState = keepState,
		})
	end

	function stubServer:stop_unreliable(entity: number, componentId: any, keepState: boolean?)
		table.insert(self.StopUnreliableCalls, {
			Entity = entity,
			ComponentId = componentId,
			KeepState = keepState,
		})
	end

	function stubServer:stop_pair(entity: number, pairId: any, keepState: boolean?)
		table.insert(self.StopPairCalls, {
			Entity = entity,
			PairId = pairId,
			KeepState = keepState,
		})
	end

	function stubServer:stop_relation(entity: number, relationId: any, keepState: boolean?)
		table.insert(self.StopRelationCalls, {
			Entity = entity,
			RelationId = relationId,
			KeepState = keepState,
		})
	end

	function stubServer:generate_handshake()
		return self.Handshake
	end

	function stubServer:verify_handshake(handshake: any)
		return handshake == self.Handshake, "mismatch"
	end

	function stubServer:encode_component(componentId: any): number
		return tonumber(componentId) or 99
	end

	function stubServer:decode_component(encodedId: number): any
		return encodedId + 1000
	end

	function stubServer:get_shared_count(): number
		return self.SharedCount
	end

	function stubServer:get_full(_player: any)
		return self.FullBuffer, self.FullVariants
	end

	function stubServer:collect_entity(_entity: number)
		local index = 0
		local packets = self.CollectEntityPackets
		return function()
			index += 1
			local packet = packets[index]
			if packet == nil then
				return nil
			end
			return packet.Player, packet.Buffer, packet.Variants
		end
	end

	function stubServer:collect_updates()
		local index = 0
		local packets = self.CollectUpdatesPackets
		return function()
			while true do
				index += 1
				local packet = packets[index]
				if packet == nil then
					return nil
				end
				if self:is_player_ready(packet.Player) then
					return packet.Player, packet.Buffer, packet.Variants
				end
			end
		end
	end

	function stubServer:collect_unreliable()
		local index = 0
		local packets = self.CollectUnreliablePackets
		return function()
			while true do
				index += 1
				local packet = packets[index]
				if packet == nil then
					return nil
				end
				if self:is_player_ready(packet.Player) then
					return packet.Player, packet.Buffer, packet.Variants
				end
			end
		end
	end

	function stubServer:mark_player_ready(player: any)
		table.insert(self.MarkedPlayers, player)
	end

	function stubServer:is_player_ready(player: any): boolean
		return table.find(self.MarkedPlayers, player) ~= nil
	end

	function stubServer:add_player_alias(player: any, alias: any)
		self.PlayerAliases[alias] = player
	end

	function stubServer:remove_player_alias(alias: any)
		self.PlayerAliases[alias] = nil
	end

	return stubServer
end

local TestReplicationService = {}
TestReplicationService.__index = TestReplicationService
setmetatable(TestReplicationService, BaseECSReplicationService)

function TestReplicationService.new(world: any)
	local self = BaseECSReplicationService.new("Test")
	self._testWorld = world
	self.SentHandshake = {}
	self.SentFull = {}
	self.SentBootstrap = {}
	self.SentReliable = {}
	self.SentUnreliable = {}
	self.SentEntity = {}
	self.IsPlayerValid = true
	self.TestPlayers = {}
	return setmetatable(self, TestReplicationService)
end

function TestReplicationService:_GetComponentRegistryName(): string
	return "ComponentRegistry"
end

function TestReplicationService:_GetEntityFactoryName(): string
	return "EntityFactory"
end

function TestReplicationService:_ResolveWorld(_registry: any)
	return self._testWorld
end

function TestReplicationService:_CreateReplecsLibrary()
	return {
		create_server = function(_world: any)
			return createStubServer(self._testWorld)
		end,
		create_custom_id = function(identifier: string, handler: any)
			local customId = {
				identifier = identifier,
				handle_callback = handler,
			}
			function customId:handle(nextHandler: any)
				self.handle_callback = nextHandler
			end
			return customId
		end,
	}
end

function TestReplicationService:_SendHandshake(player: any, payload: any)
	table.insert(self.SentHandshake, {
		Player = player,
		Payload = payload,
	})
end

function TestReplicationService:_SendFull(player: any, payload: any)
	table.insert(self.SentFull, {
		Player = player,
		Payload = payload,
	})
end

function TestReplicationService:_SendBootstrap(player: any, payload: any)
	table.insert(self.SentBootstrap, {
		Player = player,
		Payload = payload,
	})
end

function TestReplicationService:_SendReliable(player: any, payload: any)
	table.insert(self.SentReliable, {
		Player = player,
		Payload = payload,
	})
end

function TestReplicationService:_SendUnreliable(player: any, payload: any)
	table.insert(self.SentUnreliable, {
		Player = player,
		Payload = payload,
	})
end

function TestReplicationService:_SendEntity(player: any, payload: any)
	table.insert(self.SentEntity, {
		Player = player,
		Payload = payload,
	})
end

function TestReplicationService:_GetPlayers()
	return self.TestPlayers
end

function TestReplicationService:_IsPlayerValid(_player: Player): boolean
	return self.IsPlayerValid
end

local SharedSchemaReplicationService = {}
SharedSchemaReplicationService.__index = SharedSchemaReplicationService
setmetatable(SharedSchemaReplicationService, TestReplicationService)

function SharedSchemaReplicationService.new(world: any, schema: any)
	local self = TestReplicationService.new(world)
	self._sharedSchema = schema
	return setmetatable(self, SharedSchemaReplicationService)
end

function SharedSchemaReplicationService:_GetSharedSchema()
	return self._sharedSchema
end

local function createRegistry(world: any, components: any)
	local componentRegistry = {
		GetComponents = function()
			return components
		end,
	}

	local entityFactory = {}
	local registry = {}

	function registry:Get(name: string)
		if name == "World" then
			return world
		end
		if name == "ComponentRegistry" then
			return componentRegistry
		end
		if name == "EntityFactory" then
			return entityFactory
		end

		error(("unexpected registry lookup: %s"):format(name))
	end

	return registry
end

local function nameEntity(world: any, entity: any, name: string)
	world:set(entity, JECS.Name, name)
	return entity
end

describe("BaseECSReplicationService", function()
	it("initializes and registers shared ids without duplicate failures", function()
		local world = JECS.World.new()
		local healthComponent = nameEntity(world, world:component(), "Health")
		local aliveTag = nameEntity(world, world:entity(), "Alive")
		local registry = createRegistry(world, {
			HealthComponent = healthComponent,
			AliveTag = aliveTag,
		})
		local service = TestReplicationService.new(world)

		service:Init(registry, "TestService")
		service:RegisterSharedComponent(healthComponent)
		service:RegisterSharedComponent(healthComponent)
		service:RegisterSharedTag(aliveTag)
		service:RegisterSharedTag(aliveTag)

		expect(world:has(healthComponent, service:GetReplecsServerOrThrow().components.shared)).toBe(true)
		expect(world:has(aliveTag, service:GetReplecsServerOrThrow().components.shared)).toBe(true)
	end)

	it("builds and sends bootstrap payloads without marking players ready", function()
		local world = JECS.World.new()
		local registry = createRegistry(world, {})
		local service = TestReplicationService.new(world)
		local fakePlayer = {
			Name = "PlayerOne",
		}

		service:Init(registry, "TestService")
		local payload = service:BuildBootstrapPayload(fakePlayer :: any)
		local sent = service:HydratePlayer(fakePlayer :: any)

		expect(payload).never.toBeNil()
		expect(payload.Handshake).toBe(service:GetReplecsServerOrThrow().Handshake)
		expect(#service.SentBootstrap).toBe(1)
		expect(sent).toBe(true)
		expect(service.SentBootstrap[1].Player).toBe(fakePlayer)
		expect(service.SentBootstrap[1].Payload.Handshake).toBe(payload.Handshake)
		expect(service:GetReplecsServerOrThrow().MarkedPlayers[1]).toBeNil()

		local completed = service:CompleteBootstrap(fakePlayer :: any)
		expect(completed).toBe(true)
		expect(service:GetReplecsServerOrThrow().MarkedPlayers[1]).toBe(fakePlayer)
	end)

	it("flushes reliable, unreliable, and single-entity packets", function()
		local world = JECS.World.new()
		local registry = createRegistry(world, {})
		local service = TestReplicationService.new(world)
		local player = {
			Name = "PlayerOne",
		}
		local server = nil

		service:Init(registry, "TestService")
		server = service:GetReplecsServerOrThrow()
		server.CollectUpdatesPackets = {
			{
				Player = player,
				Buffer = buffer.create(1),
				Variants = {
					{ "reliable" },
				},
			},
		}
		server.CollectUnreliablePackets = {
			{
				Player = player,
				Buffer = buffer.create(2),
				Variants = {
					{ "unreliable" },
				},
			},
		}
		server.CollectEntityPackets = {
			{
				Player = player,
				Buffer = buffer.create(3),
				Variants = {
					{ "entity" },
				},
			},
		}

		service:FlushReliable()
		service:FlushUnreliable()
		local sentCount = service:CollectEntityPackets(10)

		expect(#service.SentReliable).toBe(0)
		expect(#service.SentUnreliable).toBe(0)
		expect(#service.SentEntity).toBe(0)
		expect(sentCount).toBe(0)

		service:CompleteBootstrap(player :: any)
		service:FlushReliable()
		service:FlushUnreliable()
		sentCount = service:CollectEntityPackets(10)

		expect(#service.SentReliable).toBe(1)
		expect(#service.SentUnreliable).toBe(1)
		expect(#service.SentEntity).toBe(1)
		expect(sentCount).toBe(1)
	end)

	it("exposes registration, stop, alias, and introspection helpers", function()
		local world = JECS.World.new()
		local componentId = nameEntity(world, world:component(), "Health")
		local pairId = nameEntity(world, world:component(), "TargetPair")
		local relationId = nameEntity(world, world:component(), "TargetRelation")
		local registry = createRegistry(world, {})
		local service = TestReplicationService.new(world)
		local player = {
			Name = "PlayerOne",
		}
		local server = nil

		service:Init(registry, "TestService")
		server = service:GetReplecsServerOrThrow()

		local customId = service:CreateCustomId("enemy", function()
			return nil
		end)
		service:RegisterCustomId(customId)
		service:RegisterSerdes(componentId, {
			serialize = function(_value: any)
				return buffer.create(0)
			end,
			deserialize = function(_packetBuffer: buffer)
				return nil
			end,
		})
		service:RemoveSerdes(componentId)
		service:RegisterNetworkedEntity(10)
		service:RegisterReliableComponent(10, componentId)
		service:RegisterUnreliableComponent(10, componentId)
		service:RegisterPair(10, pairId)
		service:RegisterRelation(10, relationId)
		service:SetCustomHandler(10, customId)
		service:RemoveCustomHandler(10)
		service:SetCustomIdHandler(customId, function()
			return "rebound"
		end)
		service:StopReplicatingEntity(10, true)
		service:StopReliableComponent(10, componentId, true)
		service:StopUnreliableComponent(10, componentId, false)
		service:StopPair(10, pairId, true)
		service:StopRelation(10, relationId, true)
		service:AddPlayerAlias(player :: any, "P1")
		service:RemovePlayerAlias("P1")
		service:MarkPlayerReady(player :: any)

		local verified, _message = service:VerifyHandshake(service:GenerateHandshake())
		expect(verified).toBe(true)
		expect(service:EncodeComponent(componentId)).never.toBeNil()
		expect(service:DecodeComponent(3)).toBe(1003)
		expect(service:GetSharedCount()).toBe(3)
		expect(service:IsPlayerReady(player :: any)).toBe(true)
		expect(customId.handle_callback()).toBe("rebound")
		expect(service:GetReplecsComponentsOrThrow().global).never.toBeNil()
		expect(server.StopPairCalls[1].KeepState).toBe(true)
	end)

	it("hydrates all players without activating them and destroys idempotently", function()
		local world = JECS.World.new()
		local registry = createRegistry(world, {})
		local service = TestReplicationService.new(world)
		local playerOne = { Name = "One" }
		local playerTwo = { Name = "Two" }

		service.TestPlayers = { playerOne :: any, playerTwo :: any }
		service:Init(registry, "TestService")
		service:HydrateAllPlayers()

		expect(#service.SentBootstrap).toBe(2)
		expect(#service:GetReplecsServerOrThrow().MarkedPlayers).toBe(0)

		local server = service:GetReplecsServerOrThrow()
		service:Destroy()
		service:Destroy()

		expect(server.DestroyCalls).toBe(1)
	end)

	it("supports global ids, component custom handlers, and shared schema bootstrap", function()
		local world = JECS.World.new()
		local replicatedEntity = world:entity()
		local healthComponent = nameEntity(world, world:component(), "Health")
		local aliveTag = nameEntity(world, world:entity(), "Alive")
		local trackedCustomId = {
			identifier = "tracked",
			handle_callback = nil,
		}
		function trackedCustomId:handle(nextHandler: any)
			self.handle_callback = nextHandler
		end

		local handler = function(_ctx: any)
			return nil
		end
		local serdes = {
			serialize = function(_value: any)
				return buffer.create(0)
			end,
			deserialize = function(_packetBuffer: buffer)
				return nil
			end,
		}
		local registry = createRegistry(world, {
			HealthComponent = healthComponent,
			AliveTag = aliveTag,
		})
		local service = SharedSchemaReplicationService.new(world, {
			sharedComponents = { healthComponent },
			sharedTags = { aliveTag },
			customIds = { trackedCustomId },
			serdes = {
				[healthComponent] = serdes,
			},
			componentCustomHandlers = {
				[healthComponent] = handler,
			},
		})

		service:Init(registry, "TestService")
		service:SetGlobalId(replicatedEntity, 123)
		service:RemoveGlobalId(replicatedEntity)
		service:SetComponentCustomHandler(healthComponent, handler)
		service:RemoveComponentCustomHandler(healthComponent)
		service:ApplySharedSchema(service:_GetSharedSchema() :: any)

		local replecsComponents = service:GetReplecsComponentsOrThrow()
		local server = service:GetReplecsServerOrThrow()
		expect(world:has(healthComponent, replecsComponents.shared)).toBe(true)
		expect(world:has(aliveTag, replecsComponents.shared)).toBe(true)
		expect(world:has(replicatedEntity, replecsComponents.global)).toBe(false)
		expect(world:has(healthComponent, replecsComponents.custom_handler)).toBe(true)
		expect(server.RegisterCustomIdCalls[1]).toBe(trackedCustomId)
		expect(server.SetSerdesCalls[1].Serdes).toBe(serdes)
	end)

	it("validates schemas and tracks handshake diagnostics", function()
		local world = JECS.World.new()
		local namedComponent = nameEntity(world, world:component(), "Health")
		local unnamedTag = world:entity()
		local registry = createRegistry(world, {
			HealthComponent = namedComponent,
		})
		local service = TestReplicationService.new(world)

		service:Init(registry, "TestService")

		expect(function()
			service:ValidateSharedSchema({
				sharedTags = { unnamedTag },
			})
		end).toThrow()

		expect(function()
			service:ValidateSharedSchema({
				customIds = {
					{},
				},
			})
		end).toThrow()

		service:RegisterSerdes(namedComponent, {
			serialize = function(_value: any)
				return buffer.create(0)
			end,
			deserialize = function(_packetBuffer: buffer)
				return nil
			end,
			includes_variants = false,
			bytespan = 8,
		})

		local verified, message = service:VerifyHandshake({
			components = {},
			custom_ids = {},
			serdes = {},
		})
		expect(verified).toBe(false)
		expect(message).toBe("mismatch")
		expect(service:GetLastHandshakeVerificationError()).toBe("mismatch")

		local mismatch = service:DescribeSharedSchemaMismatch({
			components = {},
			custom_ids = {},
			serdes = {
				Health = {
					includes_variants = true,
					bytespan = 16,
				},
			},
		})
		expect(mismatch.LastVerificationError).toBe("mismatch")
		expect(#mismatch.MismatchedSerdes).toBe(1)
	end)

	it("tracks applied schema state and removal helpers", function()
		local world = JECS.World.new()
		local healthComponent = nameEntity(world, world:component(), "Health")
		local aliveTag = nameEntity(world, world:entity(), "Alive")
		local trackedCustomId = {
			identifier = "tracked",
			handle_callback = nil,
		}
		function trackedCustomId:handle(nextHandler: any)
			self.handle_callback = nextHandler
		end
		local registry = createRegistry(world, {
			HealthComponent = healthComponent,
			AliveTag = aliveTag,
		})
		local service = TestReplicationService.new(world)
		local serdes = {
			serialize = function(_value: any)
				return buffer.create(0)
			end,
			deserialize = function(_packetBuffer: buffer)
				return nil
			end,
		}
		local handler = function(_ctx: any)
			return nil
		end

		service:Init(registry, "TestService")
		service:ApplySharedSchema({
			sharedComponents = { healthComponent },
			sharedTags = { aliveTag },
			customIds = { trackedCustomId },
			serdes = {
				[healthComponent] = serdes,
			},
			componentCustomHandlers = {
				[healthComponent] = handler,
			},
		})

		expect(service:HasAppliedSharedSchema()).toBe(true)
		expect(service:GetAppliedSharedSchema()).never.toBeNil()

		local summary = service:GetSchemaSummary()
		expect(summary.SharedComponentCount).toBe(1)
		expect(summary.SharedTagCount).toBe(1)
		expect(summary.CustomIdCount).toBe(1)
		expect(summary.SerdesCount).toBe(1)
		expect(summary.ComponentCustomHandlerCount).toBe(1)

		service:RemoveSharedComponent(healthComponent)
		service:RemoveSharedTag(aliveTag)
		service:ForgetTrackedCustomId(trackedCustomId)
		service:RemoveSerdes(healthComponent)
		service:RemoveComponentCustomHandler(healthComponent)

		local updatedSummary = service:GetSchemaSummary()
		expect(updatedSummary.SharedComponentCount).toBe(0)
		expect(updatedSummary.SharedTagCount).toBe(0)
		expect(updatedSummary.CustomIdCount).toBe(0)
		expect(updatedSummary.SerdesCount).toBe(0)
		expect(updatedSummary.ComponentCustomHandlerCount).toBe(0)
	end)
end)
