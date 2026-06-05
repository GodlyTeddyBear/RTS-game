--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GoodSignal = require(ReplicatedStorage.Packages.Goodsignal)
local JECS = require(ReplicatedStorage.Packages.JECS)
local Knit = require(ReplicatedStorage.Packages.Knit)
local BaseECSReplicationClient = require(ReplicatedStorage.Utilities.BaseECSReplicationClient)
local StashPlus = require(ReplicatedStorage.Utilities.StashPlus)

type TBootstrapPayload = BaseECSReplicationClient.TBootstrapPayload & {
	SchemaMetadata: any?,
}
type TReplicationPacketPayload = BaseECSReplicationClient.TReplicationPacketPayload

type TSchemaEntry = {
	ECSName: string,
	FeatureName: string?,
	Key: string?,
}

local EntityReplicationClient = {}
EntityReplicationClient.__index = EntityReplicationClient
setmetatable(EntityReplicationClient, { __index = BaseECSReplicationClient })

local function _NameEntity(world: any, entity: any, name: string)
	world:set(entity, JECS.Name, name)
end

function EntityReplicationClient.new()
	local self = setmetatable(BaseECSReplicationClient.new("Entity"), EntityReplicationClient)
	self.StateChanged = GoodSignal.new()
	self._entityContext = nil
	self._schemaMetadata = nil
	self._dynamicSchemaApplied = false
	self._bootstrapRequestLoopActive = false
	self._destroyed = false
	return self
end

function EntityReplicationClient:_BuildComponents(_world: any, _replecsLibrary: any)
	return {
		ByECSName = {},
		MetadataByECSName = {},
		SharedComponentNames = {},
		SharedTagNames = {},
	}
end

function EntityReplicationClient:_GetSharedSchema()
	return nil
end

function EntityReplicationClient:HandleBootstrap(payload: TBootstrapPayload): boolean
	if not self._dynamicSchemaApplied then
		self:_ApplyDynamicSchemaFromMetadata(payload.SchemaMetadata)
	end

	local handled = BaseECSReplicationClient.HandleBootstrap(self, payload)
	self.StateChanged:Fire()
	return handled
end

function EntityReplicationClient:HandleReliable(payload: TReplicationPacketPayload)
	BaseECSReplicationClient.HandleReliable(self, payload)
	self.StateChanged:Fire()
end

function EntityReplicationClient:HandleUnreliable(payload: TReplicationPacketPayload)
	BaseECSReplicationClient.HandleUnreliable(self, payload)
	self.StateChanged:Fire()
end

function EntityReplicationClient:HandleEntity(payload: TReplicationPacketPayload)
	BaseECSReplicationClient.HandleEntity(self, payload)
	self.StateChanged:Fire()
end

function EntityReplicationClient:ObserveStateChanged(callback: () -> ())
	return self.StateChanged:Connect(callback)
end

function EntityReplicationClient:GetSchemaMetadata()
	return self._schemaMetadata
end

function EntityReplicationClient:_ConnectTransport()
	self._entityContext = Knit.GetService("EntityContext")
	local stash = StashPlus.new()

	stash:AddConnection(self._entityContext.EntityBootstrap:Connect(function(payload)
		self:HandleBootstrap(payload)
	end))
	stash:AddConnection(self._entityContext.EntityReliable:Connect(function(payload)
		self:HandleReliable(payload)
	end))
	stash:AddConnection(self._entityContext.EntityUnreliable:Connect(function(payload)
		self:HandleUnreliable(payload)
	end))
	stash:AddConnection(self._entityContext.EntityEntity:Connect(function(payload)
		self:HandleEntity(payload)
	end))

	return stash
end

function EntityReplicationClient:_OnStart()
	assert(self._entityContext ~= nil, "EntityReplicationClient: missing EntityContext")
	self:_StartBootstrapRequestLoop()
end

function EntityReplicationClient:_OnBootstrapCompleted()
	assert(self._entityContext ~= nil, "EntityReplicationClient: missing EntityContext")
	self._entityContext:AcknowledgeEntityReplicationBootstrap()
end

function EntityReplicationClient:_ApplyDynamicSchemaFromMetadata(schemaMetadata: any)
	if type(schemaMetadata) ~= "table" then
		schemaMetadata = {
			SharedComponents = {},
			SharedTags = {},
		}
	end

	local world = self:GetWorldOrThrow()
	local components = self:GetComponentsOrThrow()
	local sharedSchema = {
		sharedComponents = {},
		sharedTags = {},
	}

	local function registerEntry(entry: TSchemaEntry, isTag: boolean)
		assert(type(entry) == "table", "EntityReplicationClient: invalid schema entry")
		assert(type(entry.ECSName) == "string" and entry.ECSName ~= "", "EntityReplicationClient: schema entry missing ECSName")

		if components.ByECSName[entry.ECSName] ~= nil then
			return components.ByECSName[entry.ECSName]
		end

		local componentId = if isTag then world:entity() else world:component()
		_NameEntity(world, componentId, entry.ECSName)
		components.ByECSName[entry.ECSName] = componentId
		components.MetadataByECSName[entry.ECSName] = table.freeze({
			ECSName = entry.ECSName,
			FeatureName = entry.FeatureName,
			Key = entry.Key,
			Kind = if isTag then "Tag" else "Component",
		})

		if isTag then
			table.insert(components.SharedTagNames, entry.ECSName)
			table.insert(sharedSchema.sharedTags, componentId)
		else
			table.insert(components.SharedComponentNames, entry.ECSName)
			table.insert(sharedSchema.sharedComponents, componentId)
		end

		return componentId
	end

	for _, entry in ipairs(schemaMetadata.SharedComponents or {}) do
		registerEntry(entry, false)
	end

	for _, entry in ipairs(schemaMetadata.SharedTags or {}) do
		registerEntry(entry, true)
	end

	self._schemaMetadata = table.freeze(schemaMetadata)
	self:ApplySharedSchema(sharedSchema)
	self._dynamicSchemaApplied = true
end

function EntityReplicationClient:_StartBootstrapRequestLoop()
	if self._bootstrapRequestLoopActive then
		return
	end

	self._bootstrapRequestLoopActive = true
	task.spawn(function()
		while self._destroyed ~= true and self:HasCompletedBootstrap() ~= true do
			assert(self._entityContext ~= nil, "EntityReplicationClient: missing EntityContext")
			local didRequest = self._entityContext:RequestEntityReplication()
			if didRequest == true then
				self._bootstrapRequestLoopActive = false
				return
			end
			task.wait(0.25)
		end
		self._bootstrapRequestLoopActive = false
	end)
end

function EntityReplicationClient:Destroy()
	self._destroyed = true
	if self.StateChanged ~= nil then
		self.StateChanged:DisconnectAll()
	end

	BaseECSReplicationClient.Destroy(self)
	self._entityContext = nil
	self._schemaMetadata = nil
end

return EntityReplicationClient
