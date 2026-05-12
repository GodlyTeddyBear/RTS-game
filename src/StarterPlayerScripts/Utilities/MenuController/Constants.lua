--!strict

local Constants = {
	Action = table.freeze({
		Open = "Open",
		Close = "Close",
		GoTo = "GoTo",
		Back = "Back",
		Reset = "Reset",
		SetContext = "SetContext",
		ClearContext = "ClearContext",
	}),
	State = table.freeze({
		Closed = "Closed",
	}),
	Error = table.freeze({
		MenuAlreadyOpen = "MenuAlreadyOpen",
		MenuAlreadyClosed = "MenuAlreadyClosed",
		MenuInvalidTarget = "MenuInvalidTarget",
		MenuUnknownState = "MenuUnknownState",
		MenuBackUnavailable = "MenuBackUnavailable",
		MenuInvalidContextPatch = "MenuInvalidContextPatch",
		MenuDestroyed = "MenuDestroyed",
	}),
}

return table.freeze(Constants)
