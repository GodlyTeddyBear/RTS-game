--!strict

--[=[
	@class StartCombatPolicy
	Domain policy that validates preconditions for starting a combat session.

	Answers: can combat be started for this user with these entities?

	Responsibilities:
	- Fetch active combats from CombatLoopService
	- Build a candidate from passed params + fetched state
	- Evaluate the CanStartCombat spec against the candidate
	- Return Ok(nil) on success or Err on validation failure
	@server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CombatSpecs = require(script.Parent.Parent.Specs.CombatSpecs)
local Result = require(ReplicatedStorage.Utilities.Result)

local Ok = Result.Ok
local Try = Result.Try

local StartCombatPolicy = {}
StartCombatPolicy.__index = StartCombatPolicy

export type TStartCombatPolicy = typeof(setmetatable({}, StartCombatPolicy))

function StartCombatPolicy.new(): TStartCombatPolicy
	return setmetatable({}, StartCombatPolicy)
end

function StartCombatPolicy:Init(registry: any)
	self.CombatLoopService = registry:Get("CombatLoopService")
end

--[=[
	Validate preconditions for starting combat.

	Checks: valid user ID, at least one adventurer, at least one enemy,
	and no existing active combat for the user.
	@within StartCombatPolicy
	@param userId number
	@param adventurerList { any } -- Flattened adventurer entities
	@param enemyEntities { any } -- Enemy entities
	@return Result.Result<nil> -- Ok if all checks pass, Err if any fails
]=]
function StartCombatPolicy:Check(
	userId: number,
	adventurerList: { any },
	enemyEntities: { any }
): Result.Result<nil>
	local activeCombats = self.CombatLoopService:GetActiveCombats()

	-- Build candidate for spec evaluation; defensive logic prevents short-circuits on invalid userId
	local candidate: CombatSpecs.TStartCombatCandidate = {
		UserIdValid    = userId ~= nil and userId > 0,
		-- Defensive: passes when userId invalid — only the root error fires from spec
		HasAdventurers = userId == nil or userId <= 0 or #adventurerList > 0,
		HasEnemies     = userId == nil or userId <= 0 or #enemyEntities > 0,
		NoCombatActive = userId == nil or userId <= 0 or activeCombats[userId] == nil,
	}

	-- Evaluate spec; throws on first unsatisfied condition
	Try(CombatSpecs.CanStartCombat:IsSatisfiedBy(candidate))

	return Ok(nil)
end

return StartCombatPolicy
