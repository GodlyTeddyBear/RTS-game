--!strict
--[=[
	@class MenuList
	Molecule that renders a vertical list of tab buttons for menu navigation.
	@client
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local GradientTokens = require(script.Parent.Parent.Parent.Config.GradientTokens)
local Colors = require(script.Parent.Parent.Parent.Config.ColorTokens)
local Typography = require(script.Parent.Parent.Parent.Config.TypographyTokens)

export type TMenuListProps = {
	OnNavigate: (featureName: string) -> (),
}

local MENU_ITEMS = {
	{ Name = "Workers", LayoutOrder = 1 },
	{ Name = "Upgrades", LayoutOrder = 2 },
	{ Name = "Statistics", LayoutOrder = 3 },
	{ Name = "Inventory", LayoutOrder = 4 },
	{ Name = "Forge", LayoutOrder = 5 },
	{ Name = "Brewery", LayoutOrder = 6 },
	{ Name = "Tailoring", LayoutOrder = 7 },
	{ Name = "Buildings", LayoutOrder = 8 },
	{ Name = "Shop", LayoutOrder = 9 },
	{ Name = "Guild", LayoutOrder = 10 },
	{ Name = "Settings", LayoutOrder = 11 },
}

local function MenuItem(props: {
	Text: string,
	LayoutOrder: number,
	IsHovered: boolean,
	OnActivated: () -> (),
	OnHoverStart: () -> (),
	OnHoverEnd: () -> (),
})
	local gradient = if props.IsHovered then GradientTokens.TAB_ACTIVE_GRADIENT else GradientTokens.TAB_INACTIVE_GRADIENT
	local strokeColor = if props.IsHovered then GradientTokens.TAB_ACTIVE_STROKE else nil
	local gradientRotation = if props.IsHovered then nil else -2

	return e("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1), -- white base needed for UIGradient tinting
		ClipsDescendants = true,
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.fromScale(1, 0.143),
		Text = "",
		TextSize = 1,
		[React.Event.Activated] = props.OnActivated,
		[React.Event.MouseEnter] = props.OnHoverStart,
		[React.Event.MouseLeave] = props.OnHoverEnd,
	}, {
		UIGradient = e("UIGradient", {
			Color = gradient,
			Rotation = gradientRotation,
		}),

		UICorner = e("UICorner", {
			CornerRadius = UDim.new(0, 0),
		}),

		UIStroke = if strokeColor
			then e("UIStroke", {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				BorderStrokePosition = Enum.BorderStrokePosition.Inner,
				Color = Color3.new(1, 1, 1),
				Thickness = 3,
			}, {
				UIGradient = e("UIGradient", {
					Color = strokeColor,
				}),
			})
			else nil,

		Label = e("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Font = Typography.Font.Bold,
			Interactable = false,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.625, 0.472),
			Text = props.Text,
			TextColor3 = Colors.Text.Primary,
			TextSize = Typography.FontSize.H2,
			TextWrapped = true,
		}),
	})
end

local function MenuList(props: TMenuListProps)
	local hoveredItem, setHoveredItem = React.useState("")

	local children = {}

	children.UIListLayout = e("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 4),
	})

	for _, item in MENU_ITEMS do
		local name = item.Name
		children[name .. "Tab"] = e(MenuItem, {
			Text = name,
			LayoutOrder = item.LayoutOrder,
			IsHovered = hoveredItem == name,
			OnActivated = function()
				props.OnNavigate(name)
			end,
			OnHoverStart = function()
				setHoveredItem(name)
			end,
			OnHoverEnd = function()
				setHoveredItem("")
			end,
		})
	end

	return e("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, children)
end

return MenuList
