--!strict

--[=[
	@class EnemyConfig
	Defines the shared phase-0 enemy role tuning used by server systems.
	@server
	@client
]=]
local EnemyConfig = {}

EnemyConfig.ROLES = table.freeze({
	swarm = table.freeze({
		displayName = "Swarm",
		maxHp = 30,
		damage = 5,
		attackRange = 6,
		attackCooldown = 1.25,
		moveSpeed = 16,
		targetPreference = "Goal",
		modelScale = Vector3.new(2.5, 3, 2.5),
		modelColor = Color3.fromRGB(240, 196, 78),
	}),
	tank = table.freeze({
		displayName = "Tank",
		maxHp = 120,
		damage = 15,
		attackRange = 6,
		attackCooldown = 1.25,
		moveSpeed = 8,
		targetPreference = "Goal",
		modelScale = Vector3.new(4, 4.5, 4),
		modelColor = Color3.fromRGB(150, 92, 74),
	}),
})

EnemyConfig.PHASE2_ALLOWED_ROLES = table.freeze({
	swarm = true,
})

return table.freeze(EnemyConfig)
