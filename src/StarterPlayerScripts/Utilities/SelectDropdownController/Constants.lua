--!strict

local Constants = {
	Action = table.freeze({
		Open = "Open",
		Close = "Close",
		Toggle = "Toggle",
		Select = "Select",
		ClearSelection = "ClearSelection",
		Reset = "Reset",
	}),
	Error = table.freeze({
		Destroyed = "SelectDropdownDestroyed",
		InvalidOption = "SelectDropdownInvalidOption",
		DisabledOption = "SelectDropdownDisabledOption",
		ClearNotAllowed = "SelectDropdownClearNotAllowed",
	}),
}

return table.freeze(Constants)
