--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseSyncClient = require(ReplicatedStorage.Utilities.BaseSyncClient)
local SharedAtoms = require(ReplicatedStorage.Contexts.Commission.Sync.SharedAtoms)

--[=[
	@class CommissionSyncClient
	Syncs commission state from the server via Blink network protocol. Stores state in a React-Charm atom for UI subscription.
	@client
]=]
local CommissionSyncClient = setmetatable({}, { __index = BaseSyncClient })
CommissionSyncClient.__index = CommissionSyncClient

--[=[
	Create a new commission sync client.
	@within CommissionSyncClient
	@param BlinkClient any -- Blink network client instance
	@return CommissionSyncClient -- New sync client instance
]=]
function CommissionSyncClient.new(BlinkClient: any)
	local self = BaseSyncClient.new(BlinkClient, "SyncCommissions", "commissions", SharedAtoms.CreateClientAtom)
	return setmetatable(self, CommissionSyncClient)
end

--[=[
	Get the commissions atom for subscription.
	@within CommissionSyncClient
	@return any -- React-Charm atom containing current commission state
]=]
function CommissionSyncClient:GetCommissionsAtom()
	return self:GetAtom()
end

return CommissionSyncClient
