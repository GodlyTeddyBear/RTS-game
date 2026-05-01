--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EnemyTypes = require(ReplicatedStorage.Contexts.Enemy.Types.EnemyTypes)
local EnemyRuntimeProfileRegistry = require(script.Parent.EnemyRuntimeProfileRegistry)

local RUN_SPEED_THRESHOLD = 17

type EnemyRole = EnemyTypes.EnemyRole

local EnemyAnimationStateResolver = {}

function EnemyAnimationStateResolver.Resolve(
	roleName: EnemyRole?,
	moveSpeed: number?,
	isMoving: boolean,
	combatAction: any
): (string, boolean)
	local profile = if roleName ~= nil then EnemyRuntimeProfileRegistry.GetByRole(roleName) else nil
	local actionId = if type(combatAction) == "table" then combatAction.CurrentActionId else nil
	local actionState = if type(combatAction) == "table" then combatAction.ActionState else nil

	if profile ~= nil and type(actionId) == "string" and type(actionState) == "string" then
		local animationStatesByPhase = profile.AnimationByActionIdAndState[actionId]
		if animationStatesByPhase ~= nil then
			local animationState = animationStatesByPhase[actionState] or profile.DefaultAnimationState
			local isLooping = profile.LoopingByAnimationState[animationState]
			return animationState, if isLooping == nil then true else isLooping
		end
	end

	if not isMoving then
		return "Idle", true
	end

	if type(moveSpeed) == "number" and moveSpeed >= RUN_SPEED_THRESHOLD then
		return "Run", true
	end

	return "Walk", true
end

return table.freeze(EnemyAnimationStateResolver)
