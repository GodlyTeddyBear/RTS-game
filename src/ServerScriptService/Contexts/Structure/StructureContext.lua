--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local AssetFetcher = require(ReplicatedStorage.Utilities.Assets.AssetFetcher)
local BaseContext = require(ServerStorage.Utilities.ContextUtilities.BaseContext)
local ModelPlus = require(ReplicatedStorage.Utilities.ModelPlus)
local PlacementTypes = require(ReplicatedStorage.Contexts.Placement.Types.PlacementTypes)
local Result = require(ReplicatedStorage.Utilities.Result)
local StructureConfig = require(ReplicatedStorage.Contexts.Structure.Config.StructureConfig)
local StructureTypes = require(ReplicatedStorage.Contexts.Structure.Types.StructureTypes)
local TeamTypes = require(ReplicatedStorage.Contexts.Team.Types.TeamTypes)
local EntityCollisionService = require(ServerScriptService.Infrastructure.EntityCollisionService)

local StructureEntityReadService = require(script.Parent.Infrastructure.Entity.StructureEntityReadService)
local StructureEntitySchema = require(script.Parent.Infrastructure.Entity.StructureEntitySchema)
local StructureExtractionSystem = require(script.Parent.Infrastructure.Systems.StructureExtractionSystem)
local RegisterStructurePolicy = require(script.Parent.StructureDomain.Policies.RegisterStructurePolicy)
local StructureAIBehaviors = require(script.Parent.Config.AIBehaviors)
local StructureAIProfiles = require(script.Parent.Config.AIProfiles)
local RegisterStructureCommand = require(script.Parent.Application.Commands.RegisterStructureCommand)
local AdvanceConstructionCommand = require(script.Parent.Application.Commands.AdvanceConstructionCommand)
local ApplyDamageStructureCommand = require(script.Parent.Application.Commands.ApplyDamageStructureCommand)
local CleanupAllCommand = require(script.Parent.Application.Commands.CleanupAllCommand)
local GetActiveStructuresQuery = require(script.Parent.Application.Queries.GetActiveStructuresQuery)
local GetStructureCountQuery = require(script.Parent.Application.Queries.GetStructureCountQuery)

local Catch = Result.Catch
local Ok = Result.Ok

type StructureRecord = PlacementTypes.StructureRecord
type RunState = "Idle" | "Prep" | "Wave" | "Resolution" | "Climax" | "Endless" | "RunEnd"

local ANIMATED_STRUCTURE_TAG = "AnimatedStructure"

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

local function ensureHumanoid(model: Model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		humanoid = Instance.new("Humanoid")
		humanoid.Parent = model
	end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
end

local InfrastructureModules: { BaseContext.TModuleSpec } = {
	{
		Name = "StructureEntityReadService",
		Factory = function(service: any, _baseContext: any)
			return StructureEntityReadService.new(service._entityContext)
		end,
		CacheAs = "_structureReadService",
	},
}

local DomainModules: { BaseContext.TModuleSpec } = {
	moduleSpec("RegisterStructurePolicy", RegisterStructurePolicy),
}

local ApplicationModules: { BaseContext.TModuleSpec } = {
	moduleSpec("RegisterStructureCommand", RegisterStructureCommand, "_registerStructureCommand"),
	moduleSpec("AdvanceConstructionCommand", AdvanceConstructionCommand, "_advanceConstructionCommand"),
	moduleSpec("ApplyDamageStructureCommand", ApplyDamageStructureCommand, "_applyDamageStructureCommand"),
	moduleSpec("CleanupAllCommand", CleanupAllCommand, "_cleanupAllCommand"),
	moduleSpec("GetActiveStructuresQuery", GetActiveStructuresQuery, "_getActiveStructuresQuery"),
	moduleSpec("GetStructureCountQuery", GetStructureCountQuery, "_getStructureCountQuery"),
}

local StructureContext = Knit.CreateService({
	Name = "StructureContext",
	Client = {},
	Modules = {
		Infrastructure = InfrastructureModules,
		Domain = DomainModules,
		Application = ApplicationModules,
	},
	ExternalServices = {
		{ Name = "AIContext", CacheAs = "_aiContext" },
		{ Name = "EntityContext", CacheAs = "_entityContext" },
		{ Name = "EnemyContext", CacheAs = "_enemyContext" },
		{ Name = "CombatContext", CacheAs = "_combatContext" },
		{ Name = "MiningContext", CacheAs = "_miningContext" },
		{ Name = "TeamContext", CacheAs = "_teamContext" },
		{ Name = "RunContext", CacheAs = "_runContext" },
		{ Name = "PlacementContext", CacheAs = "_placementContext" },
	},
	Teardown = {
		Before = "_BeforeDestroy",
		Fields = {
			{ Field = "_structurePlacedConnection", Method = "Disconnect" },
			{ Field = "_runStateChangedConnection", Method = "Disconnect" },
		},
	},
})

local StructureBaseContext = BaseContext.new(StructureContext)

function StructureContext:KnitInit()
	StructureBaseContext:KnitInit()
	self._structurePlacedConnection = nil :: RBXScriptConnection?
	self._runStateChangedConnection = nil :: RBXScriptConnection?
	self._structureAssetRegistry = nil :: any
	self._animationsFolder = nil :: Folder?
	self:_InitializeStructureAssets()
end

function StructureContext:KnitStart()
	StructureBaseContext:KnitStart()

	local entityResult = self:_RegisterEntityInfrastructure()
	if not entityResult.success then
		error(("StructureContext failed to register Entity infrastructure: [%s] %s"):format(
			tostring(entityResult.type),
			tostring(entityResult.message)
		))
	end

	local aiResult = self:_RegisterAIContracts()
	if not aiResult.success then
		error(("StructureContext failed to register AI contracts: [%s] %s"):format(
			tostring(aiResult.type),
			tostring(aiResult.message)
		))
	end

	self._structurePlacedConnection = self._placementContext.StructurePlaced:Connect(function(record: StructureRecord)
		local result = self:RegisterStructure(record)
		if not result.success then
			Result.MentionError("Structure:OnStructurePlaced", "Failed to register structure", {
				CauseType = result.type,
				CauseMessage = result.message,
				InstanceId = record.InstanceId,
				StructureType = record.StructureType,
			}, result.type)
		end
	end)

	self._runStateChangedConnection = self._runContext.StateChanged:Connect(function(newState: RunState, previousState: RunState)
		local isRunEndCleanup = newState == "RunEnd"
		local isFreshRunStartCleanup = previousState == "Idle" and newState == "Prep"
		if not isRunEndCleanup and not isFreshRunStartCleanup then
			return
		end

		local result = self:CleanupAll()
		if not result.success then
			Result.MentionError("Structure:OnRunEnd", "Failed to cleanup structures", {
				CauseType = result.type,
				CauseMessage = result.message,
			}, result.type)
		end
	end)
end

function StructureContext:_RegisterEntityInfrastructure(): Result.Result<boolean>
	return Catch(function()
		local schemaResult = self._entityContext:RegisterFeatureSchema("Structure", StructureEntitySchema)
		if not schemaResult.success then
			return schemaResult
		end

		local bindingResult = self._entityContext:RegisterInstanceBinding("Structure", {
			FeatureName = "Structure",
			ResolveAsset = function(_entityContext: any, snapshot: any): Instance
				local stats = snapshot.FeatureData.Stats or {}
				return self:_BuildStructureModel(stats.StructureType)
			end,
			PrepareInstance = function(_entityContext: any, instance: Instance, snapshot: any)
				if not instance:IsA("Model") then
					return
				end
				self:_PrepareStructureModel(instance :: Model, snapshot)
			end,
			BuildRevealAttributes = function(_entityContext: any, snapshot: any)
				local identity = snapshot.Identity or {}
				local stats = snapshot.FeatureData.Stats or {}
				local sourcePlacement = snapshot.FeatureData.SourcePlacement or {}
				return {
					PlacementInstanceId = sourcePlacement.InstanceId,
					StructureId = identity.EntityId,
					StructureType = stats.StructureType or identity.DefinitionId,
				}
			end,
			BuildRevealTags = function()
				return {
					[ANIMATED_STRUCTURE_TAG] = true,
				}
			end,
			BuildName = function(_entityContext: any, snapshot: any)
				local identity = snapshot.Identity or {}
				local stats = snapshot.FeatureData.Stats or {}
				return ("%s_%s"):format(tostring(stats.StructureType or "Structure"), tostring(identity.EntityId))
			end,
		})
		if not bindingResult.success then
			return bindingResult
		end

		local syncResult = self._entityContext:RegisterSyncContributor("Structure", {
			FeatureName = "Structure",
			QuerySyncEntities = function(entityContext: any): { number }
				local queryResult = entityContext:Query({
					FeatureName = "Structure",
					Keys = { "PlacedTag" },
				})
				return if queryResult.success then queryResult.value else {}
			end,
			BuildRuntimeAttributes = function(entityContext: any, entity: number)
				local identity = self:_ReadEntityValue(entityContext, entity, "Identity", "Entity")
				local health = self:_ReadEntityValue(entityContext, entity, "Health", "Entity")
				local construction = self:_ReadEntityValue(entityContext, entity, "Construction", "Structure")
				local stats = self:_ReadEntityValue(entityContext, entity, "Stats", "Structure")
				local animationState = self:_ReadEntityValue(entityContext, entity, "AnimationState", "Structure")
				local animationLooping = self:_ReadEntityValue(entityContext, entity, "AnimationLooping", "Structure")
				local targetEnemyId = self:_ReadEntityValue(entityContext, entity, "TargetEnemyId", "Structure")

				return {
					StructureId = if type(identity) == "table" then identity.EntityId else nil,
					StructureType = if type(stats) == "table"
						then stats.StructureType
						else if type(identity) == "table" then identity.DefinitionId else nil,
					Health = if type(health) == "table" then health.Current else nil,
					MaxHealth = if type(health) == "table" then health.Max else nil,
					CurrentBuildWork = if type(construction) == "table" then construction.CurrentWork else nil,
					RequiredBuildWork = if type(construction) == "table" then construction.RequiredWork else nil,
					AnimationState = if type(animationState) == "string" then animationState else nil,
					AnimationLooping = if type(animationLooping) == "boolean" then animationLooping else nil,
					TargetEnemyId = if type(targetEnemyId) == "string" and targetEnemyId ~= "" then targetEnemyId else nil,
				}
			end,
			BuildHumanoidProperties = function(entityContext: any, entity: number)
				local health = self:_ReadEntityValue(entityContext, entity, "Health", "Entity")

				return {
					MaxHealth = if type(health) == "table" then health.Max else nil,
					Health = if type(health) == "table" then health.Current else nil,
				}
			end,
			BuildTransformProjection = function(entityContext: any, entity: number)
				local transform = self:_ReadEntityValue(entityContext, entity, "Transform", "Entity")
				return if type(transform) == "table" then transform.CFrame else nil
			end,
		})
		if not syncResult.success then
			return syncResult
		end

		local replicationResult = self._entityContext:RegisterReplicationSurface("Structure", {
			FeatureName = "Structure",
			BuildSchema = function(entityContext: any): any
				local entityComponentsResult = entityContext:GetFeatureComponents("Entity")
				local structureComponentsResult = entityContext:GetFeatureComponents("Structure")
				assert(entityComponentsResult.success, "Structure replication surface missing Entity compiled components")
				assert(structureComponentsResult.success, "Structure replication surface missing Structure compiled components")

				return {
					sharedComponents = {
						entityComponentsResult.value.Identity,
						entityComponentsResult.value.Health,
						structureComponentsResult.value.Construction,
						structureComponentsResult.value.AnimationState,
						structureComponentsResult.value.AnimationLooping,
						structureComponentsResult.value.TargetEnemyId,
					},
					sharedTags = {
						structureComponentsResult.value.PlacedTag,
						structureComponentsResult.value.UnderConstructionTag,
						structureComponentsResult.value.OperationalTag,
					},
				}
			end,
		})
		if not replicationResult.success then
			return replicationResult
		end

		local cleanupResult = self._entityContext:RegisterPreDestroyCleanup({
			ContributorId = "Structure.ExternalCleanup",
			Cleanup = function(entity: number)
				local identity = self._structureReadService:GetIdentity(entity)
				local placement = self._structureReadService:GetSourcePlacement(entity)
				if type(identity) == "table" and type(identity.EntityId) == "string" then
					self._teamContext:UnassignMember(TeamTypes.BuildMemberHandle("Structure", identity.EntityId))
				end
				if type(placement) == "table" and type(placement.InstanceId) == "number" then
					self._placementContext:DestroyStructureInstance(placement.InstanceId)
				end
				return true
			end,
		})
		if not cleanupResult.success then return cleanupResult end

		local healthDepletedResult = self._combatContext:RegisterHealthDepletedRule({
			VictimKind = "Structure",
			MarkVictimForDestruction = true,
		})
		if not healthDepletedResult.success then
			return healthDepletedResult
		end

		local attackProjectionResult = self._combatContext:RegisterMovementPresentationRule({
			RuleId = "Structure.AttackPresentation",
			Query = {
				Keys = {
					{ Key = "OperationalTag", FeatureName = "Structure" },
					{ Key = "AttackState", FeatureName = "Combat" },
					{ Key = "ActionState", FeatureName = "AI" },
				},
			},
			Attack = {
				Target = { TargetKind = "Enemy" },
				Animation = {
					FeatureName = "Structure",
					StateKey = "AnimationState",
					LoopingKey = "AnimationLooping",
					State = "Attack",
					Looping = false,
				},
				TargetEntityId = { FeatureName = "Structure", Key = "TargetEnemyId" },
			},
		})
		if not attackProjectionResult.success then
			return attackProjectionResult
		end

		return self._entityContext:RegisterSystem("ActionAdvance", {
			Name = "StructureExtractionSystem",
			Phase = "ActionAdvance",
			Reads = {
				"Structure.ExtractState",
				"Structure.SourcePlacement",
				"Structure.OperationalTag",
				"AI.ActionState",
			},
			Writes = {
				"Structure.AnimationState",
				"Structure.AnimationLooping",
				"Entity.DirtyTag",
			},
			Factory = function(entityFactory: any, _compiledSchemas: any)
				return StructureExtractionSystem.new(entityFactory, {
					MiningContext = self._miningContext,
				})
			end,
		})
	end, "StructureContext:RegisterEntityInfrastructure")
end

function StructureContext:_RegisterAIContracts(): Result.Result<boolean>
	return Catch(function()
		local function acceptDuplicate(result: Result.Result<any>, duplicateType: string): Result.Result<boolean>
			if result.success or result.type == duplicateType then
				return Ok(true)
			end
			return result
		end

		for _, behaviorPayload in pairs(StructureAIBehaviors) do
			local result = acceptDuplicate(self._aiContext:RegisterBehaviorDefinition(behaviorPayload), "DuplicateBehaviorDefinition")
			if not result.success then
				return result
			end
		end

		for _, profilePayload in pairs(StructureAIProfiles) do
			local result = acceptDuplicate(self._aiContext:RegisterProfile(profilePayload), "DuplicateProfile")
			if not result.success then
				return result
			end
		end

		return Ok(true)
	end, "StructureContext:RegisterAIContracts")
end

function StructureContext:_InitializeStructureAssets()
	local assetsRoot = ReplicatedStorage:FindFirstChild("Assets")
	if assetsRoot == nil or not assetsRoot:IsA("Folder") then
		return
	end

	local structuresFolder = assetsRoot:FindFirstChild("Structures")
	if structuresFolder ~= nil and structuresFolder:IsA("Folder") then
		self._structureAssetRegistry = AssetFetcher.CreateStructureRegistry(structuresFolder)
	end

	local animationsFolder = assetsRoot:FindFirstChild("Animations")
	if animationsFolder ~= nil and animationsFolder:IsA("Folder") then
		self._animationsFolder = animationsFolder
	end
end

function StructureContext:_BuildStructureModel(structureType: string?): Model
	local resolvedType = if type(structureType) == "string" and structureType ~= "" then structureType else "SentryTurret"
	if self._structureAssetRegistry ~= nil then
		local model = self._structureAssetRegistry:GetStructureModel(resolvedType)
		if model ~= nil then
			return model
		end
	end

	local model = Instance.new("Model")
	model.Name = resolvedType
	local rootPart = Instance.new("Part")
	rootPart.Name = "Primary"
	rootPart.Size = Vector3.new(4, 4, 4)
	rootPart.Anchored = true
	rootPart.CanCollide = false
	rootPart.Parent = model
	model.PrimaryPart = rootPart
	return model
end

function StructureContext:_PrepareStructureModel(model: Model, snapshot: any)
	local identity = snapshot.Identity or {}
	local stats = snapshot.FeatureData.Stats or {}
	local sourcePlacement = snapshot.FeatureData.SourcePlacement or {}
	local structureType = if type(stats.StructureType) == "string" and stats.StructureType ~= "" then stats.StructureType else "Structure"
	local structureId = if type(identity.EntityId) == "string" and identity.EntityId ~= "" then identity.EntityId else tostring(sourcePlacement.InstanceId)

	model.Name = ("%s_%s"):format(structureType, structureId)
	ensureHumanoid(model)
	ensureAnimationsFolderValue(model, self._animationsFolder)

	if sourcePlacement.RotationQuarterTurns ~= 0 then
		ModelPlus.RotateYaw(model, math.rad((sourcePlacement.RotationQuarterTurns or 0) * 90))
	end
	if typeof(sourcePlacement.WorldPos) == "Vector3" then
		ModelPlus.MoveBottomAligned(model, sourcePlacement.WorldPos)
	end

	EntityCollisionService:ApplyStructureModel(model)
end

function StructureContext:_ReadEntityValue(entityContext: any, entity: number, key: string, featureName: string): any
	local result = entityContext:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

function StructureContext:RegisterStructure(record: StructureRecord): Result.Result<number>
	return Catch(function()
		return self._registerStructureCommand:Execute(record)
	end, "Structure:RegisterStructure")
end

function StructureContext:ContributeConstruction(
	entity: number,
	workAmount: number,
	_contributorMeta: any?
): Result.Result<StructureTypes.TConstructionContributionResult>
	return Catch(function()
		return self._advanceConstructionCommand:Execute(entity, workAmount)
	end, "Structure:ContributeConstruction")
end

function StructureContext:ApplyDamage(entity: any, amount: number): Result.Result<boolean>
	return Catch(function()
		return self._applyDamageStructureCommand:Execute(entity, amount)
	end, "Structure:ApplyDamage")
end

function StructureContext:CleanupAll(): Result.Result<boolean>
	return Catch(function()
		return self._cleanupAllCommand:Execute()
	end, "Structure:CleanupAll")
end

function StructureContext:GetActiveStructures(): Result.Result<{ number }>
	return Catch(function()
		return Ok(self._getActiveStructuresQuery:Execute())
	end, "Structure:GetActiveStructures")
end

function StructureContext:GetStructureCount(): Result.Result<number>
	return Catch(function()
		return Ok(self._getStructureCountQuery:Execute())
	end, "Structure:GetStructureCount")
end

function StructureContext:GetStructurePosition(entity: number): Result.Result<Vector3?>
	return Ok(self._structureReadService:GetPosition(entity))
end

function StructureContext:IsStructureBuildableForBuilder(
	entity: number,
	ownerUserId: number,
	builderPosition: Vector3?,
	buildRange: number?
): Result.Result<boolean>
	return Catch(function()
		if typeof(builderPosition) ~= "Vector3" or type(buildRange) ~= "number" then
			return Ok(false)
		end
		local structurePosition = self._structureReadService:GetPosition(entity)
		return Ok(
			self._structureReadService:IsPlaced(entity)
				and self._structureReadService:IsUnderConstruction(entity)
				and self._structureReadService:IsOwnedByUser(entity, ownerUserId)
				and structurePosition ~= nil
				and (structurePosition - builderPosition).Magnitude <= buildRange
		)
	end, "Structure:IsStructureBuildableForBuilder")
end

function StructureContext:FindNearestOwnedUnfinishedStructure(
	ownerUserId: number,
	position: Vector3,
	maxRange: number
): Result.Result<number?>
	return Ok(self._structureReadService:FindNearestOwnedUnfinishedStructure(ownerUserId, position, maxRange))
end

function StructureContext:GetSchedulerBindingStatus(targetField: string): Result.Result<any>
	return Ok(StructureBaseContext:GetSchedulerBindingStatus(targetField))
end

function StructureContext:_BeforeDestroy()
	local cleanupResult = self:CleanupAll()
	if not cleanupResult.success then
		Result.MentionError("Structure:Destroy", "Cleanup failed during destroy", {
			CauseType = cleanupResult.type,
			CauseMessage = cleanupResult.message,
		}, cleanupResult.type)
	end
end

function StructureContext:Destroy()
	local destroyResult = StructureBaseContext:Destroy()
	if not destroyResult.success then
		Result.MentionError("Structure:Destroy", "BaseContext teardown failed", {
			CauseType = destroyResult.type,
			CauseMessage = destroyResult.message,
		}, destroyResult.type)
	end
end

return StructureContext
