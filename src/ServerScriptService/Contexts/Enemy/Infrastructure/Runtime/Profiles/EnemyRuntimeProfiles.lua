--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BehaviorConfig = require(ReplicatedStorage.Contexts.Combat.Config.BehaviorConfig)
local EnemyConfig = require(ReplicatedStorage.Contexts.Enemy.Config.EnemyConfig)
local EnemyTypes = require(ReplicatedStorage.Contexts.Enemy.Types.EnemyTypes)
local BaseRuntimeProfileModule = require(ReplicatedStorage.Utilities.BaseRuntimeProfileModule)
local SwarmBehavior = require(script.Parent.Parent.Parent.BehaviorSystem.Behaviors.SwarmBehavior)
local TankBehavior = require(script.Parent.Parent.Parent.BehaviorSystem.Behaviors.TankBehavior)

local RUN_SPEED_THRESHOLD = 17

type EnemyRole = EnemyTypes.EnemyRole
type EnemyRoleConfig = EnemyTypes.EnemyRoleConfig

local SharedEnemyAnimationMap = {
	AttackStructure = {
		Running = "AttackStructure",
		Committed = "AttackStructure",
	},
	AttackBase = {
		Running = "AttackBase",
		Committed = "AttackBase",
	},
}

local SharedEnemyLoopingMap = {
	Idle = true,
	Walk = true,
	Run = true,
	AttackStructure = false,
	AttackBase = false,
}

local function _ResolveTickIntervalForRole(role: EnemyRole): number
	local roleConfig = EnemyConfig.Roles[role] :: EnemyRoleConfig?
	assert(roleConfig ~= nil, ("EnemyRuntimeProfiles: missing config for role '%s'"):format(tostring(role)))

	local behaviorDefaults = BehaviorConfig.DEFAULTS_BY_ROLE[role] or BehaviorConfig.DEFAULT
	return behaviorDefaults.TickInterval
end

local function _ResolveVariantIdForRole(roleName: EnemyRole?): string?
	if type(roleName) ~= "string" then
		return nil
	end

	local roleConfig = EnemyConfig.Roles[roleName] :: EnemyRoleConfig?
	assert(roleConfig ~= nil, ("EnemyRuntimeProfiles: missing config for role '%s'"):format(tostring(roleName)))
	return roleConfig.RuntimeProfileId
end

local BaseProfiles = BaseRuntimeProfileModule.new({
	Label = "EnemyRuntimeProfiles",
	ProfilesByVariant = {
		Swarm = BaseRuntimeProfileModule.CreateProfile({
			VariantId = "Swarm",
			BehaviorDefinition = SwarmBehavior,
			DefaultAnimationState = "Idle",
			AnimationByActionIdAndState = SharedEnemyAnimationMap,
			LoopingByAnimationState = SharedEnemyLoopingMap,
			TickInterval = _ResolveTickIntervalForRole("Swarm"),
		}),
		Tank = BaseRuntimeProfileModule.CreateProfile({
			VariantId = "Tank",
			BehaviorDefinition = TankBehavior,
			DefaultAnimationState = "Idle",
			AnimationByActionIdAndState = SharedEnemyAnimationMap,
			LoopingByAnimationState = SharedEnemyLoopingMap,
			TickInterval = _ResolveTickIntervalForRole("Tank"),
		}),
	},
	ResolveVariantId = function(input: {
		VariantId: string?,
		RoleName: EnemyRole?,
		MoveSpeed: number?,
		IsMoving: boolean?,
		CombatAction: any,
	}): string?
		if type(input.VariantId) == "string" and input.VariantId ~= "" then
			return input.VariantId
		end
		return _ResolveVariantIdForRole(input.RoleName)
	end,
	ResolveFallbackAnimationState = function(
		input: {
			VariantId: string?,
			RoleName: EnemyRole?,
			MoveSpeed: number?,
			IsMoving: boolean?,
			CombatAction: any,
		},
		_profile: any
	): (string?, boolean?)
		if input.IsMoving ~= true then
			return "Idle", true
		end

		if type(input.MoveSpeed) == "number" and input.MoveSpeed >= RUN_SPEED_THRESHOLD then
			return "Run", true
		end

		return "Walk", true
	end,
})

local EnemyRuntimeProfiles = {}

function EnemyRuntimeProfiles.GetByVariant(variantId: string)
	return BaseProfiles:GetByVariant(variantId)
end

function EnemyRuntimeProfiles.ResolveAnimationState(input: {
	VariantId: string?,
	RoleName: EnemyRole?,
	MoveSpeed: number?,
	IsMoving: boolean?,
	CombatAction: any,
}): (string, boolean)
	return BaseProfiles:ResolveAnimationState(input)
end

return table.freeze(EnemyRuntimeProfiles)
