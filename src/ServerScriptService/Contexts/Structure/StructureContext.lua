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
local EntityCollisionService = require(ServerScriptService.Infrastructure.EntityCollisionService)

local StructureEntityReadService = require(script.Parent.Infrastructure.Entity.StructureEntityReadService)
local StructureEntitySchema = require(script.Parent.Infrastructure.Entity.StructureEntitySchema)
local StructureActionExecutionSystem = require(script.Parent.Infrastructure.Entity.StructureActionExecutionSystem)
local RegisterStructurePolicy = require(script.Parent.StructureDomain.Policies.RegisterStructurePolicy)
local StructureAIProfiles = require(script.Parent.Parent.AI.Config.Profiles.StructureAIProfiles)
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
			SyncEntity = function(entityContext: any, entity: number, model: Model)
				self:_SyncStructureEntity(entityContext, entity, model)
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

		return self._entityContext:RegisterSystem("Execute", {
			Name = "StructureActionExecutionSystem",
			Phase = "Execute",
			Reads = {
				"Structure.Stats",
				"Structure.Construction",
				"Structure.OperationalTag",
				"Entity.Target",
				"AI.ActionIntent",
				"AI.ActionState",
			},
			Writes = {
				"Structure.Stats",
				"Structure.AnimationState",
				"Structure.AnimationLooping",
				"Structure.TargetEnemyId",
				"Entity.Target",
				"Entity.DirtyTag",
			},
			Factory = function(entityFactory: any, _compiledSchemas: any)
				return StructureActionExecutionSystem.new(entityFactory, {
					EntityContext = self._entityContext,
					EnemyContext = self._enemyContext,
					CombatContext = self._combatContext,
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

		local evaluations = {
			{
				EvaluationId = "StructureIsOperational",
				Evaluate = function(context: any): boolean
					return type(context) == "table"
						and type(context.Facts) == "table"
						and context.Facts.StructureOperational == true
				end,
			},
			{
				EvaluationId = "StructureCanAttack",
				Evaluate = function(context: any): boolean
					return type(context) == "table"
						and type(context.Facts) == "table"
						and context.Facts.StructureOperational == true
						and type(context.Facts.TargetEntity) == "number"
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
				ActionId = "StructureIdle",
				ProduceIntent = function(_context: any): any
					return {
						Data = {
							Reason = "Idle",
						},
					}
				end,
			},
			{
				ActionId = "StructureAttack",
				ProduceIntent = function(context: any): any
					local facts = if type(context) == "table" and type(context.Facts) == "table" then context.Facts else {}
					return {
						TargetEntity = facts.TargetEntity,
						Data = facts.AttackData,
					}
				end,
			},
			{
				ActionId = "StructureExtract",
				ProduceIntent = function(context: any): any
					local facts = if type(context) == "table" and type(context.Facts) == "table" then context.Facts else {}
					return {
						Data = facts.ExtractData,
					}
				end,
			},
			{
				ActionId = "StructureStasis",
				ProduceIntent = function(context: any): any
					local facts = if type(context) == "table" and type(context.Facts) == "table" then context.Facts else {}
					return {
						Data = facts.StasisData,
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

		local behaviorPayloads = {
			{
				DefinitionId = "StructureIdleBehavior",
				Definition = "StructureIdle",
			},
			{
				DefinitionId = "StructureAttackBehavior",
				Definition = {
					Priority = {
						{
							Sequence = {
								"StructureCanAttack",
								"StructureAttack",
							},
						},
						"StructureIdle",
					},
				},
			},
			{
				DefinitionId = "StructureExtractBehavior",
				Definition = {
					Priority = {
						{
							Sequence = {
								"StructureIsOperational",
								"StructureExtract",
							},
						},
						"StructureIdle",
					},
				},
			},
			{
				DefinitionId = "StructureStasisBehavior",
				Definition = {
					Priority = {
						{
							Sequence = {
								"StructureIsOperational",
								"StructureStasis",
							},
						},
						"StructureIdle",
					},
				},
			},
		}
		for _, behaviorPayload in ipairs(behaviorPayloads) do
			local result = acceptDuplicate(self._aiContext:RegisterBehaviorDefinition(behaviorPayload), "DuplicateBehaviorDefinition")
			if not result.success then
				return result
			end
		end

		local providerResult = acceptDuplicate(self._aiContext:RegisterFactProvider({
			ProviderId = "StructureFacts",
			BuildFacts = function(context: any): any
				return self:_BuildStructureFacts(context)
			end,
		}), "DuplicateFactProvider")
		if not providerResult.success then
			return providerResult
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
	model:SetAttribute("PlacementInstanceId", sourcePlacement.InstanceId)
	model:SetAttribute("StructureId", structureId)
	model:SetAttribute("StructureType", structureType)
	ensureHumanoid(model)
	ensureAnimationsFolderValue(model, self._animationsFolder)
	model:SetAttribute("AnimationState", model:GetAttribute("AnimationState") or "Idle")
	model:SetAttribute("AnimationLooping", if model:GetAttribute("AnimationLooping") == nil then true else model:GetAttribute("AnimationLooping"))

	if sourcePlacement.RotationQuarterTurns ~= 0 then
		ModelPlus.RotateYaw(model, math.rad((sourcePlacement.RotationQuarterTurns or 0) * 90))
	end
	if typeof(sourcePlacement.WorldPos) == "Vector3" then
		ModelPlus.MoveBottomAligned(model, sourcePlacement.WorldPos)
	end

	EntityCollisionService:ApplyStructureModel(model)
end

function StructureContext:_SyncStructureEntity(entityContext: any, entity: number, model: Model)
	local identity = self:_ReadEntityValue(entityContext, entity, "Identity", "Entity")
	local health = self:_ReadEntityValue(entityContext, entity, "Health", "Entity")
	local construction = self:_ReadEntityValue(entityContext, entity, "Construction", "Structure")
	local stats = self:_ReadEntityValue(entityContext, entity, "Stats", "Structure")
	local transform = self:_ReadEntityValue(entityContext, entity, "Transform", "Entity")
	local animationState = self:_ReadEntityValue(entityContext, entity, "AnimationState", "Structure")
	local animationLooping = self:_ReadEntityValue(entityContext, entity, "AnimationLooping", "Structure")
	local targetEnemyId = self:_ReadEntityValue(entityContext, entity, "TargetEnemyId", "Structure")

	if type(identity) == "table" then
		model:SetAttribute("StructureId", identity.EntityId)
		model:SetAttribute("StructureType", identity.DefinitionId)
	end
	if type(stats) == "table" then
		model:SetAttribute("StructureType", stats.StructureType)
	end
	if type(health) == "table" then
		model:SetAttribute("Health", health.Current)
		model:SetAttribute("MaxHealth", health.Max)
	end
	if type(construction) == "table" then
		model:SetAttribute("CurrentBuildWork", construction.CurrentWork)
		model:SetAttribute("RequiredBuildWork", construction.RequiredWork)
	end
	if type(animationState) == "string" then
		model:SetAttribute("AnimationState", animationState)
	end
	if type(animationLooping) == "boolean" then
		model:SetAttribute("AnimationLooping", animationLooping)
	end
	model:SetAttribute("TargetEnemyId", if type(targetEnemyId) == "string" and targetEnemyId ~= "" then targetEnemyId else nil)
	if type(transform) == "table" and typeof(transform.CFrame) == "CFrame" then
		model:PivotTo(transform.CFrame)
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid ~= nil and type(health) == "table" then
		humanoid.MaxHealth = health.Max or humanoid.MaxHealth
		humanoid.Health = health.Current or humanoid.Health
	end
end

function StructureContext:_ReadEntityValue(entityContext: any, entity: number, key: string, featureName: string): any
	local result = entityContext:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

function StructureContext:_BuildStructureFacts(context: any): any
	if type(context) ~= "table" or type(context.Entity) ~= "number" then
		return {}
	end
	local entity = context.Entity
	if not self._structureReadService:IsPlaced(entity) then
		return {}
	end

	local stats = self._structureReadService:GetStats(entity)
	local position = self._structureReadService:GetPosition(entity)
	local isOperational = self._structureReadService:IsOperational(entity)
	local facts = {
		StructureOperational = isOperational,
		StructureStats = stats,
	}

	if type(stats) == "table" and stats.RuntimeProfileId == "Attack" and position ~= nil then
		local nearestResult = self._enemyContext:GetNearestAliveEnemy(position, stats.AttackRange or 0)
		local nearest = if nearestResult.success then nearestResult.value else nil
		if type(nearest) == "table" then
			facts.TargetEntity = nearest.Entity
			facts.AttackData = {
				TargetPosition = nearest.CFrame.Position,
			}
		end
	elseif type(stats) == "table" and stats.RuntimeProfileId == "Extract" then
		facts.ExtractData = {
			StructureEntity = entity,
		}
	elseif type(stats) == "table" and stats.RuntimeProfileId == "Stasis" then
		facts.StasisData = {
			StructureEntity = entity,
		}
	end

	return facts
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
