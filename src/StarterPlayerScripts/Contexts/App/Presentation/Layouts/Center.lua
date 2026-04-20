--!strict
--[=[
	@class Center
	Centered layout wrapper that composes `Stack` with centered alignment for rows and columns.
	@client
]=]

local Stack = require(script.Parent.Stack)
local React = require(game:GetService("ReplicatedStorage").Packages.React)
local e = React.createElement

--[=[
	Render a centered layout that composes `Stack` with centered alignment both horizontally and vertically.
	@within Center
	@param props Stack.TStackProps -- Stack layout configuration.
	@return React.Element -- The rendered centered layout element.
]=]
local function Center(props: Stack.TStackProps & { children: any? })
	return e(Stack, {
		Direction = "Vertical",
		Align = "Center",
		Justify = "Center",
		Gap = props.Gap or 0,
		Padding = props.Padding or 0,
		BackgroundColor = props.BackgroundColor,
		BackgroundTransparency = props.BackgroundTransparency,
		BorderRadius = props.BorderRadius,
		BorderSizePixel = props.BorderSizePixel,
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position,
		LayoutOrder = props.LayoutOrder,
		AutomaticSize = props.AutomaticSize,
		ClipsDescendants = props.ClipsDescendants,
		Bg = props.Bg,
	}, props.children)
end

return Center
