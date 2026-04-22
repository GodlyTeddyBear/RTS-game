--!strict

--[[
	Module: GetResourceWalletQuery
	Purpose: Reads a full economy wallet from the sync service.
	Used In System: Invoked by EconomyContext and server-side callers that need a cloned wallet snapshot.
	Boundaries: Owns query orchestration only; does not own sync mutation or validation.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EconomyTypes = require(ReplicatedStorage.Contexts.Economy.Types.EconomyTypes)

type ResourceWallet = EconomyTypes.ResourceWallet

--[=[
	@class GetResourceWalletQuery
	Reads a full economy wallet from the sync service.
	@server
]=]
local GetResourceWalletQuery = {}
GetResourceWalletQuery.__index = GetResourceWalletQuery

-- [Initialization]

--[=[
	Creates a new wallet query.
	@within GetResourceWalletQuery
	@return GetResourceWalletQuery -- The new query instance.
]=]
function GetResourceWalletQuery.new()
	return setmetatable({}, GetResourceWalletQuery)
end

-- [Public API]

-- Resolves the sync service once so the query stays read-only and side-effect free.
--[=[
	Initializes query dependencies.
	@within GetResourceWalletQuery
	@param registry any -- The registry that owns this query.
	@param _name string -- The registered module name.
]=]
function GetResourceWalletQuery:Init(registry: any, _name: string)
	self._syncService = registry:Get("ResourceSyncService")
end

--[=[
	Reads a cloned wallet for a player.
	@within GetResourceWalletQuery
	@param userId number -- The player user id.
	@return ResourceWallet? -- The current wallet, or `nil` if uninitialized.
]=]
function GetResourceWalletQuery:Execute(userId: number): ResourceWallet?
	return self._syncService:GetWallet(userId)
end

return GetResourceWalletQuery
