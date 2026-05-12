--!strict

local Constants = require(script.Parent.Constants)
local Types = require(script.Parent.Types)

type TInternalMenuState = Types.TInternalMenuState
type TMenuConfig = Types.TMenuConfig
type TMenuStateMeta = Types.TMenuStateMeta
type TNormalizedMenuConfig = Types.TNormalizedMenuConfig
type TNormalizedMenuStateNode = Types.TNormalizedMenuStateNode

local CLOSED_STATE = Constants.State.Closed
local DEFAULT_META = table.freeze({}) :: TMenuStateMeta

local Config = {}

local function _NormalizeTargets(stateId: string, targets: { string }?): { [string]: boolean }
	if targets == nil then
		return table.freeze({})
	end

	assert(type(targets) == "table", ("MenuController state '%s' Targets must be a table"):format(stateId))

	local normalizedTargets: { [string]: boolean } = {}
	for index, targetState in targets do
		assert(type(index) == "number", ("MenuController state '%s' Targets must be an array"):format(stateId))
		assert(
			type(targetState) == "string" and #targetState > 0,
			("MenuController state '%s' target at index %d must be a non-empty string"):format(stateId, index)
		)
		normalizedTargets[targetState] = true
	end

	return table.freeze(normalizedTargets)
end

local function _NormalizeMeta(meta: TMenuStateMeta?): TMenuStateMeta
	if meta == nil then
		return DEFAULT_META
	end

	assert(type(meta) == "table", "MenuController state Meta must be a table")
	assert(meta.Title == nil or type(meta.Title) == "string", "MenuController Meta.Title must be a string")
	assert(meta.ShowBack == nil or type(meta.ShowBack) == "boolean", "MenuController Meta.ShowBack must be a boolean")
	assert(meta.ShowClose == nil or type(meta.ShowClose) == "boolean", "MenuController Meta.ShowClose must be a boolean")

	return table.freeze({
		Title = meta.Title,
		ShowBack = meta.ShowBack,
		ShowClose = meta.ShowClose,
	})
end

local function _BuildMachineTransitions(
	initialState: string,
	states: { [string]: TNormalizedMenuStateNode }
): { [TInternalMenuState]: { [TInternalMenuState]: boolean } }
	local transitions: { [TInternalMenuState]: { [TInternalMenuState]: boolean } } = {}
	transitions[CLOSED_STATE] = {
		[initialState] = true,
	}

	for stateId, stateNode in states do
		local stateTransitions: { [TInternalMenuState]: boolean } = {
			[CLOSED_STATE] = true,
		}

		for targetState, isAllowed in stateNode.Targets do
			if isAllowed then
				stateTransitions[targetState] = true
			end
		end

		transitions[stateId] = table.freeze(stateTransitions)
	end

	return table.freeze(transitions)
end

function Config.NormalizeConfig(config: TMenuConfig): TNormalizedMenuConfig
	assert(type(config) == "table", "MenuController requires a config table")
	assert(type(config.Id) == "string" and #config.Id > 0, "MenuController requires a non-empty Id")
	assert(
		type(config.InitialState) == "string" and #config.InitialState > 0,
		"MenuController requires a non-empty InitialState"
	)
	assert(type(config.States) == "table", "MenuController requires a States table")
	assert(config.States[config.InitialState] ~= nil, "MenuController InitialState must exist in States")

	local normalizedStates: { [string]: TNormalizedMenuStateNode } = {}

	for stateId, stateNode in config.States do
		assert(type(stateId) == "string" and #stateId > 0, "MenuController state ids must be non-empty strings")
		assert(type(stateNode) == "table", ("MenuController state '%s' must be a table"):format(stateId))

		normalizedStates[stateId] = table.freeze({
			Targets = _NormalizeTargets(stateId, stateNode.Targets),
			Meta = _NormalizeMeta(stateNode.Meta),
		})
	end

	for stateId, stateNode in normalizedStates do
		for targetState in stateNode.Targets do
			assert(
				normalizedStates[targetState] ~= nil,
				("MenuController state '%s' has unknown target '%s'"):format(stateId, targetState)
			)
		end
	end

	return table.freeze({
		Id = config.Id,
		InitialState = config.InitialState,
		States = table.freeze(normalizedStates),
		Transitions = _BuildMachineTransitions(config.InitialState, normalizedStates),
	})
end

function Config.CollectAllowedTargets(transitions: { [string]: boolean }?): { string }
	local allowedTargets = {}
	if transitions == nil then
		return allowedTargets
	end

	for targetState, isAllowed in transitions do
		if isAllowed and targetState ~= CLOSED_STATE then
			table.insert(allowedTargets, targetState)
		end
	end

	table.sort(allowedTargets)
	return allowedTargets
end

return table.freeze(Config)
