--!strict
--[=[
	@class Box
	Generic container layout component with padding, background, border, and optional gradient styling.
	@client
]=]

local React = require(game:GetService("ReplicatedStorage").Packages.React)
local e = React.createElement

export type TBoxProps = {
	Padding: number?,
	BackgroundColor: Color3?,
	BackgroundTransparency: number?,
	BorderRadius: UDim?,
	BorderSizePixel: number?,
	Size: UDim2?,
	Position: UDim2?,
	LayoutOrder: number?,
	AutomaticSize: Enum.AutomaticSize?,
	ClipsDescendants: boolean?,
}

--[=[
	Render a generic container with padding, background, border, and optional gradient styling.
	@within Box
	@param props TBoxProps -- Box layout configuration.
	@return React.Element -- The rendered container frame element.
]=]
local function Box(props: TBoxProps & { children: any? })
	local padding = props.Padding or 0
	local bgColor = props.BackgroundColor or Color3.fromRGB(255, 255, 255)
	local bgTransparency = props.BackgroundTransparency or 1
	local borderRadius = props.BorderRadius
	local borderSize = props.BorderSizePixel or 0
	local size = props.Size or UDim2.fromScale(1, 1)
	local position = props.Position
	local layoutOrder = props.LayoutOrder
	local autoSize = props.AutomaticSize
	local clipsDescendants = props.ClipsDescendants or false

	return e("Frame", {
		Size = size,
		Position = position or UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = bgColor,
		BackgroundTransparency = bgTransparency,
		BorderSizePixel = borderSize,
		LayoutOrder = layoutOrder,
		AutomaticSize = autoSize,
		ClipsDescendants = clipsDescendants,
	}, {
		UICorner = borderRadius and e("UICorner", {
			CornerRadius = borderRadius,
		}) or nil,

		UIPadding = e("UIPadding", {
			PaddingTop = UDim.new(padding / 600, 0),
			PaddingBottom = UDim.new(padding / 600, 0),
			PaddingLeft = UDim.new(padding / 600, 0),
			PaddingRight = UDim.new(padding / 600, 0),
		}),

		Children = e(React.Fragment, nil, props.children),
	})
end

return Box
