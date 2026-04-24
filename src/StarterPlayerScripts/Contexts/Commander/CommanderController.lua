--!strict

--[=[
	@class CommanderController
	Purpose: Owns the client commander sync wrapper and exposes the local commander atom to UI consumers.
	Used In System: Started by Knit on the client during player bootstrap and consumed by run HUD read hooks.
	High-Level Flow: Create sync client -> start replication -> expose atom for read subscriptions.
	Boundaries: Owns controller lifecycle only; does not own payload parsing, UI rendering, or authoritative commander state.
	@client
]=]
-- [Dependencies]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local CommanderSyncClient = require(script.Parent.Infrastructure.CommanderSyncClient)

local CommanderController = Knit.CreateController({
	Name = "CommanderController",
})

local function _warnAbilityRejected(slotKey: string, result: any)
	local errType = if result and result.type then tostring(result.type) else "UnknownErrorType"
	local message = if result and result.message then tostring(result.message) else "No message"
	local data = if result and result.data then result.data else nil
	warn(string.format(
		"[CommanderController] Ability request rejected slot=%s type=%s message=%s data=%s",
		slotKey,
		errType,
		message,
		if data then game:GetService("HttpService"):JSONEncode(data) else "nil"
	))
end

-- [Initialization]

--[=[
	Initializes the commander sync client.
	@within CommanderController
]=]
function CommanderController:KnitInit()
	self._syncClient = CommanderSyncClient.new()
end

-- [Public API]

--[=[
	Starts commander atom replication on the client.
	@within CommanderController
]=]
function CommanderController:KnitStart()
	self._syncClient:Start()
	self._commanderContext = Knit.GetService("CommanderContext")
end

--[=[
	Returns the local commander atom for read hooks and UI subscriptions.
	@within CommanderController
	@return any -- The client commander atom.
]=]
function CommanderController:GetAtom()
	return self._syncClient:GetAtom()
end

--[=[
	Requests a commander ability use through the server context.
	@within CommanderController
	@param slotKey string -- Commander slot key to execute.
	@return any -- Async result of ability request.
	@yields
]=]
function CommanderController:UseAbility(slotKey: string)
	return self._commanderContext:UseAbility(slotKey)
		:catch(function(err: any)
			_warnAbilityRejected(slotKey, err)
		end)
end

return CommanderController
