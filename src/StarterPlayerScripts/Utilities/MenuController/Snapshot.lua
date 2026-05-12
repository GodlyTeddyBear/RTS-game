--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)

local Constants = require(script.Parent.Constants)
local Types = require(script.Parent.Types)

type TInternalMenuState = Types.TInternalMenuState
type TMenuSnapshot = Types.TMenuSnapshot
type TMenuStateMeta = Types.TMenuStateMeta
type TNormalizedMenuConfig = Types.TNormalizedMenuConfig

local CLOSED_STATE = Constants.State.Closed
local ERROR_MENU_INVALID_CONTEXT_PATCH = Constants.Error.MenuInvalidContextPatch
local DEFAULT_META = table.freeze({}) :: TMenuStateMeta

local Snapshot = {}

local function _BuildSnapshot(
	isOpen: boolean,
	currentState: string?,
	history: { string },
	context: { [string]: any },
	meta: TMenuStateMeta
): TMenuSnapshot
	local clonedHistory = table.clone(history)
	local clonedContext = table.clone(context)

	return table.freeze({
		IsOpen = isOpen,
		CurrentState = currentState,
		History = table.freeze(clonedHistory),
		Context = table.freeze(clonedContext),
		CanGoBack = isOpen and #clonedHistory > 0,
		CanClose = isOpen,
		Meta = meta,
	})
end

function Snapshot.CreateSnapshotFromMachineState(
	machineState: TInternalMenuState,
	history: { string },
	context: { [string]: any },
	config: TNormalizedMenuConfig
): TMenuSnapshot
	if machineState == CLOSED_STATE then
		return _BuildSnapshot(false, nil, history, context, DEFAULT_META)
	end

	return _BuildSnapshot(true, machineState, history, context, config.States[machineState].Meta)
end

function Snapshot.ValidateContextPatch(patch: { [string]: any }?): Result.Err?
	if patch == nil then
		return nil
	end

	if type(patch) ~= "table" then
		return Result.Err(ERROR_MENU_INVALID_CONTEXT_PATCH, "Context patch must be a table", nil)
	end

	return nil
end

function Snapshot.ValidateClearContextKeys(keys: { string }): Result.Err?
	for index, key in keys do
		if type(key) ~= "string" or #key == 0 then
			return Result.Err(ERROR_MENU_INVALID_CONTEXT_PATCH, "ClearContext keys must be non-empty strings", {
				Index = index,
				Key = key,
			})
		end
	end

	return nil
end

function Snapshot.CloneHistoryWithPush(history: { string }, stateId: string): { string }
	local nextHistory = table.clone(history)
	table.insert(nextHistory, stateId)
	return nextHistory
end

function Snapshot.CloneHistoryWithPop(history: { string }): ({ string }, string)
	local nextHistory = table.clone(history)
	local targetState = nextHistory[#nextHistory]
	table.remove(nextHistory)
	return nextHistory, targetState
end

function Snapshot.MergeContext(currentContext: { [string]: any }, patch: { [string]: any }?): { [string]: any }
	local nextContext = table.clone(currentContext)
	if patch == nil then
		return nextContext
	end

	for key, value in patch do
		nextContext[key] = value
	end

	return nextContext
end

function Snapshot.CloneContextWithoutKeys(currentContext: { [string]: any }, keys: { string }): { [string]: any }
	local nextContext = table.clone(currentContext)
	for _, key in keys do
		nextContext[key] = nil
	end
	return nextContext
end

function Snapshot.BuildClearContextPatch(keys: { string }): { [string]: any }
	return table.freeze({
		ClearedKeys = table.freeze(table.clone(keys)),
	})
end

return table.freeze(Snapshot)
