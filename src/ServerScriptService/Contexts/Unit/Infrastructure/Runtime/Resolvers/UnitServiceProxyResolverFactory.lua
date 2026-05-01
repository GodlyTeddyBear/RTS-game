--!strict

local UnitServiceProxyResolverFactory = {}

function UnitServiceProxyResolverFactory.Create(dependencies: {
	UnitEntityFactory: any,
}): any
	return table.freeze({
		BuildFacts = function(_entity: number): { [string]: any }
			return {}
		end,
		BuildServices = function(_entity: number, currentTime: number): { [string]: any }
			return {
				CurrentTime = currentTime,
				UnitEntityFactory = dependencies.UnitEntityFactory,
			}
		end,
	})
end

return table.freeze(UnitServiceProxyResolverFactory)
