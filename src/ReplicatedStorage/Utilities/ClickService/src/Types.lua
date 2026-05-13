--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Enums = require(script.Parent.Enums)
local Result = require(ReplicatedStorage.Utilities.Result)

export type TClickTarget = BasePart | Model
export type TResolvePartCallback = (target: TClickTarget) -> any

export type TClickAttachOptions = {
	Name: string?,
	MaxActivationDistance: number?,
	CursorIcon: string?,
	ResolvePart: TResolvePartCallback?,
}

export type TClickManagerConfig = {
	Name: string?,
	MaxActivationDistance: number?,
	CursorIcon: string?,
	ResolvePart: TResolvePartCallback?,
}

export type TResolvedClickOptions = {
	Name: string,
	MaxActivationDistance: number?,
	CursorIcon: string?,
	ResolvePart: TResolvePartCallback?,
}

export type TClickErrorData = {
	Target: Instance?,
	ResolvedPart: BasePart?,
	Detector: ClickDetector?,
	DetectorName: string?,
	Reason: string?,
	State: string?,
}

export type TClickHandleState = typeof(Enums.HandleState.Active)

export type TDetectorBinding = {
	Detector: ClickDetector,
	Created: boolean,
}

export type THandleTransitionConnection = {
	Disconnect: (self: THandleTransitionConnection) -> (),
}

export type THandleTransitionSignal = {
	Connect: (
		self: THandleTransitionSignal,
		callback: (newState: TClickHandleState, previousState: TClickHandleState) -> ()
	) -> THandleTransitionConnection,
	Once: (
		self: THandleTransitionSignal,
		callback: (newState: TClickHandleState, previousState: TClickHandleState) -> ()
	) -> THandleTransitionConnection,
	Wait: (self: THandleTransitionSignal) -> (TClickHandleState, TClickHandleState),
}

export type TClickConnection = {
	Disconnect: (self: TClickConnection) -> (),
}

export type TClickSignal = {
	Connect: (
		self: TClickSignal,
		callback: (player: Player, part: BasePart, handle: TClickHandle) -> ()
	) -> TClickConnection,
	Once: (
		self: TClickSignal,
		callback: (player: Player, part: BasePart, handle: TClickHandle) -> ()
	) -> TClickConnection,
	Fire: (self: TClickSignal, player: Player, part: BasePart, handle: TClickHandle) -> (),
	Wait: (self: TClickSignal) -> (Player, BasePart, TClickHandle),
	DisconnectAll: (self: TClickSignal) -> (),
}

export type TClickHandle = {
	Clicked: TClickSignal,
	StateChanged: THandleTransitionSignal,

	GetTarget: (self: TClickHandle) -> TClickTarget,
	GetResolvedPart: (self: TClickHandle) -> BasePart,
	GetDetector: (self: TClickHandle) -> any,
	GetState: (self: TClickHandle) -> TClickHandleState,
	IsAttached: (self: TClickHandle) -> boolean,
	Detach: (self: TClickHandle) -> boolean,
	Destroy: (self: TClickHandle) -> (),
}

export type TClickService = {
	Clicked: TClickSignal,

	Attach: (self: TClickService, target: TClickTarget, options: TClickAttachOptions?) -> Result.Result<TClickHandle>,
	AttachMany: (
		self: TClickService,
		targets: { TClickTarget },
		options: TClickAttachOptions?
	) -> Result.Result<{ TClickHandle }>,
	GetHandle: (self: TClickService, target: TClickTarget) -> any,
	GetDetector: (self: TClickService, target: TClickTarget) -> any,
	Has: (self: TClickService, target: TClickTarget) -> boolean,
	Detach: (self: TClickService, target: TClickTarget) -> boolean,
	DetachAll: (self: TClickService) -> (),
	GetAttachedCount: (self: TClickService) -> number,
	Destroy: (self: TClickService) -> (),
}

local Types = {}

return Types
