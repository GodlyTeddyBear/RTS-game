--!strict

export type TMenuStateMeta = {
	Title: string?,
	ShowBack: boolean?,
	ShowClose: boolean?,
}

export type TMenuStateNode = {
	Targets: { string }?,
	Meta: TMenuStateMeta?,
}

export type TMenuConfig = {
	Id: string,
	InitialState: string,
	States: {
		[string]: TMenuStateNode,
	},
}

export type TMenuSnapshot = {
	IsOpen: boolean,
	CurrentState: string?,
	History: { string },
	Context: { [string]: any },
	CanGoBack: boolean,
	CanClose: boolean,
	Meta: TMenuStateMeta,
}

export type TMenuTransitionAction = "Open" | "Close" | "GoTo" | "Back" | "Reset" | "SetContext" | "ClearContext"

export type TMenuTransitionInfo = {
	Action: TMenuTransitionAction,
	FromState: string?,
	ToState: string?,
	Payload: { [string]: any }?,
	ContextPatch: { [string]: any }?,
}

export type TChangedConnection = {
	Disconnect: (self: TChangedConnection) -> (),
}

export type TChangedSignal = {
	Connect: (
		self: TChangedSignal,
		callback: (
			newSnapshot: TMenuSnapshot,
			previousSnapshot: TMenuSnapshot,
			transitionInfo: TMenuTransitionInfo
		) -> ()
	) -> TChangedConnection,
	Once: (
		self: TChangedSignal,
		callback: (
			newSnapshot: TMenuSnapshot,
			previousSnapshot: TMenuSnapshot,
			transitionInfo: TMenuTransitionInfo
		) -> ()
	) -> TChangedConnection,
	Fire: (
		self: TChangedSignal,
		newSnapshot: TMenuSnapshot,
		previousSnapshot: TMenuSnapshot,
		transitionInfo: TMenuTransitionInfo
	) -> (),
	Wait: (self: TChangedSignal) -> (TMenuSnapshot, TMenuSnapshot, TMenuTransitionInfo),
	DisconnectAll: (self: TChangedSignal) -> (),
}

export type TInternalMenuState = string

export type TNormalizedMenuStateNode = {
	Targets: { [string]: boolean },
	Meta: TMenuStateMeta,
}

export type TNormalizedMenuConfig = {
	Id: string,
	InitialState: string,
	States: {
		[string]: TNormalizedMenuStateNode,
	},
	Transitions: { [TInternalMenuState]: { [TInternalMenuState]: boolean } },
}

return table.freeze({})
