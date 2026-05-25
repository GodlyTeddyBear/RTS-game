--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local StructureSpecs = require(ServerScriptService.Contexts.Structure.StructureDomain.Specs.StructureSpecs)

return function()
	describe("StructureSpecs", function()
		it("accepts positive finite construction work amounts", function()
			expect(StructureSpecs.HasValidConstructionWorkAmount(0.5)).toBe(true)
			expect(StructureSpecs.HasValidConstructionWorkAmount(10)).toBe(true)
		end)

		it("rejects zero, negative, and non-finite construction work amounts", function()
			expect(StructureSpecs.HasValidConstructionWorkAmount(0)).toBe(false)
			expect(StructureSpecs.HasValidConstructionWorkAmount(-1)).toBe(false)
			expect(StructureSpecs.HasValidConstructionWorkAmount(0 / 0)).toBe(false)
			expect(StructureSpecs.HasValidConstructionWorkAmount(math.huge)).toBe(false)
		end)
	end)
end
