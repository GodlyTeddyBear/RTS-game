--!strict

-- Mirrors jecs.Entity<nil> — entities are nominal number wrappers at runtime.
type Entity = { __T: nil }

--[=[
	@class CombatPerceptionService
	Domain-adjacent service that provides perception methods for behavior tree condition nodes.

	Wraps ECS queries and delegates pure distance/range logic to `TargetSelector`.
	Handles hysteresis (enter/exit thresholds) for range checks and builds frozen
	snapshots of perception facts once per BT tick to avoid redundant queries.

	Pattern: Domain-adjacent (reads from JECS world but performs no mutations).
	All pure logic is delegated to private helpers.
	@server
]=]

--[=[
	@interface PerceptionSnapshot
	@within CombatPerceptionService
	.NearestEnemy Entity? -- Closest alive enemy within detection radius
	.ShouldFlee boolean -- True if HP is below flee threshold
	.AttackOnCooldown boolean -- True if attack cooldown has not elapsed
	.InAttackRange boolean -- True if target is within attack range (with hysteresis)
	.InRangeBand boolean -- True if target is within optimal ranged attack band
	.TooClose boolean -- True if target is closer than minimum attack range
	.IncomingAttack boolean -- True if any alive opponent targeting this entity has ActionState = "Running" (winding up)
	.SkillsReady { [string]: boolean } -- Map of SkillId -> true if off cooldown
]=]

export type PerceptionSnapshot = {
	NearestEnemy: Entity?,
	ShouldFlee: boolean,
	AttackOnCooldown: boolean,
	InAttackRange: boolean,
	InRangeBand: boolean,
	TooClose: boolean,
	IncomingAttack: boolean,
	SkillsReady: { [string]: boolean },
}

local CombatPerceptionService = {}
CombatPerceptionService.__index = CombatPerceptionService

export type TCombatPerceptionService = typeof(setmetatable({}, CombatPerceptionService))

function CombatPerceptionService.new(): TCombatPerceptionService
	local self = setmetatable({}, CombatPerceptionService)
	return self
end

function CombatPerceptionService:Init(registry: any, _name: string)
	self.Registry = registry
	self.TargetSelector = registry:Get("TargetSelector")
end

function CombatPerceptionService:Start()
	self.World = self.Registry:Get("World")
	self.Components = self.Registry:Get("Components")
	self.NPCEntityFactory = self.Registry:Get("NPCEntityFactory")
end

-- ─── Private helpers (pure logic — no ECS reads) ─────────────────────────────

function CombatPerceptionService:_ShouldFlee(health: any, behaviorConfig: any): boolean
	if not behaviorConfig or not behaviorConfig.FleeEnabled then
		return false
	end
	if not health or health.Max <= 0 then
		return false
	end
	local hpPercent = health.Current / health.Max
	return hpPercent > 0 and hpPercent <= behaviorConfig.FleeHPThreshold
end

function CombatPerceptionService:_IsAttackOnCooldown(cooldown: any, currentTime: number): boolean
	if not cooldown then
		return false
	end
	return (currentTime - cooldown.LastAttackTime) < cooldown.Cooldown
end

function CombatPerceptionService:_IsInAttackRange(
	distSq: number,
	behaviorConfig: any,
	isAttacking: boolean,
	detection: any
): boolean
	local range: number
	if behaviorConfig and behaviorConfig.AttackEnterRange then
		range = if isAttacking then behaviorConfig.AttackExitRange else behaviorConfig.AttackEnterRange
	else
		range = if detection then detection.AttackRange else 5
	end
	return distSq <= range * range
end

function CombatPerceptionService:_IsInRangeBand(distSq: number, behaviorConfig: any, isAttacking: boolean): boolean
	if not behaviorConfig or not behaviorConfig.MinAttackRange or not behaviorConfig.MaxAttackRange then
		return false
	end
	local minRange = behaviorConfig.MinAttackRange
	local maxRange = behaviorConfig.MaxAttackRange
	if isAttacking then
		minRange = minRange * 0.8
		maxRange = maxRange * 1.2
	end
	return distSq >= minRange * minRange and distSq <= maxRange * maxRange
end

function CombatPerceptionService:_IsTooClose(distSq: number, behaviorConfig: any): boolean
	if not behaviorConfig or not behaviorConfig.MinAttackRange then
		return false
	end
	return distSq < behaviorConfig.MinAttackRange * behaviorConfig.MinAttackRange
end

function CombatPerceptionService:_HasIncomingAttack(entity: Entity): boolean
	local world = self.World
	local components = self.Components

	local team = world:get(entity, components.TeamComponent)
	local identity = world:get(entity, components.NPCIdentityComponent)
	if not team then
		return false
	end

	-- Determine which tag represents opponents
	local isAdventurer = identity and identity.IsAdventurer or false
	local opponentTag = if isAdventurer then components.EnemyTag else components.AdventurerTag

	for opponentEntity in world:query(opponentTag, components.AliveTag, components.TeamComponent) do
		local opponentTeam = world:get(opponentEntity, components.TeamComponent)
		if opponentTeam and opponentTeam.UserId == team.UserId then
			local actionComp = world:get(opponentEntity, components.CombatActionComponent)
			if actionComp and actionComp.ActionState == "Running" then
				local actionData = actionComp.ActionData
				if actionData and actionData.TargetEntity == entity then
					return true
				end
			end
		end
	end

	return false
end

-- ─── Public API ───────────────────────────────────────────────────────────────

--[=[
	Get the nearest alive enemy for an entity within detection radius.

	Enemies target `AdventurerTag` entities; Adventurers target `EnemyTag` entities.
	@within CombatPerceptionService
	@param entity Entity -- The entity to find enemies for
	@return Entity? -- Nearest enemy entity, or nil if none in range
	@return number? -- Squared distance to nearest enemy, or nil
]=]
function CombatPerceptionService:GetNearestEnemy(entity: Entity): (Entity?, number?)
	local world = self.World
	local components = self.Components

	local myPos = world:get(entity, components.PositionComponent)
	local detection = world:get(entity, components.DetectionComponent)
	local team = world:get(entity, components.TeamComponent)
	local identity = world:get(entity, components.NPCIdentityComponent)
	if not myPos or not detection or not team then
		return nil, nil
	end

	-- Determine which tag to search for (opposite team)
	local isAdventurer = identity and identity.IsAdventurer or false
	local searchTag = if isAdventurer then components.EnemyTag else components.AdventurerTag

	local detRadSq = detection.DetectionRadius * detection.DetectionRadius
	local candidates = {}

	local myPosition = myPos.CFrame.Position

	for targetEntity in world:query(searchTag, components.AliveTag, components.TeamComponent) do
		local targetTeam = world:get(targetEntity, components.TeamComponent)
		if targetTeam and targetTeam.UserId == team.UserId then
			local targetPos = world:get(targetEntity, components.PositionComponent)
			if targetPos then
				local targetPosition = targetPos.CFrame.Position
				local dx = targetPosition.X - myPosition.X
				local dz = targetPosition.Z - myPosition.Z
				local distSq = dx * dx + dz * dz

				if distSq <= detRadSq then
					table.insert(candidates, {
						Entity = targetEntity,
						X = targetPosition.X,
						Y = targetPosition.Y,
						Z = targetPosition.Z,
					})
				end
			end
		end
	end

	if #candidates == 0 then
		return nil, nil
	end

	local nearestEntity: Entity? = self.TargetSelector:SelectNearest(myPosition.X, myPosition.Y, myPosition.Z, candidates)
	if not nearestEntity then
		return nil, nil
	end

	-- Calculate distance to nearest
	local nearestPos = world:get(nearestEntity, components.PositionComponent)
	if nearestPos then
		local nearestPosition = nearestPos.CFrame.Position
		local dx = nearestPosition.X - myPosition.X
		local dz = nearestPosition.Z - myPosition.Z
		local distSq = dx * dx + dz * dz
		return nearestEntity, distSq
	end

	return nearestEntity, nil
end

--[=[
	Check if a target entity is in attack range using hysteresis.

	Uses the larger `AttackExitRange` while attacking, and the smaller
	`AttackEnterRange` when idle to reduce jitter. Falls back to
	`DetectionComponent.AttackRange` if no `BehaviorConfig` exists.
	@within CombatPerceptionService
	@param entity Entity -- The attacker
	@param targetEntity Entity -- The potential target
	@return boolean -- True if target is within attack range
]=]
function CombatPerceptionService:IsInAttackRange(entity: Entity, targetEntity: Entity): boolean
	local world = self.World
	local components = self.Components

	local myPos = world:get(entity, components.PositionComponent)
	local targetPos = world:get(targetEntity, components.PositionComponent)
	if not myPos or not targetPos then
		return false
	end

	local myPosition = myPos.CFrame.Position
	local targetPosition = targetPos.CFrame.Position
	local dx = targetPosition.X - myPosition.X
	local dz = targetPosition.Z - myPosition.Z
	local distSq = dx * dx + dz * dz

	local behaviorConfig = world:get(entity, components.BehaviorConfigComponent)
	local actionComp = world:get(entity, components.CombatActionComponent)
	local isAttacking = actionComp
		and (actionComp.CurrentActionId == "MeleeAttack" or actionComp.CurrentActionId == "RangedAttack")
	local detection = world:get(entity, components.DetectionComponent)

	return self:_IsInAttackRange(distSq, behaviorConfig, isAttacking, detection)
end

--[=[
	Check if a target entity is alive.
	@within CombatPerceptionService
	@param targetEntity Entity
	@return boolean -- True if target has the `AliveTag` component
]=]
function CombatPerceptionService:IsTargetAlive(targetEntity: Entity): boolean
	return self.World:has(targetEntity, self.Components.AliveTag)
end

--[=[
	Get the squared distance between an entity and a target entity.

	Avoids `math.sqrt` for performance during range checks.
	@within CombatPerceptionService
	@param entity Entity
	@param targetEntity Entity
	@return number? -- Squared distance, or nil if positions unavailable
]=]
function CombatPerceptionService:GetDistanceSq(entity: Entity, targetEntity: Entity): number?
	local world = self.World
	local components = self.Components

	local myPos = world:get(entity, components.PositionComponent)
	local targetPos = world:get(targetEntity, components.PositionComponent)
	if not myPos or not targetPos then
		return nil
	end

	local myPosition = myPos.CFrame.Position
	local targetPosition = targetPos.CFrame.Position
	local dx = targetPosition.X - myPosition.X
	local dz = targetPosition.Z - myPosition.Z
	return dx * dx + dz * dz
end

--[=[
	Get the HP percentage of an entity as a normalized value (0.0 to 1.0).
	@within CombatPerceptionService
	@param entity Entity
	@return number -- Health percentage (0 if no health or max is 0)
]=]
function CombatPerceptionService:GetHPPercent(entity: Entity): number
	local health = self.World:get(entity, self.Components.HealthComponent)
	if not health or health.Max <= 0 then
		return 0
	end
	return health.Current / health.Max
end

--[=[
	Check if an entity's attack is on cooldown.
	@within CombatPerceptionService
	@param entity Entity
	@param currentTime number -- `os.clock()` value for this frame
	@return boolean -- True if cooldown has not elapsed
]=]
function CombatPerceptionService:IsAttackOnCooldown(entity: Entity, currentTime: number): boolean
	local cooldown = self.World:get(entity, self.Components.AttackCooldownComponent)
	return self:_IsAttackOnCooldown(cooldown, currentTime)
end

--[=[
	Get the current action state for an entity.
	@within CombatPerceptionService
	@param entity Entity
	@return string? -- Current action ID (e.g., "MeleeAttack"), or nil
	@return string -- Action state (e.g., "Running", "None")
]=]
function CombatPerceptionService:GetCurrentActionState(entity: Entity): (string?, string)
	local actionComp = self.World:get(entity, self.Components.CombatActionComponent)
	if not actionComp then
		return nil, "None"
	end
	return actionComp.CurrentActionId, actionComp.ActionState
end

--[=[
	Get the position of a target entity as a Vector3.
	@within CombatPerceptionService
	@param targetEntity Entity
	@return Vector3? -- World position, or nil if position unavailable
]=]
function CombatPerceptionService:GetTargetPosition(targetEntity: Entity): Vector3?
	local pos = self.World:get(targetEntity, self.Components.PositionComponent)
	if not pos then
		return nil
	end
	return pos.CFrame.Position
end

--[=[
	Check if a target is within the optimal range band for ranged attacks.

	Returns true if the target is between `MinAttackRange` and `MaxAttackRange`.
	Uses hysteresis: if currently attacking, uses a slightly wider band to reduce jitter.
	@within CombatPerceptionService
	@param entity Entity -- The attacker
	@param targetEntity Entity -- The potential target
	@return boolean -- True if target is in the optimal range band
]=]
function CombatPerceptionService:IsInRangeBand(entity: Entity, targetEntity: Entity): boolean
	local world = self.World
	local components = self.Components

	local myPos = world:get(entity, components.PositionComponent)
	local targetPos = world:get(targetEntity, components.PositionComponent)
	if not myPos or not targetPos then
		return false
	end

	local myPosition = myPos.CFrame.Position
	local targetPosition = targetPos.CFrame.Position
	local dx = targetPosition.X - myPosition.X
	local dz = targetPosition.Z - myPosition.Z
	local distSq = dx * dx + dz * dz

	local behaviorConfig = world:get(entity, components.BehaviorConfigComponent)
	local actionComp = world:get(entity, components.CombatActionComponent)
	local isAttacking = actionComp
		and (actionComp.CurrentActionId == "RangedAttack" or actionComp.CurrentActionId == "MeleeAttack")

	return self:_IsInRangeBand(distSq, behaviorConfig, isAttacking)
end

--[=[
	Check if a target is too close (inside minimum attack range).

	Used by ranged NPCs to decide when to reposition or flee.
	@within CombatPerceptionService
	@param entity Entity -- The attacker
	@param targetEntity Entity -- The target
	@return boolean -- True if target is closer than `MinAttackRange`
]=]
function CombatPerceptionService:IsTooClose(entity: Entity, targetEntity: Entity): boolean
	local world = self.World
	local components = self.Components

	local myPos = world:get(entity, components.PositionComponent)
	local targetPos = world:get(targetEntity, components.PositionComponent)
	if not myPos or not targetPos then
		return false
	end

	local myPosition = myPos.CFrame.Position
	local targetPosition = targetPos.CFrame.Position
	local dx = targetPosition.X - myPosition.X
	local dz = targetPosition.Z - myPosition.Z
	local distSq = dx * dx + dz * dz

	local behaviorConfig = world:get(entity, components.BehaviorConfigComponent)
	return self:_IsTooClose(distSq, behaviorConfig)
end

--[=[
	Check if an entity should flee based on its HP threshold.
	@within CombatPerceptionService
	@param entity Entity
	@return boolean -- True if HP is below the flee threshold
]=]
function CombatPerceptionService:ShouldFlee(entity: Entity): boolean
	local components = self.Components
	local behaviorConfig = self.World:get(entity, components.BehaviorConfigComponent)
	local health = self.World:get(entity, components.HealthComponent)
	return self:_ShouldFlee(health, behaviorConfig)
end

--[=[
	Get the entity's own position as a Vector3.
	@within CombatPerceptionService
	@param entity Entity
	@return Vector3? -- World position, or nil if position unavailable
]=]
function CombatPerceptionService:GetPosition(entity: Entity): Vector3?
	local pos = self.World:get(entity, self.Components.PositionComponent)
	if not pos then
		return nil
	end
	return pos.CFrame.Position
end

--[=[
	Build a frozen snapshot of all perception facts for one behavior tree tick.

	Reads each ECS component once and computes all condition booleans via
	private helpers. Eliminates redundant queries during a single BT tick.
	Attach to `perceptionContext.Facts` before running the BT so condition
	nodes read from the snapshot instead of re-querying.
	@within CombatPerceptionService
	@param entity Entity
	@param currentTime number -- `os.clock()` value for this tick
	@return PerceptionSnapshot -- Frozen snapshot of all perception facts
]=]
function CombatPerceptionService:BuildSnapshot(entity: Entity, currentTime: number): PerceptionSnapshot
	local world = self.World
	local components = self.Components

	local myPos = world:get(entity, components.PositionComponent)
	local behaviorConfig = world:get(entity, components.BehaviorConfigComponent)
	local actionComp = world:get(entity, components.CombatActionComponent)
	local cooldown = world:get(entity, components.AttackCooldownComponent)
	local health = world:get(entity, components.HealthComponent)
	local detection = world:get(entity, components.DetectionComponent)

	local nearestEnemy, _ = self:GetNearestEnemy(entity)

	local isAttacking = actionComp
		and (actionComp.CurrentActionId == "MeleeAttack" or actionComp.CurrentActionId == "RangedAttack")

	local inAttackRange = false
	local inRangeBand = false
	local tooClose = false

	if nearestEnemy and myPos then
		local nearestPos = world:get(nearestEnemy, components.PositionComponent)
		if nearestPos then
			local myPosition = myPos.CFrame.Position
			local nearestPosition = nearestPos.CFrame.Position
			local dx = nearestPosition.X - myPosition.X
			local dz = nearestPosition.Z - myPosition.Z
			local distSq = dx * dx + dz * dz

			inAttackRange = self:_IsInAttackRange(distSq, behaviorConfig, isAttacking, detection)
			inRangeBand = self:_IsInRangeBand(distSq, behaviorConfig, isAttacking)
			tooClose = self:_IsTooClose(distSq, behaviorConfig)
		end
	end

	local skillsReady = {}
	local skillSet = self.NPCEntityFactory:GetSkillSet(entity)
	if skillSet then
		for _, skillId in skillSet.Skills do
			skillsReady[skillId] = self.NPCEntityFactory:IsSkillReady(entity, skillId)
		end
	end

	return table.freeze({
		NearestEnemy = nearestEnemy,
		ShouldFlee = self:_ShouldFlee(health, behaviorConfig),
		AttackOnCooldown = self:_IsAttackOnCooldown(cooldown, currentTime),
		InAttackRange = inAttackRange,
		InRangeBand = inRangeBand,
		TooClose = tooClose,
		IncomingAttack = self:_HasIncomingAttack(entity),
		SkillsReady = table.freeze(skillsReady),
	} :: PerceptionSnapshot)
end

--[=[
	Pick a random wander target within the wander radius and verify line-of-sight.

	Casts a ray from the NPC's root toward the candidate point (excluding the NPC's
	own model). Returns the target Vector3 if clear, or nil if the position is
	unavailable or something is blocking the path. Callers should fall back to Idle
	so the behavior tree retries next tick.
	@within CombatPerceptionService
	@param entity Entity
	@param modelInstance Instance? -- The NPC's model instance (used to exclude from raycast)
	@return Vector3? -- Wander target if path is clear, or nil if blocked
]=]
function CombatPerceptionService:GetWanderTarget(entity: any, modelInstance: any?): Vector3?
	local myPos = self:GetPosition(entity)
	if not myPos then
		return nil
	end

	local behaviorConfig = self.World:get(entity, self.Components.BehaviorConfigComponent)
	local wanderRadius = if behaviorConfig and behaviorConfig.WanderRadius then behaviorConfig.WanderRadius else 10

	local angle = math.random() * math.pi * 2
	local dist = math.random() * wanderRadius
	local wanderTarget = Vector3.new(
		myPos.X + math.cos(angle) * dist,
		myPos.Y,
		myPos.Z + math.sin(angle) * dist
	)

	-- Line-of-sight check: reject targets behind walls or geometry.
	local origin = if modelInstance and modelInstance.PrimaryPart
		then modelInstance.PrimaryPart.Position
		else myPos

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	if modelInstance then
		rayParams.FilterDescendantsInstances = { modelInstance }
	end

	local hit = game:GetService("Workspace"):Raycast(origin, wanderTarget - origin, rayParams)
	if hit then
		return nil
	end

	return wanderTarget
end

return CombatPerceptionService
