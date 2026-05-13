--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Option = require(ReplicatedStorage.Utilities.Option)
local Result = require(ReplicatedStorage.Utilities.Result)

local Errors = require(script.Parent.Errors)
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

function Policies.CheckManagerConfig(config: any)
	_AssertSatisfied(Specs.HasValidConfigSpec:IsSatisfiedBy({
		Config = config,
	}))
end

function Policies.CheckAttachOptions(options: any)
	_AssertSatisfied(Specs.HasValidClickOptions:IsSatisfiedBy({
		Config = options,
		DetectorName = if options ~= nil then options.Name else nil,
		MaxActivationDistance = if options ~= nil then options.MaxActivationDistance else nil,
		CursorIcon = if options ~= nil then options.CursorIcon else nil,
		ResolvePart = if options ~= nil then options.ResolvePart else nil,
	}))
end

function Policies.CheckTarget(target: any): Result.Result<any>
	local result = Specs.HasValidTargetSpec:IsSatisfiedBy({
		Target = target,
	})
	if result.success then
		return Result.Ok(target)
	end

	local errorType, message, data = Errors.BuildTargetResolutionFailed(nil, nil, result.message)
	return Result.Err(errorType, message, data)
end

function Policies.CheckResolvedPart(target: Instance, resolvedPartOption: any, detectorName: string): Result.Result<BasePart>
	if not Option.Is(resolvedPartOption) then
		local errorType, message, data = Errors.BuildTargetResolutionFailed(
			target,
			detectorName,
			"Resolver must return an Option"
		)
		return Result.Err(errorType, message, data)
	end

	if resolvedPartOption:IsNone() then
		local errorType, message, data = Errors.BuildTargetResolutionFailed(
			target,
			detectorName,
			"Resolver did not produce a BasePart"
		)
		return Result.Err(errorType, message, data)
	end

	local resolvedPart = resolvedPartOption:Unwrap()
	local result = Specs.HasValidResolvedPartSpec:IsSatisfiedBy({
		ResolvedPart = resolvedPart,
	})
	if result.success then
		return Result.Ok(resolvedPart)
	end

	local errorType, message, data = Errors.BuildTargetDestroyed(
		target,
		resolvedPart,
		detectorName,
		result.message
	)
	return Result.Err(errorType, message, data)
end

function Policies.CheckDetectorCandidate(
	target: Instance,
	resolvedPart: BasePart,
	detectorName: string,
	existingChild: Instance?
): Result.Result<Instance?>
	local result = Specs.HasValidDetectorCandidateSpec:IsSatisfiedBy({
		ExistingChild = existingChild,
	})
	if result.success then
		return Result.Ok(existingChild)
	end

	local errorType, message, data = Errors.BuildDetectorConflict(
		target,
		resolvedPart,
		detectorName,
		result.message
	)
	return Result.Err(errorType, message, data)
end

function Policies.CheckServiceAlive(service: any, target: Instance?, detectorName: string?): Result.Result<boolean>
	local result = Specs.HasAliveServiceSpec:IsSatisfiedBy({
		IsDestroyed = service._isDestroyed == true,
	})
	if result.success then
		return Result.Ok(true)
	end

	local errorType, message, data = Errors.BuildServiceDestroyed(target, detectorName)
	return Result.Err(errorType, message, data)
end

function Policies.CheckHandleAlive(handle: any): Result.Result<boolean>
	local result = Specs.HasAliveHandleSpec:IsSatisfiedBy({
		IsDestroyed = handle._isDestroyed == true,
	})
	if result.success then
		return Result.Ok(true)
	end

	local errorType, message, data = Errors.BuildHandleDestroyed(
		handle._target,
		handle._resolvedPart,
		handle._options.Name,
		handle._stateMachine:GetState().Name
	)
	return Result.Err(errorType, message, data)
end

function Policies.CheckHandleTransition(handle: any, nextState: any): Result.Result<boolean>
	local currentState = handle._stateMachine:GetState()
	local result = Specs.HasLegalTransitionSpec:IsSatisfiedBy({
		CurrentState = currentState,
		NextState = nextState,
		CanTransition = handle._stateMachine:CanTransition(nextState),
	})
	if result.success then
		return Result.Ok(true)
	end

	local errorType, message, data = Errors.BuildIllegalTransition(
		handle._target,
		handle._resolvedPart,
		handle._options.Name,
		currentState.Name,
		result.message
	)
	return Result.Err(errorType, message, data)
end

return table.freeze(Policies)
