--!strict

--[[
	AssignMinerOrePolicy — Domain Policy

	Answers: can this worker be assigned to mine this ore type?

	RESPONSIBILITIES:
	  1. Fetch worker entity from Infrastructure (WorkerEntityFactory)
	  2. Fetch the player's mines folder from cross-context Infrastructure (LotContext)
	  3. Build a TAssignMinerOreCandidate from that state + OreConfig
	  4. Evaluate the CanAssignMinerOre spec against the candidate
	  5. Return the entity and ore instance on success (avoids double-read by the caller)

	RESULT:
	  Ok({ Entity, OreInstance })  — worker exists, has Miner role, ore is valid and present in lot
	  Err(...)                     — worker not found, not a miner, invalid ore, no lot, or ore not in lot

	NOTE:
	  LotContext is a cross-context dependency registered in KnitStart. This policy
	  resolves it via Start() rather than Init().

	USAGE:
	  -- Inside a Catch boundary (Application command):
	  local ctx = Try(self._assignMinerOrePolicy:Check(userId, workerId, oreId))
	  self.EntityFactory:AssignTaskTarget(ctx.Entity, oreId)
	  local oreCFrame = ctx.OreInstance:GetPivot()
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local Ok, Try = Result.Ok, Result.Try

local OreConfig = require(ReplicatedStorage.Contexts.Worker.Config.OreConfig)
local WorkerSpecs = require(script.Parent.Parent.Specs.WorkerSpecs)
local ZoneTargetUtils = require(script.Parent.Shared.ZoneTargetUtils)

local AssignMinerOrePolicy = {}
AssignMinerOrePolicy.__index = AssignMinerOrePolicy

export type TAssignMinerOrePolicy = typeof(setmetatable(
	{} :: {
		_registry: any,
		_entityFactory: any,
		_lotContext: any,
		_unlockContext: any,
		_miningSlotService: any,
	},
	AssignMinerOrePolicy
))

export type TAssignMinerOrePolicyResult = {
	Entity: any,
	OreInstance: Instance,
}

function AssignMinerOrePolicy.new(): TAssignMinerOrePolicy
	local self = setmetatable({}, AssignMinerOrePolicy)
	self._registry = nil :: any
	self._entityFactory = nil :: any
	self._lotContext = nil :: any
	self._unlockContext = nil :: any
	self._miningSlotService = nil :: any
	return self
end

function AssignMinerOrePolicy:Init(registry: any, _name: string)
	self._registry = registry
	self._entityFactory = registry:Get("WorkerEntityFactory")
	self._miningSlotService = registry:Get("MiningSlotService")
end

function AssignMinerOrePolicy:Start()
	self._lotContext = self._registry:Get("LotContext")
	self._unlockContext = self._registry:Get("UnlockContext")
end

function AssignMinerOrePolicy:Check(userId: number, workerId: string, oreId: string): Result.Result<TAssignMinerOrePolicyResult>
	local entity = self._entityFactory:FindWorkerById(workerId)
	local assignment = entity and self._entityFactory:GetAssignment(entity)
	local minesFolder = self._lotContext:GetMinesFolderForUser(userId)
	local oreInstance = minesFolder and ZoneTargetUtils.FindTargetInZone(minesFolder, oreId, "Default") or nil

	local oreConfig = OreConfig[oreId]
	local workersAtOre = self._miningSlotService:GetOccupiedSlotCountExcludingWorker(userId, oreId, workerId)

	local candidate: WorkerSpecs.TAssignMinerOreCandidate = {
		Entity = entity,
		IsMiner = assignment ~= nil and assignment.Role == "Miner",
		OreTypeExists = oreConfig ~= nil,
		MinesFolderExists = minesFolder ~= nil,
		OreInLot = oreInstance ~= nil,
		IsUnlocked = self._unlockContext:IsUnlocked(userId, oreId),
		WorkersAtOre = workersAtOre,
		MaxWorkers = oreConfig and oreConfig.MaxWorkers or 0,
	}

	Try(WorkerSpecs.CanAssignMinerOre:IsSatisfiedBy(candidate))

	return Ok({
		Entity = entity,
		OreInstance = oreInstance :: Instance,
	})
end

return AssignMinerOrePolicy
