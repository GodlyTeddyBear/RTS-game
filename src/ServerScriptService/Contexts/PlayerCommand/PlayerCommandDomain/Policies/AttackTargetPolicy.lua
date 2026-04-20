--!strict

--[=[
	@class AttackTargetPolicy
	Domain policy that validates whether an attack target in command data is a legitimate enemy.
	@server
]=]

--[[
	AttackTargetPolicy — Domain Policy

	Answers: is the AttackTarget command data valid for this player?

	RESPONSIBILITIES:
	  1. Parse the target NPC ID from command data
	  2. Look up the target entity from NPCEntityFactory
	  3. Build a TAttackTargetCandidate from the entity state
	  4. Evaluate the CanAttackTarget spec against the candidate
	  5. Return Ok(nil) on success (caller already holds all needed data)

	RESULT:
	  Ok(nil) — attack target is valid
	  Err(...) — target ID missing/invalid, entity not found, not alive, or is not an enemy

	USAGE:
	  -- Inside a Catch boundary (Application command):
	  Try(self.AttackTargetPolicy:Check(userId, data))
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CommandSpecs = require(script.Parent.Parent.Specs.CommandSpecs)
local Result = require(ReplicatedStorage.Utilities.Result)

local Ok = Result.Ok
local Try = Result.Try

local AttackTargetPolicy = {}
AttackTargetPolicy.__index = AttackTargetPolicy

export type TAttackTargetPolicy = typeof(setmetatable({}, AttackTargetPolicy))

--[=[
	Creates a new `AttackTargetPolicy` instance.
	@within AttackTargetPolicy
	@return TAttackTargetPolicy
]=]
function AttackTargetPolicy.new(): TAttackTargetPolicy
	return setmetatable({}, AttackTargetPolicy)
end

--[=[
	Wires dependencies from the service registry.
	@within AttackTargetPolicy
	@param registry any -- The context-local service registry
]=]
function AttackTargetPolicy:Start(registry: any)
	self.NPCEntityFactory = registry:Get("NPCEntityFactory")
end

--[=[
	Validates the attack target embedded in command data.
	@within AttackTargetPolicy
	@param userId number -- The player's user ID
	@param data {[string]: any} -- Command data containing `TargetNPCId`
	@return Result<nil> -- `Ok(nil)` when valid; `Err` if the target ID is missing, entity not found, not alive, or not an enemy
]=]
function AttackTargetPolicy:Check(userId: number, data: { [string]: any }): Result.Result<nil>
	local entityFactory = self.NPCEntityFactory
	local targetNPCId = data.TargetNPCId
	local targetIdValid = type(targetNPCId) == "string"

	local targetEntity = targetIdValid and entityFactory:GetEntityByNPCId(userId, targetNPCId) or nil
	local targetIdentity = targetEntity and entityFactory:GetIdentity(targetEntity) or nil

	local candidate: CommandSpecs.TAttackTargetCandidate = {
		TargetIdValid = targetIdValid,
		-- Defensive: passes when targetId invalid — only the root error fires
		TargetExists  = not targetIdValid or targetEntity ~= nil,
		TargetAlive   = not targetIdValid or targetEntity == nil or entityFactory:IsAlive(targetEntity),
		TargetIsEnemy = not targetIdValid or targetEntity == nil
			or (targetIdentity ~= nil and targetIdentity.IsAdventurer == false),
	}

	Try(CommandSpecs.CanAttackTarget:IsSatisfiedBy(candidate))

	return Ok(nil)
end

return AttackTargetPolicy
