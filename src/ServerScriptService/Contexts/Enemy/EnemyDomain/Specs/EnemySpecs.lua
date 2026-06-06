--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EnemyConfig = require(ReplicatedStorage.Contexts.Enemy.Config.EnemyConfig)
local EntityDefinitionSpecs = require(ReplicatedStorage.Contexts.Entity.Specs.EntityDefinitionSpecs)

--[=[
	@class EnemySpecs
	Provides pure validation predicates for enemy spawn requests.
	@server
]=]
local EnemySpecs = {}

local function _IsPositiveFiniteNumber(value: any): boolean
	return type(value) == "number" and value > 0 and value == value and value < math.huge
end

function EnemySpecs.IsValidRole(role: string): boolean
	local definition = EnemyConfig.Definitions[role]
	if definition == nil or definition.DefinitionId ~= role or not EntityDefinitionSpecs.IsValid(definition) then
		return false
	end
	if type(definition.Capabilities) ~= "table" or type(definition.Capabilities.Attack) ~= "table" then
		return false
	end
	local attack = definition.Capabilities.Attack
	return _IsPositiveFiniteNumber(attack.Damage)
		and _IsPositiveFiniteNumber(attack.Range)
		and _IsPositiveFiniteNumber(attack.Cooldown)
end

function EnemySpecs.HasValidSpawnCFrame(spawnCFrame: CFrame): boolean
	return typeof(spawnCFrame) == "CFrame"
end

return table.freeze(EnemySpecs)
