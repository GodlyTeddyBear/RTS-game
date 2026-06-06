--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StateMachine = require(ReplicatedStorage.Utilities.StateMachine)

type EntityLifecycleState =
	"Uninitialized"
	| "RegisteringECS"
	| "FinalizingECSRegistration"
	| "CompilingECS"
	| "ReadyForRuntimeRegistration"
	| "RegisteringRuntime"
	| "Running"
	| "ShuttingDown"
	| "Destroyed"

local LEGAL_TRANSITIONS: StateMachine.TStateMachineTransitionMap<EntityLifecycleState> = {
	Uninitialized = {
		RegisteringECS = true,
	},
	RegisteringECS = {
		FinalizingECSRegistration = true,
		ShuttingDown = true,
	},
	FinalizingECSRegistration = {
		CompilingECS = true,
		ShuttingDown = true,
	},
	CompilingECS = {
		ReadyForRuntimeRegistration = true,
		ShuttingDown = true,
	},
	ReadyForRuntimeRegistration = {
		RegisteringRuntime = true,
		Running = true,
		ShuttingDown = true,
	},
	RegisteringRuntime = {
		Running = true,
		ShuttingDown = true,
	},
	Running = {
		ShuttingDown = true,
	},
	ShuttingDown = {
		Destroyed = true,
	},
	Destroyed = {},
}

local EntityLifecycleStateMachine = {}
EntityLifecycleStateMachine.__index = EntityLifecycleStateMachine

function EntityLifecycleStateMachine.new()
	local self = setmetatable({}, EntityLifecycleStateMachine)
	self._machine = StateMachine.new({
		InitialState = "Uninitialized" :: EntityLifecycleState,
		Transitions = LEGAL_TRANSITIONS,
		ErrorType = "EntityLifecycleTransitionRejected",
		ErrorMessage = "Entity lifecycle transition is not allowed",
		ErrorDataBuilder = function(fromState: EntityLifecycleState, toState: EntityLifecycleState)
			return {
				From = fromState,
				To = toState,
				Context = "EntityContext",
			}
		end,
	})
	self.StateChanged = self._machine.StateChanged
	return self
end

function EntityLifecycleStateMachine:Init(_registry: any, _name: string)
end

function EntityLifecycleStateMachine:GetState(): EntityLifecycleState
	return self._machine:GetState()
end

function EntityLifecycleStateMachine:CanTransition(newState: EntityLifecycleState): boolean
	return self._machine:CanTransition(newState)
end

function EntityLifecycleStateMachine:BeginECSRegistration()
	return self._machine:Transition("RegisteringECS")
end

function EntityLifecycleStateMachine:MarkReadyForRuntimeRegistration()
	return self._machine:Transition("ReadyForRuntimeRegistration")
end

function EntityLifecycleStateMachine:BeginECSCompile()
	return self._machine:Transition("CompilingECS")
end

function EntityLifecycleStateMachine:BeginECSFinalization()
	return self._machine:Transition("FinalizingECSRegistration")
end

function EntityLifecycleStateMachine:BeginRuntimeRegistration()
	return self._machine:Transition("RegisteringRuntime")
end

function EntityLifecycleStateMachine:StartRunning()
	return self._machine:Transition("Running")
end

function EntityLifecycleStateMachine:BeginShutdown()
	return self._machine:Transition("ShuttingDown")
end

function EntityLifecycleStateMachine:MarkDestroyed()
	return self._machine:Transition("Destroyed")
end

function EntityLifecycleStateMachine:BeginRegistration()
	return self:BeginECSRegistration()
end

function EntityLifecycleStateMachine:MarkReady()
	return self:MarkReadyForRuntimeRegistration()
end

function EntityLifecycleStateMachine:RegisterOnEnter(state: EntityLifecycleState, callback: (EntityLifecycleState, EntityLifecycleState) -> ())
	return self._machine:RegisterOnEnter(state, callback)
end

function EntityLifecycleStateMachine:RegisterOnExit(state: EntityLifecycleState, callback: (EntityLifecycleState, EntityLifecycleState) -> ())
	return self._machine:RegisterOnExit(state, callback)
end

function EntityLifecycleStateMachine:RegisterTransitionAction(
	fromState: EntityLifecycleState,
	toState: EntityLifecycleState,
	callback: (EntityLifecycleState, EntityLifecycleState) -> ()
)
	return self._machine:RegisterTransitionAction(fromState, toState, callback)
end

function EntityLifecycleStateMachine:RegisterTransitionGuard(
	fromState: EntityLifecycleState,
	toState: EntityLifecycleState,
	callback: (EntityLifecycleState, EntityLifecycleState) -> any
)
	return self._machine:RegisterTransitionGuard(fromState, toState, callback)
end

function EntityLifecycleStateMachine:Destroy()
	self._machine:Destroy()
end

return EntityLifecycleStateMachine
