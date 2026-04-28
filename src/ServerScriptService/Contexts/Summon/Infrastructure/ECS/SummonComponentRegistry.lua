--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseECSComponentRegistry = require(ReplicatedStorage.Utilities.BaseECSComponentRegistry)

local SummonComponentRegistry = {}
SummonComponentRegistry.__index = SummonComponentRegistry
setmetatable(SummonComponentRegistry, { __index = BaseECSComponentRegistry })

function SummonComponentRegistry.new()
	return setmetatable(BaseECSComponentRegistry.new("Summon"), SummonComponentRegistry)
end

function SummonComponentRegistry:_RegisterComponents(_registry: any, _name: string)
	-- [AUTHORITATIVE] Stable summon identity for ownership and cleanup.
	self:RegisterComponent("IdentityComponent", "Summon.Identity", "AUTHORITATIVE")
	-- [DERIVED] Current drone world transform.
	self:RegisterComponent("PositionComponent", "Summon.Position", "DERIVED")
	-- [AUTHORITATIVE] Combat tuning and last-attack timestamp.
	self:RegisterComponent("CombatComponent", "Summon.Combat", "AUTHORITATIVE")
	-- [AUTHORITATIVE] Expiration windows for timed summon cleanup.
	self:RegisterComponent("LifetimeComponent", "Summon.Lifetime", "AUTHORITATIVE")
	-- [AUTHORITATIVE] Runtime instance reference for placeholder visuals.
	self:RegisterComponent("InstanceRefComponent", "Summon.InstanceRef", "AUTHORITATIVE")

	self:RegisterTag("ActiveTag", "Summon.ActiveTag")
end

return SummonComponentRegistry
