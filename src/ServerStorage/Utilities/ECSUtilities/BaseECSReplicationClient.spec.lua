--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JECS = require(ReplicatedStorage.Packages.JECS)
local BaseECSReplicationClient = require(ReplicatedStorage.Utilities.BaseECSReplicationClient)

local function createStubClient(world: any)
	local sharedComponent = world:entity()
	local customHandlerComponent = world:component()
	local stubClient = {
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
		SharedCount = 5,
		ServerIds = {},
		ClientIds = {},
		AppliedFull = {},
		AppliedReliable = {},
		AppliedUnreliable = {},
		AppliedEntity = {},
		AfterReplicationCallbacks = {},
		AddedCallbacks = {},
		HookCalls = {},
		OverrideCalls = {},
		RegisterCustomIdCalls = {},
		SetSerdesCalls = {},
		RemoveSerdesCalls = {},
		HandleGlobalCalls = {},
		components = {
			shared = sharedComponent,
			custom_handler = customHandlerComponent,
		},
	}

	function stubClient:init(_world: any)
		self.inited = true
		self.InitCalls += 1
	end

	function stubClient:destroy()
		self.inited = nil
		self.DestroyCalls += 1
	end

	function stubClient:verify_handshake(handshake: any)
		return handshake == self.Handshake, "mismatch"
	end

	function stubClient:generate_handshake()
		return self.Handshake
	end

	function stubClient:encode_component(componentId: any): number
		return tonumber(componentId) or 77
	end

	function stubClient:decode_component(encodedId: number): any
		return encodedId + 2000
	end

	function stubClient:get_shared_count(): number
		return self.SharedCount
	end

	function stubClient:register_custom_id(customId: any)
		table.insert(self.RegisterCustomIdCalls, customId)
	end

	function stubClient:set_serdes(componentId: any, serdes: any)
		table.insert(self.SetSerdesCalls, {
			ComponentId = componentId,
			Serdes = serdes,
		})
	end

	function stubClient:remove_serdes(componentId: any)
		table.insert(self.RemoveSerdesCalls, componentId)
	end

	function stubClient:handle_global(handler: (id: number) -> any)
		table.insert(self.HandleGlobalCalls, handler)
	end

	function stubClient:get_server_entity(clientEntity: any): number?
		return self.ClientIds[clientEntity]
	end

	function stubClient:get_client_entity(serverEntity: number): any
		return self.ServerIds[serverEntity]
	end

	function stubClient:register_entity(clientEntity: any, serverEntity: number)
		self.ServerIds[serverEntity] = clientEntity
		self.ClientIds[clientEntity] = serverEntity
	end

	function stubClient:unregister_entity(clientEntity: any)
		local serverEntity = self.ClientIds[clientEntity]
		if serverEntity ~= nil then
			self.ClientIds[clientEntity] = nil
			self.ServerIds[serverEntity] = nil
		end
	end

	function stubClient:apply_full(packetBuffer: buffer, packetVariants: any)
		table.insert(self.AppliedFull, {
			Buffer = packetBuffer,
			Variants = packetVariants,
		})
	end

	function stubClient:apply_updates(packetBuffer: buffer, packetVariants: any)
		table.insert(self.AppliedReliable, {
			Buffer = packetBuffer,
			Variants = packetVariants,
		})
	end

	function stubClient:apply_unreliable(packetBuffer: buffer, packetVariants: any)
		table.insert(self.AppliedUnreliable, {
			Buffer = packetBuffer,
			Variants = packetVariants,
		})
	end

	function stubClient:apply_entity(packetBuffer: buffer, packetVariants: any)
		table.insert(self.AppliedEntity, {
			Buffer = packetBuffer,
			Variants = packetVariants,
		})
	end

	function stubClient:after_replication(callback: () -> ())
		table.insert(self.AfterReplicationCallbacks, callback)
		callback()
	end

	function stubClient:added(callback: (entity: any) -> ())
		table.insert(self.AddedCallbacks, callback)
		return "added-disconnect"
	end

	function stubClient:hook(action: string, relationOrEntity: any, callback: (...any) -> ())
		table.insert(self.HookCalls, {
			Action = action,
			RelationOrEntity = relationOrEntity,
			Callback = callback,
		})
		return "hook-disconnect"
	end

	function stubClient:override(action: string, relationOrEntity: any, callback: (...any) -> ())
		table.insert(self.OverrideCalls, {
			Action = action,
			RelationOrEntity = relationOrEntity,
			Callback = callback,
		})
		return "override-disconnect"
	end

	return stubClient
end

local function nameEntity(world: any, entity: any, name: string)
	world:set(entity, JECS.Name, name)
	return entity
end

local TestReplicationClient = {}
TestReplicationClient.__index = TestReplicationClient
setmetatable(TestReplicationClient, BaseECSReplicationClient)

function TestReplicationClient.new()
	local self = BaseECSReplicationClient.new("Test")
	self.TransportConnectCalls = 0
	self.TransportCleanupCalls = 0
	self.BootstrapCompletedCalls = 0
	return setmetatable(self, TestReplicationClient)
end

function TestReplicationClient:_CreateReplecsLibrary()
	return {
		create_client = function(_world: any)
			return createStubClient(_world)
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

function TestReplicationClient:_BuildComponents(world: any, _replecsLibrary: any)
	return {
		HealthComponent = nameEntity(world, world:component(), "Health"),
		AliveTag = nameEntity(world, world:entity(), "Alive"),
	}
end

function TestReplicationClient:_ConnectTransport()
	self.TransportConnectCalls += 1
	return function()
		self.TransportCleanupCalls += 1
	end
end

function TestReplicationClient:_OnBootstrapCompleted()
	self.BootstrapCompletedCalls += 1
end

local SharedSchemaReplicationClient = {}
SharedSchemaReplicationClient.__index = SharedSchemaReplicationClient
setmetatable(SharedSchemaReplicationClient, TestReplicationClient)

function SharedSchemaReplicationClient.new(schema: any)
	local self = TestReplicationClient.new()
	self._sharedSchema = schema
	return setmetatable(self, SharedSchemaReplicationClient)
end

function SharedSchemaReplicationClient:_GetSharedSchema()
	if self._sharedSchema == nil then
		return nil
	end

	return {
		sharedComponents = { self._bootstrapComponent },
		sharedTags = { self._bootstrapTag },
		customIds = self._sharedSchema.customIds,
		serdes = {
			[self._bootstrapComponent] = self._sharedSchema.serdes,
		},
		componentCustomHandlers = {
			[self._bootstrapComponent] = self._sharedSchema.componentCustomHandler,
		},
	}
end

function SharedSchemaReplicationClient:_BuildComponents(world: any, replecsLibrary: any)
	local components = TestReplicationClient._BuildComponents(self, world, replecsLibrary)
	self._bootstrapComponent = nameEntity(world, world:component(), "BootstrapComponent")
	self._bootstrapTag = nameEntity(world, world:entity(), "BootstrapTag")
	return components
end

describe("BaseECSReplicationClient", function()
	it("initializes a mirror world and starts transport once", function()
		local client = TestReplicationClient.new()

		client:Init()
		client:Start()

		expect(client:GetWorldOrThrow()).never.toBeNil()
		expect(client:GetComponentsOrThrow().HealthComponent).never.toBeNil()
		expect(client:GetReplecsClientOrThrow().InitCalls).toBe(1)
		expect(client.TransportConnectCalls).toBe(1)
		expect(client:IsStarted()).toBe(true)
	end)

	it("stages post-handshake deltas until full state is applied", function()
		local client = TestReplicationClient.new()

		client:Init()

		expect(function()
			client:HandleReliable({
				Buffer = buffer.create(1),
			})
		end).toThrow()

		expect(function()
			client:HandleFull({
				Buffer = buffer.create(1),
			})
		end).toThrow()

		client:HandleHandshake({
			Handshake = client:GetReplecsClientOrThrow().Handshake,
		})
		expect(client:HasVerifiedHandshake()).toBe(true)

		client:HandleReliable({
			Buffer = buffer.create(3),
			Variants = {
				{ "reliable" },
			},
		})
		client:HandleUnreliable({
			Buffer = buffer.create(4),
			Variants = {
				{ "unreliable" },
			},
		})
		client:HandleEntity({
			Buffer = buffer.create(5),
			Variants = {
				{ "entity" },
			},
		})

		local replecsClient = client:GetReplecsClientOrThrow()
		expect(#replecsClient.AppliedReliable).toBe(0)
		expect(#replecsClient.AppliedUnreliable).toBe(0)
		expect(#replecsClient.AppliedEntity).toBe(0)

		client:HandleFull({
			Buffer = buffer.create(2),
			Variants = {
				{ "full" },
			},
		})
		expect(client:HasReceivedFull()).toBe(true)
		expect(client:HasCompletedBootstrap()).toBe(true)
		expect(client.BootstrapCompletedCalls).toBe(1)

		expect(#replecsClient.AppliedFull).toBe(1)
		expect(#replecsClient.AppliedReliable).toBe(1)
		expect(#replecsClient.AppliedUnreliable).toBe(1)
		expect(#replecsClient.AppliedEntity).toBe(1)
	end)

	it("handles bootstrap atomically", function()
		local client = TestReplicationClient.new()

		client:Init()

		local handled = client:HandleBootstrap({
			Handshake = client:GetReplecsClientOrThrow().Handshake,
			Buffer = buffer.create(2),
			Variants = {
				{ "full" },
			},
		})

		expect(handled).toBe(true)
		expect(client:HasVerifiedHandshake()).toBe(true)
		expect(client:HasReceivedFull()).toBe(true)
		expect(client:HasCompletedBootstrap()).toBe(true)
		expect(client.BootstrapCompletedCalls).toBe(1)
		expect(#client:GetReplecsClientOrThrow().AppliedFull).toBe(1)
	end)

	it("resets bootstrap state on reliable queue overflow", function()
		local client = TestReplicationClient.new()

		client:Init()
		client:HandleHandshake({
			Handshake = client:GetReplecsClientOrThrow().Handshake,
		})

		for _ = 1, 32 do
			client:HandleReliable({
				Buffer = buffer.create(1),
			})
		end

		expect(function()
			client:HandleReliable({
				Buffer = buffer.create(1),
			})
		end).toThrow()
		expect(client:HasVerifiedHandshake()).toBe(false)
		expect(client:HasReceivedFull()).toBe(false)
		expect(client:HasCompletedBootstrap()).toBe(false)
	end)

	it("drops oldest unreliable packets when the pending queue is full", function()
		local client = TestReplicationClient.new()

		client:Init()
		client:HandleHandshake({
			Handshake = client:GetReplecsClientOrThrow().Handshake,
		})

		for index = 1, 65 do
			local packetBuffer = buffer.create(1)
			buffer.writeu8(packetBuffer, 0, index)
			client:HandleUnreliable({
				Buffer = packetBuffer,
			})
		end

		client:HandleFull({
			Buffer = buffer.create(1),
		})

		local replecsClient = client:GetReplecsClientOrThrow()
		expect(#replecsClient.AppliedUnreliable).toBe(64)
		expect(buffer.readu8(replecsClient.AppliedUnreliable[1].Buffer, 0)).toBe(2)
	end)

	it("fails fast on handshake mismatch", function()
		local client = TestReplicationClient.new()

		client:Init()

		expect(function()
			client:HandleHandshake({
				Handshake = {},
			})
		end).toThrow()
	end)

	it("exposes identity, custom id, serdes, and shared introspection helpers", function()
		local client = TestReplicationClient.new()
		local marker = {}

		client:Init()

		local customId = client:CreateCustomId("enemy", function()
			return nil
		end)
		client:RegisterCustomId(customId)
		client:SetCustomIdHandler(customId, function()
			return "rebound"
		end)
		client:RegisterSerdes(10, {
			serialize = function(_value: any)
				return buffer.create(0)
			end,
			deserialize = function(_packetBuffer: buffer)
				return nil
			end,
		})
		client:RemoveSerdes(10)
		client:SetGlobalHandler(function(id: number)
			return id
		end)
		client:RegisterEntity(marker, 99)

		expect(client:GetServerEntity(marker)).toBe(99)
		expect(client:GetClientEntity(99)).toBe(marker)
		client:UnregisterEntity(marker)
		expect(client:GetClientEntity(99)).toBeNil()
		expect(client:GenerateHandshake()).toBe(client:GetReplecsClientOrThrow().Handshake)
		expect(client:EncodeComponent(12)).never.toBeNil()
		expect(client:DecodeComponent(2)).toBe(2002)
		expect(client:GetSharedCount()).toBe(5)
		expect(customId.handle_callback()).toBe("rebound")
		expect(client:GetReplecsComponentsOrThrow().custom_handler).never.toBeNil()
	end)

	it("passes through subscriptions and destroys idempotently", function()
		local client = TestReplicationClient.new()
		local afterReplicationCalls = 0
		local callback = function() end

		client:Init()
		client:AfterReplication(function()
			afterReplicationCalls += 1
		end)

		local addedDisconnect = client:Added(function(_entity: any) end)
		local onAddedDisconnect = client:OnAdded(function(_entity: any) end)
		local hookDisconnect = client:Hook("changed", "Health", callback)
		local overrideDisconnect = client:Override("removed", "Health", callback)

		expect(afterReplicationCalls).toBe(1)
		expect(addedDisconnect).toBe("added-disconnect")
		expect(onAddedDisconnect).toBe("added-disconnect")
		expect(hookDisconnect).toBe("hook-disconnect")
		expect(overrideDisconnect).toBe("override-disconnect")

		client:Start()
		client:Destroy()
		client:Destroy()

		expect(client.TransportCleanupCalls).toBe(1)
		expect(client:IsStarted()).toBe(false)
		expect(client:HasVerifiedHandshake()).toBe(false)
		expect(client:HasReceivedFull()).toBe(false)
		expect(client:HasCompletedBootstrap()).toBe(false)
	end)

	it("supports a transport-style end to end envelope flow", function()
		local client = TestReplicationClient.new()
		local reliablePayload = {
			Buffer = buffer.create(1),
			Variants = {
				{ "reliable" },
			},
		}
		local unreliablePayload = {
			Buffer = buffer.create(2),
			Variants = {
				{ "unreliable" },
			},
		}
		local entityPayload = {
			Buffer = buffer.create(3),
			Variants = {
				{ "entity" },
			},
		}

		client:Init()
		client:HandleHandshake({
			Handshake = client:GetReplecsClientOrThrow().Handshake,
		})
		client:HandleFull({
			Buffer = buffer.create(4),
			Variants = {
				{ "full" },
			},
		})
		client:HandleReliable(reliablePayload)
		client:HandleUnreliable(unreliablePayload)
		client:HandleEntity(entityPayload)

		local replecsClient = client:GetReplecsClientOrThrow()
		expect(replecsClient.AppliedReliable[1].Buffer).toBe(reliablePayload.Buffer)
		expect(replecsClient.AppliedUnreliable[1].Buffer).toBe(unreliablePayload.Buffer)
		expect(replecsClient.AppliedEntity[1].Buffer).toBe(entityPayload.Buffer)
	end)

	it("applies shared schema bootstrap and readiness getters", function()
		local serdes = {
			serialize = function(_value: any)
				return buffer.create(0)
			end,
			deserialize = function(_packetBuffer: buffer)
				return nil
			end,
		}
		local customId = {
			identifier = "tracked",
			handle_callback = nil,
		}
		function customId:handle(nextHandler: any)
			self.handle_callback = nextHandler
		end
		local handler = function(_ctx: any)
			return nil
		end
		local client = SharedSchemaReplicationClient.new({
			customIds = { customId },
			serdes = serdes,
			componentCustomHandler = handler,
		})

		client:Init()

		local world = client:GetWorldOrThrow()
		local bootstrapComponent = client._bootstrapComponent
		local bootstrapTag = client._bootstrapTag
		local replecsClient = client:GetReplecsClientOrThrow()
		expect(replecsClient.RegisterCustomIdCalls[1]).toBe(customId)
		expect(replecsClient.SetSerdesCalls[1].Serdes).toBe(serdes)
		expect(world:has(bootstrapComponent, client:GetReplecsComponentsOrThrow().shared)).toBe(true)
		expect(world:has(bootstrapTag, client:GetReplecsComponentsOrThrow().shared)).toBe(true)
		expect(world:get(bootstrapComponent, client:GetReplecsComponentsOrThrow().custom_handler)).toBe(handler)
		expect(client:HasAppliedSharedSchema()).toBe(true)
		expect(client:HasVerifiedHandshake()).toBe(false)
		expect(client:HasReceivedFull()).toBe(false)
	end)

	it("validates schemas and tracks handshake diagnostics", function()
		local client = TestReplicationClient.new()

		client:Init()

		local unnamedTag = client:GetWorldOrThrow():entity()
		expect(function()
			client:ValidateSharedSchema({
				sharedTags = { unnamedTag },
			})
		end).toThrow()

		expect(function()
			client:ValidateSharedSchema({
				serdes = {
					[client:GetComponentsOrThrow().HealthComponent] = {},
				},
			})
		end).toThrow()

		client:RegisterSerdes(client:GetComponentsOrThrow().HealthComponent, {
			serialize = function(_value: any)
				return buffer.create(0)
			end,
			deserialize = function(_packetBuffer: buffer)
				return nil
			end,
			includes_variants = false,
			bytespan = 8,
		})

		local verified, message = client:VerifyHandshake({
			components = {},
			custom_ids = {},
			serdes = {},
		})
		expect(verified).toBe(false)
		expect(message).toBe("mismatch")
		expect(client:GetLastHandshakeVerificationError()).toBe("mismatch")

		local mismatch = client:DescribeSharedSchemaMismatch({
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

	it("tracks schema summary and removal helpers", function()
		local client = SharedSchemaReplicationClient.new({
			customIds = {
				{
					identifier = "tracked",
					handle = function(_self: any, _handler: any) end,
				},
			},
			serdes = {
				serialize = function(_value: any)
					return buffer.create(0)
				end,
				deserialize = function(_packetBuffer: buffer)
					return nil
				end,
			},
			componentCustomHandler = function(_ctx: any)
				return nil
			end,
		})

		client:Init()

		local summary = client:GetSchemaSummary()
		expect(summary.SharedComponentCount).toBe(1)
		expect(summary.SharedTagCount).toBe(1)
		expect(summary.CustomIdCount).toBe(1)
		expect(summary.SerdesCount).toBe(1)
		expect(summary.ComponentCustomHandlerCount).toBe(1)

		client:RemoveSharedComponent(client._bootstrapComponent)
		client:RemoveSharedTag(client._bootstrapTag)
		client:ForgetTrackedCustomId(client:GetAppliedSharedSchema().customIds[1])
		client:RemoveSerdes(client._bootstrapComponent)
		client:RemoveComponentCustomHandler(client._bootstrapComponent)

		local updatedSummary = client:GetSchemaSummary()
		expect(updatedSummary.SharedComponentCount).toBe(0)
		expect(updatedSummary.SharedTagCount).toBe(0)
		expect(updatedSummary.CustomIdCount).toBe(0)
		expect(updatedSummary.SerdesCount).toBe(0)
		expect(updatedSummary.ComponentCustomHandlerCount).toBe(0)
	end)

	it("supports explicit bootstrap state reset", function()
		local client = TestReplicationClient.new()

		client:Init()
		client:HandleBootstrap({
			Handshake = client:GetReplecsClientOrThrow().Handshake,
			Buffer = buffer.create(1),
		})

		client:ResetBootstrapState()

		expect(client:HasVerifiedHandshake()).toBe(false)
		expect(client:HasReceivedFull()).toBe(false)
		expect(client:HasCompletedBootstrap()).toBe(false)
	end)
end)
