--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BehaviorConfig = require(ReplicatedStorage.Contexts.Combat.Config.BehaviorConfig)
local EnemyConfig = require(ReplicatedStorage.Contexts.Enemy.Config.EnemyConfig)
local EnemyTypes = require(ReplicatedStorage.Contexts.Enemy.Types.EnemyTypes)
local SwarmBehavior = require(script.Parent.Parent.BehaviorSystem.Behaviors.SwarmBehavior)
local TankBehavior = require(script.Parent.Parent.BehaviorSystem.Behaviors.TankBehavior)

type EnemyRole = EnemyTypes.EnemyRole
type EnemyRoleConfig = EnemyTypes.EnemyRoleConfig

type TAnimationStateMap = {
	[string]: {
		[string]: string,
	},
}

type TLoopingStateMap = {
	[string]: boolean,
}

export type TEnemyRuntimeProfile = {
	BehaviorDefinition: any,
	DefaultAnimationState: string,
	AnimationByActionIdAndState: TAnimationStateMap,
	LoopingByAnimationState: TLoopingStateMap,
	TickInterval: number,
}

local function _CreateSharedEnemyAnimationMap(): TAnimationStateMap
	return table.freeze({
		AttackStructure = table.freeze({
			Running = "AttackStructure",
			Committed = "AttackStructure",
		}),
		AttackBase = table.freeze({
			Running = "AttackBase",
			Committed = "AttackBase",
		}),
	})
end

local function _CreateSharedEnemyLoopingMap(): TLoopingStateMap
	return table.freeze({
		Idle = true,
		Walk = true,
		Run = true,
		AttackStructure = false,
		AttackBase = false,
	})
end

local SHARED_ENEMY_ANIMATION_MAP = _CreateSharedEnemyAnimationMap()
local SHARED_ENEMY_LOOPING_MAP = _CreateSharedEnemyLoopingMap()

local function _CreateProfile(role: EnemyRole, behaviorDefinition: any): TEnemyRuntimeProfile
	local roleConfig = EnemyConfig.Roles[role] :: EnemyRoleConfig?
	assert(roleConfig ~= nil, ("EnemyRuntimeProfileRegistry: missing config for role '%s'"):format(tostring(role)))

	local behaviorDefaults = BehaviorConfig.DEFAULTS_BY_ROLE[role] or BehaviorConfig.DEFAULT
	return table.freeze({
		BehaviorDefinition = behaviorDefinition,
		DefaultAnimationState = "Idle",
		AnimationByActionIdAndState = SHARED_ENEMY_ANIMATION_MAP,
		LoopingByAnimationState = SHARED_ENEMY_LOOPING_MAP,
		TickInterval = behaviorDefaults.TickInterval,
	})
end

local PROFILES_BY_ROLE: { [EnemyRole]: TEnemyRuntimeProfile } = table.freeze({
	Swarm = _CreateProfile("Swarm", SwarmBehavior),
	Tank = _CreateProfile("Tank", TankBehavior),
})

local EnemyRuntimeProfileRegistry = {}

function EnemyRuntimeProfileRegistry.GetByRole(role: EnemyRole): TEnemyRuntimeProfile
	local profile = PROFILES_BY_ROLE[role]
	assert(profile ~= nil, ("EnemyRuntimeProfileRegistry: unknown role '%s'"):format(tostring(role)))
	return profile
end

return table.freeze(EnemyRuntimeProfileRegistry)
