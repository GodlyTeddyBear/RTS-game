--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HitboxConfig = require(ReplicatedStorage.Contexts.Combat.Config.HitboxConfig)

local EnemyHitboxProxyResolverFactory = {}

function EnemyHitboxProxyResolverFactory.Create(dependencies: {
	EnemyEntityFactory: any,
	HitboxService: any,
}): any
	return table.freeze({
		CreateProxy = function(entity: number): any
			return {
				CreateAttackHitbox = function(_proxy: any, _runtimeId: number, attackerKind: any, config: any)
					local modelRef = dependencies.EnemyEntityFactory:GetModelRef(entity)
					local model = if modelRef ~= nil then modelRef.Model else nil
					return dependencies.HitboxService:CreateAttackHitboxForModel(
						entity,
						attackerKind,
						model,
						config or HitboxConfig.AttackStructure
					)
				end,
				DestroyHitbox = function(_proxy: any, handle: string)
					dependencies.HitboxService:DestroyHitbox(handle)
				end,
				GetHitEntities = function(_proxy: any, handle: string)
					return dependencies.HitboxService:GetHitEntities(handle)
				end,
			}
		end,
	})
end

return table.freeze(EnemyHitboxProxyResolverFactory)
