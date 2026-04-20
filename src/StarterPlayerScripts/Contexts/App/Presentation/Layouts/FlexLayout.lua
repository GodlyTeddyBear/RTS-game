--!strict
--[=[
	@class FlexLayout
	Flexible layout component that positions children in a row or column with configurable gap, padding, and alignment.
	@client
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

--[=[
	Render a flexible layout that positions children horizontally or vertically with configurable gap, padding, and alignment.
	@within FlexLayout
	@return React.Element -- The rendered layout frame element.
]=]
local function FlexLayout(props)
	local direction = props.Direction or "Row"
	local gap = props.Gap or 0
	local padding = props.Padding or UDim.new(0, 0)
	local align = props.Align or "Start"
	local justify = props.Justify or "Start"

	local hAlign = _GetHorizontalAlignment(align)
	local vAlign = _GetVerticalAlignment(align)
	local justifyHAlign, justifyVAlign = _ResolveJustifyAlignment(direction, justify, hAlign, vAlign)

	local e = React.createElement
	return e("Frame", {
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = props.LayoutOrder,
	}, {
		UIListLayout = e("UIListLayout", {
			FillDirection = if direction == "Column"
				then Enum.FillDirection.Vertical
				else Enum.FillDirection.Horizontal,
			HorizontalAlignment = justifyHAlign,
			VerticalAlignment = justifyVAlign,
			Padding = UDim.new(0, gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),

		UIPadding = e("UIPadding", {
			PaddingTop = padding,
			PaddingBottom = padding,
			PaddingLeft = padding,
			PaddingRight = padding,
		}),

		Children = e(React.Fragment, nil, props.children),
	})
end

function _GetHorizontalAlignment(align: string?): Enum.HorizontalAlignment
	if align == "Center" then
		return Enum.HorizontalAlignment.Center
	elseif align == "End" then
		return Enum.HorizontalAlignment.Right
	end
	return Enum.HorizontalAlignment.Left
end

function _GetVerticalAlignment(align: string?): Enum.VerticalAlignment
	if align == "Center" then
		return Enum.VerticalAlignment.Center
	elseif align == "End" then
		return Enum.VerticalAlignment.Bottom
	end
	return Enum.VerticalAlignment.Top
end

function _ResolveJustifyAlignment(direction: string, justify: string?, hAlign: Enum.HorizontalAlignment, vAlign: Enum.VerticalAlignment)
	if direction == "Column" then
		if justify == "Center" then
			return hAlign, Enum.VerticalAlignment.Center
		elseif justify == "End" then
			return hAlign, Enum.VerticalAlignment.Bottom
		end
		return hAlign, vAlign
	else
		if justify == "Center" then
			return Enum.HorizontalAlignment.Center, vAlign
		elseif justify == "End" then
			return Enum.HorizontalAlignment.Right, vAlign
		end
		return hAlign, vAlign
	end
end

return FlexLayout
