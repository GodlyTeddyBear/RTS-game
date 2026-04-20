--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local Frame = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Frame)
local TabButton = require(script.Parent.Parent.Parent.Parent.App.Presentation.Molecules.TabButton)
local GradientTokens = require(script.Parent.Parent.Parent.Parent.App.Config.GradientTokens)
local TypographyTokens = require(script.Parent.Parent.Parent.Parent.App.Config.TypographyTokens)

--[=[
	@interface TTabInfo
	@within InventoryTabBar
	.Name string -- Category name
	.Count number -- Number of items in category
	.DisplayOrder number -- Sort order
]=]
export type TTabInfo = {
	Name: string,
	Count: number,
	DisplayOrder: number,
}

--[=[
	@interface TInventoryTabBarProps
	@within InventoryTabBar
	.UsedSlots number -- Occupied slots
	.TotalSlots number -- Total slots
	.Tabs { TTabInfo } -- Category tabs
	.ActiveTab string -- Selected tab
	.OnTabSelect (tabName: string) -> () -- Tab selection handler
	.Position UDim2? -- Custom position
	.AnchorPoint Vector2? -- Custom anchor point
]=]
export type TInventoryTabBarProps = {
	UsedSlots: number,
	TotalSlots: number,
	Tabs: { TTabInfo },
	ActiveTab: string,
	OnTabSelect: (tabName: string) -> (),
	Position: UDim2?,
	AnchorPoint: Vector2?,
}

--[=[
	@function InventoryTabBar
	@within InventoryTabBar
	Render category tabs with item counts and slot usage indicator.
	@param props TInventoryTabBarProps
	@return React.ReactElement
]=]
local function InventoryTabBar(props: TInventoryTabBarProps)
	local tabChildren: { [string]: any } = {
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0.015, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		UIPadding = e("UIPadding", {
			PaddingLeft = UDim.new(0.02, 0),
			PaddingRight = UDim.new(0.02, 0),
		}),
	}

	-- Build tabs for each category
	for i, tab in ipairs(props.Tabs) do
		local tabName = tab.Name
		tabChildren["Tab_" .. tabName] = e(TabButton, {
			Label = tabName,
			IsActive = tabName == props.ActiveTab,
			LayoutOrder = i,
			Width = UDim2.fromScale(0.12551, 0.90909),
			ActiveGradient = GradientTokens.GREEN_BUTTON_GRADIENT,
			ActiveDecoreStroke = GradientTokens.GREEN_BUTTON_STROKE,
			ActiveLabelStrokeColor = Color3.fromRGB(5, 101, 47),
			GradientRotation = -141,
			FontFamily = "rbxasset://fonts/families/GothamSSm.json",
			LabelStrokeThickness = 1,
			OnSelect = function()
				props.OnTabSelect(tabName)
			end,
		})
	end

	return e(Frame, {
		Size = UDim2.fromScale(1, 0.05957),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0,
		Gradient = GradientTokens.BAR_GRADIENT,
		LayoutOrder = 2,
		ClipsDescendants = true,
		children = {
			SlotsLabel = e("TextLabel", {
				Text = "Slots:",
				FontFace = TypographyTokens.FontFace.Bold,
				TextColor3 = Color3.new(1, 1, 1),
				TextSize = 25,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Right,
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.fromScale(0.02431, 0.4918),
				Size = UDim2.fromScale(0.09236, 0.4918),
			}),

			Amount = e("TextLabel", {
				Text = tostring(props.UsedSlots) .. "/" .. tostring(props.TotalSlots),
				FontFace = TypographyTokens.FontFace.Body,
				TextColor3 = Color3.new(1, 1, 1),
				TextSize = 25,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.fromScale(0.12847, 0.4918),
				Size = UDim2.fromScale(0.09931, 0.4918),
			}),

			Container = e("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				ClipsDescendants = true,
				Position = UDim2.fromScale(0.61528, 0.4918),
				Size = UDim2.fromScale(0.68056, 0.72131),
			}, tabChildren),
		},
	})
end

return InventoryTabBar
