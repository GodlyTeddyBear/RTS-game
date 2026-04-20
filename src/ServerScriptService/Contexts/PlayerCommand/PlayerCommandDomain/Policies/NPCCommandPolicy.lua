--!strict

--[=[
	@class NPCCommandPolicy
	Domain policy that evaluates whether a specific NPC can be commanded by a player.
	@server
]=]

--[[
	NPCCommandPolicy — Domain Policy

	Answers: can this NPC be commanded by this player?

	RESPONSIBILITIES:
	  1. Look up the NPC entity from NPCEntityFactory
	  2. Build a TNPCCommandCandidate from the entity state
	  3. Evaluate the CanCommandNPC spec against the candidate
	  4. Return Ok({ Entity }) on success so the caller avoids a second entity lookup

	RESULT:
	  Ok({ Entity }) — NPC is commandable; entity returned for command use
	  Err(...)       — NPC not found, not alive, not an adventurer, or not owned

	NOTE:
	  This policy is intended for per-NPC soft-check loops where the caller
	  inspects result.success directly WITHOUT using Try:

	    local result = self.NPCCommandPolicy:Check(userId, npcId)
	    if result.success then
	        local entity = (result :: any).value.Entity
	        -- command entity
	    else
	        -- log and skip
	    end

	  For command-level gates (abort on failure) use Try as normal.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CommandSpecs = require(script.Parent.Parent.Specs.CommandSpecs)
local Result = require(ReplicatedStorage.Utilities.Result)

local Ok = Result.Ok

local NPCCommandPolicy = {}
NPCCommandPolicy.__index = NPCCommandPolicy

export type TNPCCommandPolicy = typeof(setmetatable({}, NPCCommandPolicy))

--[=[
	Creates a new `NPCCommandPolicy` instance.
	@within NPCCommandPolicy
	@return TNPCCommandPolicy
]=]
function NPCCommandPolicy.new(): TNPCCommandPolicy
	return setmetatable({}, NPCCommandPolicy)
end

--[=[
	Wires dependencies from the service registry.
	@within NPCCommandPolicy
	@param registry any -- The context-local service registry
]=]
function NPCCommandPolicy:Start(registry: any)
	self.NPCEntityFactory = registry:Get("NPCEntityFactory")
end

--[=[
	Checks whether an NPC can be commanded by the given player.
	@within NPCCommandPolicy
	@param userId number -- The player's user ID
	@param npcId string -- The NPC identifier to check
	@return Result<{Entity: any}> -- `Ok({Entity})` on success; `Err` if the NPC is invalid, not alive, not an adventurer, or not owned
]=]
function NPCCommandPolicy:Check(userId: number, npcId: string): Result.Result<{ Entity: any }>
	local entityFactory = self.NPCEntityFactory
	local entity = entityFactory:GetEntityByNPCId(userId, npcId)
	local identity = entity and entityFactory:GetIdentity(entity) or nil
	local team = entity and entityFactory:GetTeam(entity) or nil

	local candidate: CommandSpecs.TNPCCommandCandidate = {
		NPCExists       = entity ~= nil,
		-- Defensive: passes when entity not found — only the root error fires
		NPCAlive        = entity == nil or entityFactory:IsAlive(entity),
		NPCIsAdventurer = entity == nil or (identity ~= nil and identity.IsAdventurer == true),
		NPCOwned        = entity == nil or (team ~= nil and team.UserId == userId),
	}

	local result = CommandSpecs.CanCommandNPC:IsSatisfiedBy(candidate)
	if not result.success then
		return result :: any
	end

	return Ok({ Entity = entity })
end

return NPCCommandPolicy
