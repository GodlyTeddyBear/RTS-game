--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement
local useRef = React.useRef

local Frame = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Frame)
local GradientTokens = require(script.Parent.Parent.Parent.Parent.App.Config.GradientTokens)
local AnimationTokens = require(script.Parent.Parent.Parent.Parent.App.Config.AnimationTokens)
local useHoverSpring = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useHoverSpring)
local useSoundActions = require(script.Parent.Parent.Parent.Parent.Sound.Application.Hooks.useSoundActions)

local RecipeViewModel = require(script.Parent.Parent.Parent.Application.ViewModels.RecipeViewModel)

--[=[
	@interface TRecipeCardProps
	Props for a recipe card display.
	.Recipe RecipeViewModel.TRecipeViewModel -- Recipe data model
	.OnCraft (recipeId: string) -> () -- Callback fired when craft button clicked
	.LayoutOrder number? -- Layout order for parent list
]=]
export type TRecipeCardProps = {
	Recipe: RecipeViewModel.TRecipeViewModel,
	OnCraft: (recipeId: string) -> (),
	LayoutOrder: number?,
}

-- Disabled state styling: button gradient when player lacks materials
local DISABLED_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(55, 55, 55)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(75, 75, 75)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(55, 55, 55)),
})
-- Disabled state: inner border decoration color
local DISABLED_DECORE_COLOR = Color3.fromRGB(45, 45, 45)
-- Disabled state: text outline color
local DISABLED_LABEL_STROKE = Color3.fromRGB(25, 25, 25)

--[=[
	@class RecipeCard
	Renders a single recipe as a card; shows ingredients, availability, and craft button.
	@client
]=]
local function RecipeCard(props: TRecipeCardProps)
	local recipe = props.Recipe
	local soundActions = useSoundActions()
	local cardRef = useRef(nil :: Frame?)
	local craftBtnRef = useRef(nil :: TextButton?)

	-- Setup hover spring animations for card and craft button
	local cardHover = useHoverSpring(cardRef, AnimationTokens.Interaction.Card)
	local craftHover = useHoverSpring(craftBtnRef, {
		HoverScale = AnimationTokens.Interaction.ActionButton.HoverScale,
		PressScale = AnimationTokens.Interaction.ActionButton.PressScale,
		SpringPreset = AnimationTokens.Interaction.ActionButton.SpringPreset,
		Disabled = not recipe.CanAfford,
	})

	-- Build ingredient list rows
	local ingredientChildren: { [string]: any } = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 2),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	-- Add ingredient row for each required item (green if met, red if missing)
	for i, ing in ipairs(recipe.Ingredients) do
		local textColor = if ing.Met then Color3.fromRGB(170, 170, 170) else Color3.fromRGB(255, 80, 80)
		ingredientChildren["Ing_" .. i] = e("TextLabel", {
			BackgroundTransparency = 1,
			FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json"),
			LayoutOrder = i,
			Size = UDim2.new(1, 0, 0, 14),
			Text = ing.Name .. ": " .. ing.Have .. "/" .. ing.Required,
			TextColor3 = textColor,
			TextSize = 13,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
	end

	-- Choose button styling based on affordability
	local btnGradient = if recipe.CanAfford then GradientTokens.GREEN_ACTION_GRADIENT else DISABLED_GRADIENT
	local btnDecoreColor = if recipe.CanAfford then GradientTokens.GREEN_ACTION_DECORE_COLOR else DISABLED_DECORE_COLOR
	local btnLabelStroke = if recipe.CanAfford then GradientTokens.GREEN_ACTION_LABEL_STROKE_COLOR else DISABLED_LABEL_STROKE
	local btnText = if recipe.CanAfford then "Craft" else "Need Materials"

	return e("Frame", {
		ref = cardRef,
		Size = UDim2.new(1, 0, 0, 90),
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder,
		[React.Event.MouseEnter] = cardHover.onMouseEnter,
		[React.Event.MouseLeave] = cardHover.onMouseLeave,
	}, {
		Inner = e(Frame, {
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0,
			ClipsDescendants = true,
			Gradient = GradientTokens.TAB_INACTIVE_GRADIENT,
			GradientRotation = -2,
			StrokeColor = GradientTokens.GOLD_STROKE,
			StrokeThickness = 1,
			children = {
				-- Left: recipe name, description, ingredients
				Info = e("Frame", {
					AnchorPoint = Vector2.new(0, 0.5),
					BackgroundTransparency = 1,
					Position = UDim2.fromScale(0.03, 0.5),
					Size = UDim2.fromScale(0.6, 0.82),
				}, {
					Layout = e("UIListLayout", {
						FillDirection = Enum.FillDirection.Vertical,
						Padding = UDim.new(0, 3),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),

					NameLabel = e("TextLabel", {
						BackgroundTransparency = 1,
						FontFace = Font.new(
							"rbxasset://fonts/families/GothamSSm.json",
							Enum.FontWeight.Bold,
							Enum.FontStyle.Normal
						),
						LayoutOrder = 1,
						Size = UDim2.new(1, 0, 0, 20),
						Text = recipe.Name,
						TextColor3 = Color3.new(1, 1, 1),
						TextSize = 18,
						TextWrapped = true,
						TextXAlignment = Enum.TextXAlignment.Left,
					}, {
						UIStroke = e("UIStroke", {
							Color = Color3.fromRGB(4, 4, 4),
							LineJoinMode = Enum.LineJoinMode.Miter,
							Thickness = 2,
						}),
					}),

					DescLabel = e("TextLabel", {
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json"),
						LayoutOrder = 2,
						Size = UDim2.new(1, 0, 0, 13),
						Text = recipe.Description,
						TextColor3 = Color3.fromRGB(120, 120, 120),
						TextSize = 13,
						TextWrapped = true,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),

					Ingredients = e("Frame", {
						BackgroundTransparency = 1,
						LayoutOrder = 3,
						Size = UDim2.new(1, 0, 0, 40),
					}, ingredientChildren),
				}),

				-- Right: output quantity + craft button
				CraftArea = e("Frame", {
					AnchorPoint = Vector2.new(1, 0.5),
					BackgroundTransparency = 1,
					Position = UDim2.fromScale(0.97, 0.5),
					Size = UDim2.fromScale(0.3, 0.82),
				}, {
					Layout = e("UIListLayout", {
						FillDirection = Enum.FillDirection.Vertical,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						Padding = UDim.new(0, 4),
						SortOrder = Enum.SortOrder.LayoutOrder,
						VerticalAlignment = Enum.VerticalAlignment.Center,
					}),

					OutputLabel = e("TextLabel", {
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json"),
						LayoutOrder = 1,
						Size = UDim2.new(1, 0, 0, 14),
						Text = "x" .. recipe.OutputQuantity,
						TextColor3 = Color3.fromRGB(170, 170, 170),
						TextSize = 13,
						TextWrapped = true,
						TextXAlignment = Enum.TextXAlignment.Center,
					}),

					CraftBtn = e("TextButton", {
						ref = craftBtnRef,
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundColor3 = Color3.new(1, 1, 1),
						ClipsDescendants = true,
						LayoutOrder = 2,
						Size = UDim2.new(1, 0, 0, 36),
						Text = "",
						TextSize = 1,
						[React.Event.MouseEnter] = craftHover.onMouseEnter,
						[React.Event.MouseLeave] = craftHover.onMouseLeave,
						[React.Event.Activated] = if recipe.CanAfford
							then craftHover.onActivated(function()
								props.OnCraft(recipe.Id)
							end)
							else function()
								soundActions.playError()
							end,
					}, {
						UIGradient = e("UIGradient", {
							Color = btnGradient,
							Rotation = -3,
						}),

						UICorner = e("UICorner"),

						Decore = e("Frame", {
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = 1,
							ClipsDescendants = true,
							Position = UDim2.fromScale(0.5, 0.5),
							Size = UDim2.fromScale(0.91, 0.82),
						}, {
							UIStroke = e("UIStroke", {
								ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
								BorderStrokePosition = Enum.BorderStrokePosition.Inner,
								Color = btnDecoreColor,
								Thickness = 2,
							}),

							UICorner = e("UICorner", {
								CornerRadius = UDim.new(0, 4),
							}),
						}),

						Label = e("TextLabel", {
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = 1,
							FontFace = Font.new(
								"rbxasset://fonts/families/GothamSSm.json",
								Enum.FontWeight.Bold,
								Enum.FontStyle.Normal
							),
							Interactable = false,
							Position = UDim2.fromScale(0.5, 0.5),
							Size = UDim2.fromScale(0.91, 0.82),
							Text = btnText,
							TextColor3 = Color3.new(1, 1, 1),
							TextSize = 13,
							TextWrapped = true,
						}, {
							UIStroke = e("UIStroke", {
								Color = btnLabelStroke,
								LineJoinMode = Enum.LineJoinMode.Miter,
								Thickness = 2,
							}),
						}),
					}),
				}),
			},
		}),
	})
end

return RecipeCard
