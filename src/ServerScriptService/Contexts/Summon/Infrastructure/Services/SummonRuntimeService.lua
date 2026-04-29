--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Orient = require(ReplicatedStorage.Utilities.Orient)
local Result = require(ReplicatedStorage.Utilities.Result)
local SpatialQuery = require(ReplicatedStorage.Utilities.SpatialQuery)
local SummonConfig = require(ReplicatedStorage.Contexts.Summon.Config.SummonConfig)

local SummonRuntimeService = {}
SummonRuntimeService.__index = SummonRuntimeService

local function _computeSpawnOffset(index: number): Vector3
	local angle = (math.pi * 2) * (index / 5)
	local radius = 3 + ((index % 2) * 1.5)
	return Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
end

local function _makeDronePart(ownerUserId: number): BasePart
	local part = Instance.new("Part")
	part.Name = string.format("SwarmDrone_%d", ownerUserId)
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

local function _resolveTarget(enemyContext: any, fromPosition: Vector3, maxRange: number): { Entity: number, CFrame: CFrame }?
	local nearestResult = enemyContext:GetNearestAliveEnemy(fromPosition, maxRange)
	if not nearestResult.success then
		return nil
	end
	return nearestResult.value
end

function SummonRuntimeService.new()
	return setmetatable({}, SummonRuntimeService)
end

function SummonRuntimeService:Init(registry: any, _name: string)
	self._entityFactory = registry:Get("SummonEntityFactory")
	self._summonFolder = Workspace:FindFirstChild("Summons")
	if self._summonFolder == nil then
		local folder = Instance.new("Folder")
		folder.Name = "Summons"
		folder.Parent = Workspace
		self._summonFolder = folder
	end
end

function SummonRuntimeService:SpawnSwarmDrones(player: Player, castOriginCFrame: CFrame, summonCount: number, lifetime: number): number
	local tuning = SummonConfig.SWARM_DRONES
	local ownerUserId = player.UserId
	local spawnedCount = 0
	local currentCount = self._entityFactory:GetOwnerDroneCount(ownerUserId)

	for index = 1, summonCount do
		if currentCount >= tuning.maxConcurrentDronesPerPlayer then
			break
		end

		local offset = _computeSpawnOffset(index)
		local spawnPosition = castOriginCFrame.Position + offset
		local lookAt = castOriginCFrame.LookVector
		local spawnCFrame = Orient.BuildLookAt(spawnPosition, spawnPosition + lookAt) or castOriginCFrame
		local now = os.clock()
		local entity = self._entityFactory:CreateDrone(ownerUserId, spawnCFrame, now, {
			summonCount = summonCount,
			lifetime = lifetime,
			maxConcurrentDronesPerPlayer = tuning.maxConcurrentDronesPerPlayer,
			moveSpeed = tuning.moveSpeed,
			acquireRange = tuning.acquireRange,
			attackRange = tuning.attackRange,
			attackInterval = tuning.attackInterval,
			damagePerHit = tuning.damagePerHit,
		})

		local dronePart = _makeDronePart(ownerUserId)
		dronePart.CFrame = spawnCFrame
		dronePart.Parent = self._summonFolder
		self._entityFactory:SetInstanceRef(entity, dronePart)

		spawnedCount += 1
		currentCount += 1
	end

	Result.MentionEvent("Summon:Spawn", "Spawned swarm drones", {
		OwnerUserId = ownerUserId,
		SpawnedCount = spawnedCount,
		RequestedCount = summonCount,
		Lifetime = lifetime,
	})

	return spawnedCount
end

function SummonRuntimeService:Tick(dt: number, currentTime: number, enemyContext: any)
	if enemyContext == nil then
		return
	end

	for _, entity in ipairs(self._entityFactory:QueryActiveEntities()) do
		local positionCFrame = self._entityFactory:GetPosition(entity)
		local combat = self._entityFactory:GetCombat(entity)
		local lifetime = self._entityFactory:GetLifetime(entity)
		if positionCFrame == nil or combat == nil or lifetime == nil then
			self._entityFactory:DeleteEntity(entity)
			continue
		end

		if currentTime >= lifetime.ExpiresAt then
			self._entityFactory:DeleteEntity(entity)
			continue
		end

		local target = _resolveTarget(enemyContext, positionCFrame.Position, combat.AcquireRange)
		local nextPosition = positionCFrame.Position
		if target ~= nil then
			local targetPosition = target.CFrame.Position
			local distanceToTarget = (targetPosition - nextPosition).Magnitude

			if distanceToTarget > combat.AttackRange then
				nextPosition = Orient.MoveTowards(nextPosition, targetPosition, combat.MoveSpeed * dt)
				distanceToTarget = (targetPosition - nextPosition).Magnitude
			end

			if
				SpatialQuery.IsWithinRange(nextPosition, targetPosition, combat.AttackRange)
				and (currentTime - combat.LastAttackAt) >= combat.AttackInterval
			then
				local damageResult = enemyContext:ApplyDamage(target.Entity, combat.DamagePerHit)
				if damageResult.success then
					self._entityFactory:SetLastAttackAt(entity, currentTime)
				end
			end
		end

		local nextCFrame = Orient.BuildLookAt(nextPosition, nextPosition + positionCFrame.LookVector)
			or Orient.BuildAtPosition(positionCFrame, nextPosition)
		self._entityFactory:SetPosition(entity, nextCFrame)

		local instanceRef = self._entityFactory:GetInstanceRef(entity)
		if instanceRef ~= nil then
			instanceRef.CFrame = nextCFrame
		end
	end
end

function SummonRuntimeService:CleanupAll()
	self._entityFactory:DeleteAll()
	self._entityFactory:FlushPendingDeletes()
end

function SummonRuntimeService:CleanupOwner(ownerUserId: number)
	self._entityFactory:DeleteOwnerSummons(ownerUserId)
	self._entityFactory:FlushPendingDeletes()
end

return SummonRuntimeService
