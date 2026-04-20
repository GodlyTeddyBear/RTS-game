--!strict

--[[
	AssignRolePolicy — Domain Policy

	Answers: can this worker be assigned to this role?

	RESPONSIBILITIES:
	  1. Fetch worker entity from Infrastructure (WorkerEntityFactory)
	  2. Build a TAssignRoleCandidate from that state + RoleConfig
	  3. Evaluate the CanAssignRole spec against the candidate
	  4. Return the fetched entity on success (avoids double-read by the caller)

	RESULT:
	  Ok({ Entity })  — worker exists and role is valid
	  Err(...)        — worker not found, or role does not exist in config

	USAGE:
	  -- Inside a Catch boundary (Application command):
	  local ctx = Try(self._assignRolePolicy:Check(workerId, roleId))
	  self.EntityFactory:AssignRole(ctx.Entity, roleId)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local Ok, Try = Result.Ok, Result.Try

local RoleConfig = require(ReplicatedStorage.Contexts.Worker.Config.RoleConfig)
local WorkerSpecs = require(script.Parent.Parent.Specs.WorkerSpecs)

local AssignRolePolicy = {}
AssignRolePolicy.__index = AssignRolePolicy

export type TAssignRolePolicy = typeof(setmetatable(
	{} :: {
		_entityFactory: any,
		_registry: any,
		_unlockContext: any,
	},
	AssignRolePolicy
))

export type TAssignRolePolicyResult = {
	Entity: any,
}

function AssignRolePolicy.new(): TAssignRolePolicy
	local self = setmetatable({}, AssignRolePolicy)
	self._entityFactory = nil :: any
	self._registry = nil :: any
	self._unlockContext = nil :: any
	return self
end

function AssignRolePolicy:Init(registry: any, _name: string)
	self._registry = registry
	self._entityFactory = registry:Get("WorkerEntityFactory")
end

function AssignRolePolicy:Start()
	self._unlockContext = self._registry:Get("UnlockContext")
end

function AssignRolePolicy:Check(userId: number, workerId: string, roleId: string): Result.Result<TAssignRolePolicyResult>
	local entity = self._entityFactory:FindWorkerById(workerId)

	local candidate: WorkerSpecs.TAssignRoleCandidate = {
		Entity = entity,
		RoleExists = RoleConfig[roleId] ~= nil,
		IsUnlocked = self._unlockContext:IsUnlocked(userId, roleId),
	}

	Try(WorkerSpecs.CanAssignRole:IsSatisfiedBy(candidate))

	return Ok({
		Entity = entity,
	})
end

return AssignRolePolicy
