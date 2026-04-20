--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local Frame = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Frame)
local GradientTokens = require(script.Parent.Parent.Parent.Parent.App.Config.GradientTokens)
local ActionButton = require(script.Parent.Parent.Molecules.ActionButton)

--[=[
	@interface TInventoryFooterProps
	@within InventoryFooter
	.OnAction ((actionName: string) -> ())? -- Action button callback
	.Position UDim2? -- Custom position
	.AnchorPoint Vector2? -- Custom anchor point
]=]
export type TInventoryFooterProps = {
	OnAction: ((actionName: string) -> ())?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
}

--[=[
	@function InventoryFooter
	@within InventoryFooter
	Render the inventory footer with action buttons.
	@param props TInventoryFooterProps
	@return React.ReactElement
]=]
local function InventoryFooter(props: TInventoryFooterProps)
	return e(Frame, {
		Size = UDim2.fromScale(1, 0.08105),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0,
		Gradient = GradientTokens.BAR_GRADIENT,
		LayoutOrder = 4,
		ZIndex = 0,
		children = {
			OptionsContainer = e("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				ClipsDescendants = true,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.95694, 0.80723),
			}, {
				OptionButton = e(ActionButton, {
					Label = "Action",
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.fromScale(0.07475, 0.5),
					Size = UDim2.fromScale(0.08999, 0.76119),
					OnActivated = if props.OnAction then function() props.OnAction("action") end else nil,
				}),
			}),
		},
	})
end

return InventoryFooter
