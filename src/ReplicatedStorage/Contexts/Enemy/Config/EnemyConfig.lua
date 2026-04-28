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
type TPhase2AllowedRoles = { [TEnemyRole]: boolean }

local Roles: { [TEnemyRole]: TEnemyRoleConfig } = table.freeze({
	Swarm = table.freeze({
		DisplayName = "Swarm",
		MaxHp = 30,
		Damage = 5,
		AttackRange = 6,
		AttackCooldown = 1.25,
		MoveSpeed = 16,
		TargetPreference = "Goal",
		ModelScale = Vector3.new(2.5, 3, 2.5),
		ModelColor = Color3.fromRGB(240, 196, 78),
		MovementMode = "Any",
	}),
	Tank = table.freeze({
		DisplayName = "Tank",
		MaxHp = 120,
		Damage = 15,
		AttackRange = 6,
		AttackCooldown = 1.25,
		MoveSpeed = 8,
		TargetPreference = "Goal",
		ModelScale = Vector3.new(4, 4.5, 4),
		ModelColor = Color3.fromRGB(150, 92, 74),
		MovementMode = "Path",
	}),
})

local Phase2AllowedRoles: TPhase2AllowedRoles = table.freeze({
	Swarm = true,
})

local EnemyConfig: TEnemyConfig = table.freeze({
	Roles = Roles,
	Phase2AllowedRoles = Phase2AllowedRoles,
})

return EnemyConfig
