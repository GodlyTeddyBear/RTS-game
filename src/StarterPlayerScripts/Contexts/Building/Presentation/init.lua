--!strict
--[=[
	@class Building.Presentation
	Exports presentation layer screens and components for the Building context.
	@client
]=]

local BuildingScreen = require(script.Templates.BuildingScreen)

return {
	BuildingScreen = BuildingScreen,
}
