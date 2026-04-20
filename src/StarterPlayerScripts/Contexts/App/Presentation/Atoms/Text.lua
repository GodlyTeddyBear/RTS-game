--!strict
--[=[
	@class Text
	Themed text label atom with variant-driven font, size, and colour, supporting per-prop style overrides.
	@client
]=]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local Colors = require(script.Parent.Parent.Parent.Config.ColorTokens)
local Typography = require(script.Parent.Parent.Parent.Config.TypographyTokens)

--[=[
	@type TTextVariant "heading" | "body" | "caption" | "label"
	@within Text
]=]
export type TTextVariant = "heading" | "body" | "caption" | "label"

--[=[
	@interface TTextProps
	@within Text
	.ref any? -- React ref to attach to the label.
	.Text string? -- Label text. Defaults to `""`.
	.Size UDim2? -- Label size. Defaults to `UDim2.fromScale(1, 0)`.
	.Position UDim2? -- Label position.
	.LayoutOrder number? -- Sort order within a layout.
	.Variant TTextVariant? -- Variant preset. Defaults to `"body"`.
	.TextColor3 Color3? -- Override text colour.
	.Font Enum.Font? -- Override font.
	.TextSize number? -- Override text size.
	.TextWrapped boolean? -- Enable text wrapping. Defaults to `false`.
	.TextXAlignment Enum.TextXAlignment? -- Horizontal text alignment. Defaults to `Enum.TextXAlignment.Left`.
	.TextYAlignment Enum.TextYAlignment? -- Vertical text alignment. Defaults to `Enum.TextYAlignment.Top`.
	.AutomaticSize Enum.AutomaticSize? -- Auto-sizing mode.
	.TextScaled boolean? -- Enable auto text scaling. Defaults to `false`.
	.RichText boolean? -- Enable RichText formatting.
	.children any? -- Extra React children rendered inside the label.
]=]
export type TTextProps = {
	ref: any?,
	Text: string?,
	Size: UDim2?,
	Position: UDim2?,
	LayoutOrder: number?,
	Variant: TTextVariant?,

	-- Style overrides
	TextColor3: Color3?,
	Font: Enum.Font?,
	TextSize: number?,

	-- Alignment
	TextWrapped: boolean?,
	TextXAlignment: Enum.TextXAlignment?,
	TextYAlignment: Enum.TextYAlignment?,

	-- Sizing
	AutomaticSize: Enum.AutomaticSize?,
	TextScaled: boolean?,
	RichText: boolean?,

	children: any?,
}

local VARIANT_STYLES = {
	heading = { TextColor3 = Colors.Text.Primary, Font = Typography.Font.Heading, TextSize = Typography.FontSize.H1 },
	body = { TextColor3 = Colors.Text.Primary, Font = Typography.Font.Body, TextSize = Typography.FontSize.Body },
	caption = { TextColor3 = Colors.Text.Muted, Font = Typography.Font.Body, TextSize = Typography.FontSize.Caption },
	label = { TextColor3 = Colors.Text.Secondary, Font = Typography.Font.Heading, TextSize = Typography.FontSize.Small },
}

--[=[
	Render a themed text label with variant-driven font, size, and colour, supporting per-prop style overrides.
	@within Text
	@param props TTextProps -- Text label configuration.
	@return React.Element -- The rendered `TextLabel` element.
]=]
local function Text(props: TTextProps)
	local variantName = props.Variant or "body"
	local style = VARIANT_STYLES[variantName]

	return e("TextLabel", {
		ref = props.ref,
		Text = props.Text or "",
		Size = props.Size or UDim2.fromScale(1, 0),
		Position = props.Position,
		TextColor3 = props.TextColor3 or style.TextColor3,
		Font = props.Font or style.Font,
		TextSize = props.TextSize or style.TextSize,
		TextWrapped = props.TextWrapped or false,
		TextScaled = props.TextScaled or false,
		TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left,
		TextYAlignment = props.TextYAlignment or Enum.TextYAlignment.Top,
		AutomaticSize = props.AutomaticSize,
		RichText = props.RichText,
		LayoutOrder = props.LayoutOrder,
		BackgroundTransparency = 1,
	}, props.children)
end

return Text
