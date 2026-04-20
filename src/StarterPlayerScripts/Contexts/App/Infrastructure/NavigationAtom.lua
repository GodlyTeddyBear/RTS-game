--!strict
--[=[
	@class NavigationAtom
	Singleton Charm atom holding the global navigation state (current screen, history, and params).
	@client
]=]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Charm = require(ReplicatedStorage.Packages.Charm)

--[=[
	@interface TNavigationState
	@within NavigationAtom
	.CurrentScreen string -- Name of the screen currently displayed.
	.History { string } -- Stack of previously visited screen names.
	.Params { [string]: any }? -- Optional parameters passed to the current screen.
]=]
export type TNavigationState = {
	CurrentScreen: string,
	History: { string },
	Params: { [string]: any }?,
}

-- Create singleton atom
local navigationAtom = Charm.atom({
	CurrentScreen = "Home",
	History = { "Home" },
	Params = nil,
} :: TNavigationState)

return navigationAtom
