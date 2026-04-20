--!strict
--[=[
	@class HStack
	Horizontal layout wrapper that composes `Stack` with `Direction = "Horizontal"` for row spacing.
	@client
]=]

local Stack = require(script.Parent.Stack)
local React = require(game:GetService("ReplicatedStorage").Packages.React)
local e = React.createElement

--[=[
	Render a horizontal stack layout that arranges children in a row.
	@within HStack
	@param props Stack.TStackProps -- Stack layout configuration.
	@return React.Element -- The rendered horizontal stack element.
]=]
local function HStack(props: Stack.TStackProps & { children: any? })
	return e(Stack, {
		Direction = "Horizontal",
		Gap = props.Gap,
		Padding = props.Padding,
		Align = props.Align,
		Justify = props.Justify,
		BackgroundColor3 = props.BackgroundColor3,
		BackgroundTransparency = props.BackgroundTransparency,
		BorderRadius = props.BorderRadius,
		BorderSizePixel = props.BorderSizePixel,
		Size = props.Size,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		LayoutOrder = props.LayoutOrder,
		AutomaticSize = props.AutomaticSize,
		ClipsDescendants = props.ClipsDescendants,
	}, props.children)
end

return HStack
