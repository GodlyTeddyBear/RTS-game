--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local StateMachine = require(ReplicatedStorage.Utilities.StateMachine)
local CombatTypes = require(ReplicatedStorage.Contexts.Combat.Types.CombatTypes)

local Errors = require(script.Parent.Parent.Parent.Errors)

type CombatSessionState = CombatTypes.CombatSessionState

local LEGAL_TRANSITIONS: { [CombatSessionState | "Inactive"]: { [CombatSessionState | "Inactive"]: boolean } } = {
	Inactive = {
		Starting = true,
	},
	Starting = {
		Active = true,
		Inactive = true,
	},
	Active = {
		Ending = true,
	},
	Ending = {
		Inactive = true,
	},
}

type InternalCombatSessionState = CombatSessionState | "Inactive"

--[=[
	@class CombatSessionStateMachine
	Tracks one combat session lifecycle through the shared StateMachine utility.
	@server
]=]
local CombatSessionStateMachine = {}
CombatSessionStateMachine.__index = CombatSessionStateMachine

function CombatSessionStateMachine.new()
	local self = setmetatable({}, CombatSessionStateMachine)
	self._machine = StateMachine.new({
		InitialState = "Inactive" :: InternalCombatSessionState,
		Transitions = LEGAL_TRANSITIONS,
		ErrorType = "IllegalCombatSessionTransition",
		ErrorMessage = Errors.ILLEGAL_SESSION_TRANSITION,
		ErrorDataBuilder = function(fromState: InternalCombatSessionState, toState: InternalCombatSessionState)
			return {
				From = fromState,
				To = toState,
			}
		end,
	})
	self.StateChanged = self._machine.StateChanged
	return self
end

function CombatSessionStateMachine:GetState(): InternalCombatSessionState
	return self._machine:GetState()
end

function CombatSessionStateMachine:Transition(newState: InternalCombatSessionState): Result.Result<InternalCombatSessionState>
	return self._machine:Transition(newState)
end

function CombatSessionStateMachine:Destroy()
	self._machine:Destroy()
end

return CombatSessionStateMachine
