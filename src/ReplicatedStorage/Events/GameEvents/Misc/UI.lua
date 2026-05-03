--!strict

local UI = {}

local events = table.freeze({
	ButtonClicked = "UI.ButtonClicked",
	MenuOpened = "UI.MenuOpened",
	MenuClosed = "UI.MenuClosed",
	TabSwitched = "UI.TabSwitched",
	ErrorOccurred = "UI.ErrorOccurred",
})

local schemas: { [string]: { string } } = {
	[events.ButtonClicked] = { "string" },
	[events.MenuOpened] = { "string" },
	[events.MenuClosed] = { "string" },
	[events.TabSwitched] = { "string" },
	[events.ErrorOccurred] = { "string" },
}

UI.events = events
UI.schemas = schemas

return UI
