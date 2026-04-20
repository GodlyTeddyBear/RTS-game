--!strict
--[=[
	@class Presentation
	Shop feature presentation layer. Exports the ShopScreen template component.
	@client
]=]
local ShopScreen = require(script.Templates.ShopScreen)

return {
	ShopScreen = ShopScreen,
}
