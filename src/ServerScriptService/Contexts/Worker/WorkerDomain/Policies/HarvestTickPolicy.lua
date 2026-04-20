--!strict

--[[
	HarvestTickPolicy — Domain Policy

	Answers: should this harvesting worker (Lumberjack/Herbalist/Farmer) complete
	a harvest action this tick?

	Shared by all three roles — the caller passes the zone folder getter and
	target config so this single policy handles all harvest types.

	RESPONSIBILITIES:
	  1. Resolve target instance from the lot (Infrastructure - LotContext)
	  2. Compute proximity between worker and target (Infrastructure - EntityFactory)
	  3. Check harvest timer completion (Domain - WorkerLevelService)
	  4. Build a THarvestTickCandidate and evaluate CanHarvestThisTick spec
	  5. Return target config on success for the command to grant rewards

	RESULT:
	  Ok({ TargetId, TargetConfig })  — worker is near target and harvest action is complete
	  Err(...)                        — target missing, worker too far, or timer not elapsed

	USAGE:
	  -- Inside a Catch boundary (Application tick system):
	  local ctx = Try(self._harvestTickPolicy:Check(entity, worker, harvestState, currentTime, targetConfig, getFolderFn))
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local Ok = Result.Ok
local Err = Result.Err

local Errors = require(script.Parent.Parent.Parent.Errors)
local WorkerSpecs = require(script.Parent.Parent.Specs.WorkerSpecs)
local ZoneTargetUtils = require(script.Parent.Shared.ZoneTargetUtils)

local HARVEST_PROXIMITY_STUDS = 10

local HarvestTickPolicy = {}
HarvestTickPolicy.__index = HarvestTickPolicy

export type THarvestTickPolicy = typeof(setmetatable(
	{} :: {
		_registry: any,
		_entityFactory: any,
		_levelService: any,
		_lotContext: any?,
	},
	HarvestTickPolicy
))

export type THarvestTickPolicyResult = {
	TargetId: string,
	TargetConfig: any,
}

function HarvestTickPolicy.new(): THarvestTickPolicy
	local self = setmetatable({}, HarvestTickPolicy)
	self._registry = nil :: any
	self._entityFactory = nil :: any
	self._levelService = nil :: any
	self._lotContext = nil :: any
	return self
end

function HarvestTickPolicy:Init(registry: any, _name: string)
	self._registry = registry
	self._entityFactory = registry:Get("WorkerEntityFactory")
	self._levelService = registry:Get("WorkerLevelService")
end

function HarvestTickPolicy:Start()
	self._lotContext = self._registry:Get("LotContext")
end

--- Check harvest eligibility for a single worker.
--- targetConfig: the full config table (TreeConfig, PlantConfig, or CropConfig)
--- getFolderFn: function(lotContext, userId) -> folder | nil  (zone-specific lookup)
--- preferredFolderName: preferred child folder inside the zone folder (e.g. "Default")
function HarvestTickPolicy:Check(
	entity: any,
	worker: any,
	harvestState: any,
	currentTime: number,
	targetConfig: { [string]: any },
	getFolderFn: (lotContext: any, userId: number) -> any?,
	preferredFolderName: string
): Result.Result<THarvestTickPolicyResult>
	if not self._lotContext then
		return Err("HarvestTickPolicy", Errors.LOT_NOT_FOUND)
	end

	local targetId = harvestState.TargetOreId -- reuses same ECS field as miners
	local targetExists = self:_DoesTargetExist(worker.UserId, targetId, getFolderFn, preferredFolderName)
	local isNear = self:_IsWorkerNearTarget(entity, worker.UserId, targetId, getFolderFn, preferredFolderName)
	local isComplete = self._levelService:IsMiningComplete(harvestState.MiningStartTime, harvestState.MiningDuration, currentTime)

	local candidate: WorkerSpecs.THarvestTickCandidate = {
		TargetExists = targetExists,
		IsNearTarget = isNear,
		HarvestComplete = isComplete,
	}

	local specResult = WorkerSpecs.CanHarvestThisTick:IsSatisfiedBy(candidate)
	if not specResult.success then return specResult end

	return Ok({
		TargetId = targetId,
		TargetConfig = targetConfig[targetId],
	})
end

function HarvestTickPolicy:_DoesTargetExist(
	userId: number,
	targetId: string,
	getFolderFn: (any, number) -> any?,
	preferredFolderName: string
): boolean
	if not self._lotContext then return false end
	local zoneFolder = getFolderFn(self._lotContext, userId)
	if not zoneFolder then return false end
	return ZoneTargetUtils.FindTargetInZone(zoneFolder, targetId, preferredFolderName) ~= nil
end

function HarvestTickPolicy:_IsWorkerNearTarget(
	entity: any,
	userId: number,
	targetId: string,
	getFolderFn: (any, number) -> any?,
	preferredFolderName: string
): boolean
	if not self._lotContext then return false end

	local zoneFolder = getFolderFn(self._lotContext, userId)
	if not zoneFolder then return false end

	local targetInstance = ZoneTargetUtils.FindTargetInZone(zoneFolder, targetId, preferredFolderName)
	if not targetInstance then return false end

	local workerPosition = self._entityFactory:GetInstancePosition(entity)
	if not workerPosition then return false end

	local targetPosition: Vector3 = targetInstance:GetPivot().Position
	local distance = (workerPosition - targetPosition).Magnitude
	return distance <= HARVEST_PROXIMITY_STUDS
end

return HarvestTickPolicy
