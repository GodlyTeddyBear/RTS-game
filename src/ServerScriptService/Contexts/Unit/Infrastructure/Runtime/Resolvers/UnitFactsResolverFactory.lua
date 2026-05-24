--!strict

local NAVIGATION_GROUP = "Navigation"

local UnitFactsResolverFactory = {}

function UnitFactsResolverFactory.Create(dependencies: {
	UnitEntityFactory: any,
}): any
	return table.freeze({
		BuildCheapFactGroups = function(entity: number): { [string]: { BuildFacts: () -> { [string]: any } } }
			return {
				[NAVIGATION_GROUP] = {
					BuildFacts = function(): { [string]: any }
						local pathState = dependencies.UnitEntityFactory:GetPathState(entity)
						--print(pathState, "build fact")
						return {
							HasGoalTarget = pathState ~= nil and pathState.GoalPosition ~= nil,
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
			return nil
		end,
		ReacquireTarget = function(
			_cheapFacts: { [string]: any }
		): { TargetEntity: number?, TargetKind: string?, TargetPosition: Vector3? }?
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
			}
		end,
	})
end

return table.freeze(UnitFactsResolverFactory)
