--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)

local EnemySpecs = require(script.Parent.Parent.Specs.EnemySpecs)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok = Result.Ok
local Err = Result.Err

--[=[
	@class EnemySpawnPolicy
	Validates enemy spawn role and spawn transform before command execution.
	@server
]=]
local EnemySpawnPolicy = {}
EnemySpawnPolicy.__index = EnemySpawnPolicy

function EnemySpawnPolicy.new()
	return setmetatable({}, EnemySpawnPolicy)
end

function EnemySpawnPolicy:Check(role: string, spawnCFrame: CFrame): Result.Result<boolean>
	if not EnemySpecs.IsValidRole(role) then
		return Err("InvalidRole", Errors.INVALID_ROLE, { role = role })
	end

	if not EnemySpecs.HasValidSpawnCFrame(spawnCFrame) then
		return Err("InvalidSpawnCFrame", Errors.INVALID_SPAWN_CFRAME)
	end

	return Ok(true)
end

return EnemySpawnPolicy
