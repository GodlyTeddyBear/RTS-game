--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local StateMachine = require(ReplicatedStorage.Utilities.StateMachine)

type TestState = "Idle" | "Running" | "Paused" | "Stopped"

local TRANSITIONS: StateMachine.TStateMachineTransitionMap<TestState> = {
	Idle = {
		Running = true,
	},
	Running = {
		Paused = true,
		Stopped = true,
	},
	Paused = {
		Running = true,
	},
	Stopped = {},
}

return function()
	describe("StateMachine", function()
		it("runs lifecycle hooks, actions, and state changed listeners in order", function()
			local events = {}
			local machine = StateMachine.new({
				InitialState = "Idle" :: TestState,
				Transitions = {
					Idle = {
						Running = {
							Action = function(fromState: TestState, toState: TestState)
								table.insert(events, `{fromState}->{toState}:action`)
							end,
						},
					},
					Running = {},
				},
				StateHooks = {
					Idle = {
						OnExit = function(previousState: TestState, nextState: TestState)
							table.insert(events, `{previousState}->{nextState}:exit`)
						end,
					},
					Running = {
						OnEnter = function(newState: TestState, previousState: TestState)
							table.insert(events, `{previousState}->{newState}:enter`)
						end,
					},
				},
			})

			machine.StateChanged:Connect(function(newState: TestState, previousState: TestState)
				table.insert(events, `{previousState}->{newState}:changed`)
			end)

			local transitionResult = machine:Transition("Running")
			expect(transitionResult.success).to.be.equal(true)
			expect(machine:GetState()).to.be.equal("Running")
			expect(machine:GetPreviousState()).to.be.equal("Idle")
			expect(#events).to.be.equal(4)
			expect(events[1]).to.be.equal("Idle->Running:exit")
			expect(events[2]).to.be.equal("Idle->Running:action")
			expect(events[3]).to.be.equal("Idle->Running:enter")
			expect(events[4]).to.be.equal("Idle->Running:changed")

			machine:Destroy()
		end)

		it("runs registered hooks after config hooks in stable order", function()
			local events = {}
			local machine = StateMachine.new({
				InitialState = "Idle" :: TestState,
				Transitions = {
					Idle = {
						Running = {
							Action = function()
								table.insert(events, "config-action")
							end,
						},
					},
					Running = {},
				},
				StateHooks = {
					Idle = {
						OnExit = function()
							table.insert(events, "config-exit")
						end,
					},
					Running = {
						OnEnter = function()
							table.insert(events, "config-enter")
						end,
					},
				},
			})

			machine:RegisterOnExit("Idle", function()
				table.insert(events, "runtime-exit-1")
			end)
			machine:RegisterOnExit("Idle", function()
				table.insert(events, "runtime-exit-2")
			end)
			machine:RegisterTransitionAction("Idle", "Running", function()
				table.insert(events, "runtime-action-1")
			end)
			machine:RegisterTransitionAction("Idle", "Running", function()
				table.insert(events, "runtime-action-2")
			end)
			machine:RegisterOnEnter("Running", function()
				table.insert(events, "runtime-enter-1")
			end)
			machine:RegisterOnEnter("Running", function()
				table.insert(events, "runtime-enter-2")
			end)

			local transitionResult = machine:Transition("Running")
			expect(transitionResult.success).to.be.equal(true)
			expect(#events).to.be.equal(9)
			expect(events[1]).to.be.equal("config-exit")
			expect(events[2]).to.be.equal("runtime-exit-1")
			expect(events[3]).to.be.equal("runtime-exit-2")
			expect(events[4]).to.be.equal("config-action")
			expect(events[5]).to.be.equal("runtime-action-1")
			expect(events[6]).to.be.equal("runtime-action-2")
			expect(events[7]).to.be.equal("config-enter")
			expect(events[8]).to.be.equal("runtime-enter-1")
			expect(events[9]).to.be.equal("runtime-enter-2")

			machine:Destroy()
		end)

		it("rejects guarded transitions without mutating state", function()
			local machine = StateMachine.new({
				InitialState = "Idle" :: TestState,
				Transitions = {
					Idle = {
						Running = {
							Guard = function(fromState: TestState, toState: TestState): Result.Err
								return Result.Err("GuardBlocked", "Guard blocked the transition", {
									From = fromState,
									To = toState,
								})
							end,
						},
					},
					Running = {},
				},
			})

			local transitionResult = machine:Transition("Running")
			expect(transitionResult.success).to.be.equal(false)
			expect(transitionResult.type).to.be.equal("GuardBlocked")
			expect(machine:GetState()).to.be.equal("Idle")
			expect(machine:GetPreviousState()).to.be.equal(nil)

			machine:Destroy()
		end)

		it("runs registered guards after config guards and stops at the first runtime error", function()
			local guardEvents = {}
			local machine = StateMachine.new({
				InitialState = "Idle" :: TestState,
				Transitions = {
					Idle = {
						Running = {
							Guard = function(): Result.Err?
								table.insert(guardEvents, "config-guard")
								return nil
							end,
						},
					},
					Running = {},
				},
			})

			machine:RegisterTransitionGuard("Idle", "Running", function()
				table.insert(guardEvents, "runtime-guard-1")
				return nil
			end)
			machine:RegisterTransitionGuard("Idle", "Running", function()
				table.insert(guardEvents, "runtime-guard-2")
				return Result.Err("GuardBlocked", "Stopped by runtime guard")
			end)
			machine:RegisterTransitionGuard("Idle", "Running", function()
				table.insert(guardEvents, "runtime-guard-3")
				return nil
			end)

			local transitionResult = machine:Transition("Running")
			expect(transitionResult.success).to.be.equal(false)
			expect(transitionResult.type).to.be.equal("GuardBlocked")
			expect(machine:GetState()).to.be.equal("Idle")
			expect(#guardEvents).to.be.equal(3)
			expect(guardEvents[1]).to.be.equal("config-guard")
			expect(guardEvents[2]).to.be.equal("runtime-guard-1")
			expect(guardEvents[3]).to.be.equal("runtime-guard-2")

			machine:Destroy()
		end)

		it("prevents reentrant transitions while callbacks are executing", function()
			local nestedResult: Result.Result<TestState>? = nil
			local machine = StateMachine.new({
				InitialState = "Idle" :: TestState,
				Transitions = TRANSITIONS,
			})

			machine.StateChanged:Connect(function()
				nestedResult = machine:Transition("Stopped")
			end)

			local transitionResult = machine:Transition("Running")
			expect(transitionResult.success).to.be.equal(true)
			expect(nestedResult).to.be.ok()
			expect((nestedResult :: Result.Result<TestState>).success).to.be.equal(false)
			expect((nestedResult :: Result.Err).type).to.be.equal("TransitionInProgress")
			expect(machine:GetState()).to.be.equal("Running")

			machine:Destroy()
		end)

		it("disconnects exactly one registration and allows repeated disconnect calls", function()
			local events = {}
			local machine = StateMachine.new({
				InitialState = "Idle" :: TestState,
				Transitions = TRANSITIONS,
			})

			local firstConnection = machine:RegisterTransitionAction("Idle", "Running", function()
				table.insert(events, "first")
			end)
			machine:RegisterTransitionAction("Idle", "Running", function()
				table.insert(events, "second")
			end)

			firstConnection:Disconnect()
			firstConnection:Disconnect()

			local transitionResult = machine:Transition("Running")
			expect(transitionResult.success).to.be.equal(true)
			expect(#events).to.be.equal(1)
			expect(events[1]).to.be.equal("second")

			machine:Destroy()
		end)

		it("keeps the current execution stable when a registration disconnects during iteration", function()
			local events = {}
			local machine = StateMachine.new({
				InitialState = "Idle" :: TestState,
				Transitions = TRANSITIONS,
			})

			local secondConnection: StateMachine.TStateMachineRegistrationConnection? = nil
			machine:RegisterOnEnter("Running", function()
				table.insert(events, "first")
				if secondConnection ~= nil then
					secondConnection:Disconnect()
				end
			end)
			secondConnection = machine:RegisterOnEnter("Running", function()
				table.insert(events, "second")
			end)

			local firstTransitionResult = machine:Transition("Running")
			expect(firstTransitionResult.success).to.be.equal(true)
			expect(#events).to.be.equal(2)
			expect(events[1]).to.be.equal("first")
			expect(events[2]).to.be.equal("second")

			local resetResult = machine:Reset()
			expect(resetResult.success).to.be.equal(true)

			table.clear(events)

			local secondTransitionResult = machine:Transition("Running")
			expect(secondTransitionResult.success).to.be.equal(true)
			expect(#events).to.be.equal(1)
			expect(events[1]).to.be.equal("first")

			machine:Destroy()
		end)

		it("supports introspection, force state, and reset", function()
			local machine = StateMachine.new({
				InitialState = "Idle" :: TestState,
				Transitions = TRANSITIONS,
				StateHooks = {
					Stopped = {},
				},
			})

			expect(machine:HasState("Paused")).to.be.equal(true)
			expect(machine:IsInState("Idle")).to.be.equal(true)
			local allowedTransitions = machine:GetAllowedTransitions()
			expect(#allowedTransitions).to.be.equal(1)
			expect(allowedTransitions[1]).to.be.equal("Running")

			local forceResult = machine:ForceState("Stopped")
			expect(forceResult.success).to.be.equal(true)
			expect(machine:GetState()).to.be.equal("Stopped")
			expect(machine:GetPreviousState()).to.be.equal("Idle")

			local resetResult = machine:Reset()
			expect(resetResult.success).to.be.equal(true)
			expect(machine:GetState()).to.be.equal("Idle")
			expect(machine:GetPreviousState()).to.be.equal("Stopped")

			machine:Destroy()
		end)

		it("rejects operations and registrations after destroy", function()
			local machine = StateMachine.new({
				InitialState = "Idle" :: TestState,
				Transitions = TRANSITIONS,
			})

			machine:Destroy()

			local transitionResult = machine:Transition("Running")
			expect(transitionResult.success).to.be.equal(false)
			expect(transitionResult.type).to.be.equal("StateMachineDestroyed")
			expect(machine:CanTransition("Running")).to.be.equal(false)
			expect(function()
				machine:RegisterOnEnter("Running", function() end)
			end).to.throw()
		end)
	end)
end
