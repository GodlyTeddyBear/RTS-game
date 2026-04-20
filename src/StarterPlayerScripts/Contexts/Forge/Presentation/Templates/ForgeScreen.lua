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

local RecipeCard = require(script.Parent.Parent.Organisms.RecipeCard)
local ForgeScreenView = require(script.Parent.ForgeScreenView)
local useInventoryState = require(script.Parent.Parent.Parent.Parent.Inventory.Application.Hooks.useInventoryState)
local useUnlockState = require(script.Parent.Parent.Parent.Parent.Unlock.Application.Hooks.useUnlockState)
local useForgeActions = require(script.Parent.Parent.Parent.Application.Hooks.useForgeActions)
local RecipeViewModel = require(script.Parent.Parent.Parent.Application.ViewModels.RecipeViewModel)

--[=[
	@class ForgeScreen
	Main forge UI screen showing available recipes and crafting interface.
	@client
]=]

type TStaggeredCardProps = RecipeCard.TRecipeCardProps & { Index: number }

-- Wrapper that only renders recipe card once its staggered animation delay passes
local function StaggeredRecipeCard(props: TStaggeredCardProps)
	local isVisible = useStaggeredMount(props.Index, AnimationTokens.Stagger.List)
	if not isVisible then
		return nil
	end
	return e(RecipeCard, props)
end

--[=[
	Render the forge screen with available recipes and craft actions. Subscribes to inventory state to drive recipe availability.
	@within ForgeScreen
]=]
local function ForgeScreen()
	-- Load state and hooks
	local anim = useScreenTransition("Standard")
	local inventoryState = useInventoryState()
	local unlockState = useUnlockState()
	local forgeActions = useForgeActions()
	local navActions = useNavigationActions()
	local soundActions = useSoundActions()

	-- Build recipe list and prepare for rendering
	local recipeList = RecipeViewModel.allFromInventory(inventoryState, unlockState)
	local recipeCount = #recipeList

	-- Build scroll content children
	local scrollChildren: { [string]: any } = {
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
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

	-- Render empty state or recipe list based on availability
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
		-- Render each recipe card with staggered animation
		for i, vm in ipairs(recipeList) do
			scrollChildren["Recipe_" .. vm.Id] = e(StaggeredRecipeCard, {
				Recipe = vm,
				OnCraft = function(recipeId: string)
					local result = forgeActions.craftItem(recipeId)
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

	return e(ForgeScreenView, {
		containerRef = anim.containerRef,
		recipeCount = recipeCount,
		scrollChildren = scrollChildren,
		onBack = function()
			soundActions.playMenuClose("Forge")
			navActions.goBack()
		end,
	})
end

return ForgeScreen
