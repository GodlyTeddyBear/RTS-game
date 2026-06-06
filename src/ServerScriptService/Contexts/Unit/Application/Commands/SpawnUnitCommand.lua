--!strict

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)
local TeamTypes = require(ReplicatedStorage.Contexts.Team.Types.TeamTypes)
local UnitTypes = require(ReplicatedStorage.Contexts.Unit.Types.UnitTypes)
local Errors = require(script.Parent.Parent.Parent.Errors)

type SpawnUnitRequest = UnitTypes.SpawnUnitRequest
type SpawnUnitResult = UnitTypes.SpawnUnitResult

local Ok = Result.Ok
local Try = Result.Try
local Ensure = Result.Ensure

local SpawnUnitCommand = {}
SpawnUnitCommand.__index = SpawnUnitCommand
setmetatable(SpawnUnitCommand, BaseCommand)

function SpawnUnitCommand.new()
	local self = BaseCommand.new("Unit", "SpawnUnit")
	return setmetatable(self, SpawnUnitCommand)
end

function SpawnUnitCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_spawnPolicy = "UnitSpawnPolicy",
	})
end

function SpawnUnitCommand:Start(registry: any, _name: string)
	self._aiContext = registry:Get("AIContext")
	self._combatContext = registry:Get("CombatContext")
	self._entityContext = registry:Get("EntityContext")
	self._teamContext = registry:Get("TeamContext")
end

function SpawnUnitCommand:Execute(request: SpawnUnitRequest): Result.Result<SpawnUnitResult>
	local entity: number? = nil
	local unitGuid: string? = nil

	return Result.Catch(function()
		local definition = Try(self._spawnPolicy:Check(request))
		unitGuid = HttpService:GenerateGUID(false)
		local now = os.clock()

		entity = Try(self._entityContext:CreateEntity("Unit.Actor", {
			Identity = {
				EntityId = unitGuid,
				EntityKind = "Unit",
				DefinitionId = request.UnitId,
			},
			Ownership = {
				Faction = request.Faction,
				OwnerKind = request.OwnerKind,
				OwnerId = request.OwnerId,
			},
			Health = {
				Current = definition.Health.Max,
				Max = definition.Health.Max,
			},
			Transform = {
				CFrame = request.SpawnCFrame,
			},
			ModelAsset = {
				AssetDomain = "Units",
				AssetId = request.UnitId,
				AssetKind = "Model",
			},
			ModelBinding = {
				ParentFolder = "Unit",
				SetupProfileId = "HumanoidActor",
				RevealTag = "CombatUnit",
				NameFormat = "Unit_{DefinitionId}_{EntityId}",
			},
			HumanoidProjection = {
				Enabled = true,
				Health = true,
				WalkSpeed = true,
			},
			CleanupOutcomes = {
				OutcomeIds = { "AICleanup", "MovementCleanup", "TeamUnassign" },
			},
			Role = {
				Role = definition.Role,
				DisplayName = definition.DisplayName,
				UnitId = definition.DefinitionId,
				MovementMode = definition.Movement.Mode,
				BuildWorkPerSecond = if definition.Capabilities.Build then definition.Capabilities.Build.WorkPerSecond else nil,
				BuildRange = if definition.Capabilities.Build then definition.Capabilities.Build.Range else nil,
			},
			BaseMoveSpeed = {
				Value = definition.Movement.Speed,
			},
			CurrentMoveSpeed = {
				Value = definition.Movement.Speed,
			},
			PathState = {
				GoalPosition = nil,
				RequestedGoalPosition = nil,
				GoalRevision = 0,
				FailedGoalRevision = nil,
				IsMoving = false,
			},
			BuilderAssignment = {
				TargetStructureEntity = nil,
			},
			AnimationState = "Idle",
			AnimationLooping = true,
			LockOn = {
				Attachment0 = nil,
				Attachment1 = nil,
				Constraint = nil,
			},
		}))

		if request.Lifetime ~= nil then
			Try(self._entityContext:Set(entity, "Lifetime", {
				SpawnedAt = now,
				ExpiresAt = now + request.Lifetime,
			}, "Entity"))
		end

		Try(self._combatContext:SetupMovementActor(entity, {
			ApplyMode = "Humanoid",
			MoveSpeed = definition.Movement.Speed,
		}))

		Try(self._aiContext:SetupEntityAIFromProfile(entity, definition.AI.ProfileId, {
			TickInterval = definition.AI.TickInterval,
		}))

		Try(self._entityContext:RegisterRuntimeEntity(entity))
		Try(self._entityContext:FlushBindQueue())

		local boundInstanceResult = self._entityContext:GetBoundInstance(entity)
		local boundInstance = if boundInstanceResult.success then boundInstanceResult.value else nil
		Ensure(boundInstance ~= nil and boundInstance:IsA("Model"), "SpawnModelFailed", Errors.SPAWN_MODEL_FAILED)
		Try(self._entityContext:Set(entity, "ModelRef", {
			Model = boundInstance,
		}, "Entity"))

		local unitHandle = TeamTypes.BuildMemberHandle("Unit", unitGuid)
		if request.Faction == "Enemy" then
			Try(self._teamContext:AssignMemberToEnemyTeam(unitHandle))
		elseif request.OwnerKind == "Player" then
			local ownerUserId = tonumber(request.OwnerId)
			Ensure(ownerUserId ~= nil and ownerUserId > 0, "InvalidOwnerId", Errors.INVALID_OWNER_ID, {
				OwnerId = request.OwnerId,
			})
			Try(self._teamContext:AssignMemberToPlayerTeam(ownerUserId, unitHandle))
		end

		return Ok({
			Entity = entity,
			UnitId = request.UnitId,
		})
	end, self:_Label(), function()
		if entity ~= nil then
			self._entityContext:DestroyEntity(entity)
		end
	end)
end

return SpawnUnitCommand
