--!strict

export type TSelectDropdownOption = {
	Id: string,
	Label: string,
	Disabled: boolean?,
}

export type TSelectDropdownConfig = {
	Id: string,
	Options: { TSelectDropdownOption },
	InitialOpen: boolean?,
	InitialSelectedId: string?,
	PlaceholderLabel: string?,
	CloseOnSelect: boolean?,
	AllowEmptySelection: boolean?,
}

export type TSelectDropdownSnapshot = {
	Id: string,
	IsOpen: boolean,
	SelectedId: string?,
	SelectedOption: TSelectDropdownOption?,
	PlaceholderLabel: string?,
	CanClearSelection: boolean,
}

export type TSelectDropdownTransitionAction =
	"Open" | "Close" | "Toggle" | "Select" | "ClearSelection" | "Reset"

export type TSelectDropdownTransitionInfo = {
	Action: TSelectDropdownTransitionAction,
	PreviousIsOpen: boolean,
	NextIsOpen: boolean,
	PreviousSelectedId: string?,
	NextSelectedId: string?,
}

export type TChangedConnection = {
	Disconnect: (self: TChangedConnection) -> (),
}

export type TChangedSignal = {
	Connect: (
		self: TChangedSignal,
		callback: (
			newSnapshot: TSelectDropdownSnapshot,
			previousSnapshot: TSelectDropdownSnapshot,
			transitionInfo: TSelectDropdownTransitionInfo
		) -> ()
	) -> TChangedConnection,
	Once: (
		self: TChangedSignal,
		callback: (
			newSnapshot: TSelectDropdownSnapshot,
			previousSnapshot: TSelectDropdownSnapshot,
			transitionInfo: TSelectDropdownTransitionInfo
		) -> ()
	) -> TChangedConnection,
	Fire: (
		self: TChangedSignal,
		newSnapshot: TSelectDropdownSnapshot,
		previousSnapshot: TSelectDropdownSnapshot,
		transitionInfo: TSelectDropdownTransitionInfo
	) -> (),
	Wait: (self: TChangedSignal) -> (TSelectDropdownSnapshot, TSelectDropdownSnapshot, TSelectDropdownTransitionInfo),
	DisconnectAll: (self: TChangedSignal) -> (),
}

export type TNormalizedSelectDropdownOption = {
	Id: string,
	Label: string,
	Disabled: boolean,
}

export type TNormalizedSelectDropdownConfig = {
	Id: string,
	Options: { TNormalizedSelectDropdownOption },
	OptionsById: { [string]: TNormalizedSelectDropdownOption },
	InitialOpen: boolean,
	InitialSelectedId: string?,
	PlaceholderLabel: string?,
	CloseOnSelect: boolean,
	AllowEmptySelection: boolean,
}

return table.freeze({})
