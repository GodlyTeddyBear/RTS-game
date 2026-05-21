--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JECS = require(ReplicatedStorage.Packages.JECS)
local Replecs = require(ReplicatedStorage.Packages.Replecs)

type TPayload = {
	Buffer: buffer,
	Variants: { { any } }?,
}

type TCleanupTask = RBXScriptConnection | (() -> ()) | { Destroy: (self: any) -> (), Disconnect: ((self: any) -> ())? } | nil

local function _RunCleanupTask(cleanupTask: TCleanupTask)
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
	self._cleanupTasks = {}
	return self
end

function BaseECSReplicationClient:Init()
	assert(not self._initialized, ("%sECSReplicationClient: Init called twice"):format(self._contextName))

	self._world = self:_CreateWorld()
	assert(self._world ~= nil, ("%sECSReplicationClient: failed to create world"):format(self._contextName))

	self._replecsLibrary = self:_CreateReplecsLibrary()
	self._components = self:_BuildComponents(self._world, self._replecsLibrary)
	assert(self._components ~= nil, ("%sECSReplicationClient: _BuildComponents returned nil"):format(self._contextName))

	self._replecsClient = self:_CreateReplecsClient(self._world)
	assert(self._replecsClient ~= nil, ("%sECSReplicationClient: failed to create Replecs client"):format(self._contextName))
	assert(type(self._replecsClient.init) == "function", ("%sECSReplicationClient: Replecs client missing init"):format(self._contextName))

	self._replecsClient:init(self._world)
	self:_RegisterReplicatedSurface()

	self._initialized = true
end

function BaseECSReplicationClient:Start()
	self:RequireReady()
	assert(not self._started, ("%sECSReplicationClient: Start called twice"):format(self._contextName))

	local cleanupTask = self:_ConnectTransport()
	self:_TrackCleanup(cleanupTask)
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

function BaseECSReplicationClient:GetReplecsClientOrThrow()
	self:RequireReady()
	return self._replecsClient
end

function BaseECSReplicationClient:GetComponentsOrThrow()
	self:RequireReady()
	return self._components
end

function BaseECSReplicationClient:GetReplecsLibraryOrThrow()
	self:RequireReady()
	return self._replecsLibrary
end

function BaseECSReplicationClient:HandleHandshake(payload: { Handshake: any })
	self:RequireReady()

	local handshake = payload.Handshake
	assert(handshake ~= nil, ("%sECSReplicationClient: missing handshake payload"):format(self._contextName))

	local ok, message = self._replecsClient:verify_handshake(handshake)
	assert(ok, ("%sECSReplicationClient: handshake verification failed: %s"):format(self._contextName, tostring(message)))

	self._handshakeVerified = true
end

function BaseECSReplicationClient:HandleFull(payload: TPayload)
	self:RequireReady()
	assert(self._handshakeVerified, ("%sECSReplicationClient: received full payload before handshake"):format(self._contextName))
	assert(payload.Buffer ~= nil, ("%sECSReplicationClient: missing full payload buffer"):format(self._contextName))

	self._replecsClient:apply_full(payload.Buffer, payload.Variants)
	self._hasReceivedFull = true
end

function BaseECSReplicationClient:HandleReliable(payload: TPayload)
	self:RequireReady()
	assert(self._hasReceivedFull, ("%sECSReplicationClient: received reliable payload before full snapshot"):format(self._contextName))
	assert(payload.Buffer ~= nil, ("%sECSReplicationClient: missing reliable payload buffer"):format(self._contextName))

	self._replecsClient:apply_updates(payload.Buffer, payload.Variants)
end

function BaseECSReplicationClient:HandleUnreliable(payload: TPayload)
	self:RequireReady()
	assert(self._hasReceivedFull, ("%sECSReplicationClient: received unreliable payload before full snapshot"):format(self._contextName))
	assert(payload.Buffer ~= nil, ("%sECSReplicationClient: missing unreliable payload buffer"):format(self._contextName))

	self._replecsClient:apply_unreliable(payload.Buffer, payload.Variants)
end

function BaseECSReplicationClient:AfterReplication(callback: () -> ())
	self:RequireReady()
	self._replecsClient:after_replication(callback)
end

function BaseECSReplicationClient:Hook(action: string, relationOrEntity: any, callback: (...any) -> ())
	self:RequireReady()
	return self._replecsClient:hook(action, relationOrEntity, callback)
end

function BaseECSReplicationClient:Override(action: string, relationOrEntity: any, callback: (...any) -> ())
	self:RequireReady()
	return self._replecsClient:override(action, relationOrEntity, callback)
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

	local replecsClient = self._replecsClient
	if replecsClient ~= nil and replecsClient.inited ~= nil then
		replecsClient:destroy()
	end

	self._world = nil
	self._components = nil
	self._replecsLibrary = nil
	self._replecsClient = nil
	self._initialized = false
	self._started = false
	self._handshakeVerified = false
	self._hasReceivedFull = false
end

function BaseECSReplicationClient:_CreateWorld()
	return JECS.World.new()
end

function BaseECSReplicationClient:_CreateReplecsLibrary()
	return Replecs
end

function BaseECSReplicationClient:_CreateReplecsClient(world: any)
	return self:_CreateReplecsLibrary().create_client(world)
end

function BaseECSReplicationClient:_BuildComponents(_world: any, _replecsLibrary: any)
	error(("%sECSReplicationClient must implement _BuildComponents"):format(self._contextName))
end

function BaseECSReplicationClient:_RegisterReplicatedSurface()
	return
end

function BaseECSReplicationClient:_ConnectTransport(): TCleanupTask
	return nil
end

function BaseECSReplicationClient:_OnStart()
	return
end

function BaseECSReplicationClient:_OnDestroy()
	return
end

function BaseECSReplicationClient:_TrackCleanup(cleanupTask: TCleanupTask)
	if cleanupTask == nil then
		return
	end

	table.insert(self._cleanupTasks, cleanupTask)
end

return BaseECSReplicationClient
