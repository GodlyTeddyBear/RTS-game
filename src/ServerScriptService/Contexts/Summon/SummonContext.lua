--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local BaseContext = require(ServerStorage.Utilities.ContextUtilities.BaseContext)
local Result = require(ReplicatedStorage.Utilities.Result)
local SummonConfig = require(ReplicatedStorage.Contexts.Summon.Config.SummonConfig)
local UnitTypes = require(ReplicatedStorage.Contexts.Unit.Types.UnitTypes)

local SummonAIBehaviors = require(script.Parent.Config.AIBehaviors)
local SummonAIProfiles = require(script.Parent.Config.AIProfiles)
local SummonEntityReadService = require(script.Parent.Infrastructure.Entity.SummonEntityReadService)
local SummonEntitySchema = require(script.Parent.Infrastructure.Entity.SummonEntitySchema)
local SummonLifetimeSystem = require(script.Parent.Infrastructure.Systems.SummonLifetimeSystem)
local CleanupSummonsCommand = require(script.Parent.Application.Commands.CleanupSummonsCommand)
local SpawnAllyCommand = require(script.Parent.Application.Commands.SpawnAllyCommand)
local SpawnSwarmDronesCommand = require(script.Parent.Application.Commands.SpawnSwarmDronesCommand)

local Errors = require(script.Parent.Errors)

type SpawnUnitResult = UnitTypes.SpawnUnitResult

local Catch = Result.Catch
local Ok = Result.Ok
local Ensure = Result.Ensure

local DRONE_REVEAL_TAG = "SummonDrone"

local function moduleSpec(name: string, module: any, cacheAs: string?): BaseContext.TModuleSpec
	return {
		Name = name,
		Module = module,
		CacheAs = cacheAs,
	}
end

local function makeDronePart(): BasePart
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(1.2, 1.2, 1.2)
	part.Color = Color3.fromRGB(255, 199, 93)
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	return part
end

local InfrastructureModules: { BaseContext.TModuleSpec } = {
	{
		Name = "SummonEntityReadService",
		Factory = function(service: any, _baseContext: any)
			return SummonEntityReadService.new(service._entityContext)
		end,
		CacheAs = "_summonReadService",
	},
}

local ApplicationModules: { BaseContext.TModuleSpec } = {
	moduleSpec("SpawnSwarmDronesCommand", SpawnSwarmDronesCommand, "_spawnSwarmDronesCommand"),
	moduleSpec("SpawnAllyCommand", SpawnAllyCommand, "_spawnAllyCommand"),
	moduleSpec("CleanupSummonsCommand", CleanupSummonsCommand, "_cleanupSummonsCommand"),
}

local SummonModules: BaseContext.TModuleLayers = {
	Infrastructure = InfrastructureModules,
	Application = ApplicationModules,
}

local SummonContext = Knit.CreateService({
	Name = "SummonContext",
	Client = {},
	Modules = SummonModules,
	ExternalServices = {
		{ Name = "CombatContext", CacheAs = "_combatContext" },
		{ Name = "AIContext", CacheAs = "_aiContext" },
		{ Name = "EnemyContext", CacheAs = "_enemyContext" },
		{ Name = "EntityContext", CacheAs = "_entityContext" },
		{ Name = "RunContext", CacheAs = "_runContext" },
		{ Name = "UnitContext" },
	},
	Teardown = {
		Before = "_BeforeDestroy",
		Fields = {
			{ Field = "_runWaveEndedConnection", Method = "Disconnect" },
			{ Field = "_runEndedConnection", Method = "Disconnect" },
			{ Field = "_playerRemovingConnection", Method = "Disconnect" },
		},
	},
})

local SummonBaseContext = BaseContext.new(SummonContext)

function SummonContext:KnitInit()
	SummonBaseContext:KnitInit()
	self._runWaveEndedConnection = nil :: any
	self._runEndedConnection = nil :: any
	self._playerRemovingConnection = nil :: any
end

function SummonContext:KnitStart()
	SummonBaseContext:KnitStart()

	local entityResult = self:_RegisterEntityInfrastructure()
	if not entityResult.success then
		error(("SummonContext failed to register Entity infrastructure: [%s] %s"):format(
			tostring(entityResult.type),
			tostring(entityResult.message)
		))
	end

	local aiResult = self:_RegisterAIContracts()
	if not aiResult.success then
		error(("SummonContext failed to register AI contracts: [%s] %s"):format(
			tostring(aiResult.type),
			tostring(aiResult.message)
		))
	end

	SummonBaseContext:OnContextEvent("Run", "WaveEnded", function(_waveNumber: number)
		self:_CleanupAllSummons()
	end, "_runWaveEndedConnection")

	SummonBaseContext:OnContextEvent("Run", "RunEnded", function()
		self:_CleanupAllSummons()
	end, "_runEndedConnection")

	SummonBaseContext:OnPlayerRemoving(function(player: Player)
		self:_CleanupOwnerSummons(player.UserId)
	end, "_playerRemovingConnection")
end

function SummonContext:_RegisterEntityInfrastructure(): Result.Result<boolean>
	return Catch(function()
		local schemaResult = self._entityContext:RegisterFeatureSchema("Summon", SummonEntitySchema)
		if not schemaResult.success then
			return schemaResult
		end

		local bindingResult = self._entityContext:RegisterInstanceBinding("Summon", {
			FeatureName = "Summon",
			ResolveAsset = function(_entityContext: any, _snapshot: any): Instance
				return makeDronePart()
			end,
			PrepareInstance = function(_entityContext: any, instance: Instance, snapshot: any)
				if not instance:IsA("BasePart") then
					return
				end

				local identity = snapshot.Identity or {}
				local transform = snapshot.Transform or {}
				instance.Name = ("SwarmDrone_%s"):format(tostring(identity.EntityId or "Summon"))
				if typeof(transform.CFrame) == "CFrame" then
					instance.CFrame = transform.CFrame
				end
			end,
			BuildRevealAttributes = function(_entityContext: any, snapshot: any)
				local identity = snapshot.Identity or {}
				local ownership = snapshot.Ownership or {}
				local kind = snapshot.FeatureData.Kind or {}
				return {
					SummonId = identity.EntityId,
					SummonKind = kind.Kind,
					OwnerKind = ownership.OwnerKind,
					OwnerId = ownership.OwnerId,
				}
			end,
			BuildRevealTags = function()
				return {
					[DRONE_REVEAL_TAG] = true,
				}
			end,
			BuildName = function(_entityContext: any, snapshot: any)
				local identity = snapshot.Identity or {}
				return ("SwarmDrone_%s"):format(tostring(identity.EntityId or "Summon"))
			end,
		})
		if not bindingResult.success then
			return bindingResult
		end

		local syncResult = self._entityContext:RegisterSyncContributor("Summon", {
			FeatureName = "Summon",
			QuerySyncEntities = function(entityContext: any): { number }
				local queryResult = entityContext:Query({
					FeatureName = "Summon",
					Keys = {
						{ Key = "ActiveTag", FeatureName = "Entity" },
						{ Key = "DroneTag", FeatureName = "Summon" },
					},
				})
				return if queryResult.success then queryResult.value else {}
			end,
			BuildRuntimeAttributes = function(entityContext: any, entity: number)
				local identity = self:_ReadEntityValue(entityContext, entity, "Identity", "Entity")
				local ownership = self:_ReadEntityValue(entityContext, entity, "Ownership", "Entity")
				local kind = self:_ReadEntityValue(entityContext, entity, "Kind", "Summon")
				local targetEnemyId = self:_ReadEntityValue(entityContext, entity, "TargetEnemyId", "Summon")

				return {
					SummonId = if type(identity) == "table" then identity.EntityId else nil,
					SummonKind = if type(kind) == "table" then kind.Kind else nil,
					OwnerKind = if type(ownership) == "table" then ownership.OwnerKind else nil,
					OwnerId = if type(ownership) == "table" then ownership.OwnerId else nil,
					TargetEnemyId = if type(targetEnemyId) == "string" then targetEnemyId else nil,
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

		local lifetimeResult = self._entityContext:RegisterSystem("ActionAdvance", {
			Name = "SummonLifetimeSystem",
			Phase = "ActionAdvance",
			Reads = {
				"Summon.DroneTag",
				"Entity.Lifetime",
			},
			Writes = {
				"Entity.DestructionQueue",
			},
			Factory = function(entityFactory: any, _compiledSchemas: any)
				return SummonLifetimeSystem.new(entityFactory, self._entityContext)
			end,
		})
		if not lifetimeResult.success then
			return lifetimeResult
		end

		return self._combatContext:RegisterMovementPresentationRule({
			RuleId = "Summon.MovementPresentation",
			Query = { FeatureName = "Summon", Keys = { "DroneTag" } },
			TargetEntityId = { FeatureName = "Summon", Key = "TargetEnemyId" },
		})
	end, "SummonContext:RegisterEntityInfrastructure")
end

function SummonContext:_RegisterAIContracts(): Result.Result<boolean>
	return Catch(function()
		local function acceptDuplicate(result: Result.Result<any>, duplicateType: string): Result.Result<boolean>
			if result.success or result.type == duplicateType then
				return Ok(true)
			end
			return result
		end

		for _, behaviorPayload in pairs(SummonAIBehaviors) do
			local behaviorResult =
				acceptDuplicate(self._aiContext:RegisterBehaviorDefinition(behaviorPayload), "DuplicateBehaviorDefinition")
			if not behaviorResult.success then
				return behaviorResult
			end
		end

		for _, profilePayload in pairs(SummonAIProfiles) do
			local profileResult = acceptDuplicate(self._aiContext:RegisterProfile(profilePayload), "DuplicateProfile")
			if not profileResult.success then
				return profileResult
			end
		end

		return Ok(true)
	end, "SummonContext:RegisterAIContracts")
end

function SummonContext:_ReadEntityValue(entityContext: any, entity: number, key: string, featureName: string): any
	local result = entityContext:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

function SummonContext:SpawnSwarmDrones(
	player: Player,
	slotMetadata: { [string]: any }?,
	castOriginCFrame: CFrame
): Result.Result<{ SpawnedCount: number }>
	return Catch(function()
		Ensure(player, "InvalidPlayer", Errors.INVALID_PLAYER)
		Ensure(castOriginCFrame, "InvalidCastOrigin", Errors.INVALID_CAST_ORIGIN)

		return self._spawnSwarmDronesCommand:Execute(player, slotMetadata, castOriginCFrame)
	end, "Summon:SpawnSwarmDrones")
end

function SummonContext:SpawnAlly(
	player: Player,
	slotMetadata: { [string]: any }?,
	castOriginCFrame: CFrame
): Result.Result<SpawnUnitResult>
	return Catch(function()
		Ensure(player, "InvalidPlayer", Errors.INVALID_PLAYER)
		Ensure(castOriginCFrame, "InvalidCastOrigin", Errors.INVALID_CAST_ORIGIN)

		return self._spawnAllyCommand:Execute(player, slotMetadata, castOriginCFrame)
	end, "Summon:SpawnAlly")
end

function SummonContext:_CleanupAllSummons()
	local result = self._cleanupSummonsCommand:Execute(nil)
	if not result.success then
		Result.MentionError("Summon:CleanupAll", "Failed to cleanup summons", {
			CauseType = result.type,
			CauseMessage = result.message,
		}, result.type)
	end
end

function SummonContext:_CleanupOwnerSummons(ownerUserId: number)
	local result = self._cleanupSummonsCommand:Execute(ownerUserId)
	if not result.success then
		Result.MentionError("Summon:CleanupOwner", "Failed to cleanup owner summons", {
			OwnerUserId = ownerUserId,
			CauseType = result.type,
			CauseMessage = result.message,
		}, result.type)
	end
end

function SummonContext:_BeforeDestroy()
	self:_CleanupAllSummons()
end

function SummonContext:Destroy()
	local destroyResult = SummonBaseContext:Destroy()
	if not destroyResult.success then
		Result.MentionError("Summon:Destroy", "BaseContext teardown failed", {
			CauseType = destroyResult.type,
			CauseMessage = destroyResult.message,
		}, destroyResult.type)
	end
end

return SummonContext
