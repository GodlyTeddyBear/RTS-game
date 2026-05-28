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
	describe("Entity deferred startup", function()
		it("binds the scheduler without closing ECS registration during Start", function()
			local schedulerBound = false
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
					schedulerBound = true
				end,
			}
			local validationService = {}

			local command = StartCommand.new()
			command:Init(createRegistry({
				EntityLifecycleStateMachine = lifecycle,
				EntityValidationService = validationService,
				EntityStartupStateService = startupState,
				EntityRuntimeSchedulerService = runtimeScheduler,
			}), "StartCommand")

			local result = command:Execute()

			expect(result.success).to.equal(true)
			expect(schedulerBound).to.equal(true)
			expect(lifecycle:GetState()).to.equal("RegisteringECS")
		end)

		it("finalizes Entity startup before running ECS phases", function()
			local lifecycleState = "RegisteringECS"
			local finalizeCalled = false
			local phasesRan = false
			local synced = false
			local polled = false

			local baseContext = {
				RegisterSchedulerSystem = function() end,
			}
			local entityContext = {
				_EnsureRuntimeStarted = function()
					finalizeCalled = true
					lifecycleState = "Running"
					return {
						success = true,
						value = true,
					}
				end,
			}
			local scheduler = EntityRuntimeSchedulerService.new(baseContext, entityContext)
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
						synced = true
						return {
							success = true,
							value = true,
						}
					end,
					RunRuntimePoll = function()
						polled = true
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

			expect(finalizeCalled).to.equal(true)
			expect(phasesRan).to.equal(true)
			expect(synced).to.equal(true)
			expect(polled).to.equal(true)
		end)
	end)
end
