--!strict

local EnemyGoalReachedSystem = {}
EnemyGoalReachedSystem.__index = EnemyGoalReachedSystem

function EnemyGoalReachedSystem.new(entityFactory: any, enemyContext: any)
	return setmetatable({ _entityFactory = entityFactory, _enemyContext = enemyContext }, EnemyGoalReachedSystem)
end

function EnemyGoalReachedSystem:Run()
	-- READS: Movement.MoveIntent [AUTHORITATIVE], Movement.ApplyResult [AUTHORITATIVE]
	-- WRITES: Enemy.GoalReachedTag
	local result = self._entityFactory:Query({ FeatureName = "Enemy", Keys = { "AliveTag" } })
	if not result.success then return end
	for _, entity in ipairs(result.value) do
		local intent = self:_Get(entity, "MoveIntent", "Movement")
		local applyResult = self:_Get(entity, "ApplyResult", "Movement")
		if type(intent) == "table" and intent.ActionId == "Advance" and type(applyResult) == "table" and applyResult.IsDone == true then
			self._entityFactory:Add(entity, "GoalReachedTag", "Enemy")
			self._enemyContext:HandleGoalReached(entity)
		end
	end
end

function EnemyGoalReachedSystem:_Get(entity: number, key: string, featureName: string): any
	local result = self._entityFactory:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

return EnemyGoalReachedSystem
