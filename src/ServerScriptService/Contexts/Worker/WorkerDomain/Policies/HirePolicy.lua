--!strict

--[[
	HirePolicy — Domain Policy

	Answers: is this worker type valid for hiring?

	RESPONSIBILITIES:
	  1. Build a THireCandidate from WorkerConfig state
	  2. Evaluate the CanHire spec against the candidate
	  3. Return Ok(nil) on success (no state needed by the command)

	RESULT:
	  Ok(nil)   — worker type is valid and can be hired
	  Err(...)  — worker type does not exist in config

	USAGE:
	  -- Inside a Catch boundary (Application command):
	  Try(self._hirePolicy:Check(workerType))
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local Ok, Try = Result.Ok, Result.Try

local WorkerConfig = require(ReplicatedStorage.Contexts.Worker.Config.WorkerConfig)
local WorkerSpecs = require(script.Parent.Parent.Specs.WorkerSpecs)

local HirePolicy = {}
HirePolicy.__index = HirePolicy

export type THirePolicy = typeof(setmetatable({}, HirePolicy))

function HirePolicy.new(): THirePolicy
	return setmetatable({}, HirePolicy)
end

function HirePolicy:Check(workerType: string): Result.Result<nil>
	local candidate: WorkerSpecs.THireCandidate = {
		WorkerTypeExists = WorkerConfig[workerType] ~= nil,
	}
	Try(WorkerSpecs.CanHire:IsSatisfiedBy(candidate))
	return Ok(nil)
end

return HirePolicy
