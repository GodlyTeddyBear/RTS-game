--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Run = require(ReplicatedStorage.Events.GameEvents.Contexts.Run)

return function()
	describe("Run GameEvents contract", function()
		it("registers RunStarted with an empty schema", function()
			expect(Run.events.RunStarted).to.equal("Run.RunStarted")
			expect(Run.schemas[Run.events.RunStarted]).never.toBeNil()
			expect(#Run.schemas[Run.events.RunStarted]).to.equal(0)
		end)
	end)
end
