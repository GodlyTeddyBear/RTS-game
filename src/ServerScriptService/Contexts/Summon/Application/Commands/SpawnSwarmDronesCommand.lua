--!strict

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Orient = require(ReplicatedStorage.Utilities.Orient)
local Result = require(ReplicatedStorage.Utilities.Result)
local SummonConfig = require(ReplicatedStorage.Contexts.Summon.Config.SummonConfig)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok = Result.Ok
local Try = Result.Try
local Ensure = Result.Ensure

local SpawnSwarmDronesCommand = {}
SpawnSwarmDronesCommand.__index = SpawnSwarmDronesCommand
setmetatable(SpawnSwarmDronesCommand, BaseCommand)

local function _computeSpawnOffset(index: number): Vector3
	local angle = (math.pi * 2) * (index / 5)
	local radius = 3 + ((index % 2) * 1.5)
	return Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
end

local function _toPositiveInt(value: any, fallback: number): number
	if type(value) ~= "number" or value <= 0 then
		return fallback
	end
	return math.floor(value)
end

function SpawnSwarmDronesCommand.new()
	local self = BaseCommand.new("Summon", "SpawnSwarmDrones")
	return setmetatable(self, SpawnSwarmDronesCommand)
end

function SpawnSwarmDronesCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_summonReadService = "SummonEntityReadService",
	})
end

function SpawnSwarmDronesCommand:Start(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_aiContext = "AIContext",
		_combatContext = "CombatContext",
		_entityContext = "EntityContext",
	})
end

function SpawnSwarmDronesCommand:Execute(
	player: Player,
	slotMetadata: { [string]: any }?,
	castOriginCFrame: CFrame
): Result.Result<{ SpawnedCount: number }>
	local createdEntities = {}

	return Result.Catch(function()
		Ensure(player, "InvalidPlayer", Errors.INVALID_PLAYER)
		Ensure(castOriginCFrame, "InvalidCastOrigin", Errors.INVALID_CAST_ORIGIN)
		Ensure(slotMetadata == nil or type(slotMetadata) == "table", "InvalidMetadata", Errors.INVALID_METADATA)

		local defaults = SummonConfig.SWARM_DRONES
		local summonCount = _toPositiveInt(if slotMetadata then slotMetadata.SummonCount else nil, defaults.SummonCount)
		local lifetime = if slotMetadata and type(slotMetadata.Lifetime) == "number" and slotMetadata.Lifetime > 0
			then slotMetadata.Lifetime
			else defaults.Lifetime

		Ensure(summonCount > 0, "InvalidSummonCount", Errors.INVALID_SUMMON_COUNT)
		Ensure(lifetime > 0, "InvalidLifetime", Errors.INVALID_LIFETIME)

		local spawnedCount = 0
		local ownerUserId = player.UserId
		local currentCount = self._summonReadService:GetOwnerDroneCount(ownerUserId)
		for index = 1, summonCount do
			if currentCount >= defaults.MaxConcurrentDronesPerPlayer then
				break
			end

			local offset = _computeSpawnOffset(index)
			local spawnPosition = castOriginCFrame.Position + offset
			local spawnCFrame = Orient.BuildLookAt(spawnPosition, spawnPosition + castOriginCFrame.LookVector)
				or castOriginCFrame
			local now = os.clock()
			local summonId = HttpService:GenerateGUID(false)
			local entity = Try(self._entityContext:CreateEntity("Summon.Drone", {
				Identity = {
					EntityId = summonId,
					EntityKind = "Summon",
					DefinitionId = "SwarmDrone",
				},
				Ownership = {
					Faction = "Player",
					OwnerKind = "Player",
					OwnerId = tostring(ownerUserId),
				},
				Health = {
					Current = 1,
					Max = 1,
				},
				Transform = {
					CFrame = spawnCFrame,
				},
				ModelAsset = {
					AssetKind = "Part",
					AssetId = "SwarmDrone",
				},
				ModelBinding = {
					ParentFolder = "Summon",
					SetupProfileId = "KinematicPart",
					RevealTag = "SummonDrone",
					NameFormat = "SwarmDrone_{EntityId}",
				},
				TransformProjection = {
					Enabled = true,
				},
				TransformPoll = {
					Enabled = false,
				},
				CleanupOutcomes = {
					OutcomeIds = { "AICleanup", "MovementCleanup" },
				},
				Lifetime = {
					SpawnedAt = now,
					ExpiresAt = now + lifetime,
				},
				Kind = {
					Kind = "SwarmDrone",
				},
				CombatProfile = {
					MoveSpeed = defaults.MoveSpeed,
					AcquireRange = defaults.AcquireRange,
					AttackRange = defaults.AttackRange,
					AttackInterval = defaults.AttackInterval,
					DamagePerHit = defaults.DamagePerHit,
				},
				AttackCooldown = {
					LastAttackAt = 0,
				},
				TargetEnemyId = nil,
			}))
			table.insert(createdEntities, entity)

			Try(self._combatContext:SetupMovementActor(entity, {
				ApplyMode = "Kinematic",
				DefaultMode = "Direct",
				GoalReachedDistance = defaults.AttackRange,
				MoveSpeed = defaults.MoveSpeed,
			}))
			Try(self._aiContext:SetupEntityAIFromProfile(entity, "SummonSwarmDroneAI"))
			Try(self._entityContext:RegisterRuntimeEntity(entity))
			Try(self._entityContext:FlushBindQueue())

			local boundInstanceResult = self._entityContext:GetBoundInstance(entity)
			local boundInstance = if boundInstanceResult.success then boundInstanceResult.value else nil
			if boundInstance ~= nil and boundInstance:IsA("BasePart") then
				Try(self._entityContext:Set(entity, "ModelRef", {
					Model = boundInstance,
				}, "Entity"))
			end

			spawnedCount += 1
			currentCount += 1
		end

		Ensure(spawnedCount > 0, "MaxConcurrentReached", Errors.MAX_CONCURRENT_REACHED, {
			UserId = ownerUserId,
		})
		return Ok({
			SpawnedCount = spawnedCount,
		})
	end, self:_Label(), function()
		for _, entity in ipairs(createdEntities) do
			self._entityContext:DestroyEntity(entity)
		end
	end)
end

return SpawnSwarmDronesCommand
