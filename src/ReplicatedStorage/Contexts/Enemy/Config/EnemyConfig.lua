--!strict

--[=[
	@class EnemyConfig
	Defines the shared phase-0 enemy role tuning used by server systems.
	@server
	@client
]=]
local EnemyTypes = require(script.Parent.Parent.Types.EnemyTypes)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FreezeDeep = require(ReplicatedStorage.Utilities.FreezeDeep)
type TEnemyRole = EnemyTypes.EnemyRole
type TEnemyRoleConfig = EnemyTypes.EnemyRoleConfig
type TEnemyConfig = EnemyTypes.EnemyConfig

local Definitions: { [TEnemyRole]: TEnemyRoleConfig } = {
	Swarm = {
		DefinitionId = "Swarm",
		DisplayName = "Swarm",
		Health = { Max = 30 },
		AI = { ProfileId = "EnemySwarmAI" },
		Movement = { Mode = "Boids", Speed = 16 },
		Capabilities = {
			Attack = {
				Damage = 5,
				Range = 6,
				Cooldown = 1.25,
				TargetPreference = "Goal",
			},
		},
	},
	Tank = {
		DefinitionId = "Tank",
		DisplayName = "Tank",
		Health = { Max = 120 },
		AI = { ProfileId = "EnemyTankAI" },
		Movement = { Mode = "Path", Speed = 8 },
		Capabilities = {
			Attack = {
				Damage = 15,
				Range = 6,
				Cooldown = 1.25,
				TargetPreference = "Goal",
			},
		},
	},
}

local EnemyConfig: TEnemyConfig = {
	Definitions = FreezeDeep(Definitions),
}

return FreezeDeep(EnemyConfig)
