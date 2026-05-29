--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local AssetFetcher = require(ReplicatedStorage.Utilities.Assets.AssetFetcher)
local BaseContext = require(ServerStorage.Utilities.ContextUtilities.BaseContext)
local ModelPlus = require(ReplicatedStorage.Utilities.ModelPlus)
local Result = require(ReplicatedStorage.Utilities.Result)
local UnitConfig = require(ReplicatedStorage.Contexts.Unit.Config.UnitConfig)
local UnitTypes = require(ReplicatedStorage.Contexts.Unit.Types.UnitTypes)
local EntityCollisionService = require(ServerScriptService.Infrastructure.EntityCollisionService)

local UnitEntityReadService = require(script.Parent.Infrastructure.Entity.UnitEntityReadService)
local UnitEntitySchema = require(script.Parent.Infrastructure.Entity.UnitEntitySchema)
local UnitMovementRuntimeService = require(script.Parent.Infrastructure.Entity.UnitMovementRuntimeService)
local UnitActionExecutionSystem = require(script.Parent.Infrastructure.Entity.UnitActionExecutionSystem)
local UnitAIProfiles = require(script.Parent.Parent.AI.Config.Profiles.UnitAIProfiles)
local UnitSpawnPolicy = require(script.Parent.UnitDomain.Policies.UnitSpawnPolicy)

local SpawnUnitCommand = require(script.Parent.Application.Commands.SpawnUnitCommand)
local DespawnUnitCommand = require(script.Parent.Application.Commands.DespawnUnitCommand)
local CleanupUnitsCommand = require(script.Parent.Application.Commands.CleanupUnitsCommand)
local IssueUnitMoveOrderCommand = require(script.Parent.Application.Commands.IssueUnitMoveOrderCommand)
local GetActiveUnitsQuery = require(script.Parent.Application.Queries.GetActiveUnitsQuery)
local GetOwnerUnitCountQuery = require(script.Parent.Application.Queries.GetOwnerUnitCountQuery)

type SpawnUnitRequest = UnitTypes.SpawnUnitRequest
type SpawnUnitResult = UnitTypes.SpawnUnitResult

local Catch = Result.Catch
local Ok = Result.Ok

local UNIT_TAG = "CombatUnit"

local function moduleSpec(name: string, module: any, cacheAs: string?): BaseContext.TModuleSpec
	return {
		Name = name,
		Module = module,
		CacheAs = cacheAs,
	}
end

local function ensureAnimationsFolderValue(model: Model, animationsFolder: Folder?)
	local animationsFolderRef = model:FindFirstChild("AnimationsFolder")
	if animationsFolderRef ~= nil and not animationsFolderRef:IsA("ObjectValue") then
		animationsFolderRef:Destroy()
		animationsFolderRef = nil
	end

	if animationsFolderRef == nil then
		animationsFolderRef = Instance.new("ObjectValue")
		animationsFolderRef.Name = "AnimationsFolder"
		animationsFolderRef.Parent = model
	end

	if animationsFolder ~= nil then
		(animationsFolderRef :: ObjectValue).Value = animationsFolder
	end
end

local InfrastructureModules: { BaseContext.TModuleSpec } = {
	{
		Name = "UnitEntityReadService",
		Factory = function(service: any, _baseContext: any)
			return UnitEntityReadService.new(service._entityContext)
		end,
		CacheAs = "_unitReadService",
	},
	moduleSpec("UnitMovementRuntimeService", UnitMovementRuntimeService, "_movementRuntimeService"),
}

local DomainModules: { BaseContext.TModuleSpec } = {
	moduleSpec("UnitSpawnPolicy", UnitSpawnPolicy),
}

local ApplicationModules: { BaseContext.TModuleSpec } = {
	moduleSpec("SpawnUnitCommand", SpawnUnitCommand, "_spawnUnitCommand"),
	moduleSpec("DespawnUnitCommand", DespawnUnitCommand, "_despawnUnitCommand"),
	moduleSpec("CleanupUnitsCommand", CleanupUnitsCommand, "_cleanupUnitsCommand"),
	moduleSpec("IssueUnitMoveOrderCommand", IssueUnitMoveOrderCommand, "_issueUnitMoveOrderCommand"),
	moduleSpec("GetActiveUnitsQuery", GetActiveUnitsQuery, "_getActiveUnitsQuery"),
	moduleSpec("GetOwnerUnitCountQuery", GetOwnerUnitCountQuery, "_getOwnerUnitCountQuery"),
}

local UnitContext = Knit.CreateService({
	Name = "UnitContext",
	Client = {},
	Modules = {
		Infrastructure = InfrastructureModules,
		Domain = DomainModules,
		Application = ApplicationModules,
	},
	ExternalServices = {
		{ Name = "AIContext", CacheAs = "_aiContext" },
		{ Name = "CombatContext", CacheAs = "_combatContext" },
		{ Name = "EntityContext", CacheAs = "_entityContext" },
		{ Name = "StructureContext", CacheAs = "_structureContext" },
		{ Name = "TeamContext", CacheAs = "_teamContext" },
		{ Name = "WorldContext", CacheAs = "_worldContext" },
	},
	Teardown = {
		Before = "_BeforeDestroy",
		Fields = {
			{ Field = "_runEndedConnection", Method = "Disconnect" },
			{ Field = "_playerRemovingConnection", Method = "Disconnect" },
		},
	},
})

local UnitBaseContext = BaseContext.new(UnitContext)

function UnitContext:KnitInit()
	UnitBaseContext:KnitInit()
	self._runEndedConnection = nil :: any
	self._playerRemovingConnection = nil :: any
	self._unitAssetRegistry = nil :: any
	self._animationsFolder = nil :: Folder?
	self:_InitializeUnitAssets()
end

function UnitContext:KnitStart()
	UnitBaseContext:KnitStart()

	local entityResult = self:_RegisterEntityInfrastructure()
	if not entityResult.success then
		error(("UnitContext failed to register Entity infrastructure: [%s] %s"):format(
			tostring(entityResult.type),
			tostring(entityResult.message)
		))
	end

	local aiResult = self:_RegisterAIContracts()
	if not aiResult.success then
		error(("UnitContext failed to register AI contracts: [%s] %s"):format(
			tostring(aiResult.type),
			tostring(aiResult.message)
		))
	end

	UnitBaseContext:OnContextEvent("Run", "RunEnded", function()
		self:_OnRunEnded()
	end, "_runEndedConnection")

	UnitBaseContext:OnPlayerRemoving(function(player: Player)
		self:CleanupOwner("Player", tostring(player.UserId))
	end, "_playerRemovingConnection")
end

function UnitContext:_RegisterEntityInfrastructure(): Result.Result<boolean>
	return Catch(function()
		local schemaResult = self._entityContext:RegisterFeatureSchema("Unit", UnitEntitySchema)
		if not schemaResult.success then
			return schemaResult
		end

		local bindingResult = self._entityContext:RegisterInstanceBinding("Unit", {
			FeatureName = "Unit",
			ResolveAsset = function(_entityContext: any, snapshot: any): Instance
				local identity = snapshot.Identity or {}
				local unitId = if type(identity.DefinitionId) == "string" then identity.DefinitionId else UnitConfig.DEFAULT_UNIT_ID
				local unitGuid = if type(identity.EntityId) == "string" then identity.EntityId else tostring(os.clock())
				return self:_BuildUnitModel(unitId, unitGuid)
			end,
			PrepareInstance = function(_entityContext: any, instance: Instance, snapshot: any)
				if not instance:IsA("Model") then
					return
				end
				self:_PrepareUnitModel(instance :: Model, snapshot)
			end,
			BuildRevealAttributes = function(_entityContext: any, snapshot: any)
				local identity = snapshot.Identity or {}
				local ownership = snapshot.Ownership or {}
				return {
					UnitGuid = identity.EntityId,
					UnitId = identity.DefinitionId,
					Faction = ownership.Faction,
					OwnerKind = ownership.OwnerKind,
					OwnerId = ownership.OwnerId,
				}
			end,
			BuildRevealTags = function()
				return {
					[UNIT_TAG] = true,
				}
			end,
			BuildName = function(_entityContext: any, snapshot: any)
				local identity = snapshot.Identity or {}
				return ("Unit_%s_%s"):format(tostring(identity.DefinitionId or "Unit"), tostring(identity.EntityId))
			end,
		})
		if not bindingResult.success then
			return bindingResult
		end

		local syncResult = self._entityContext:RegisterSyncContributor("Unit", {
			FeatureName = "Unit",
			QuerySyncEntities = function(entityContext: any): { number }
				local queryResult = entityContext:Query({
					FeatureName = "Unit",
					Keys = {
						{ Key = "ActiveTag", FeatureName = "Entity" },
						{ Key = "Role", FeatureName = "Unit" },
					},
				})
				return if queryResult.success then queryResult.value else {}
			end,
			QueryPollEntities = function(entityContext: any): { number }
				local queryResult = entityContext:Query({
					FeatureName = "Unit",
					Keys = {
						{ Key = "ActiveTag", FeatureName = "Entity" },
						{ Key = "Role", FeatureName = "Unit" },
					},
				})
				return if queryResult.success then queryResult.value else {}
			end,
			SyncEntity = function(entityContext: any, entity: number, model: Model)
				self:_SyncUnitEntity(entityContext, entity, model)
			end,
			PollEntity = function(entityContext: any, entity: number, model: Model)
				entityContext:Set(entity, "Transform", {
					CFrame = ModelPlus.GetPivot(model),
				}, "Entity")
			end,
		})
		if not syncResult.success then
			return syncResult
		end

		local replicationResult = self._entityContext:RegisterReplicationSurface("Unit", {
			FeatureName = "Unit",
			BuildSchema = function(entityContext: any): any
				local entityComponentsResult = entityContext:GetFeatureComponents("Entity")
				local unitComponentsResult = entityContext:GetFeatureComponents("Unit")
				assert(entityComponentsResult.success, "Unit replication surface missing Entity compiled components")
				assert(unitComponentsResult.success, "Unit replication surface missing Unit compiled components")

				return {
					sharedComponents = {
						entityComponentsResult.value.Identity,
						entityComponentsResult.value.Health,
						unitComponentsResult.value.AnimationState,
						unitComponentsResult.value.AnimationLooping,
					},
					sharedTags = {
						entityComponentsResult.value.ActiveTag,
						unitComponentsResult.value.GoalReachedTag,
					},
				}
			end,
		})
		if not replicationResult.success then
			return replicationResult
		end

		return self._entityContext:RegisterSystem("Execute", {
			Name = "UnitActionExecutionSystem",
			Phase = "Execute",
			Reads = {
				"Unit.Role",
				"Unit.PathState",
				"Unit.BuilderAssignment",
				"Unit.CurrentMoveSpeed",
				"Entity.Transform",
				"Entity.Ownership",
				"AI.ActionIntent",
				"AI.ActionState",
			},
			Writes = {
				"Unit.PathState",
				"Unit.BuilderAssignment",
				"Unit.AnimationState",
				"Unit.AnimationLooping",
				"Entity.Target",
				"Entity.DirtyTag",
			},
			Factory = function(entityFactory: any, _compiledSchemas: any)
				return UnitActionExecutionSystem.new(entityFactory, {
					EntityContext = self._entityContext,
					StructureContext = self._structureContext,
					UnitReadService = self._unitReadService,
					MovementRuntimeService = self._movementRuntimeService,
				})
			end,
		})
	end, "UnitContext:RegisterEntityInfrastructure")
end

function UnitContext:_RegisterAIContracts(): Result.Result<boolean>
	return Catch(function()
		local function acceptDuplicate(result: Result.Result<any>, duplicateType: string): Result.Result<boolean>
			if result.success or result.type == duplicateType then
				return Ok(true)
			end
			return result
		end

		local evaluations = {
			{
				EvaluationId = "UnitHasGoalTarget",
				Evaluate = function(context: any): boolean
					return type(context) == "table" and type(context.Facts) == "table" and context.Facts.UnitHasGoalTarget == true
				end,
			},
			{
				EvaluationId = "UnitHasBuildableStructure",
				Evaluate = function(context: any): boolean
					return type(context) == "table"
						and type(context.Facts) == "table"
						and context.Facts.UnitHasBuildableStructure == true
				end,
			},
		}
		for _, evaluation in ipairs(evaluations) do
			local result = acceptDuplicate(self._aiContext:RegisterEvaluation(evaluation), "DuplicateEvaluation")
			if not result.success then
				return result
			end
		end

		local actions = {
			{
				ActionId = "UnitIdle",
				ProduceIntent = function(_context: any): any
					return {
						Data = {
							Reason = "Idle",
						},
					}
				end,
			},
			{
				ActionId = "UnitManualMove",
				ProduceIntent = function(context: any): any
					local facts = if type(context) == "table" and type(context.Facts) == "table" then context.Facts else {}
					return {
						Data = facts.UnitMoveData,
					}
				end,
			},
			{
				ActionId = "UnitBuildStructure",
				ProduceIntent = function(context: any): any
					local facts = if type(context) == "table" and type(context.Facts) == "table" then context.Facts else {}
					return {
						TargetEntity = facts.UnitBuildTargetEntity,
						Data = facts.UnitBuildData,
					}
				end,
			},
		}
		for _, action in ipairs(actions) do
			local result = acceptDuplicate(self._aiContext:RegisterActionDefinition(action), "DuplicateActionDefinition")
			if not result.success then
				return result
			end
		end

		local behaviorResult = acceptDuplicate(self._aiContext:RegisterBehaviorDefinition({
			DefinitionId = "UnitBuilderBehavior",
			Definition = {
				Priority = {
					{
						Sequence = {
							"UnitHasGoalTarget",
							"UnitManualMove",
						},
					},
					{
						Sequence = {
							"UnitHasBuildableStructure",
							"UnitBuildStructure",
						},
					},
					"UnitIdle",
				},
			},
		}), "DuplicateBehaviorDefinition")
		if not behaviorResult.success then
			return behaviorResult
		end

		local providerResult = acceptDuplicate(self._aiContext:RegisterFactProvider({
			ProviderId = "UnitFacts",
			BuildFacts = function(context: any): any
				return self:_BuildUnitFacts(context)
			end,
		}), "DuplicateFactProvider")
		if not providerResult.success then
			return providerResult
		end

		for _, profilePayload in pairs(UnitAIProfiles) do
			local profileResult = acceptDuplicate(self._aiContext:RegisterProfile(profilePayload), "DuplicateProfile")
			if not profileResult.success then
				return profileResult
			end
		end

		return Ok(true)
	end, "UnitContext:RegisterAIContracts")
end

function UnitContext:_InitializeUnitAssets()
	local assetsRoot = ReplicatedStorage:FindFirstChild("Assets")
	if assetsRoot == nil or not assetsRoot:IsA("Folder") then
		return
	end

	local unitsFolder = assetsRoot:FindFirstChild("Units")
	if unitsFolder ~= nil and unitsFolder:IsA("Folder") then
		self._unitAssetRegistry = AssetFetcher.CreateUnitRegistry(unitsFolder)
	end

	local animationsFolder = assetsRoot:FindFirstChild("Animations")
	if animationsFolder ~= nil and animationsFolder:IsA("Folder") then
		self._animationsFolder = animationsFolder
	end
end

function UnitContext:_BuildUnitModel(unitId: string, unitGuid: string): Model
	if self._unitAssetRegistry ~= nil then
		local model = self._unitAssetRegistry:GetUnitModel(unitId)
		if model ~= nil then
			return model
		end
	end

	local definition = UnitConfig.Definitions[unitId] or UnitConfig.Definitions[UnitConfig.DEFAULT_UNIT_ID]
	assert(definition ~= nil, "Unknown unit id: " .. tostring(unitId))

	local model = Instance.new("Model")
	model.Name = "Unit_" .. unitId .. "_" .. unitGuid

	local rootPart = Instance.new("Part")
	rootPart.Name = "HumanoidRootPart"
	rootPart.Size = definition.ModelScale
	rootPart.Color = definition.ModelColor
	rootPart.Material = Enum.Material.SmoothPlastic
	rootPart.Anchored = false
	rootPart.CanCollide = false
	rootPart.Parent = model

	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = definition.MaxHp
	humanoid.Health = definition.MaxHp
	humanoid.WalkSpeed = definition.MoveSpeed
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.Parent = model

	model.PrimaryPart = rootPart
	return model
end

function UnitContext:_PrepareUnitModel(model: Model, snapshot: any)
	local identity = snapshot.Identity or {}
	local ownership = snapshot.Ownership or {}
	local unitId = if type(identity.DefinitionId) == "string" and identity.DefinitionId ~= ""
		then identity.DefinitionId
		else UnitConfig.DEFAULT_UNIT_ID
	local unitGuid = if type(identity.EntityId) == "string" and identity.EntityId ~= "" then identity.EntityId else tostring(os.clock())
	local definition = UnitConfig.Definitions[unitId] or UnitConfig.Definitions[UnitConfig.DEFAULT_UNIT_ID]
	assert(definition ~= nil, "Unknown unit id: " .. tostring(unitId))

	model.Name = "Unit_" .. unitId .. "_" .. unitGuid
	model:SetAttribute("UnitGuid", unitGuid)
	model:SetAttribute("UnitId", unitId)
	model:SetAttribute("Faction", ownership.Faction)
	model:SetAttribute("OwnerKind", ownership.OwnerKind)
	model:SetAttribute("OwnerId", ownership.OwnerId)
	ensureAnimationsFolderValue(model, self._animationsFolder)

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		humanoid = Instance.new("Humanoid")
		humanoid.Parent = model
	end
	humanoid.MaxHealth = definition.MaxHp
	humanoid.Health = definition.MaxHp
	humanoid.WalkSpeed = definition.MoveSpeed
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

	if model.PrimaryPart == nil then
		local rootPart = model:FindFirstChild("HumanoidRootPart")
		if rootPart ~= nil and rootPart:IsA("BasePart") then
			model.PrimaryPart = rootPart
		end
	end

	assert(model.PrimaryPart ~= nil, "Unit model missing PrimaryPart: " .. model.Name)
	model.PrimaryPart.Anchored = false
	model:SetAttribute("AnimationState", model:GetAttribute("AnimationState") or "Idle")
	model:SetAttribute("AnimationLooping", if model:GetAttribute("AnimationLooping") == nil then true else model:GetAttribute("AnimationLooping"))

	local transform = snapshot.Transform
	if type(transform) == "table" and typeof(transform.CFrame) == "CFrame" then
		ModelPlus.MoveToCFrame(model, transform.CFrame)
	end
	EntityCollisionService:ApplyModel(model)
end

function UnitContext:_SyncUnitEntity(entityContext: any, entity: number, model: Model)
	local identity = self:_ReadEntityValue(entityContext, entity, "Identity", "Entity")
	local ownership = self:_ReadEntityValue(entityContext, entity, "Ownership", "Entity")
	local health = self:_ReadEntityValue(entityContext, entity, "Health", "Entity")
	local role = self:_ReadEntityValue(entityContext, entity, "Role", "Unit")
	local currentMoveSpeed = self:_ReadEntityValue(entityContext, entity, "CurrentMoveSpeed", "Unit")
	local animationState = self:_ReadEntityValue(entityContext, entity, "AnimationState", "Unit")
	local animationLooping = self:_ReadEntityValue(entityContext, entity, "AnimationLooping", "Unit")

	if type(identity) == "table" then
		model:SetAttribute("UnitGuid", identity.EntityId)
		model:SetAttribute("UnitId", identity.DefinitionId)
	end
	if type(ownership) == "table" then
		model:SetAttribute("Faction", ownership.Faction)
		model:SetAttribute("OwnerKind", ownership.OwnerKind)
		model:SetAttribute("OwnerId", ownership.OwnerId)
	end
	if type(role) == "table" then
		model:SetAttribute("UnitRole", role.Role)
		model:SetAttribute("UnitDisplayName", role.DisplayName)
	end
	if type(health) == "table" then
		model:SetAttribute("Health", health.Current)
		model:SetAttribute("MaxHealth", health.Max)
	end
	if type(animationState) == "string" then
		model:SetAttribute("AnimationState", animationState)
	end
	if type(animationLooping) == "boolean" then
		model:SetAttribute("AnimationLooping", animationLooping)
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid ~= nil then
		if type(health) == "table" and type(health.Max) == "number" then
			humanoid.MaxHealth = health.Max
			humanoid.Health = health.Current
		end
		if type(currentMoveSpeed) == "table" and type(currentMoveSpeed.Value) == "number" then
			humanoid.WalkSpeed = currentMoveSpeed.Value
		end
	end
end

function UnitContext:_BuildUnitFacts(context: any): any
	if type(context) ~= "table" or type(context.Entity) ~= "number" then
		return {}
	end

	local entity = context.Entity
	local role = self._unitReadService:GetRole(entity)
	if type(role) ~= "table" then
		return {}
	end

	local pathState = self._unitReadService:GetPathState(entity)
	local hasGoalTarget = type(pathState) == "table"
		and pathState.GoalPosition ~= nil
		and pathState.FailedGoalRevision ~= pathState.GoalRevision
	local buildTargetEntity = self:_ResolveBuildTargetFact(entity)

	return {
		UnitHasGoalTarget = hasGoalTarget == true,
		UnitMoveData = {
			GoalPosition = if type(pathState) == "table" then pathState.GoalPosition else nil,
		},
		UnitHasBuildableStructure = type(buildTargetEntity) == "number",
		UnitBuildTargetEntity = buildTargetEntity,
		UnitBuildData = {
			TargetStructureEntity = buildTargetEntity,
		},
	}
end

function UnitContext:_ResolveBuildTargetFact(entity: number): number?
	local role = self._unitReadService:GetRole(entity)
	if type(role) ~= "table" or type(role.BuildWorkPerSecond) ~= "number" or type(role.BuildRange) ~= "number" then
		return nil
	end

	local ownership = self._unitReadService:GetOwnership(entity)
	if type(ownership) ~= "table" or ownership.OwnerKind ~= "Player" then
		return nil
	end

	local ownerUserId = tonumber(ownership.OwnerId)
	local cframe = self._unitReadService:GetEntityCFrame(entity)
	if ownerUserId == nil or cframe == nil then
		return nil
	end

	local assignment = self._unitReadService:GetBuilderAssignment(entity)
	local assignedEntity = if type(assignment) == "table" then assignment.TargetStructureEntity else nil
	if type(assignedEntity) == "number" then
		local assignedResult =
			self._structureContext:IsStructureBuildableForBuilder(assignedEntity, ownerUserId, cframe.Position, role.BuildRange)
		if assignedResult.success and assignedResult.value == true then
			return assignedEntity
		end
	end

	local result = self._structureContext:FindNearestOwnedUnfinishedStructure(ownerUserId, cframe.Position, math.huge)
	return if result.success then result.value else nil
end

function UnitContext:_ReadEntityValue(entityContext: any, entity: number, key: string, featureName: string): any
	local result = entityContext:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

function UnitContext:SpawnUnit(request: SpawnUnitRequest): Result.Result<SpawnUnitResult>
	return Catch(function()
		return self._spawnUnitCommand:Execute(request)
	end, "Unit:SpawnUnit")
end

function UnitContext:DespawnUnit(entity: number): Result.Result<boolean>
	return Catch(function()
		return self._despawnUnitCommand:Execute(entity)
	end, "Unit:DespawnUnit")
end

function UnitContext:CleanupOwner(ownerKind: string, ownerId: string): Result.Result<boolean>
	return Catch(function()
		return self._cleanupUnitsCommand:Execute(ownerKind, ownerId)
	end, "Unit:CleanupOwner")
end

function UnitContext:CleanupAll(): Result.Result<boolean>
	return Catch(function()
		return self._cleanupUnitsCommand:Execute(nil, nil)
	end, "Unit:CleanupAll")
end

function UnitContext:IssueMoveOrder(player: Player, request: UnitTypes.IssueMoveOrderRequest): Result.Result<number>
	return Catch(function()
		return self._issueUnitMoveOrderCommand:Execute(player, request)
	end, "Unit:IssueMoveOrder")
end

function UnitContext:GetActiveUnits(): Result.Result<{ number }>
	return Catch(function()
		return self._getActiveUnitsQuery:Execute()
	end, "Unit:GetActiveUnits")
end

function UnitContext:GetOwnerUnitCount(ownerKind: string, ownerId: string): Result.Result<number>
	return Catch(function()
		return self._getOwnerUnitCountQuery:Execute(ownerKind, ownerId)
	end, "Unit:GetOwnerUnitCount")
end

function UnitContext:WarmFastFlowForRun(): Result.Result<boolean>
	return Catch(function()
		return Ok(self._movementRuntimeService:WarmFastFlowForRun())
	end, "Unit:WarmFastFlowForRun")
end

function UnitContext:GetSchedulerBindingStatus(targetField: string): Result.Result<any>
	return Ok(UnitBaseContext:GetSchedulerBindingStatus(targetField))
end

function UnitContext:_OnRunEnded()
	local result = self:CleanupAll()
	if not result.success then
		Result.MentionError("Unit:RunEnded", "Failed to cleanup units after run ended", {
			CauseType = result.type,
			CauseMessage = result.message,
		}, result.type)
	end
end

function UnitContext:_BeforeDestroy()
	local result = self:CleanupAll()
	if not result.success then
		Result.MentionError("Unit:Destroy", "Cleanup failed during destroy", {
			CauseType = result.type,
			CauseMessage = result.message,
		}, result.type)
	end
end

function UnitContext:Destroy()
	local destroyResult = UnitBaseContext:Destroy()
	if not destroyResult.success then
		Result.MentionError("Unit:Destroy", "BaseContext teardown failed", {
			CauseType = destroyResult.type,
			CauseMessage = destroyResult.message,
		}, destroyResult.type)
	end
end

function UnitContext.Client:IssueMoveOrder(player: Player, request: UnitTypes.IssueMoveOrderRequest): boolean
	local result = self.Server:IssueMoveOrder(player, request)
	return result.success and result.value > 0
end

return UnitContext
