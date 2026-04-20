--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local ScreenHeader = require(script.Parent.Parent.Parent.Parent.App.Presentation.Organisms.ScreenHeader)

--[=[
	@interface TInventoryHeaderProps
	@within InventoryHeader
	.OnBack () -> () -- Back button handler
	.Position UDim2? -- Custom position
	.AnchorPoint Vector2? -- Custom anchor point
]=]
export type TInventoryHeaderProps = {
	OnBack: () -> (),
	Position: UDim2?,
	AnchorPoint: Vector2?,
}

--[=[
	@function InventoryHeader
	@within InventoryHeader
	Render the inventory screen header with title and back button.
	@param props TInventoryHeaderProps
	@return React.ReactElement
]=]
local function InventoryHeader(props: TInventoryHeaderProps)
	return e(ScreenHeader, {
		Title = "Inventory",
		OnBack = props.OnBack,
		FontFamily = "rbxasset://fonts/families/GothamSSm.json",
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
	})
end

return InventoryHeader
