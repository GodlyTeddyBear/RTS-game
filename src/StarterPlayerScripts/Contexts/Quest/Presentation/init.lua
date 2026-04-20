--!strict

--[=[
	@class Presentation
	Quest feature UI screens and components.
	Exports the three main quest-related screens: board, party selection, and expedition result.
	@client
]=]

local QuestBoardScreen = require(script.Templates.QuestBoardScreen)
local QuestPartySelectionScreen = require(script.Templates.QuestPartySelectionScreen)
local QuestExpeditionResultScreen = require(script.Templates.QuestExpeditionResultScreen)

return {
	QuestBoardScreen = QuestBoardScreen,
	QuestPartySelectionScreen = QuestPartySelectionScreen,
	QuestExpeditionResultScreen = QuestExpeditionResultScreen,
}
