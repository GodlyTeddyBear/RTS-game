--!strict

--[=[
	@class Worker.Presentation
	Public exports for the Worker feature presentation layer.
	@client
]=]

local WorkersScreen = require(script.Templates.WorkersScreen)

return {
	WorkersScreen = WorkersScreen,
}
