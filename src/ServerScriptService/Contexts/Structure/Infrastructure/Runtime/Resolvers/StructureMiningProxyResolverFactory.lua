--!strict

local StructureMiningProxyResolverFactory = {}

function StructureMiningProxyResolverFactory.Create(dependencies: {
	MiningEntityFactory: any,
	ExtractorMiningSystem: any,
}): any
	return table.freeze({
		CreateProxy = function(instanceId: number): any
			return table.freeze({
				IsActive = function(_self: any): boolean
					local miningEntity = dependencies.MiningEntityFactory:FindExtractorByInstanceId(instanceId)
					return dependencies.MiningEntityFactory:IsActive(miningEntity)
				end,
				Advance = function(_self: any, dt: number): boolean
					local miningEntity = dependencies.MiningEntityFactory:FindExtractorByInstanceId(instanceId)
					if not dependencies.MiningEntityFactory:IsActive(miningEntity) then
						return false
					end

					dependencies.ExtractorMiningSystem:AdvanceExtractor(miningEntity :: number, dt)
					return true
				end,
			})
		end,
	})
end

return table.freeze(StructureMiningProxyResolverFactory)
