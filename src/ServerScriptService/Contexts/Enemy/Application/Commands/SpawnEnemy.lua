--!strict

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local TeamTypes = require(ReplicatedStorage.Contexts.Team.Types.TeamTypes)
local EnemyConfig = require(ReplicatedStorage.Contexts.Enemy.Config.EnemyConfig)
local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok = Result.Ok
local Try = Result.Try
local Ensure = Result.Ensure

--[=[
	@class SpawnEnemy
	Creates an enemy entity, model, and movement state for the active lane.
	@server
]=]
local SpawnEnemy = {}
SpawnEnemy.__index = SpawnEnemy
setmetatable(SpawnEnemy, BaseCommand)

function SpawnEnemy.new()
	local self = BaseCommand.new("Enemy", "SpawnEnemy")
	return setmetatable(self, SpawnEnemy)
end

function SpawnEnemy:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_spawnPolicy = "EnemySpawnPolicy",
		_entityContext = "EntityContext",
		_aiContext = "AIContext",
		_combatContext = "CombatContext",
	})
end

function SpawnEnemy:Start(registry: any, _name: string)
	self._teamContext = registry:Get("TeamContext")
end

function SpawnEnemy:Execute(role: string, spawnCFrame: CFrame, waveNumber: number): Result.Result<number>
	local entity: number? = nil
	local enemyId: string? = nil
	local teamAssigned = false

	return Result.Catch(function()
		Try(self._spawnPolicy:Check(role, spawnCFrame))
		Ensure(waveNumber > 0, "InvalidWaveNumber", Errors.INVALID_WAVE_NUMBER)

		local roleConfig = EnemyConfig.Roles[role]
		Ensure(roleConfig ~= nil, "InvalidRole", Errors.INVALID_ROLE, {
			Role = role,
		})

		enemyId = HttpService:GenerateGUID(false)
		local createResult = self._entityContext:CreateEntity("Enemy.Actor", {
			Identity = {
				EntityId = enemyId,
				EntityKind = "Enemy",
				DefinitionId = role,
			},
			Health = {
				Current = roleConfig.MaxHp,
				Max = roleConfig.MaxHp,
			},
			Transform = {
				CFrame = spawnCFrame,
			},
			ModelRef = {
				Model = nil,
			},
			Target = {
				TargetEntity = nil,
				TargetKind = nil,
			},
			Role = {
				Role = role,
				WaveNumber = waveNumber,
				MoveSpeed = roleConfig.MoveSpeed,
				Damage = roleConfig.Damage,
				AttackRange = roleConfig.AttackRange,
				AttackCooldown = roleConfig.AttackCooldown,
				TargetPreference = roleConfig.TargetPreference,
				MovementMode = roleConfig.MovementMode,
			},
			PathState = {
				GoalPosition = nil,
				IsMoving = false,
			},
			CurrentMoveSpeed = {
				Value = roleConfig.MoveSpeed,
			},
			AttackCooldown = {
				Cooldown = roleConfig.AttackCooldown,
				LastAttackTime = 0,
			},
			AnimationState = "Idle",
			AnimationLooping = true,
		})
		Try(createResult)
		entity = createResult.value

		Try(self._combatContext:SetupMovementActor(entity, {
			ApplyMode = "Kinematic",
			DefaultMode = roleConfig.MovementMode,
			GoalReachedDistance = 4,
			MoveSpeed = roleConfig.MoveSpeed,
		}))

		Try(self._aiContext:SetupEntityAIFromProfile(entity, ("Enemy%sAI"):format(role)))
		Try(self._entityContext:EnableRuntimeBinding("Enemy"))
		Try(self._entityContext:EnableRuntimeSync("Enemy"))
		Try(self._entityContext:EnableRuntimeReplication("Enemy"))
		Try(self._entityContext:RegisterRuntimeEntity(entity))
		Try(self._entityContext:FlushBindQueue())

		local boundInstanceResult = self._entityContext:GetBoundInstance(entity)
		if boundInstanceResult.success and boundInstanceResult.value ~= nil then
			Try(self._entityContext:Set(entity, "ModelRef", {
				Model = boundInstanceResult.value,
			}, "Entity"))
		end

		Try(self._teamContext:AssignMemberToEnemyTeam(TeamTypes.BuildMemberHandle("Enemy", enemyId)))
		teamAssigned = true
		self:_EmitGameEvent("Wave", "EnemySpawned", entity, role, waveNumber)

		return Ok(entity)
	end, self:_Label(), function()
		if entity then
			self._entityContext:DestroyEntity(entity)
		end
		if teamAssigned and enemyId ~= nil then
			self._teamContext:UnassignMember(TeamTypes.BuildMemberHandle("Enemy", enemyId))
		end
	end)
end

return SpawnEnemy
