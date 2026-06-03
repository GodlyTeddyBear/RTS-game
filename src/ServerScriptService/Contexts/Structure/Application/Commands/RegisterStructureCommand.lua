--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)
local StructureConfig = require(ReplicatedStorage.Contexts.Structure.Config.StructureConfig)
local StructureSpecs = require(script.Parent.Parent.Parent.StructureDomain.Specs.StructureSpecs)
local TeamTypes = require(ReplicatedStorage.Contexts.Team.Types.TeamTypes)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ensure = Result.Ensure
local Ok = Result.Ok
local Try = Result.Try

local RegisterStructureCommand = {}
RegisterStructureCommand.__index = RegisterStructureCommand
setmetatable(RegisterStructureCommand, BaseCommand)

function RegisterStructureCommand.new()
	local self = BaseCommand.new("Structure", "RegisterStructure")
	return setmetatable(self, RegisterStructureCommand)
end

function RegisterStructureCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_policy = "RegisterStructurePolicy",
		_entityContext = "EntityContext",
		_aiContext = "AIContext",
	})
end

function RegisterStructureCommand:Start(registry: any, _name: string)
	self._teamContext = registry:Get("TeamContext")
end

function RegisterStructureCommand:Execute(record: any): Result.Result<number>
	local entity: number? = nil
	local structureId: string? = nil
	local teamAssigned = false

	return Result.Catch(function()
		Ensure(type(record) == "table", "InvalidPlacementRecord", Errors.INVALID_PLACEMENT_RECORD)
		if not StructureSpecs.IsValidStructureType(record.StructureType) then
			return Result.Err("UnknownStructureType", Errors.UNKNOWN_STRUCTURE_TYPE)
		end

		local resolved = Try(self._policy:Check(record))
		local structureConfig = StructureConfig.STRUCTURES[resolved.StructureType]
		Ensure(structureConfig ~= nil, "UnknownStructureType", Errors.UNKNOWN_STRUCTURE_TYPE, {
			StructureType = resolved.StructureType,
		})

		structureId = tostring(resolved.InstanceId)
		local runtimeProfileId = structureConfig.RuntimeProfileId or "Passive"
		local profileId = ("Structure%sAI"):format(runtimeProfileId)
		local createResult = self._entityContext:CreateEntity("Structure.Actor", {
			Identity = {
				EntityId = structureId,
				EntityKind = "Structure",
				DefinitionId = resolved.StructureType,
			},
			Health = {
				Current = structureConfig.MaxHealth,
				Max = structureConfig.MaxHealth,
			},
			Transform = {
				CFrame = CFrame.new(resolved.WorldPos),
			},
			ModelRef = {
				Model = nil,
			},
			ModelAsset = {
				AssetDomain = "Structures",
				AssetId = resolved.StructureType,
				AssetKind = "Model",
			},
			ModelBinding = {
				ParentFolder = "Structure",
				SetupProfileId = "StructurePlacement",
				RevealTag = "AnimatedStructure",
				NameFormat = "{DefinitionId}_{EntityId}",
			},
			HumanoidProjection = {
				Enabled = true,
				Health = true,
				WalkSpeed = false,
			},
			TransformProjection = {
				Enabled = true,
			},
			TransformPoll = {
				Enabled = false,
			},
			CleanupOutcomes = {
				OutcomeIds = { "AICleanup", "PlacementDestroy", "TeamUnassign" },
			},
			HealthDepletedOutcome = {
				OutcomeId = "StructureDeath",
			},
			Target = {
				TargetEntity = nil,
				TargetKind = nil,
			},
			Stats = {
				StructureType = resolved.StructureType,
				RuntimeProfileId = runtimeProfileId,
				AttackRange = structureConfig.AttackRange or 0,
				AttackDamage = structureConfig.AttackDamage or 0,
				AttackCooldown = structureConfig.AttackCooldown or 0,
				LastAttackAt = 0,
				StasisRadius = structureConfig.StasisRadius or 0,
				MoveSpeedMultiplier = structureConfig.MoveSpeedMultiplier or 1,
			},
			Construction = {
				CurrentWork = 0,
				RequiredWork = structureConfig.BuildWorkRequired,
			},
			SourcePlacement = {
				InstanceId = resolved.InstanceId,
				OwnerUserId = resolved.OwnerUserId,
				WorldPos = resolved.WorldPos,
				RotationQuarterTurns = resolved.RotationQuarterTurns,
				ResourceType = record.ResourceType,
			},
			AnimationState = "Idle",
			AnimationLooping = true,
			TargetEnemyId = nil,
		})
		Try(createResult)
		entity = createResult.value

		Try(self._aiContext:SetupEntityAIFromProfile(entity, profileId))
		Try(self._entityContext:RegisterRuntimeEntity(entity))
		Try(self._entityContext:FlushBindQueue())

		local boundInstanceResult = self._entityContext:GetBoundInstance(entity)
		if boundInstanceResult.success and boundInstanceResult.value ~= nil then
			Try(self._entityContext:Set(entity, "ModelRef", {
				Model = boundInstanceResult.value,
			}, "Entity"))
		end

		Try(
			self._teamContext:AssignMemberToPlayerTeam(
				resolved.OwnerUserId,
				TeamTypes.BuildMemberHandle("Structure", structureId)
			)
		)
		teamAssigned = true

		Result.MentionSuccess("Structure:RegisterStructureCommand", "Registered structure entity", {
			instanceId = resolved.InstanceId,
			structureType = resolved.StructureType,
			entity = entity,
		})

		return Ok(entity)
	end, "Structure:RegisterStructureCommand", function()
		if entity ~= nil then
			self._entityContext:DestroyEntity(entity)
		end
		if teamAssigned and structureId ~= nil then
			self._teamContext:UnassignMember(TeamTypes.BuildMemberHandle("Structure", structureId))
		end
	end)
end

return RegisterStructureCommand
