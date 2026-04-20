--!strict

--[[
	ProductionEligibilityPolicy — Domain Policy

	Answers: is this worker eligible to produce this tick?

	RESPONSIBILITIES:
	  1. Check worker has an assignment with a valid role
	  2. Look up role config to verify production capability
	  3. Calculate accumulated production from delta time and level
	  4. Build a TProductionTickCandidate and evaluate CanProduceThisTick spec
	  5. Return role config + production amount on success

	RESULT:
	  Ok({ RoleConfig, Production })  — worker is eligible and has accumulated >= 1 unit
	  Err(...)                        — no assignment, role can't produce, or production < 1

	USAGE:
	  -- Inside a Catch boundary (Application tick system):
	  local ctx = Try(self._productionPolicy:Check(workerData, currentTime))
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local Ok = Result.Ok

local RoleConfig = require(ReplicatedStorage.Contexts.Worker.Config.RoleConfig)
local WorkerSpecs = require(script.Parent.Parent.Specs.WorkerSpecs)

local ProductionEligibilityPolicy = {}
ProductionEligibilityPolicy.__index = ProductionEligibilityPolicy

export type TProductionEligibilityPolicy = typeof(setmetatable(
	{} :: {
		_levelService: any,
	},
	ProductionEligibilityPolicy
))

export type TProductionEligibilityPolicyResult = {
	RoleConfig: any,
	Production: number,
	Assignment: any,
}

function ProductionEligibilityPolicy.new(): TProductionEligibilityPolicy
	local self = setmetatable({}, ProductionEligibilityPolicy)
	self._levelService = nil :: any
	return self
end

function ProductionEligibilityPolicy:Init(registry: any, _name: string)
	self._levelService = registry:Get("WorkerLevelService")
end

function ProductionEligibilityPolicy:Check(
	workerData: any,
	currentTime: number
): Result.Result<TProductionEligibilityPolicyResult>
	local assignment = workerData.Assignment
	local worker = workerData.Worker
	local hasAssignment = assignment ~= nil and assignment.Role ~= nil
	local roleConfig = hasAssignment and RoleConfig[assignment.Role] or nil
	local canProduce = roleConfig ~= nil and roleConfig.CanProduce == true

	local production = 0
	if canProduce and hasAssignment then -- If can produce, causes generic production automatically produce exp
		local deltaTime = currentTime - assignment.LastProductionTick
		if deltaTime > 0 then
			local speedMultiplier = self._levelService:CalculateProductionSpeedForRole(worker.Level, assignment.Role)
			local rankBonus = self._levelService:CalculateRankProductionBonus(worker.Rank)
			production = roleConfig.BaseProductionRate
				* speedMultiplier
				* (1 + rankBonus)
				* deltaTime
		end
	end

	local candidate: WorkerSpecs.TProductionTickCandidate = {
		HasAssignment = hasAssignment,
		CanProduce = canProduce,
		Production = production,
	}

	local specResult = WorkerSpecs.CanProduceThisTick:IsSatisfiedBy(candidate)
	if not specResult.success then
		return specResult
	end

	return Ok({
		RoleConfig = roleConfig,
		Production = production,
		Assignment = assignment,
	})
end

return ProductionEligibilityPolicy
