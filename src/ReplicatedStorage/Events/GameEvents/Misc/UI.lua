--!strict

--[=[
	@class UIEvents
	Event registry for UI and presentation layer events.
	@server
]=]

--[=[
	@prop ButtonClicked string
	@within UIEvents
	Fired when a UI button is clicked. Emitted with: `(buttonId: string)`
]=]

--[=[
	@prop MenuOpened string
	@within UIEvents
	Fired when a UI menu is opened. Emitted with: `(menuName: string)`
]=]

--[=[
	@prop MenuClosed string
	@within UIEvents
	Fired when a UI menu is closed. Emitted with: `(menuName: string)`
]=]

--[=[
	@prop TabSwitched string
	@within UIEvents
	Fired when a UI tab is switched. Emitted with: `(tabName: string)`
]=]

--[=[
	@prop ErrorOccurred string
	@within UIEvents
	Fired when an error occurs that should be displayed to the user. Emitted with: `(errorMessage: string)`
]=]

local events = table.freeze({
	ButtonClicked = "UI.ButtonClicked",
	MenuOpened = "UI.MenuOpened",
	MenuClosed = "UI.MenuClosed",
	TabSwitched = "UI.TabSwitched",
	ErrorOccurred = "UI.ErrorOccurred",
})

-- Validation schemas: event name -> array of expected argument type strings
local schemas: { [string]: { string } } = {
	[events.ButtonClicked] = { "string" },
	[events.MenuOpened] = { "string" },
	[events.MenuClosed] = { "string" },
	[events.TabSwitched] = { "string" },
	[events.ErrorOccurred] = { "string" },
}

return { events = events, schemas = schemas }
