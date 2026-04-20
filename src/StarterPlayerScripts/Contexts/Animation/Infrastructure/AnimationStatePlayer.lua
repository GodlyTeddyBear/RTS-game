--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ActionRegistry = require(ReplicatedStorage.Utilities.ActionSystem.ActionRegistry)
local ActionEventRouter = require(ReplicatedStorage.Utilities.ActionSystem.ActionEventRouter)
local Types = require(script.Parent.AnimationTypes)

type TAnimationPreset = Types.TAnimationPreset

local AnimationStatePlayer = {}

function AnimationStatePlayer.Bind(
	model: Model,
	janitor: any,
	action: any,
	validActions: { [string]: boolean },
	context: any,
	preset: TAnimationPreset
)
	local activeAction: string? = nil
	local activeCallbackState: string? = nil
	local stoppedConnection: RBXScriptConnection? = nil
	local routerCleanup: (() -> ())? = nil

	local function stopActive()
		if stoppedConnection then
			stoppedConnection:Disconnect()
			stoppedConnection = nil
		end

		if routerCleanup then
			routerCleanup()
			routerCleanup = nil
		end

		if activeAction then
			local callbackState = activeCallbackState or activeAction
			local actionDef = ActionRegistry.Get(callbackState) or ActionRegistry.Get(activeAction)
			if actionDef then
				actionDef:OnStop(context)
			end

			if action:GetAction(activeAction) then
				action:StopAction(activeAction)
			end
			activeAction = nil
			activeCallbackState = nil
		end
	end

	local function playState(state: string)
		local animState = state
		if not validActions[animState] and preset.ActionStateFallback then
			local fallback = if ActionRegistry.Get(state) then preset.ActionStateFallback(state, validActions) else nil
			if fallback then
				animState = fallback
			end
		end

		if not validActions[animState] then
			return
		end

		local track = action:PlayAction(animState)
		if not track then
			warn(preset.Tag, "PlayAction returned nil track for state:", state)
			return
		end

		activeAction = animState
		activeCallbackState = state

		local actionDef = ActionRegistry.Get(state) or ActionRegistry.Get(animState)
		if actionDef then
			actionDef:OnStart(track, context)
			routerCleanup = ActionEventRouter.Wire(track, actionDef, context)
		elseif not actionDef then
			warn(preset.Tag, "No actionDef registered for state:", state)
		end

		stoppedConnection = track.Stopped:Connect(function()
			if routerCleanup then
				routerCleanup()
				routerCleanup = nil
			end

			if activeAction == animState and model:GetAttribute("AnimationLooping") == true then
				local newTrack = action:PlayAction(animState)
				if actionDef and newTrack then
					actionDef:OnStart(newTrack, context)
					routerCleanup = ActionEventRouter.Wire(newTrack, actionDef, context)
				end
			end
		end)
	end

	local function applyState(state: string)
		stopActive()
		playState(state)
	end

	janitor:Add(
		model:GetAttributeChangedSignal("AnimationState"):Connect(function()
			applyState((model:GetAttribute("AnimationState") or "Idle") :: string)
		end),
		"Disconnect"
	)

	janitor:Add(function()
		stopActive()
	end, true)

	applyState((model:GetAttribute("AnimationState") or "Idle") :: string)
end

return AnimationStatePlayer
