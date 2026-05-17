--!strict

local UnitServiceProxyResolverFactory = {}

function UnitServiceProxyResolverFactory.Create(dependencies: {
	UnitEntityFactory: any,
}): any
	return table.freeze({
		BuildFacts = function(_entity: number): { [string]: any }
			return {}
		end,
		BuildServices = function(_entity: number, currentTime: number, tickId: number?): { [string]: any }
			local services = {
				CurrentTime = currentTime,
				UnitEntityFactory = dependencies.UnitEntityFactory,
			}

			if type(tickId) == "number" then
				services.TickId = tickId
			end

			return services
		end,
	})
end

return table.freeze(UnitServiceProxyResolverFactory)
