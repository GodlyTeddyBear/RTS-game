--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local function getService(serviceName: string): any?
	local didGet, service = pcall(function()
		return Knit.GetService(serviceName)
	end)
	return if didGet then service else nil
end

local function readEntityValue(context: any, entity: number, key: string, featureName: string): any?
	local entityContext = if type(context) == "table" then context.EntityContext else nil
	if entityContext == nil or type(entityContext.Get) ~= "function" then
		return nil
	end

	local result = entityContext:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

local function hasEntityTag(context: any, entity: number, key: string, featureName: string): boolean
	local entityContext = if type(context) == "table" then context.EntityContext else nil
	if entityContext == nil or type(entityContext.Has) ~= "function" then
		return false
	end

	local result = entityContext:Has(entity, key, featureName)
	return result.success and result.value == true
end

local function getEntityCFrame(context: any, entity: number): CFrame?
	local transform = readEntityValue(context, entity, "Transform", "Entity")
	return if type(transform) == "table" and typeof(transform.CFrame) == "CFrame" then transform.CFrame else nil
end

local function buildAttackTargetFacts(context: any): any
	if type(context.Entity) ~= "number" then
		return {}
	end

	local entity = context.Entity
	local role = readEntityValue(context, entity, "Role", "Enemy")
	local currentCFrame = getEntityCFrame(context, entity)
	if type(role) ~= "table" or currentCFrame == nil then
		return {}
	end

	local baseContext = getService("BaseContext")
	local structureContext = getService("StructureContext")
	local baseTargetResult = if baseContext ~= nil and type(baseContext.GetBaseTargetCFrame) == "function"
		then baseContext:GetBaseTargetCFrame()
		else nil
	local baseTargetCFrame = if baseTargetResult ~= nil and baseTargetResult.success then baseTargetResult.value else nil
	local advanceData = {
		GoalPosition = if baseTargetCFrame ~= nil then baseTargetCFrame.Position else nil,
	}

	if structureContext ~= nil and type(structureContext.GetActiveStructures) == "function" then
		local structuresResult = structureContext:GetActiveStructures()
		local structures = if structuresResult.success and type(structuresResult.value) == "table" then structuresResult.value else {}
		local nearestEntity = nil :: number?
		local nearestPosition = nil :: Vector3?
		local nearestDistance = if type(role.AttackRange) == "number" then role.AttackRange else 0

		for _, structureEntity in ipairs(structures) do
			if type(structureEntity) ~= "number" then
				continue
			end

			local positionResult = structureContext:GetStructurePosition(structureEntity)
			local structurePosition = if positionResult.success then positionResult.value else nil
			if structurePosition ~= nil then
				local distance = (structurePosition - currentCFrame.Position).Magnitude
				if distance <= nearestDistance then
					nearestEntity = structureEntity
					nearestPosition = structurePosition
					nearestDistance = distance
				end
			end
		end

		if nearestEntity ~= nil and nearestPosition ~= nil then
			return {
				TargetEntity = nearestEntity,
				AttackTargetKind = "Structure",
				AttackData = {
					AbilityId = "EnemyStructureAttack",
					TargetKind = "Structure",
					TargetPosition = nearestPosition,
				},
				AdvanceData = advanceData,
			}
		end
	end

	if
		baseTargetCFrame ~= nil
		and type(role.AttackRange) == "number"
		and (baseTargetCFrame.Position - currentCFrame.Position).Magnitude <= role.AttackRange
	then
		return {
			AttackTargetKind = "Base",
			AttackData = {
				AbilityId = "EnemyBaseAttack",
				TargetKind = "Base",
				TargetPosition = baseTargetCFrame.Position,
			},
			AdvanceData = advanceData,
		}
	end

	return {
		AdvanceData = advanceData,
	}
end

local function buildOperationalFacts(context: any): any
	if type(context.Entity) ~= "number" then
		return {}
	end

	local entity = context.Entity
	local stats = readEntityValue(context, entity, "Stats", "Structure")
	local sourcePlacement = readEntityValue(context, entity, "SourcePlacement", "Structure")
	local positionCFrame = getEntityCFrame(context, entity)
	local isOperational = hasEntityTag(context, entity, "OperationalTag", "Structure")
	if type(stats) ~= "table" then
		return {}
	end

	local facts = {
		IsOperational = isOperational,
		StructureStats = stats,
		ExtractData = {
			StructureEntity = entity,
			InstanceId = if type(sourcePlacement) == "table" then sourcePlacement.InstanceId else nil,
		},
		StasisData = {
			StructureEntity = entity,
		},
	}

	if positionCFrame ~= nil then
		local enemyContext = getService("EnemyContext")
		local nearestResult = if enemyContext ~= nil and type(enemyContext.GetNearestAliveEnemy) == "function"
			then enemyContext:GetNearestAliveEnemy(positionCFrame.Position, stats.AttackRange or 0)
			else nil
		local nearest = if nearestResult ~= nil and nearestResult.success then nearestResult.value else nil
		if type(nearest) == "table" and typeof(nearest.CFrame) == "CFrame" then
			facts.TargetEntity = nearest.Entity
			facts.AttackData = {
				AbilityId = "StructureBullet",
				UseCombatPipeline = true,
				TargetPosition = nearest.CFrame.Position,
				Range = stats.AttackRange,
				Damage = stats.AttackDamage,
				Cooldown = stats.AttackCooldown,
			}
		end
	end

	return facts
end

local function resolveBuildTarget(context: any, entity: number, role: any): number?
	if type(role) ~= "table" or type(role.BuildWorkPerSecond) ~= "number" or type(role.BuildRange) ~= "number" then
		return nil
	end

	local structureContext = getService("StructureContext")
	if structureContext == nil then
		return nil
	end

	local ownership = readEntityValue(context, entity, "Ownership", "Entity")
	if type(ownership) ~= "table" or ownership.OwnerKind ~= "Player" then
		return nil
	end

	local ownerUserId = tonumber(ownership.OwnerId)
	local cframe = getEntityCFrame(context, entity)
	if ownerUserId == nil or cframe == nil then
		return nil
	end

	local assignment = readEntityValue(context, entity, "BuilderAssignment", "Unit")
	local assignedEntity = if type(assignment) == "table" then assignment.TargetStructureEntity else nil
	if type(assignedEntity) == "number" then
		local assignedResult =
			structureContext:IsStructureBuildableForBuilder(assignedEntity, ownerUserId, cframe.Position, role.BuildRange)
		if assignedResult.success and assignedResult.value == true then
			return assignedEntity
		end
	end

	local result = structureContext:FindNearestOwnedUnfinishedStructure(ownerUserId, cframe.Position, math.huge)
	return if result.success then result.value else nil
end

local function buildMoveBuildFacts(context: any): any
	if type(context.Entity) ~= "number" then
		return {}
	end

	local entity = context.Entity
	local role = readEntityValue(context, entity, "Role", "Unit")
	if type(role) ~= "table" then
		return {}
	end

	local pathState = readEntityValue(context, entity, "PathState", "Unit")
	local hasGoalTarget = type(pathState) == "table"
		and pathState.GoalPosition ~= nil
		and pathState.FailedGoalRevision ~= pathState.GoalRevision
	local buildTargetEntity = resolveBuildTarget(context, entity, role)

	return {
		HasGoalTarget = hasGoalTarget == true,
		MoveData = {
			GoalPosition = if type(pathState) == "table" then pathState.GoalPosition else nil,
		},
		BuildTargetEntity = buildTargetEntity,
		BuildData = {
			TargetStructureEntity = buildTargetEntity,
		},
	}
end

local function buildEngageEnemyFacts(context: any): any
	if type(context.Entity) ~= "number" then
		return {}
	end

	local entity = context.Entity
	local currentCFrame = getEntityCFrame(context, entity)
	local combatProfile = readEntityValue(context, entity, "CombatProfile", "Summon")
	if currentCFrame == nil or type(combatProfile) ~= "table" then
		return {}
	end

	local enemyContext = getService("EnemyContext")
	local targetResult = if enemyContext ~= nil and type(enemyContext.GetNearestAliveEnemy) == "function"
		then enemyContext:GetNearestAliveEnemy(currentCFrame.Position, combatProfile.AcquireRange or 0)
		else nil
	local target = if targetResult ~= nil and targetResult.success then targetResult.value else nil
	if type(target) ~= "table" or type(target.Entity) ~= "number" or typeof(target.CFrame) ~= "CFrame" then
		return {
			HasEnemyTarget = false,
		}
	end

	return {
		HasEnemyTarget = true,
		TargetEntity = target.Entity,
		TargetPosition = target.CFrame.Position,
	}
end

local BasicFactProviders = {
	EmptyFacts = {
		ProviderId = "EmptyFacts",
		BuildFacts = function(_context: any): any
			return {}
		end,
		Metadata = {
			Description = "Template fact provider that contributes no facts.",
		},
	},

	AttackTargetFacts = {
		ProviderId = "AttackTargetFacts",
		BuildFacts = buildAttackTargetFacts,
		Metadata = {
			Description = "Builds generic attack target and advance facts for hostile advancing actors.",
		},
	},

	OperationalActionFacts = {
		ProviderId = "OperationalActionFacts",
		BuildFacts = buildOperationalFacts,
		Metadata = {
			Description = "Builds generic operational action facts for placed actors.",
		},
	},

	MovementBuildFacts = {
		ProviderId = "MovementBuildFacts",
		BuildFacts = buildMoveBuildFacts,
		Metadata = {
			Description = "Builds generic movement and builder facts.",
		},
	},

	EnemyEngagementFacts = {
		ProviderId = "EnemyEngagementFacts",
		BuildFacts = buildEngageEnemyFacts,
		Metadata = {
			Description = "Builds generic enemy engagement facts.",
		},
	},
}

return table.freeze(BasicFactProviders)
