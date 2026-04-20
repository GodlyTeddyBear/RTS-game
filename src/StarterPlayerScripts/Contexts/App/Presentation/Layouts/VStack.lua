--!strict
--[=[
	@class VStack
	Vertical layout wrapper that composes `Stack` with `Direction = "Vertical"` for column spacing.
	@client
]=]

local Stack = require(script.Parent.Stack)
local React = require(game:GetService("ReplicatedStorage").Packages.React)
local e = React.createElement

--[=[
	Render a vertical stack layout that arranges children in a column.
	@within VStack
	@param props Stack.TStackProps -- Stack layout configuration.
	@return React.Element -- The rendered vertical stack element.
]=]
local function VStack(props: Stack.TStackProps & { children: any? })
	return e(Stack, {
		Direction = "Vertical",
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

return VStack
