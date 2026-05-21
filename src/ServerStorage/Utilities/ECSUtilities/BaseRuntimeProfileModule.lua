--!strict

export type RuntimeProfile = {
	VariantId: string,
	BehaviorDefinition: any,
	DefaultAnimationState: string,
	AnimationByActionIdAndState: {
		[string]: {
			[string]: string,
		},
	},
	LoopingByAnimationState: {
		[string]: boolean,
	},
	TickInterval: number,
}

type RuntimeProfileMap = {
	[string]: RuntimeProfile,
}

export type RuntimeProfileModule = {
	GetByVariant: (self: RuntimeProfileModule, variantId: string) -> RuntimeProfile,
	ResolveAnimationState: (self: RuntimeProfileModule, input: any) -> (string, boolean),
	ResolveActionAnimationState: (
		self: RuntimeProfileModule,
		variantId: string?,
		combatAction: any
	) -> (string?, boolean?),
}

export type RuntimeProfileModuleConfig = {
	Label: string,
	ProfilesByVariant: RuntimeProfileMap,
	ResolveVariantId: (input: any) -> string?,
	ResolveFallbackAnimationState: ((input: any, profile: RuntimeProfile) -> (string?, boolean?))?,
}

local function _AssertNonEmptyString(value: any, label: string)
	assert(type(value) == "string" and value ~= "", ("%s must be a non-empty string"):format(label))
end

local function _FreezeAnimationStateMap(
	label: string,
	animationByActionIdAndState: {
		[string]: {
			[string]: string,
		},
	}
): {
		[string]: {
			[string]: string,
		},
	}
	assert(type(animationByActionIdAndState) == "table", ("%s AnimationByActionIdAndState must be a table"):format(label))

	local frozenMap = {}
	for actionId, statesByActionState in animationByActionIdAndState do
		_AssertNonEmptyString(actionId, ("%s action id"):format(label))
		assert(type(statesByActionState) == "table", ("%s states for '%s' must be a table"):format(label, actionId))

		local frozenStates = {}
		for actionState, animationState in statesByActionState do
			_AssertNonEmptyString(actionState, ("%s action state for '%s'"):format(label, actionId))
			_AssertNonEmptyString(animationState, ("%s animation state for '%s.%s'"):format(label, actionId, actionState))
			frozenStates[actionState] = animationState
		end

		frozenMap[actionId] = table.freeze(frozenStates)
	end

	return table.freeze(frozenMap)
end

local function _FreezeLoopingMap(
	label: string,
	loopingByAnimationState: {
		[string]: boolean,
	}
): {
		[string]: boolean,
	}
	assert(type(loopingByAnimationState) == "table", ("%s LoopingByAnimationState must be a table"):format(label))

	local frozenMap = {}
	for animationState, isLooping in loopingByAnimationState do
		_AssertNonEmptyString(animationState, ("%s looping animation state"):format(label))
		assert(type(isLooping) == "boolean", ("%s looping value for '%s' must be a boolean"):format(label, animationState))
		frozenMap[animationState] = isLooping
	end

	return table.freeze(frozenMap)
end

local function _FreezeProfile(label: string, variantId: string, profile: RuntimeProfile): RuntimeProfile
	assert(type(profile) == "table", ("%s profile '%s' must be a table"):format(label, variantId))
	_AssertNonEmptyString(profile.VariantId, ("%s profile '%s'.VariantId"):format(label, variantId))
	assert(
		profile.VariantId == variantId,
		("%s profile key '%s' must match VariantId '%s'"):format(label, variantId, tostring(profile.VariantId))
	)
	assert(profile.BehaviorDefinition ~= nil, ("%s profile '%s'.BehaviorDefinition is required"):format(label, variantId))
	_AssertNonEmptyString(
		profile.DefaultAnimationState,
		("%s profile '%s'.DefaultAnimationState"):format(label, variantId)
	)
	assert(type(profile.TickInterval) == "number", ("%s profile '%s'.TickInterval must be a number"):format(label, variantId))

	return table.freeze({
		VariantId = profile.VariantId,
		BehaviorDefinition = profile.BehaviorDefinition,
		DefaultAnimationState = profile.DefaultAnimationState,
		AnimationByActionIdAndState = _FreezeAnimationStateMap(label, profile.AnimationByActionIdAndState),
		LoopingByAnimationState = _FreezeLoopingMap(label, profile.LoopingByAnimationState),
		TickInterval = profile.TickInterval,
	})
end

local function _FreezeProfiles(label: string, profilesByVariant: RuntimeProfileMap): RuntimeProfileMap
	assert(type(profilesByVariant) == "table", ("%s profilesByVariant must be a table"):format(label))

	local frozenProfiles = {}
	for variantId, profile in profilesByVariant do
		_AssertNonEmptyString(variantId, ("%s variant id"):format(label))
		frozenProfiles[variantId] = _FreezeProfile(label, variantId, profile)
	end

	return table.freeze(frozenProfiles)
end

local function _ResolveLoopingForAnimationState(profile: RuntimeProfile, animationState: string): boolean
	local isLooping = profile.LoopingByAnimationState[animationState]
	return if isLooping == nil then true else isLooping
end

local BaseRuntimeProfileModule = {}

function BaseRuntimeProfileModule.CreateProfile(profile: RuntimeProfile): RuntimeProfile
	assert(type(profile) == "table", "BaseRuntimeProfileModule.CreateProfile profile must be a table")
	_AssertNonEmptyString(profile.VariantId, "BaseRuntimeProfileModule.CreateProfile VariantId")
	return _FreezeProfile("BaseRuntimeProfileModule.CreateProfile", profile.VariantId, profile)
end

function BaseRuntimeProfileModule.new(config: RuntimeProfileModuleConfig): RuntimeProfileModule
	assert(type(config) == "table", "BaseRuntimeProfileModule.new config must be a table")
	_AssertNonEmptyString(config.Label, "BaseRuntimeProfileModule label")
	assert(type(config.ResolveVariantId) == "function", "BaseRuntimeProfileModule ResolveVariantId must be a function")
	if config.ResolveFallbackAnimationState ~= nil then
		assert(
			type(config.ResolveFallbackAnimationState) == "function",
			"BaseRuntimeProfileModule ResolveFallbackAnimationState must be a function"
		)
	end

	local label = config.Label
	local frozenProfiles = _FreezeProfiles(label, config.ProfilesByVariant)

	local runtimeProfileModule = {}

	function runtimeProfileModule:GetByVariant(variantId: string): RuntimeProfile
		local profile = frozenProfiles[variantId]
		assert(profile ~= nil, ("%s: unknown runtime profile variant '%s'"):format(label, tostring(variantId)))
		return profile
	end

	function runtimeProfileModule:ResolveActionAnimationState(variantId: string?, combatAction: any): (string?, boolean?)
		if type(variantId) ~= "string" or variantId == "" then
			return nil, nil
		end

		local actionId = if type(combatAction) == "table" then combatAction.CurrentActionId else nil
		local actionState = if type(combatAction) == "table" then combatAction.ActionState else nil
		if type(actionId) ~= "string" or type(actionState) ~= "string" then
			return nil, nil
		end

		local profile = self:GetByVariant(variantId)
		local statesByActionState = profile.AnimationByActionIdAndState[actionId]
		if statesByActionState == nil then
			return nil, nil
		end

		local animationState = statesByActionState[actionState]
		if type(animationState) ~= "string" or animationState == "" then
			return nil, nil
		end

		return animationState, _ResolveLoopingForAnimationState(profile, animationState)
	end

	function runtimeProfileModule:ResolveAnimationState(input: any): (string, boolean)
		local variantId = config.ResolveVariantId(input)
		local profile = nil :: RuntimeProfile?
		if type(variantId) == "string" and variantId ~= "" then
			profile = self:GetByVariant(variantId)
		end

		local combatAction = if type(input) == "table" then input.CombatAction else nil
		local animationState, isLooping = self:ResolveActionAnimationState(variantId, combatAction)
		if animationState ~= nil then
			return animationState, if isLooping == nil then true else isLooping
		end

		if profile ~= nil and config.ResolveFallbackAnimationState ~= nil then
			local fallbackAnimationState, fallbackIsLooping = config.ResolveFallbackAnimationState(input, profile)
			if type(fallbackAnimationState) == "string" and fallbackAnimationState ~= "" then
				if type(fallbackIsLooping) == "boolean" then
					return fallbackAnimationState, fallbackIsLooping
				end
				return fallbackAnimationState, _ResolveLoopingForAnimationState(profile, fallbackAnimationState)
			end
		end

		if profile == nil then
			return "Idle", true
		end

		return profile.DefaultAnimationState, _ResolveLoopingForAnimationState(profile, profile.DefaultAnimationState)
	end

	return table.freeze(runtimeProfileModule)
end

return table.freeze(BaseRuntimeProfileModule)
