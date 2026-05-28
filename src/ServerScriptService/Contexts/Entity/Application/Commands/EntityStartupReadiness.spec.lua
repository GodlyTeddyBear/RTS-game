--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local EntityRuntimeSchedulerService =
	require(ServerScriptService.Contexts.Entity.Infrastructure.Services.EntityRuntimeSchedulerService)
local StartCommand = require(ServerScriptService.Contexts.Entity.Application.Commands.StartCommand)

local function createRegistry(values: { [string]: any })
	return {
		Get = function(_self, name: string)
			local value = values[name]
			if value ~= nil then
				return value
			end

			error(("Unexpected registry lookup: %s"):format(name))
		end,
	}
end

return function()
	describe("Entity startup readiness", function()
		it("finalizes startup before binding the scheduler", function()
			local schedulerBound = false
			local finalized = false
			local lifecycle = {
				GetState = function()
					return "RegisteringECS"
				end,
			}
			local startupState = {
				ClearLastStartupFailure = function() end,
				SetLastStartupFailure = function() end,
			}
			local runtimeScheduler = {
				BindSchedulerTick = function()
					expect(finalized).to.equal(true)
					schedulerBound = true
				end,
			}
			local finalizeStartupCommand = {
				Execute = function()
					finalized = true
					return {
						success = true,
						value = true,
					}
				end,
			}

			local command = StartCommand.new()
			command:Init(createRegistry({
				EntityLifecycleStateMachine = lifecycle,
				EntityValidationService = {},
				EntityStartupStateService = startupState,
				EntityRuntimeSchedulerService = runtimeScheduler,
				FinalizeStartupCommand = finalizeStartupCommand,
			}), "StartCommand")

			local result = command:Execute()

			expect(result.success).to.equal(true)
			expect(finalized).to.equal(true)
			expect(schedulerBound).to.equal(true)
		end)

		it("does not finalize startup from the scheduler tick", function()
			local lifecycleState = "RegisteringECS"
			local phasesRan = false

			local scheduler = EntityRuntimeSchedulerService.new({
				RegisterSchedulerSystem = function() end,
			}, {})
			scheduler:Init(createRegistry({
				EntityLifecycleStateMachine = {
					GetState = function()
						return lifecycleState
					end,
				},
				EntitySystemRegistry = {
					RunAllPhases = function()
						phasesRan = true
						return {
							success = true,
							value = true,
						}
					end,
				},
				EntityInstanceBindingService = {
					FlushBindQueue = function()
						return {
							success = true,
							value = true,
						}
					end,
				},
				EntityRuntimeParticipationService = {
					GetFeatureName = function()
						return nil
					end,
				},
				EntityRuntimeSyncService = {
					RunRuntimeSync = function()
						return {
							success = true,
							value = true,
						}
					end,
					RunRuntimePoll = function()
						return {
							success = true,
							value = true,
						}
					end,
				},
				EntityReplicationService = {
					FlushReliableResult = function()
						return {
							success = true,
							value = true,
						}
					end,
					FlushUnreliableResult = function()
						return {
							success = true,
							value = true,
						}
					end,
				},
			}), "EntityRuntimeSchedulerService")

			scheduler:RunScheduledTick()

			expect(phasesRan).to.equal(false)
		end)
	end)
end
