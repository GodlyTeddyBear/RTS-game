--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local PlacementSpecs = require(ServerScriptService.Contexts.Placement.PlacementDomain.Specs.PlacementSpecs)

return function()
	describe("PlacementSpecs.CanPlaceInRunState", function()
		it("allows all active run phases", function()
			expect(PlacementSpecs.CanPlaceInRunState("Prep")).to.equal(true)
			expect(PlacementSpecs.CanPlaceInRunState("Wave")).to.equal(true)
			expect(PlacementSpecs.CanPlaceInRunState("Resolution")).to.equal(true)
			expect(PlacementSpecs.CanPlaceInRunState("Climax")).to.equal(true)
			expect(PlacementSpecs.CanPlaceInRunState("Endless")).to.equal(true)
		end)

		it("rejects non-active run phases", function()
			expect(PlacementSpecs.CanPlaceInRunState("Idle")).to.equal(false)
			expect(PlacementSpecs.CanPlaceInRunState("RunEnd")).to.equal(false)
		end)
	end)
end
