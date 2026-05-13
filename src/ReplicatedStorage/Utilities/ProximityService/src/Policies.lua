--!strict

local Enums = require(script.Parent.Enums)
local Specs = require(script.Parent.Specs)

local Policies = {}

local function _RaiseValidationFailure(result: any)
	error(result.message, 3)
end

local function _AssertSatisfied(result: any)
	if not result.success then
		_RaiseValidationFailure(result)
	end
end

function Policies.CheckOptions(options: any)
	_AssertSatisfied(Specs.HasValidOptions:IsSatisfiedBy({
		Config = options,
		PromptName = if options ~= nil then options.PromptName else nil,
		ActionKind = if options ~= nil then options.ActionKind else nil,
		Enabled = if options ~= nil then options.Enabled else nil,
		ActionText = if options ~= nil then options.ActionText else nil,
		ObjectText = if options ~= nil then options.ObjectText else nil,
		HoldDuration = if options ~= nil then options.HoldDuration else nil,
		MaxActivationDistance = if options ~= nil then options.MaxActivationDistance else nil,
		RequiresLineOfSight = if options ~= nil then options.RequiresLineOfSight else nil,
		KeyboardKeyCode = if options ~= nil then options.KeyboardKeyCode else nil,
		GamepadKeyCode = if options ~= nil then options.GamepadKeyCode else nil,
		Exclusivity = if options ~= nil then options.Exclusivity else nil,
		ResolveParent = if options ~= nil then options.ResolveParent else nil,
		CanShow = if options ~= nil then options.CanShow else nil,
		CanTrigger = if options ~= nil then options.CanTrigger else nil,
		OnShown = if options ~= nil then options.OnShown else nil,
		OnHidden = if options ~= nil then options.OnHidden else nil,
		OnTriggered = if options ~= nil then options.OnTriggered else nil,
		OnHoldStarted = if options ~= nil then options.OnHoldStarted else nil,
		OnHoldEnded = if options ~= nil then options.OnHoldEnded else nil,
		Metadata = if options ~= nil then options.Metadata else nil,
		OwnsPrompt = if options ~= nil then options.OwnsPrompt else nil,
	}))
end

function Policies.CheckKey(key: any)
	_AssertSatisfied(Specs.HasValidKeySpec:IsSatisfiedBy({
		Key = key,
	}))
end

function Policies.CheckTarget(target: any)
	_AssertSatisfied(Specs.HasValidTargetSpec:IsSatisfiedBy({
		Target = target,
	}))
end

function Policies.CheckPrompt(prompt: any)
	_AssertSatisfied(Specs.HasValidPromptSpec:IsSatisfiedBy({
		Prompt = prompt,
	}))
end

function Policies.CheckProfile(profile: any)
	_AssertSatisfied(Specs.HasValidProfileSpec:IsSatisfiedBy({
		Profile = profile,
	}))
end

function Policies.CheckResolvedParent(resolvedParent: any)
	_AssertSatisfied(Specs.HasValidResolvedParentSpec:IsSatisfiedBy({
		ResolvedParent = resolvedParent,
	}))
end

function Policies.CheckMode(mode: any)
	_AssertSatisfied(Specs.HasValidModeSpec:IsSatisfiedBy({
		Mode = mode,
	}))
end

function Policies.CheckServiceAlive(service: any)
	_AssertSatisfied(Specs.HasAliveServiceSpec:IsSatisfiedBy({
		IsDestroyed = service._isDestroyed == true,
	}))
end

function Policies.CheckHandleAlive(handle: any)
	_AssertSatisfied(Specs.HasAliveHandleSpec:IsSatisfiedBy({
		IsDestroyed = handle._isDestroyed == true,
	}))
end

function Policies.CheckHandleTransition(handle: any, nextState: any)
	local currentState = handle._stateMachine:GetState()
	local result = Specs.HasLegalTransitionSpec:IsSatisfiedBy({
		CurrentState = currentState,
		CanTransition = handle._stateMachine:CanTransition(nextState),
	})

	if not result.success then
		error(Enums.ErrorMessage[Enums.ErrorKey.IllegalProximityHandleTransition], 3)
	end
end

return table.freeze(Policies)
