--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local CombatLoopService = require(ServerScriptService.Contexts.Combat.Infrastructure.Services.CombatLoopService)

local function createRegistry()
	return {
		Get = function(_self, name: string)
			if name == "CombatActorRegistryService" then
				return {
					HasActorTypes = function()
						return true
					end,
					IsRuntimeStarted = function()
						return false
					end,
					GetPendingActorPayloadCount = function()
						return 0
					end,
				}
			end

			if name == "CombatBehaviorRuntimeService" then
				return {
					HasRuntimeObject = function()
						return false
					end,
				}
			end

			error(("Unexpected registry lookup: %s"):format(name))
		end,
	}
end

return function()
	describe("CombatLoopService", function()
		it("starts run-scoped sessions with neutral wave metadata", function()
			local service = CombatLoopService.new()
			service:Init(createRegistry(), "CombatLoopService")

			local beginResult = service:BeginSession(123)
			local session = service:GetSession(123)

			expect(beginResult.success).to.equal(true)
			expect(beginResult.value).to.equal("Starting")
			expect(session).never.toBeNil()
			expect((session :: any).WaveNumber).to.equal(0)
			expect((session :: any).IsEndless).to.equal(false)
			expect((session :: any).IsPaused).to.equal(false)

			service:Destroy()
		end)

		it("updates wave number and endless state without recreating the session", function()
			local service = CombatLoopService.new()
			service:Init(createRegistry(), "CombatLoopService")
			service:BeginSession(123)

			local updateResult = service:SetWaveContext(123, 7, true)
			local session = service:GetSession(123)

			expect(updateResult.success).to.equal(true)
			expect(updateResult.value).to.equal(true)
			expect(session).never.toBeNil()
			expect((session :: any).WaveNumber).to.equal(7)
			expect((session :: any).IsEndless).to.equal(true)

			service:Destroy()
		end)

		it("no-ops safely when wave metadata is updated without an active session", function()
			local service = CombatLoopService.new()
			service:Init(createRegistry(), "CombatLoopService")

			local updateResult = service:SetWaveContext(123, 2, false)

			expect(updateResult.success).to.equal(true)
			expect(updateResult.value).to.equal(false)

			service:Destroy()
		end)
	end)
end
