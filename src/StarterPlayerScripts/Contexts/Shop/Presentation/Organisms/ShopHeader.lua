--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local ScreenHeader = require(script.Parent.Parent.Parent.Parent.App.Presentation.Organisms.ScreenHeader)

--[=[
	@interface TShopHeaderProps
	Props for the Shop header.
	.OnBack () -> () -- Navigate back callback
	.Position UDim2? -- Optional position override
	.AnchorPoint Vector2? -- Optional anchor point override
]=]
export type TShopHeaderProps = {
	OnBack: () -> (),
	Position: UDim2?,
	AnchorPoint: Vector2?,
}

--[=[
	@class ShopHeader
	Header bar for the Shop screen displaying title and back button.
	@client
]=]

--[=[
	Render the Shop header with title and back navigation.
	@within ShopHeader
	@param props TShopHeaderProps
	@return React.ReactElement -- Header component
]=]
local function ShopHeader(props: TShopHeaderProps)
	return e(ScreenHeader, {
		Title = "Shop",
		OnBack = props.OnBack,
		Height = UDim2.fromScale(1, 0.09766),
		FontFamily = "rbxasset://fonts/families/GothamSSm.json",
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
	})
end

return ShopHeader
