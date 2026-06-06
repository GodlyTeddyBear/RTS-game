--!strict

--[=[
	@class EnemyConfig
	Defines the shared phase-0 enemy role tuning used by server systems.
	@server
	@client
]=]
local EnemyTypes = require(script.Parent.Parent.Types.EnemyTypes)

type TEnemyRole = EnemyTypes.EnemyRole
type TEnemyRoleConfig = EnemyTypes.EnemyRoleConfig
type TEnemyConfig = EnemyTypes.EnemyConfig

local Definitions: { [TEnemyRole]: TEnemyRoleConfig } = table.freeze({
	Swarm = table.freeze({
		DefinitionId = "Swarm",
		DisplayName = "Swarm",
		Health = table.freeze({ Max = 30 }),
		AI = table.freeze({ ProfileId = "EnemySwarmAI" }),
		Movement = table.freeze({ Mode = "Any", Speed = 16 }),
		Capabilities = table.freeze({
			Attack = table.freeze({
				Damage = 5,
				Range = 6,
				Cooldown = 1.25,
				TargetPreference = "Goal",
			}),
		}),
	}),
	Tank = table.freeze({
		DefinitionId = "Tank",
		DisplayName = "Tank",
		Health = table.freeze({ Max = 120 }),
		AI = table.freeze({ ProfileId = "EnemyTankAI" }),
		Movement = table.freeze({ Mode = "Path", Speed = 8 }),
		Capabilities = table.freeze({
			Attack = table.freeze({
				Damage = 15,
				Range = 6,
				Cooldown = 1.25,
				TargetPreference = "Goal",
			}),
		}),
	}),
})

local EnemyConfig: TEnemyConfig = table.freeze({
	Definitions = Definitions,
})

return EnemyConfig
