--!strict

--[=[
	@class Dialogue.Presentation
	Exports dialogue UI components for use in the App context.
	@client
]=]

local DialogueOverlay = require(script.Templates.DialogueOverlay)

--[=[
	@prop DialogueOverlay function
	@within Dialogue.Presentation
	Screen template that renders the dialogue modal when active.
]=]
return {
	DialogueOverlay = DialogueOverlay,
}
