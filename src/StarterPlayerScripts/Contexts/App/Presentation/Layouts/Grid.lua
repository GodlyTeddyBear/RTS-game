--!strict
--[=[
	@class Grid
	Grid layout component that arranges children in a multi-column layout with configurable column count, gap, and padding.
	@client
]=]

local React = require(game:GetService("ReplicatedStorage").Packages.React)
local e = React.createElement

export type TGridProps = {
	Columns: number?,
	Gap: number?,
	Padding: number?,
	BackgroundColor: Color3?,
	BackgroundTransparency: number?,
	BorderRadius: UDim?,
	BorderSizePixel: number?,
	Size: UDim2?,
	Position: UDim2?,
	LayoutOrder: number?,
	AutomaticSize: Enum.AutomaticSize?,
}

--[=[
	Render a multi-column grid layout with configurable column count, gap, and padding.
	@within Grid
	@param props TGridProps -- Grid layout configuration.
	@return React.Element -- The rendered layout frame element.
]=]
local function Grid(props: TGridProps & { children: any? })
	local columns = props.Columns or 3
	local gap = props.Gap or 8
	local padding = props.Padding or 0
	local bgColor = props.BackgroundColor or Color3.fromRGB(255, 255, 255)
	local bgTransparency = props.BackgroundTransparency or 1
	local borderRadius = props.BorderRadius
	local borderSize = props.BorderSizePixel or 0
	local size = props.Size or UDim2.fromScale(1, 1)
	local position = props.Position
	local layoutOrder = props.LayoutOrder
	local autoSize = props.AutomaticSize

	return e("Frame", {
		Size = size,
		Position = position or UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = bgColor,
		BackgroundTransparency = bgTransparency,
		BorderSizePixel = borderSize,
		LayoutOrder = layoutOrder,
		AutomaticSize = autoSize,
	}, {
		UIGridLayout = e("UIGridLayout", {
			CellSize = UDim2.new(1 / columns, -gap, 0, 100), -- Width: 1/columns, Height: 100px
			CellPadding = UDim2.new(0, gap, 0, gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Top,
		}),

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

return Grid
