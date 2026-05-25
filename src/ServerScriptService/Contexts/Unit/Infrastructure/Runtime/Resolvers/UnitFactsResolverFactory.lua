--!strict

--[=[
    @class UnitFactsResolverFactory
    Builds the cached fact resolvers used by the unit behavior system to evaluate movement-related conditions.

    @server
]=]

local NAVIGATION_GROUP = "Navigation"

local UnitFactsResolverFactory = {}

-- Creates the fact resolver bundle for a single unit entity.
function UnitFactsResolverFactory.Create(dependencies: {
	UnitEntityFactory: any,
	HasBuildableStructureForEntity: ((entity: number) -> boolean)?,
}): any
	return table.freeze({
		BuildCheapFactGroups = function(entity: number): { [string]: { BuildFacts: () -> { [string]: any } } }
			return {
				[NAVIGATION_GROUP] = {
					BuildFacts = function(): { [string]: any }
						return {
							HasGoalTarget = dependencies.UnitEntityFactory:HasActionableGoal(entity),
							HasBuildableStructure = if dependencies.HasBuildableStructureForEntity ~= nil
								then dependencies.HasBuildableStructureForEntity(entity)
								else false,
						}
					end,
				},
			}
		end,
		ValidateCachedTarget = function(
			_cachedTargetState: {
				TargetEntity: number?,
				TargetKind: string?,
				TargetPosition: Vector3?,
			},
			_cheapFacts: { [string]: any }
			): { TargetEntity: number?, TargetKind: string?, TargetPosition: Vector3? }?
			-- The unit behavior currently does not cache targets between ticks, so there is nothing to validate here.
			return nil
		end,
		ReacquireTarget = function(
			_cheapFacts: { [string]: any }
		): { TargetEntity: number?, TargetKind: string?, TargetPosition: Vector3? }?
			-- The unit behavior does not reacquire targets from cheap facts in this profile.
			return nil
		end,
		BuildFactSnapshot = function(
			cheapFacts: { [string]: any },
			_targetState: {
				TargetEntity: number?,
				TargetKind: string?,
				TargetPosition: Vector3?,
			}
		): { [string]: any }
			return {
				HasGoalTarget = cheapFacts.HasGoalTarget == true,
				HasBuildableStructure = cheapFacts.HasBuildableStructure == true,
			}
		end,
	})
end

return table.freeze(UnitFactsResolverFactory)
