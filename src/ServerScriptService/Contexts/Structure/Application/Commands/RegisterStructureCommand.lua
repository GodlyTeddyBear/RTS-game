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
	self:_RequireDependency(registry, "_policy", "RegisterStructurePolicy")
end

function RegisterStructureCommand:Start(registry: any, _name: string)
	self._entityContext = registry:Get("EntityContext")
	self._aiContext = registry:Get("AIContext")
	self._teamContext = registry:Get("TeamContext")
	self._animationContext = registry:Get("AnimationContext")
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
		local structureConfig = StructureConfig.Definitions[resolved.StructureType]
		Ensure(structureConfig ~= nil, "UnknownStructureType", Errors.UNKNOWN_STRUCTURE_TYPE, {
			StructureType = resolved.StructureType,
		})
		local attack = structureConfig.Capabilities.Attack
		local construction = structureConfig.Capabilities.Construction
		local statusAura = structureConfig.Capabilities.StatusAura

		structureId = tostring(resolved.InstanceId)
		local createResult = self._entityContext:CreateEntity("Structure.Actor", {
			Identity = {
				EntityId = structureId,
				EntityKind = "Structure",
				DefinitionId = resolved.StructureType,
			},
			Health = {
				Current = structureConfig.Health.Max,
				Max = structureConfig.Health.Max,
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
				AIProfileId = structureConfig.AI.ProfileId,
				AttackRange = if attack then attack.Range else 0,
				AttackDamage = if attack then attack.Damage else 0,
				AttackCooldown = if attack then attack.Cooldown else 0,
				LastAttackAt = 0,
				StasisRadius = if statusAura then statusAura.Radius else 0,
				MoveSpeedMultiplier = if statusAura then statusAura.MoveSpeedMultiplier else 1,
			},
			Construction = {
				CurrentWork = 0,
				RequiredWork = construction.RequiredWork,
			},
			SourcePlacement = {
				InstanceId = resolved.InstanceId,
				OwnerUserId = resolved.OwnerUserId,
				WorldPos = resolved.WorldPos,
				RotationQuarterTurns = resolved.RotationQuarterTurns,
				ResourceType = record.ResourceType,
			},
			TargetEnemyId = nil,
		})
		Try(createResult)
		entity = createResult.value

		local aim = structureConfig.Capabilities.Aim
		Try(self._animationContext:SetupEntity(entity, {
			ProfileId = "StructureActor",
			AnimationSetId = "Structure",
			VariantId = resolved.StructureType,
			FeatureOverrides = if aim ~= nil then {
				Aim = aim,
			} else nil,
		}))

		Try(self._aiContext:SetupEntityAIFromProfile(entity, structureConfig.AI.ProfileId, {
			TickInterval = structureConfig.AI.TickInterval,
		}))
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
