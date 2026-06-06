--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ActionRegistry = require(ReplicatedStorage.Utilities.ActionSystem.ActionRegistry)
local ActionEventRouter = require(ReplicatedStorage.Utilities.ActionSystem.ActionEventRouter)
local Types = require(ReplicatedStorage.Contexts.Animation.Types.AnimationTypes)

type TAnimationPreset = Types.TAnimationPreset
type TAnimationStateSource = Types.TAnimationStateSource

local AnimationStatePlayer = {}

function AnimationStatePlayer.Bind(
	model: Model,
	janitor: any,
	action: any,
	validActions: { [string]: boolean },
	core: any,
	validCoreStates: { [string]: boolean },
	context: any,
	preset: TAnimationPreset,
	stateSource: TAnimationStateSource
)
	local activeAction: string? = nil
	local activeCallbackState: string? = nil
	local activeActionLooping: boolean? = nil
	local stoppedConnection: RBXScriptConnection? = nil
	local routerCleanup: (() -> ())? = nil
	local stateCleanup: (() -> ())? = nil
	local loopingCleanup: (() -> ())? = nil
	local revisionCleanup: (() -> ())? = nil
	local actionAnimationCleanup: (() -> ())? = nil
	local poseController = if core ~= nil then core.PoseController else nil
	local isActionOnly = preset.ReplicatedStateMode == "ActionOnly"
	local useStateDrivenCorePoses = not isActionOnly
		and preset.UseStateDrivenCorePoses == true
		and poseController ~= nil
		and next(validCoreStates) ~= nil
	local latestLooping = true
	local latestRevision: number? = nil
	local warnedMissingActionStates = {}

	local function readState(): string?
		local state = stateSource:GetState()
		if type(state) == "string" and state ~= "" then
			return state
		end

		return if isActionOnly then nil else "Idle"
	end

	local function syncLooping()
		local isLooping = stateSource:GetLooping()
		latestLooping = if type(isLooping) == "boolean" then isLooping else true
	end

	local function readRevision(): number?
		local getRevision = stateSource.GetRevision
		if typeof(getRevision) ~= "function" then
			return nil
		end

		local revision = getRevision(stateSource)
		return if type(revision) == "number" then revision else nil
	end

	local function readActionAnimation(): any?
		local getActionAnimation = stateSource.GetActionAnimation
		if typeof(getActionAnimation) == "function" then
			local snapshot = getActionAnimation(stateSource)
			if type(snapshot) == "table" then
				return {
					State = if type(snapshot.State) == "string" then snapshot.State else "",
					Looping = if type(snapshot.Looping) == "boolean" then snapshot.Looping else true,
					Revision = if type(snapshot.Revision) == "number" then snapshot.Revision else 0,
				}
			end
		end

		local state = readState()
		if state == nil or state == "" then
			return nil
		end

		return {
			State = state,
			Looping = stateSource:GetLooping() ~= false,
			Revision = readRevision() or 0,
		}
	end

	local function setCoreActive(enabled: boolean)
		if not poseController then
			return
		end

		local setCoreActiveMethod = poseController.SetCoreActive
		if typeof(setCoreActiveMethod) == "function" then
			pcall(setCoreActiveMethod, poseController, enabled)
		end
	end

	local function setCoreCanPlayAnims(enabled: boolean)
		if not poseController then
			return
		end

		local setCoreCanPlayAnimsMethod = poseController.SetCoreCanPlayAnims
		if typeof(setCoreCanPlayAnimsMethod) == "function" then
			pcall(setCoreCanPlayAnimsMethod, poseController, enabled)
		end
	end

	local function applyCorePose(state: string)
		if not poseController then
			return
		end

		local getPoseMethod = poseController.GetPose
		local changePoseMethod = poseController.ChangePose
		if typeof(getPoseMethod) ~= "function" or typeof(changePoseMethod) ~= "function" then
			return
		end

		local ok, currentPose = pcall(getPoseMethod, poseController)
		if not ok then
			return
		end

		if currentPose ~= state then
			pcall(changePoseMethod, poseController, state, 1, false)
		end
	end

	local function buildAvailableActionList(): string
		local names = {}
		for actionName in validActions do
			table.insert(names, actionName)
		end
		table.sort(names)
		return table.concat(names, ", ")
	end

	local function warnMissingActionState(requestedState: string, fallbackState: string?)
		local warningKey = requestedState .. "->" .. tostring(fallbackState)
		if warnedMissingActionStates[warningKey] == true then
			return
		end
		warnedMissingActionStates[warningKey] = true

		warn(
			preset.Tag,
			model.Name,
			"- missing animation action for state:",
			requestedState,
			"fallback:",
			fallbackState or "none",
			"available actions:",
			buildAvailableActionList()
		)
	end

	local function resolveActionState(state: string): string?
		if validActions[state] then
			return state
		end

		if preset.ActionStateFallback then
			local fallback = preset.ActionStateFallback(state, validActions)
			if type(fallback) == "string" and validActions[fallback] then
				return fallback
			end
		end

		return nil
	end

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
			activeActionLooping = nil
		end
	end

	local function stopActiveForStateClear()
		if activeActionLooping == false then
			return
		end
		stopActive()
	end

	if useStateDrivenCorePoses then
		setCoreActive(false)
		setCoreCanPlayAnims(true)
	end

	local function playState(state: string)
		local animState = resolveActionState(state)
		if animState == nil then
			if not validCoreStates[state] then
				warnMissingActionState(state, nil)
			end
			return
		end

		local track = action:PlayAction(animState)
		if not track then
			warn(preset.Tag, "PlayAction returned nil track for state:", state)
			return
		end

		activeAction = animState
		activeCallbackState = state
		activeActionLooping = latestLooping

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

			if activeAction == animState and latestLooping == true then
				local newTrack = action:PlayAction(animState)
				if actionDef and newTrack then
					actionDef:OnStart(newTrack, context)
					routerCleanup = ActionEventRouter.Wire(newTrack, actionDef, context)
				end
			elseif activeAction == animState then
				if actionDef then
					actionDef:OnStop(context)
				end
				activeAction = nil
				activeCallbackState = nil
				activeActionLooping = nil
				stoppedConnection = nil
			end
		end)
	end

	local function applyState(state: string?, forceReplay: boolean?)
		if state == nil or state == "" then
			stopActiveForStateClear()
			if useStateDrivenCorePoses then
				setCoreCanPlayAnims(true)
				applyCorePose("Idle")
			end
			return
		end

		if isActionOnly then
			local resolvedActionState = resolveActionState(state)
			if forceReplay == true or activeAction ~= resolvedActionState then
				stopActive()
			end
			if resolvedActionState ~= nil then
				if forceReplay == true or activeAction ~= resolvedActionState then
					playState(state)
				end
			elseif not validCoreStates[state] then
				warnMissingActionState(state, nil)
			end
			return
		end

		if useStateDrivenCorePoses then
			local resolvedActionState = resolveActionState(state)
			if resolvedActionState ~= nil then
				stopActive()
				playState(state)
				return
			end

			local nextState = state
			if not validCoreStates[nextState] then
				warnMissingActionState(state, "Idle")
				nextState = "Idle"
			end

			stopActive()
			setCoreCanPlayAnims(true)
			applyCorePose(nextState)
			return
		end

		stopActive()
		playState(state)
	end

	local function applyCurrentActionAnimation()
		local snapshot = readActionAnimation()
		if snapshot == nil then
			applyState(nil, false)
			return
		end

		latestLooping = snapshot.Looping
		local revision = snapshot.Revision
		local forceReplay = revision ~= latestRevision
		latestRevision = revision
		applyState(snapshot.State, forceReplay)
	end

	if typeof(stateSource.GetActionAnimation) == "function" and typeof(stateSource.ObserveActionAnimationChanged) == "function" then
		actionAnimationCleanup = stateSource:ObserveActionAnimationChanged(function()
			applyCurrentActionAnimation()
		end)
	else
		stateCleanup = stateSource:ObserveStateChanged(function()
			syncLooping()
			local revision = readRevision()
			local forceReplay = revision ~= nil and revision ~= latestRevision
			latestRevision = revision
			applyState(readState(), forceReplay)
		end)
		loopingCleanup = stateSource:ObserveLoopingChanged(function()
			syncLooping()
		end)
		if typeof(stateSource.ObserveRevisionChanged) == "function" then
			revisionCleanup = stateSource:ObserveRevisionChanged(function()
				syncLooping()
				local revision = readRevision()
				local forceReplay = revision ~= nil and revision ~= latestRevision
				latestRevision = revision
				applyState(readState(), forceReplay)
			end)
		end
	end

	janitor:Add(function()
		if actionAnimationCleanup then
			actionAnimationCleanup()
			actionAnimationCleanup = nil
		end
		if stateCleanup then
			stateCleanup()
			stateCleanup = nil
		end
		if loopingCleanup then
			loopingCleanup()
			loopingCleanup = nil
		end
		if revisionCleanup then
			revisionCleanup()
			revisionCleanup = nil
		end
		stopActive()
		if useStateDrivenCorePoses then
			setCoreActive(true)
		end
	end, true)

	syncLooping()
	local initialSnapshot = readActionAnimation()
	latestRevision = if initialSnapshot ~= nil then initialSnapshot.Revision else readRevision()
	applyCurrentActionAnimation()
end

return AnimationStatePlayer
