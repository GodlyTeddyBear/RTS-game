--!strict

local Enums = require(script.Parent.Enums)

export type TProximityTarget = BasePart | Attachment | Model
export type TResolvePromptParentCallback = (target: TProximityTarget) -> (BasePart | Attachment)?
export type TEligibilityPredicate = (context: TProximityEligibilityContext, player: Player?) -> boolean
export type THandleCallback = (player: Player?, prompt: ProximityPrompt, handle: TProximityHandle) -> ()

export type TProximityOptions = {
	PromptName: string?,
	ActionKind: any?,
	Enabled: boolean?,
	ActionText: string?,
	ObjectText: string?,
	HoldDuration: number?,
	MaxActivationDistance: number?,
	RequiresLineOfSight: boolean?,
	KeyboardKeyCode: Enum.KeyCode?,
	GamepadKeyCode: Enum.KeyCode?,
	Exclusivity: Enum.ProximityPromptExclusivity?,
	ResolveParent: TResolvePromptParentCallback?,
	CanShow: ((context: TProximityEligibilityContext) -> boolean)?,
	CanTrigger: TEligibilityPredicate?,
	OnShown: THandleCallback?,
	OnHidden: THandleCallback?,
	OnTriggered: THandleCallback?,
	OnHoldStarted: THandleCallback?,
	OnHoldEnded: THandleCallback?,
	Metadata: { [string]: any }?,
	OwnsPrompt: boolean?,
}

export type TResolvedProximityOptions = {
	PromptName: string,
	ActionKind: any,
	Enabled: boolean,
	ActionText: string,
	ObjectText: string,
	HoldDuration: number,
	MaxActivationDistance: number,
	RequiresLineOfSight: boolean,
	KeyboardKeyCode: Enum.KeyCode,
	GamepadKeyCode: Enum.KeyCode,
	Exclusivity: Enum.ProximityPromptExclusivity,
	ResolveParent: TResolvePromptParentCallback?,
	CanShow: ((context: TProximityEligibilityContext) -> boolean)?,
	CanTrigger: TEligibilityPredicate?,
	OnShown: THandleCallback?,
	OnHidden: THandleCallback?,
	OnTriggered: THandleCallback?,
	OnHoldStarted: THandleCallback?,
	OnHoldEnded: THandleCallback?,
	Metadata: { [string]: any }?,
	OwnsPrompt: boolean,
}

export type TProximityProfile = {
	Defaults: TResolvedProximityOptions,
}

export type TProximityProfileSpec = TProximityOptions
export type TProximityManagerConfig = TProximityOptions
export type TProximityHandleState = typeof(Enums.HandleState.Registered)
export type TRegistrationMode = typeof(Enums.RegistrationMode.Create)

export type TProximityEligibilityContext = {
	Manager: TProximityManager?,
	Handle: TProximityHandle?,
	Key: string,
	ActionKind: any,
	Target: TProximityTarget?,
	Prompt: ProximityPrompt?,
	State: TProximityHandleState?,
	Enabled: boolean,
	OwnsPrompt: boolean,
	Mode: TRegistrationMode?,
}

export type TPromptBinding = {
	Prompt: ProximityPrompt,
	Created: boolean,
}

export type TProximityConnection = {
	Disconnect: (self: TProximityConnection) -> (),
}

export type TShownSignal = {
	Connect: (
		self: TShownSignal,
		callback: (prompt: ProximityPrompt, handle: TProximityHandle) -> ()
	) -> TProximityConnection,
	Once: (
		self: TShownSignal,
		callback: (prompt: ProximityPrompt, handle: TProximityHandle) -> ()
	) -> TProximityConnection,
	Fire: (self: TShownSignal, prompt: ProximityPrompt, handle: TProximityHandle) -> (),
	Wait: (self: TShownSignal) -> (ProximityPrompt, TProximityHandle),
	DisconnectAll: (self: TShownSignal) -> (),
}

export type THiddenSignal = TShownSignal

export type TTriggeredSignal = {
	Connect: (
		self: TTriggeredSignal,
		callback: (player: Player?, prompt: ProximityPrompt, handle: TProximityHandle) -> ()
	) -> TProximityConnection,
	Once: (
		self: TTriggeredSignal,
		callback: (player: Player?, prompt: ProximityPrompt, handle: TProximityHandle) -> ()
	) -> TProximityConnection,
	Fire: (self: TTriggeredSignal, player: Player?, prompt: ProximityPrompt, handle: TProximityHandle) -> (),
	Wait: (self: TTriggeredSignal) -> (Player?, ProximityPrompt, TProximityHandle),
	DisconnectAll: (self: TTriggeredSignal) -> (),
}

export type TDestroyedSignal = {
	Connect: (
		self: TDestroyedSignal,
		callback: (handle: TProximityHandle) -> ()
	) -> TProximityConnection,
	Once: (
		self: TDestroyedSignal,
		callback: (handle: TProximityHandle) -> ()
	) -> TProximityConnection,
	Fire: (self: TDestroyedSignal, handle: TProximityHandle) -> (),
	Wait: (self: TDestroyedSignal) -> TProximityHandle,
	DisconnectAll: (self: TDestroyedSignal) -> (),
}

export type TStateChangedConnection = {
	Disconnect: (self: TStateChangedConnection) -> (),
}

export type TStateChangedSignal = {
	Connect: (
		self: TStateChangedSignal,
		callback: (newState: TProximityHandleState, previousState: TProximityHandleState) -> ()
	) -> TStateChangedConnection,
	Once: (
		self: TStateChangedSignal,
		callback: (newState: TProximityHandleState, previousState: TProximityHandleState) -> ()
	) -> TStateChangedConnection,
	Wait: (self: TStateChangedSignal) -> (TProximityHandleState, TProximityHandleState),
}

export type TProximityHandle = {
	Shown: TShownSignal,
	Hidden: THiddenSignal,
	Triggered: TTriggeredSignal,
	HoldStarted: TTriggeredSignal,
	HoldEnded: TTriggeredSignal,
	Destroyed: TDestroyedSignal,
	StateChanged: TStateChangedSignal,

	GetPrompt: (self: TProximityHandle) -> ProximityPrompt,
	GetKey: (self: TProximityHandle) -> string,
	GetActionKind: (self: TProximityHandle) -> any,
	GetTarget: (self: TProximityHandle) -> TProximityTarget,
	GetState: (self: TProximityHandle) -> TProximityHandleState,
	GetMetadata: (self: TProximityHandle) -> { [string]: any }?,
	IsVisible: (self: TProximityHandle) -> boolean,
	SetEnabled: (self: TProximityHandle, enabled: boolean) -> (),
	Refresh: (self: TProximityHandle) -> (),
	Destroy: (self: TProximityHandle) -> (),
}

export type TProximityManager = {
	Create: (self: TProximityManager, key: string, target: TProximityTarget, options: TProximityOptions?) -> TProximityHandle,
	Register: (self: TProximityManager, key: string, prompt: ProximityPrompt, options: TProximityOptions?) -> TProximityHandle,
	BindProfile: (
		self: TProximityManager,
		key: string,
		targetOrPrompt: TProximityTarget | ProximityPrompt,
		profile: TProximityProfile,
		overrides: TProximityOptions?
	) -> TProximityHandle,
	Get: (self: TProximityManager, key: string) -> TProximityHandle?,
	Remove: (self: TProximityManager, key: string) -> (),
	Clear: (self: TProximityManager) -> (),
	Destroy: (self: TProximityManager) -> (),
}

local Types = {}

return Types
