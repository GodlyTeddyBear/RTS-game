--!strict

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

function Policies.CheckConfig(config: any)
	_AssertSatisfied(Specs.HasValidConfigSpec:IsSatisfiedBy({
		Config = config,
	}))
end

function Policies.CheckChannelName(channelName: any)
	_AssertSatisfied(Specs.HasValidChannelNameSpec:IsSatisfiedBy({
		ChannelName = channelName,
	}))
end

function Policies.CheckRequest(request: any)
	_AssertSatisfied(Specs.HasValidRequestSpec:IsSatisfiedBy({
		Config = request,
		Target = if request ~= nil then request.Target else nil,
		ResolverOptions = if request ~= nil then request.ResolverOptions else nil,
		Highlight = if request ~= nil then request.Highlight else nil,
		Radius = if request ~= nil then request.Radius else nil,
		Metadata = if request ~= nil then request.Metadata else nil,
	}))
end

function Policies.CheckTarget(target: any)
	_AssertSatisfied(Specs.HasValidTargetSpec:IsSatisfiedBy({
		Target = target,
	}))
end

function Policies.CheckSetRequest(request: any)
	_AssertSatisfied(Specs.HasValidSetRequestSpec:IsSatisfiedBy({
		Config = request,
		Targets = if request ~= nil then request.Targets else nil,
		ResolverOptions = if request ~= nil then request.ResolverOptions else nil,
		Highlight = if request ~= nil then request.Highlight else nil,
		Radius = if request ~= nil then request.Radius else nil,
		Metadata = if request ~= nil then request.Metadata else nil,
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
		_RaiseValidationFailure(result)
	end
end

return table.freeze(Policies)
