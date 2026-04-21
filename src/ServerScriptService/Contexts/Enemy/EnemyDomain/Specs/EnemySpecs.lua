--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EnemyConfig = require(ReplicatedStorage.Contexts.Enemy.Config.EnemyConfig)

--[=[
	@class EnemySpecs
	Provides pure validation predicates for enemy spawn requests.
	@server
]=]
local EnemySpecs = {}

function EnemySpecs.IsValidRole(role: string): boolean
	return EnemyConfig.ROLES[role] ~= nil
end

function EnemySpecs.HasValidSpawnCFrame(spawnCFrame: CFrame): boolean
	return typeof(spawnCFrame) == "CFrame"
end

return table.freeze(EnemySpecs)
