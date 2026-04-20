--!strict
local ForgeScreen = require(script.Templates.ForgeScreen)

--[=[
	@class Presentation
	Public presentation layer exports for the Forge feature slice.
	@client
]=]
return {
	--[=[
		@prop ForgeScreen React.FC<void>
		@within Presentation
		Main forge UI screen component.
	]=]
	ForgeScreen = ForgeScreen,
}
