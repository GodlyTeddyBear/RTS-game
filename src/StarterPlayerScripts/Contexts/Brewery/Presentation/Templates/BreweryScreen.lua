--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local Frame = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Frame)
local IconButton = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.IconButton)
local GradientTokens = require(script.Parent.Parent.Parent.Parent.App.Config.GradientTokens)
local AnimationTokens = require(script.Parent.Parent.Parent.Parent.App.Config.AnimationTokens)
local useStaggeredMount = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useStaggeredMount)
local useNavigationActions = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useNavigationActions)
local useScreenTransition = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useScreenTransition)
local useSoundActions = require(script.Parent.Parent.Parent.Parent.Sound.Application.Hooks.useSoundActions)

local BreweryRecipeCard = require(script.Parent.Parent.Organisms.BreweryRecipeCard)
local BreweryScreenView = require(script.Parent.BreweryScreenView)
local useInventoryState = require(script.Parent.Parent.Parent.Parent.Inventory.Application.Hooks.useInventoryState)
local useBreweryActions = require(script.Parent.Parent.Parent.Application.Hooks.useBreweryActions)
local BreweryRecipeViewModel = require(script.Parent.Parent.Parent.Application.ViewModels.BreweryRecipeViewModel)

type TStaggeredCardProps = BreweryRecipeCard.TBreweryRecipeCardProps & { Index: number }

-- Wrapper that hides recipe cards until their stagger animation triggers.
local function StaggeredBreweryRecipeCard(props: TStaggeredCardProps)
	local isVisible = useStaggeredMount(props.Index, AnimationTokens.Stagger.List)
	if not isVisible then
		return nil
	end
	return e(BreweryRecipeCard, props)
end

--[=[
	@class BreweryScreen
	Root screen component for the brewery feature. Manages recipe list, inventory lookup, and navigation.
	@client
]=]
local function BreweryScreen()
	-- Set up screen animation, hooks, and state
	local anim = useScreenTransition("Standard")
	local inventoryState = useInventoryState()
	local breweryActions = useBreweryActions()
	local navActions = useNavigationActions()
	local soundActions = useSoundActions()

	-- Transform recipes with current inventory state
	local recipeList = BreweryRecipeViewModel.allFromInventory(inventoryState)
	local recipeCount = #recipeList

	-- Build scroll content with layout and appearance
	local scrollChildren: { [string]: any } = {
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			-- Center empty state, top-align recipe list
			VerticalAlignment = if recipeCount == 0
				then Enum.VerticalAlignment.Center
				else Enum.VerticalAlignment.Top,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		UIPadding = e("UIPadding", {
			PaddingLeft = UDim.new(0.015, 0),
			PaddingRight = UDim.new(0.015, 0),
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 8),
		}),
		InnerStroke = e("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = Color3.new(1, 1, 1),
			LineJoinMode = Enum.LineJoinMode.Miter,
			Thickness = 3,
		}, {
			UIGradient = e("UIGradient", {
				Color = GradientTokens.GOLD_STROKE_SUBTLE,
			}),
		}),
	}

	-- Populate scroll with empty state or recipe cards
	if recipeCount == 0 then
		scrollChildren["EmptyText"] = e("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json"),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.8, 0.1),
			Text = "No recipes available.",
			TextColor3 = Color3.fromRGB(150, 150, 150),
			TextSize = 18,
			TextWrapped = true,
		})
	else
		for i, vm in ipairs(recipeList) do
			scrollChildren["Recipe_" .. vm.Id] = e(StaggeredBreweryRecipeCard, {
				Recipe = vm,
				OnBrew = function(recipeId: string)
					local result = breweryActions.brewItem(recipeId)
					if result then
						result:catch(function()
							soundActions.playError()
						end)
					end
				end,
				LayoutOrder = i,
				Index = i,
			})
		end
	end

	return e(BreweryScreenView, {
		containerRef = anim.containerRef,
		recipeCount = recipeCount,
		scrollChildren = scrollChildren,
		onBack = function()
			soundActions.playMenuClose("Brewery")
			navActions.goBack()
		end,
	})
end

return BreweryScreen
