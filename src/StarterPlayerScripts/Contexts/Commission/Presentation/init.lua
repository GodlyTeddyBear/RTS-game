--!strict

--[=[
	@class Commission
	Commission UI feature slice. Exports the main commission board screen component.
	@client
]=]

local CommissionBoardScreen = require(script.Templates.CommissionBoardScreen)

return {
	--[=[
		@prop CommissionBoardScreen function
		@within Commission
		Main commission board screen component.
	]=]
	CommissionBoardScreen = CommissionBoardScreen,
}
