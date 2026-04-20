--!strict
--[=[
	@class Stack
	Base layout component that positions children horizontally or vertically with configurable gap and padding via `UIListLayout` and `UIPadding`.
	@client
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)

export type TStackProps = {
	Direction: string?,
	Gap: number?,
	Padding: number?,
	Align: string?,
	Justify: string?,
	BackgroundTransparency: number?,
	BackgroundColor3: Color3?,
	BorderRadius: UDim?,
	BorderSizePixel: number?,
	Size: UDim2?,
	Position: UDim2?,
	LayoutOrder: number?,
	AutomaticSize: Enum.AutomaticSize?,
	ClipsDescendants: boolean?,
	AnchorPoint: Vector2?,
}

--[=[
	Render a base stack layout that positions children horizontally or vertically with configurable gap and padding.
	@within Stack
	@param props TStackProps -- Stack layout configuration.
	@return React.Element -- The rendered layout frame element.
]=]
local function Stack(props: TStackProps & { children: any? })
	local direction = props.Direction or "Vertical"
	local align = props.Align or "Start"
	local justify = props.Justify or "Start"

	local gap = props.Gap or 0
	local padding = props.Padding or 0

	local hAlign = _GetHorizontalAlignment(align)
	local vAlign = _GetVerticalAlignment(align)
	local justifyHAlign, justifyVAlign = _ResolveJustifyAlignment(direction, justify, hAlign, vAlign)

	local e = React.createElement
	return e("Frame", {
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.fromScale(0.5, 0.5),
		AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5),
		BackgroundTransparency = props.BackgroundTransparency or 1,
		BackgroundColor3 = props.BackgroundColor3,
		BorderSizePixel = props.BorderSizePixel or 0,
		LayoutOrder = props.LayoutOrder,
		AutomaticSize = props.AutomaticSize,
		ClipsDescendants = props.ClipsDescendants or false,
	}, {
		UIListLayout = e("UIListLayout", {
			FillDirection = _GetFillDirection(direction),
			HorizontalAlignment = justifyHAlign,
			VerticalAlignment = justifyVAlign,
			Padding = UDim.new(0, gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),

		UICorner = props.BorderRadius and e("UICorner", {
			CornerRadius = props.BorderRadius,
		}) or nil,

		UIPadding = padding > 0 and e("UIPadding", {
			PaddingTop = UDim.new(0, padding),
			PaddingBottom = UDim.new(0, padding),
			PaddingLeft = UDim.new(0, padding),
			PaddingRight = UDim.new(0, padding),
		}) or nil,

		Children = e(React.Fragment, nil, props.children),
	})
end

function _GetHorizontalAlignment(align: string?): Enum.HorizontalAlignment
	if align == "Center" then
		return Enum.HorizontalAlignment.Center
	elseif align == "End" or align == "Stretch" then
		return Enum.HorizontalAlignment.Right
	end
	return Enum.HorizontalAlignment.Left
end

function _GetVerticalAlignment(align: string?): Enum.VerticalAlignment
	if align == "Center" then
		return Enum.VerticalAlignment.Center
	elseif align == "End" or align == "Stretch" then
		return Enum.VerticalAlignment.Bottom
	end
	return Enum.VerticalAlignment.Top
end

function _GetFillDirection(direction: string?): Enum.FillDirection
	return (direction == "Horizontal") and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical
end

function _ResolveJustifyAlignment(
	direction: string,
	justify: string?,
	align: Enum.HorizontalAlignment,
	valign: Enum.VerticalAlignment
)
	if direction == "Horizontal" then
		if justify == "Center" then
			return Enum.HorizontalAlignment.Center, valign
		elseif justify == "End" then
			return Enum.HorizontalAlignment.Right, valign
		end
		return align, valign
	else
		if justify == "Center" then
			return align, Enum.VerticalAlignment.Center
		elseif justify == "End" then
			return align, Enum.VerticalAlignment.Bottom
		end
		return align, valign
	end
end

return Stack
