--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local UpdateCombatWaveContextCommand =
	require(ServerScriptService.Contexts.Combat.Application.Commands.UpdateCombatWaveContextCommand)

local function createRegistry(dependencies: { [string]: any })
	return {
		Get = function(_self, name: string)
			return dependencies[name]
		end,
	}
end

return function()
	describe("UpdateCombatWaveContextCommand", function()
		it("updates the active combat session wave metadata", function()
			local command = UpdateCombatWaveContextCommand.new()
			local receivedUserId = nil :: number?
			local receivedWaveNumber = nil :: number?
			local receivedIsEndless = nil :: boolean?

			command:Init(createRegistry({
				CombatLoopService = {
					SetWaveContext = function(_self, userId: number, waveNumber: number, isEndless: boolean)
						receivedUserId = userId
						receivedWaveNumber = waveNumber
						receivedIsEndless = isEndless
						return {
							success = true,
							value = true,
						}
					end,
				},
			}), "UpdateCombatWaveContextCommand")

			local result = command:Execute(123, 5, true)

			expect(result.success).to.equal(true)
			expect(result.value).to.equal(true)
			expect(receivedUserId).to.equal(123)
			expect(receivedWaveNumber).to.equal(5)
			expect(receivedIsEndless).to.equal(true)
		end)

		it("returns an error when the incoming wave number is invalid", function()
			local command = UpdateCombatWaveContextCommand.new()
			local wasCalled = false

			command:Init(createRegistry({
				CombatLoopService = {
					SetWaveContext = function()
						wasCalled = true
						return {
							success = true,
							value = true,
						}
					end,
				},
			}), "UpdateCombatWaveContextCommand")

			local result = command:Execute(123, 0, false)

			expect(result.success).to.equal(false)
			expect(result.type).to.equal("InvalidWaveNumber")
			expect(wasCalled).to.equal(false)
		end)

		it("passes through the no-session no-op result", function()
			local command = UpdateCombatWaveContextCommand.new()

			command:Init(createRegistry({
				CombatLoopService = {
					SetWaveContext = function()
						return {
							success = true,
							value = false,
						}
					end,
				},
			}), "UpdateCombatWaveContextCommand")

			local result = command:Execute(123, 2, false)

			expect(result.success).to.equal(true)
			expect(result.value).to.equal(false)
		end)
	end)
end
