--!strict

--[=[
	@class ProjectileConfig
	Defines server-authoritative projectile tuning for combat weapons.
	@server
	@client
]=]
local ProjectileConfig = {}

ProjectileConfig.Bullet = table.freeze({
	Speed = 160,
	MaxPierces = 10,
	Gravity = Vector3.zero,
	HighFidelitySegmentSize = 1,
	CosmeticCacheSize = 20,
	TemplatePath = table.freeze({ "Projectiles", "Bullet", "Template" }),
})

return table.freeze(ProjectileConfig)
