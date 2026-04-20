--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WorkerLevelConfig = require(ReplicatedStorage.Contexts.Worker.Config.WorkerLevelConfig)
local WorkerConfig = require(ReplicatedStorage.Contexts.Worker.Config.WorkerConfig)
local RoleConfig = require(ReplicatedStorage.Contexts.Worker.Config.RoleConfig)
local OreConfig = require(ReplicatedStorage.Contexts.Worker.Config.OreConfig)
local RankConfig = require(ReplicatedStorage.Contexts.Worker.Config.RankConfig)

-- Pure business logic service for worker level calculations
-- No external dependencies, no side effects

local WorkerLevelService = {}
WorkerLevelService.__index = WorkerLevelService

export type TWorkerLevelService = typeof(setmetatable({}, WorkerLevelService))

function WorkerLevelService.new(): TWorkerLevelService
	local self = setmetatable({}, WorkerLevelService)
	return self
end

--- Calculate production speed multiplier based on worker level
--- Formula: baseRate × (1 + (level - 1) × levelScaling)
--- Example: Level 1 = 1.0x, Level 10 = 1.9x, Level 20 = 2.9x
function WorkerLevelService:CalculateProductionSpeed(level: number, workerType: string): number
	assert(type(level) == "number", "Level must be a number")
	assert(level >= 1, "Level must be at least 1")
	assert(type(workerType) == "string", "WorkerType must be a string")

	local config = WorkerConfig[workerType]
	assert(config, "Worker type does not exist in config")

	local baseRate = config.BaseProductionRate
	local levelScaling = config.LevelScaling

	return baseRate * (1 + (level - 1) * levelScaling)
end

--- Calculate XP required to reach the next level
--- Formula: baseXP × (growthRate ^ (level - 1))
--- Example: L1→L2 = 100 XP, L2→L3 = 120 XP, L3→L4 = 144 XP
function WorkerLevelService:CalculateXPRequired(level: number): number
	assert(type(level) == "number", "Level must be a number")
	assert(level >= 1, "Level must be at least 1")

	local baseXP = WorkerLevelConfig.XPRequirementBase
	local growthRate = WorkerLevelConfig.XPRequirementGrowth

	return math.floor(baseXP * (growthRate ^ (level - 1)))
end

--- Check if worker should level up and handle overflow XP
--- Returns: (shouldLevelUp: boolean, newLevel: number, remainingXP: number)
function WorkerLevelService:CheckLevelUp(
	currentXP: number,
	currentLevel: number
): (boolean, number, number)
	assert(type(currentXP) == "number", "CurrentXP must be a number")
	assert(type(currentLevel) == "number", "CurrentLevel must be a number")
	assert(currentLevel >= 1, "CurrentLevel must be at least 1")

	-- Check if at max level
	if currentLevel >= WorkerLevelConfig.MaxLevel then
		return false, currentLevel, currentXP
	end

	local xpRequired = self:CalculateXPRequired(currentLevel)

	-- Check if enough XP to level up
	if currentXP < xpRequired then
		return false, currentLevel, currentXP
	end

	-- Level up and calculate remaining XP
	local newLevel = currentLevel + 1
	local remainingXP = currentXP - xpRequired

	-- Handle multiple level ups (overflow XP)
	while remainingXP >= self:CalculateXPRequired(newLevel) and newLevel < WorkerLevelConfig.MaxLevel do
		remainingXP = remainingXP - self:CalculateXPRequired(newLevel)
		newLevel = newLevel + 1
	end

	return true, newLevel, remainingXP
end

--- Calculate production speed multiplier based on role and level
--- Formula: roleBaseRate × (1 + (level - 1) × roleLevelScaling)
--- Example: Forge Level 1 = 1.0, Level 10 = 1.9, Level 20 = 2.9
function WorkerLevelService:CalculateProductionSpeedForRole(level: number, roleId: string): number
	assert(type(level) == "number", "Level must be a number")
	assert(level >= 1, "Level must be at least 1")
	assert(type(roleId) == "string", "RoleId must be a string")

	local roleConfig = RoleConfig[roleId]
	assert(roleConfig, "Role does not exist in config")

	local baseRate = roleConfig.BaseProductionRate
	local levelScaling = roleConfig.LevelScaling

	return baseRate * (1 + (level - 1) * levelScaling)
end

--- Calculate XP gained for production in a role
--- Formula: unitsProduced × roleXPPerProduction
function WorkerLevelService:CalculateXPForProduction(unitsProduced: number, roleId: string): number
	assert(type(unitsProduced) == "number", "UnitsProduced must be a number")
	assert(type(roleId) == "string", "RoleId must be a string")

	local roleConfig = RoleConfig[roleId]
	assert(roleConfig, "Role does not exist in config")

	return math.floor(unitsProduced * roleConfig.XPPerProduction)
end

--- Calculate XP gained for completing one mining action on an ore type
--- Pure lookup: returns OreConfig[oreId].XPPerMine
function WorkerLevelService:CalculateXPForMining(oreId: string): number
	assert(type(oreId) == "string", "OreId must be a string")

	local oreConfig = OreConfig[oreId]
	assert(oreConfig, "Ore does not exist in config")

	return oreConfig.XPPerMine
end

--- Calculate quality roll based on worker level
--- Level  1-4:  Common only
--- Level  5-9:  70% Common, 30% Uncommon
--- Level 10+:  40% Common, 40% Uncommon, 20% Rare
--- Returns: "Common" | "Uncommon" | "Rare"
function WorkerLevelService:CalculateQualityRoll(level: number): string
	assert(type(level) == "number", "Level must be a number")
	assert(level >= 1, "Level must be at least 1")

	local roll = math.random()

	if level >= 10 then
		if roll < 0.40 then
			return "Common"
		elseif roll < 0.80 then
			return "Uncommon"
		else
			return "Rare"
		end
	elseif level >= 5 then
		if roll < 0.70 then
			return "Common"
		else
			return "Uncommon"
		end
	else
		return "Common"
	end
end

--- Return the additive production bonus for a given rank.
--- Defaults to 0 (Apprentice) if rank is nil or unrecognised.
function WorkerLevelService:CalculateRankProductionBonus(rank: string?): number
	local rankData = rank and RankConfig.Ranks[rank] or nil
	return rankData and rankData.ProductionBonus or 0
end

--- Return the rank ID that a worker should hold at the given level.
--- Workers are promoted automatically when they level up past a threshold.
function WorkerLevelService:GetRankForLevel(level: number): string
	if level >= 30 then return "Master" end
	if level >= 15 then return "Journeyman" end
	return "Apprentice"
end

--- Check if a timed mining action has completed
--- Returns: (isComplete: boolean, elapsed: number)
function WorkerLevelService:IsMiningComplete(
	miningStartTime: number,
	miningDuration: number,
	currentTime: number
): (boolean, number)
	assert(type(miningStartTime) == "number", "MiningStartTime must be a number")
	assert(type(miningDuration) == "number", "MiningDuration must be a number")
	assert(type(currentTime) == "number", "CurrentTime must be a number")

	local elapsed = currentTime - miningStartTime
	return elapsed >= miningDuration, elapsed
end

return WorkerLevelService
