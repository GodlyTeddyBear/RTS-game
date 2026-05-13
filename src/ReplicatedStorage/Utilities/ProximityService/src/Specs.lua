--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Specification = require(ReplicatedStorage.Utilities.Specification)

local Enums = require(script.Parent.Enums)

local Specs = {}

local function _ErrorName(errorKey: any): string
	return errorKey.Name
end

function Specs.IsValidConfig(config: any): boolean
	return config == nil or type(config) == "table"
end

function Specs.IsValidKey(key: any): boolean
	return type(key) == "string" and key ~= ""
end

function Specs.IsValidTarget(target: any): boolean
	return typeof(target) == "Instance"
		and (target:IsA("BasePart") or target:IsA("Attachment") or target:IsA("Model"))
end

function Specs.IsValidPrompt(prompt: any): boolean
	return typeof(prompt) == "Instance" and prompt:IsA("ProximityPrompt") and prompt.Parent ~= nil
end

function Specs.IsValidPromptName(promptName: any): boolean
	return promptName == nil or (type(promptName) == "string" and promptName ~= "")
end

function Specs.IsValidActionKind(actionKind: any): boolean
	return actionKind == nil or Enums.ActionKind:BelongsTo(actionKind)
end

function Specs.IsValidEnabled(enabled: any): boolean
	return enabled == nil or type(enabled) == "boolean"
end

function Specs.IsValidActionText(actionText: any): boolean
	return actionText == nil or type(actionText) == "string"
end

function Specs.IsValidObjectText(objectText: any): boolean
	return objectText == nil or type(objectText) == "string"
end

function Specs.IsValidHoldDuration(holdDuration: any): boolean
	return holdDuration == nil or (type(holdDuration) == "number" and holdDuration >= 0)
end

function Specs.IsValidMaxActivationDistance(maxActivationDistance: any): boolean
	return maxActivationDistance == nil or (type(maxActivationDistance) == "number" and maxActivationDistance > 0)
end

function Specs.IsValidRequiresLineOfSight(requiresLineOfSight: any): boolean
	return requiresLineOfSight == nil or type(requiresLineOfSight) == "boolean"
end

function Specs.IsValidKeyCode(keyCode: any): boolean
	return keyCode == nil or typeof(keyCode) == "EnumItem"
		and keyCode.EnumType == Enum.KeyCode
end

function Specs.IsValidExclusivity(exclusivity: any): boolean
	return exclusivity == nil or typeof(exclusivity) == "EnumItem"
		and exclusivity.EnumType == Enum.ProximityPromptExclusivity
end

function Specs.IsValidResolveParent(resolveParent: any): boolean
	return resolveParent == nil or type(resolveParent) == "function"
end

function Specs.IsValidCanShow(canShow: any): boolean
	return canShow == nil or type(canShow) == "function"
end

function Specs.IsValidCanTrigger(canTrigger: any): boolean
	return canTrigger == nil or type(canTrigger) == "function"
end

function Specs.IsValidCallback(callback: any): boolean
	return callback == nil or type(callback) == "function"
end

function Specs.IsValidMetadata(metadata: any): boolean
	return metadata == nil or type(metadata) == "table"
end

function Specs.IsValidOwnsPrompt(ownsPrompt: any): boolean
	return ownsPrompt == nil or type(ownsPrompt) == "boolean"
end

function Specs.IsValidProfile(profile: any): boolean
	return type(profile) == "table"
		and type(profile.Defaults) == "table"
		and type(profile.Defaults.PromptName) == "string"
end

function Specs.IsValidResolvedParent(resolvedParent: any): boolean
	return typeof(resolvedParent) == "Instance"
		and (resolvedParent:IsA("BasePart") or resolvedParent:IsA("Attachment"))
		and resolvedParent.Parent ~= nil
end

function Specs.IsValidMode(mode: any): boolean
	return mode == nil or Enums.RegistrationMode:BelongsTo(mode)
end

function Specs.IsServiceAlive(isDestroyed: boolean): boolean
	return not isDestroyed
end

function Specs.IsHandleAlive(isDestroyed: boolean): boolean
	return not isDestroyed
end

function Specs.IsLegalTransition(currentState: any, canTransition: boolean): boolean
	if currentState == Enums.HandleState.Destroyed then
		return false
	end

	return canTransition
end

local HasValidConfig = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidConfig),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidConfig],
	function(candidate): boolean
		return Specs.IsValidConfig(candidate.Config)
	end
)

local HasValidKey = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidKey),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidKey],
	function(candidate): boolean
		return Specs.IsValidKey(candidate.Key)
	end
)

local HasValidTarget = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidTarget),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidTarget],
	function(candidate): boolean
		return Specs.IsValidTarget(candidate.Target)
	end
)

local HasValidPrompt = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidPrompt),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidPrompt],
	function(candidate): boolean
		return Specs.IsValidPrompt(candidate.Prompt)
	end
)

local HasValidPromptName = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidPromptName),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidPromptName],
	function(candidate): boolean
		return Specs.IsValidPromptName(candidate.PromptName)
	end
)

local HasValidActionKind = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidActionKind),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidActionKind],
	function(candidate): boolean
		return Specs.IsValidActionKind(candidate.ActionKind)
	end
)

local HasValidEnabled = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidEnabled),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidEnabled],
	function(candidate): boolean
		return Specs.IsValidEnabled(candidate.Enabled)
	end
)

local HasValidActionText = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidActionText),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidActionText],
	function(candidate): boolean
		return Specs.IsValidActionText(candidate.ActionText)
	end
)

local HasValidObjectText = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidObjectText),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidObjectText],
	function(candidate): boolean
		return Specs.IsValidObjectText(candidate.ObjectText)
	end
)

local HasValidHoldDuration = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidHoldDuration),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidHoldDuration],
	function(candidate): boolean
		return Specs.IsValidHoldDuration(candidate.HoldDuration)
	end
)

local HasValidMaxActivationDistance = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidMaxActivationDistance),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidMaxActivationDistance],
	function(candidate): boolean
		return Specs.IsValidMaxActivationDistance(candidate.MaxActivationDistance)
	end
)

local HasValidRequiresLineOfSight = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidRequiresLineOfSight),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidRequiresLineOfSight],
	function(candidate): boolean
		return Specs.IsValidRequiresLineOfSight(candidate.RequiresLineOfSight)
	end
)

local HasValidKeyboardKeyCode = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidKeyboardKeyCode),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidKeyboardKeyCode],
	function(candidate): boolean
		return Specs.IsValidKeyCode(candidate.KeyboardKeyCode)
	end
)

local HasValidGamepadKeyCode = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidGamepadKeyCode),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidGamepadKeyCode],
	function(candidate): boolean
		return Specs.IsValidKeyCode(candidate.GamepadKeyCode)
	end
)

local HasValidExclusivity = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidExclusivity),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidExclusivity],
	function(candidate): boolean
		return Specs.IsValidExclusivity(candidate.Exclusivity)
	end
)

local HasValidResolveParent = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidResolveParent),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidResolveParent],
	function(candidate): boolean
		return Specs.IsValidResolveParent(candidate.ResolveParent)
	end
)

local HasValidCanShow = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidCanShow),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidCanShow],
	function(candidate): boolean
		return Specs.IsValidCanShow(candidate.CanShow)
	end
)

local HasValidCanTrigger = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidCanTrigger),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidCanTrigger],
	function(candidate): boolean
		return Specs.IsValidCanTrigger(candidate.CanTrigger)
	end
)

local HasValidCallbacks = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidCallback),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidCallback],
	function(candidate): boolean
		return Specs.IsValidCallback(candidate.OnShown)
			and Specs.IsValidCallback(candidate.OnHidden)
			and Specs.IsValidCallback(candidate.OnTriggered)
			and Specs.IsValidCallback(candidate.OnHoldStarted)
			and Specs.IsValidCallback(candidate.OnHoldEnded)
	end
)

local HasValidMetadata = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidMetadata),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidMetadata],
	function(candidate): boolean
		return Specs.IsValidMetadata(candidate.Metadata)
	end
)

local HasValidOwnsPrompt = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidOwnsPrompt),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidOwnsPrompt],
	function(candidate): boolean
		return Specs.IsValidOwnsPrompt(candidate.OwnsPrompt)
	end
)

local HasValidProfile = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidProfile),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidProfile],
	function(candidate): boolean
		return Specs.IsValidProfile(candidate.Profile)
	end
)

local HasValidResolvedParent = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidResolvedParent),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidResolvedParent],
	function(candidate): boolean
		return Specs.IsValidResolvedParent(candidate.ResolvedParent)
	end
)

local HasValidMode = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidMode),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidMode],
	function(candidate): boolean
		return Specs.IsValidMode(candidate.Mode)
	end
)

local HasAliveService = Specification.new(
	_ErrorName(Enums.ErrorKey.ProximityServiceDestroyed),
	Enums.ErrorMessage[Enums.ErrorKey.ProximityServiceDestroyed],
	function(candidate): boolean
		return Specs.IsServiceAlive(candidate.IsDestroyed)
	end
)

local HasAliveHandle = Specification.new(
	_ErrorName(Enums.ErrorKey.ProximityHandleDestroyed),
	Enums.ErrorMessage[Enums.ErrorKey.ProximityHandleDestroyed],
	function(candidate): boolean
		return Specs.IsHandleAlive(candidate.IsDestroyed)
	end
)

local HasLegalTransition = Specification.new(
	_ErrorName(Enums.ErrorKey.IllegalProximityHandleTransition),
	Enums.ErrorMessage[Enums.ErrorKey.IllegalProximityHandleTransition],
	function(candidate): boolean
		return Specs.IsLegalTransition(candidate.CurrentState, candidate.CanTransition)
	end
)

Specs.HasValidConfigSpec = HasValidConfig
Specs.HasValidKeySpec = HasValidKey
Specs.HasValidTargetSpec = HasValidTarget
Specs.HasValidPromptSpec = HasValidPrompt
Specs.HasValidPromptNameSpec = HasValidPromptName
Specs.HasValidActionKindSpec = HasValidActionKind
Specs.HasValidEnabledSpec = HasValidEnabled
Specs.HasValidActionTextSpec = HasValidActionText
Specs.HasValidObjectTextSpec = HasValidObjectText
Specs.HasValidHoldDurationSpec = HasValidHoldDuration
Specs.HasValidMaxActivationDistanceSpec = HasValidMaxActivationDistance
Specs.HasValidRequiresLineOfSightSpec = HasValidRequiresLineOfSight
Specs.HasValidKeyboardKeyCodeSpec = HasValidKeyboardKeyCode
Specs.HasValidGamepadKeyCodeSpec = HasValidGamepadKeyCode
Specs.HasValidExclusivitySpec = HasValidExclusivity
Specs.HasValidResolveParentSpec = HasValidResolveParent
Specs.HasValidCanShowSpec = HasValidCanShow
Specs.HasValidCanTriggerSpec = HasValidCanTrigger
Specs.HasValidCallbacksSpec = HasValidCallbacks
Specs.HasValidMetadataSpec = HasValidMetadata
Specs.HasValidOwnsPromptSpec = HasValidOwnsPrompt
Specs.HasValidProfileSpec = HasValidProfile
Specs.HasValidResolvedParentSpec = HasValidResolvedParent
Specs.HasValidModeSpec = HasValidMode
Specs.HasAliveServiceSpec = HasAliveService
Specs.HasAliveHandleSpec = HasAliveHandle
Specs.HasLegalTransitionSpec = HasLegalTransition
Specs.HasValidOptions = Specification.All({
	HasValidConfig,
	HasValidPromptName,
	HasValidActionKind,
	HasValidEnabled,
	HasValidActionText,
	HasValidObjectText,
	HasValidHoldDuration,
	HasValidMaxActivationDistance,
	HasValidRequiresLineOfSight,
	HasValidKeyboardKeyCode,
	HasValidGamepadKeyCode,
	HasValidExclusivity,
	HasValidResolveParent,
	HasValidCanShow,
	HasValidCanTrigger,
	HasValidCallbacks,
	HasValidMetadata,
	HasValidOwnsPrompt,
})

return table.freeze(Specs)
