--!strict

local StructureMiningFactsResolverFactory = {}

function StructureMiningFactsResolverFactory.Create(_dependencies: any): any
	return table.freeze({
		BuildFacts = function(_entity: number): { [string]: any }
			return {}
		end,
	})
end

return table.freeze(StructureMiningFactsResolverFactory)
