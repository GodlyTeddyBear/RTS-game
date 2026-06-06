--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local ATTACK_RANGE_EXIT_BUFFER = 2

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

local function getActiveBaseEntity(context: any): number?
	local entityContext = if type(context) == "table" then context.EntityContext else nil
	if entityContext == nil or type(entityContext.Query) ~= "function" then
		return nil
	end

	local result = entityContext:Query({
		Keys = {
			{ Key = "BaseTag", FeatureName = "Base" },
			{ Key = "ActiveTag", FeatureName = "Entity" },
		},
	})
	if not result.success or type(result.value) ~= "table" then
		return nil
	end

	return result.value[1]
end

local function resolveTargetGeometry(
	combatContext: any?,
	sourcePosition: Vector3,
	targetEntity: number?,
	fallbackTargetPosition: Vector3?
): any?
	if
		combatContext == nil
		or type(targetEntity) ~= "number"
		or type(combatContext.ResolveTargetGeometry) ~= "function"
	then
		return nil
	end

	local geometryResult = combatContext:ResolveTargetGeometry(sourcePosition, targetEntity, fallbackTargetPosition)
	return if geometryResult ~= nil and geometryResult.success then geometryResult.value else nil
end

local function getGeometryHorizontalDistance(
	geometry: any?,
	sourcePosition: Vector3,
	fallbackTargetPosition: Vector3?
): number?
	if type(geometry) == "table" and type(geometry.HorizontalDistance) == "number" then
		return geometry.HorizontalDistance
	end
	if fallbackTargetPosition ~= nil then
		return (Vector2.new(fallbackTargetPosition.X, fallbackTargetPosition.Z) - Vector2.new(sourcePosition.X, sourcePosition.Z)).Magnitude
	end
	return nil
end

local function getGeometryTargetPosition(geometry: any?, fallbackTargetPosition: Vector3?): Vector3?
	if type(geometry) == "table" then
		if typeof(geometry.SurfacePosition) == "Vector3" then
			return geometry.SurfacePosition
		end
		if typeof(geometry.AimPosition) == "Vector3" then
			return geometry.AimPosition
		end
	end
	return fallbackTargetPosition
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

	local sourcePosition = currentCFrame.Position
	local baseContext = getService("BaseContext")
	local combatContext = getService("CombatContext")
	local structureContext = getService("StructureContext")
	local baseEntity = getActiveBaseEntity(context)
	local actionState = if type(context.ActionState) == "table" then context.ActionState else nil
	local attackRange = if type(role.AttackRange) == "number" then role.AttackRange else 0
	local attackThreshold = attackRange
	if type(actionState) == "table" and actionState.ActionId == "Attack" then
		attackThreshold += ATTACK_RANGE_EXIT_BUFFER
	end
	local baseTargetResult = if baseContext ~= nil and type(baseContext.GetBaseTargetCFrame) == "function"
		then baseContext:GetBaseTargetCFrame()
		else nil
	local baseTargetCFrame = if baseTargetResult ~= nil and baseTargetResult.success then baseTargetResult.value else nil
	local baseTargetPosition = if baseTargetCFrame ~= nil then baseTargetCFrame.Position else nil
	local baseGeometry = resolveTargetGeometry(combatContext, sourcePosition, baseEntity, baseTargetPosition)
	local advanceData = {
		GoalPosition = getGeometryTargetPosition(baseGeometry, baseTargetPosition),
		MovementMode = role.MovementMode,
	}
	local baseDistance = getGeometryHorizontalDistance(baseGeometry, sourcePosition, baseTargetPosition)

	if structureContext ~= nil and type(structureContext.GetActiveStructures) == "function" then
		local structuresResult = structureContext:GetActiveStructures()
		local structures = if structuresResult.success and type(structuresResult.value) == "table" then structuresResult.value else {}
		local nearestEntity = nil :: number?
		local nearestPosition = nil :: Vector3?
		local nearestDistance = attackThreshold

		for _, structureEntity in ipairs(structures) do
			if type(structureEntity) ~= "number" then
				continue
			end

			local positionResult = structureContext:GetStructurePosition(structureEntity)
			local structurePosition = if positionResult.success then positionResult.value else nil
			if structurePosition ~= nil then
				local structureGeometry =
					resolveTargetGeometry(combatContext, sourcePosition, structureEntity, structurePosition)
				local distance = getGeometryHorizontalDistance(structureGeometry, sourcePosition, structurePosition)
				if distance ~= nil and distance <= nearestDistance then
					nearestEntity = structureEntity
					nearestPosition = getGeometryTargetPosition(structureGeometry, structurePosition)
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
					Damage = role.Damage,
					Cooldown = role.AttackCooldown,
				},
				AdvanceData = advanceData,
			}
		end
	end

	if attackRange > 0 and baseDistance ~= nil and baseDistance <= attackThreshold then
		if type(baseEntity) ~= "number" then
			return {
				AdvanceData = advanceData,
			}
		end

		return {
			TargetEntity = baseEntity,
			AttackTargetKind = "Base",
			AttackData = {
				AbilityId = "EnemyBaseAttack",
				TargetKind = "Base",
				TargetPosition = getGeometryTargetPosition(baseGeometry, baseTargetPosition),
				Damage = role.Damage,
				Cooldown = role.AttackCooldown,
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
			MovementMode = role.MovementMode,
		},
		BuildTargetEntity = buildTargetEntity,
		BuildData = {
			TargetStructureEntity = buildTargetEntity,
		},
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

}

return table.freeze(BasicFactProviders)
