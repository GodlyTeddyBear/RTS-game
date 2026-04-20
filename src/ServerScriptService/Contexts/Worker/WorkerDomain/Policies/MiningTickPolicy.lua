--!strict

--[[
	MiningTickPolicy — Domain Policy

	Answers: should this miner complete a mining action this tick?

	RESPONSIBILITIES:
	  1. Resolve ore instance from the lot (Infrastructure - LotContext)
	  2. Compute proximity between miner and ore (Infrastructure - EntityFactory)
	  3. Check mining timer completion (Domain - WorkerLevelService)
	  4. Build a TMiningTickCandidate and evaluate CanMineThisTick spec
	  5. Return ore config on success for the command to grant rewards

	RESULT:
	  Ok({ OreId, OreConfig })  — miner is near ore and mining action is complete
	  Err(...)                  — ore missing, miner too far, or timer not elapsed

	USAGE:
	  -- Inside a Catch boundary (Application tick system):
	  local ctx = Try(self._miningTickPolicy:Check(entity, worker, miningState, currentTime))
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local Ok = Result.Ok
local Err = Result.Err

local OreConfig = require(ReplicatedStorage.Contexts.Worker.Config.OreConfig)
local Errors = require(script.Parent.Parent.Parent.Errors)
local WorkerSpecs = require(script.Parent.Parent.Specs.WorkerSpecs)
local ZoneTargetUtils = require(script.Parent.Shared.ZoneTargetUtils)

local MINING_PROXIMITY_STUDS = 10

local MiningTickPolicy = {}
MiningTickPolicy.__index = MiningTickPolicy

export type TMiningTickPolicy = typeof(setmetatable(
	{} :: {
		_registry: any,
		_entityFactory: any,
		_levelService: any,
		_lotContext: any?,
	},
	MiningTickPolicy
))

export type TMiningTickPolicyResult = {
	OreId: string,
	OreConfig: any,
}

function MiningTickPolicy.new(): TMiningTickPolicy
	local self = setmetatable({}, MiningTickPolicy)
	self._registry = nil :: any
	self._entityFactory = nil :: any
	self._levelService = nil :: any
	self._lotContext = nil :: any
	return self
end

function MiningTickPolicy:Init(registry: any, _name: string)
	self._registry = registry
	self._entityFactory = registry:Get("WorkerEntityFactory")
	self._levelService = registry:Get("WorkerLevelService")
end

function MiningTickPolicy:Start()
	self._lotContext = self._registry:Get("LotContext")
end

function MiningTickPolicy:Check(entity: any, worker: any, miningState: any, currentTime: number): Result.Result<TMiningTickPolicyResult>
	if not self._lotContext then
		return Err("MiningTickPolicy", Errors.LOT_NOT_FOUND)
	end

	local oreId = miningState.TargetOreId
	local oreExists = self:_DoesOreExist(worker.UserId, oreId)
	local isNearOre = self:_IsMinerNearOre(entity, worker.UserId, oreId)
	local isComplete = self._levelService:IsMiningComplete(miningState.MiningStartTime, miningState.MiningDuration, currentTime)

	local candidate: WorkerSpecs.TMiningTickCandidate = {
		OreExists = oreExists,
		IsNearOre = isNearOre,
		MiningComplete = isComplete,
	}

	local specResult = WorkerSpecs.CanMineThisTick:IsSatisfiedBy(candidate)
	if not specResult.success then return specResult end

	return Ok({
		OreId = oreId,
		OreConfig = OreConfig[oreId],
	})
end

function MiningTickPolicy:_DoesOreExist(userId: number, oreId: string): boolean
	if not self._lotContext then return false end
	local minesFolder = self._lotContext:GetMinesFolderForUser(userId)
	if not minesFolder then return false end
	return ZoneTargetUtils.FindTargetInZone(minesFolder, oreId, "Default") ~= nil
end

function MiningTickPolicy:_IsMinerNearOre(entity: any, userId: number, oreId: string): boolean
	if not self._lotContext then return false end

	local minesFolder = self._lotContext:GetMinesFolderForUser(userId)
	if not minesFolder then return false end

	local oreInstance = ZoneTargetUtils.FindTargetInZone(minesFolder, oreId, "Default")
	if not oreInstance then return false end

	local minerPosition = self._entityFactory:GetInstancePosition(entity)
	if not minerPosition then return false end

	local orePosition: Vector3 = oreInstance:GetPivot().Position
	local distance = (minerPosition - orePosition).Magnitude
	return distance <= MINING_PROXIMITY_STUDS
end

return MiningTickPolicy
