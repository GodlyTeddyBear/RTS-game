--!strict

--[=[
    @class UnitServiceProxyResolverFactory
    Builds the runtime service proxies that let unit behaviors talk back to unit ECS and movement services.

    @server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UnitConfig = require(ReplicatedStorage.Contexts.Unit.Config.UnitConfig)

local UnitServiceProxyResolverFactory = {}

local function _ResolveBuilderDefinition(unitEntityFactory: any, entity: number): any?
	local identity = unitEntityFactory:GetIdentity(entity)
	local unitId = if identity ~= nil then identity.UnitId else nil
	if type(unitId) ~= "string" then
		return nil
	end

	return UnitConfig.Definitions[unitId]
end

local function _ResolveBuilderOwnerUserId(unitEntityFactory: any, entity: number): number?
	local ownership = unitEntityFactory:GetOwnership(entity)
	if ownership == nil or ownership.OwnerKind ~= "Player" then
		return nil
	end

	local ownerUserId = tonumber(ownership.OwnerId)
	if type(ownerUserId) ~= "number" then
		return nil
	end

	return ownerUserId
end

-- Creates the proxy bundle used by the behavior runtime to interact with unit ECS and optional movement services.
function UnitServiceProxyResolverFactory.Create(dependencies: {
	UnitEntityFactory: any,
	MovementProxyResolver: any?,
	StructureContext: any?,
	GetRuntimeOwner: (() -> any)?,
	}): any
	return table.freeze({
		-- Builds the per-entity runtime service surface consumed by behavior executors.
		BuildServices = function(entity: number, currentTime: number, tickId: number?): { [string]: any }
			local unitEntityFactory = dependencies.UnitEntityFactory
			local structureContext = dependencies.StructureContext
			local services = {
				CurrentTime = currentTime,
				UnitEntityFactory = {
					ResolveRuntimeEntity = function(_proxy: any, _runtimeId: number): number
						return entity
					end,
					IsActive = function(_proxy: any, _runtimeId: number): boolean
						return unitEntityFactory:IsActive(entity)
					end,
					GetPathState = function(_proxy: any, _runtimeId: number)
						return unitEntityFactory:GetPathState(entity)
					end,
					HasActionableGoal = function(_proxy: any, _runtimeId: number): boolean
						return unitEntityFactory:HasActionableGoal(entity)
					end,
					GetIdentity = function(_proxy: any, _runtimeId: number)
						return unitEntityFactory:GetIdentity(entity)
					end,
					GetPosition = function(_proxy: any, _runtimeId: number)
						return unitEntityFactory:GetPosition(entity)
					end,
					GetAttackCooldown = function(_proxy: any, _runtimeId: number)
						return unitEntityFactory:GetAttackCooldown(entity)
					end,
					GetCombatAction = function(_proxy: any, _runtimeId: number)
						return unitEntityFactory:GetCombatAction(entity)
					end,
					GetBehaviorConfig = function(_proxy: any, _runtimeId: number)
						return unitEntityFactory:GetBehaviorConfig(entity)
					end,
					SetGoalPosition = function(_proxy: any, _runtimeId: number, goalPosition: Vector3)
						unitEntityFactory:SetGoalPosition(entity, goalPosition)
					end,
					ClearGoalPosition = function(_proxy: any, _runtimeId: number)
						unitEntityFactory:ClearGoalPosition(entity)
					end,
					MarkGoalFailedCurrentRevision = function(_proxy: any, _runtimeId: number)
						unitEntityFactory:MarkGoalFailedCurrentRevision(entity)
					end,
					SetTarget = function(
						_proxy: any,
						_runtimeId: number,
						targetEntity: number?,
						targetKind: "Enemy" | "Structure" | "Base"
					)
						unitEntityFactory:SetTarget(entity, targetEntity, targetKind)
					end,
					ClearTarget = function(_proxy: any, _runtimeId: number)
						unitEntityFactory:ClearTarget(entity)
					end,
					SetLastAttackTime = function(_proxy: any, _runtimeId: number, lastAttackTime: number)
						unitEntityFactory:SetLastAttackTime(entity, lastAttackTime)
					end,
					PromoteToCommitted = function(_proxy: any, _runtimeId: number)
						unitEntityFactory:PromoteToCommitted(entity)
					end,
					SetCombatAction = function(_proxy: any, _runtimeId: number, action: any)
						unitEntityFactory:SetCombatAction(entity, action)
					end,
					ClearAction = function(_proxy: any, _runtimeId: number)
						unitEntityFactory:ClearAction(entity)
					end,
					SetBehaviorConfig = function(_proxy: any, _runtimeId: number, config: { TickInterval: number })
						unitEntityFactory:SetBehaviorConfig(entity, config)
					end,
					GetLockOn = function(_proxy: any, _runtimeId: number)
						return unitEntityFactory:GetLockOn(entity)
					end,
					SetLockOn = function(_proxy: any, _runtimeId: number, lockOn: any)
						unitEntityFactory:SetLockOn(entity, lockOn)
					end,
					ClearLockOn = function(_proxy: any, _runtimeId: number)
						unitEntityFactory:ClearLockOn(entity)
					end,
					MarkGoalReached = function(_proxy: any, _runtimeId: number)
						unitEntityFactory:MarkGoalReached(entity)
					end,
					ClearGoalReached = function(_proxy: any, _runtimeId: number)
						unitEntityFactory:ClearGoalReached(entity)
					end,
					SetPathMoving = function(_proxy: any, _runtimeId: number, isMoving: boolean)
						unitEntityFactory:SetPathMoving(entity, isMoving)
					end,
					GetBuilderAssignment = function(_proxy: any, _runtimeId: number)
						return unitEntityFactory:GetBuilderAssignment(entity)
					end,
					SetBuilderAssignment = function(_proxy: any, _runtimeId: number, targetStructureEntity: number?)
						unitEntityFactory:SetBuilderAssignment(entity, targetStructureEntity)
					end,
					ClearBuilderAssignment = function(_proxy: any, _runtimeId: number)
						unitEntityFactory:ClearBuilderAssignment(entity)
					end,
				},
			}

			services.BuilderConstructionService = {
				GetBuildWorkPerSecond = function(_proxy: any, _runtimeId: number): number?
					local definition = _ResolveBuilderDefinition(unitEntityFactory, entity)
					local value = if definition ~= nil then definition.BuildWorkPerSecond else nil
					return if type(value) == "number" and value > 0 then value else nil
				end,
				GetBuildRange = function(_proxy: any, _runtimeId: number): number?
					local definition = _ResolveBuilderDefinition(unitEntityFactory, entity)
					local value = if definition ~= nil then definition.BuildRange else nil
					return if type(value) == "number" and value > 0 then value else nil
				end,
				GetAssignedStructureEntity = function(_proxy: any, _runtimeId: number): number?
					local assignment = unitEntityFactory:GetBuilderAssignment(entity)
					return if assignment ~= nil then assignment.TargetStructureEntity else nil
				end,
				SetAssignedStructureEntity = function(_proxy: any, _runtimeId: number, targetStructureEntity: number?)
					unitEntityFactory:SetBuilderAssignment(entity, targetStructureEntity)
				end,
				ClearAssignedStructureEntity = function(_proxy: any, _runtimeId: number)
					unitEntityFactory:ClearBuilderAssignment(entity)
				end,
				GetStructurePosition = function(_proxy: any, _runtimeId: number, structureEntity: number): Vector3?
					if structureContext == nil then
						return nil
					end

					local result = structureContext:GetStructurePosition(structureEntity)
					return if result.success then result.value else nil
				end,
				IsStructureBuildableForBuilder = function(_proxy: any, _runtimeId: number, structureEntity: number): boolean
					if structureContext == nil then
						return false
					end
					if services.BuilderConstructionService:GetBuildWorkPerSecond(entity) == nil then
						return false
					end
					if services.BuilderConstructionService:GetBuildRange(entity) == nil then
						return false
					end

					local ownerUserId = _ResolveBuilderOwnerUserId(unitEntityFactory, entity)
					if ownerUserId == nil then
						return false
					end

					local transform = unitEntityFactory:GetPosition(entity)
					local builderPosition = if transform ~= nil then transform.CFrame.Position else nil
					local buildRange = services.BuilderConstructionService:GetBuildRange(entity)
					local result =
						structureContext:IsStructureBuildableForBuilder(structureEntity, ownerUserId, builderPosition, buildRange)
					return result.success and result.value == true
				end,
				FindNearestOwnedUnfinishedStructure = function(_proxy: any, _runtimeId: number): number?
					if structureContext == nil then
						return nil
					end
					if services.BuilderConstructionService:GetBuildWorkPerSecond(entity) == nil then
						return nil
					end
					if services.BuilderConstructionService:GetBuildRange(entity) == nil then
						return nil
					end

					local ownerUserId = _ResolveBuilderOwnerUserId(unitEntityFactory, entity)
					if ownerUserId == nil then
						return nil
					end

					local transform = unitEntityFactory:GetPosition(entity)
					local builderPosition = if transform ~= nil then transform.CFrame.Position else nil
					if builderPosition == nil then
						return nil
					end

					local result =
						structureContext:FindNearestOwnedUnfinishedStructure(ownerUserId, builderPosition, services.BuilderConstructionService:GetBuildRange(entity))
					return if result.success then result.value else nil
				end,
				IsBuilderWithinBuildRange = function(_proxy: any, _runtimeId: number, structureEntity: number): boolean
					if structureContext == nil then
						return false
					end

					local buildRange = services.BuilderConstructionService:GetBuildRange(entity)
					if buildRange == nil then
						return false
					end

					local transform = unitEntityFactory:GetPosition(entity)
					local builderPosition = if transform ~= nil then transform.CFrame.Position else nil
					local result =
						structureContext:IsStructureBuildableForBuilder(structureEntity, _ResolveBuilderOwnerUserId(unitEntityFactory, entity) or -1, builderPosition, buildRange)
					return result.success and result.value == true
				end,
				ContributeToStructure = function(_proxy: any, _runtimeId: number, structureEntity: number, dt: number)
					if structureContext == nil then
						return nil
					end

					local buildWorkPerSecond = services.BuilderConstructionService:GetBuildWorkPerSecond(entity)
					if buildWorkPerSecond == nil or type(dt) ~= "number" or dt <= 0 then
						return nil
					end

					return structureContext:ContributeConstruction(structureEntity, buildWorkPerSecond * dt, {
						BuilderEntity = entity,
					})
				end,
			}

			if dependencies.MovementProxyResolver ~= nil then
				services.MovementService = dependencies.MovementProxyResolver.CreateProxy(entity)
			end
			if type(tickId) == "number" then
				services.TickId = tickId
			end
			if dependencies.GetRuntimeOwner ~= nil then
				services.UnitContext = dependencies.GetRuntimeOwner()
			end

			return services
		end,
	})
end

return table.freeze(UnitServiceProxyResolverFactory)
