--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement
local useRef = React.useRef

local GradientTokens = require(script.Parent.Parent.Parent.Parent.App.Config.GradientTokens)
local Colors = require(script.Parent.Parent.Parent.Parent.App.Config.ColorTokens)
local Typography = require(script.Parent.Parent.Parent.Parent.App.Config.TypographyTokens)
local AnimationTokens = require(script.Parent.Parent.Parent.Parent.App.Config.AnimationTokens)
local useHoverSpring = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useHoverSpring)

local SlotViewModel = require(script.Parent.Parent.Parent.Application.ViewModels.SlotViewModel)
local SharedAtoms = require(ReplicatedStorage.Contexts.Building.Sync.SharedAtoms)

--[=[
	@type TZoneSlotGridProps
	@within ZoneSlotGrid
	.ZoneName string -- Zone to display slots for
	.PlayerBuildings SharedAtoms.TBuildingsMap -- Current player buildings
	.SelectedSlot number? -- Currently selected slot (if any)
	.OnSelectSlot (slotIndex: number) -> () -- Slot selection callback
]=]
export type TZoneSlotGridProps = {
	ZoneName: string,
	PlayerBuildings: SharedAtoms.TBuildingsMap,
	SelectedSlot: number?,
	OnSelectSlot: (slotIndex: number) -> (),
}

--[=[
	@class ZoneSlotGrid
	Renders a grid of building slots with empty/occupied states and selection.
	@client
]=]

local function SlotCard(props: {
	SlotData: SlotViewModel.TSlotData,
	IsSelected: boolean,
	LayoutOrder: number,
	OnActivated: () -> (),
})
	local slot = props.SlotData
	local gradient = if props.IsSelected
		then GradientTokens.TAB_ACTIVE_GRADIENT
		else GradientTokens.SLOT_GRADIENT

	local labelText = slot.DisplayLabel
	local sublabelText = slot.DisplaySublabel

	local btnRef = useRef(nil :: TextButton?)
	local hover = useHoverSpring(btnRef, AnimationTokens.Interaction.SlotCell)

	return e("TextButton", {
		ref = btnRef,
		BackgroundColor3 = Color3.new(1, 1, 1),
		ClipsDescendants = true,
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		TextSize = 1,
		[React.Event.MouseEnter] = hover.onMouseEnter,
		[React.Event.MouseLeave] = hover.onMouseLeave,
		[React.Event.Activated] = hover.onActivated(props.OnActivated),
	}, {
		UIGradient = e("UIGradient", {
			Color = gradient,
			Rotation = -16,
		}),

		UICorner = e("UICorner", {
			CornerRadius = UDim.new(0, 6),
		}),

		UIStroke = e("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = Color3.new(1, 1, 1),
			Thickness = if props.IsSelected then 2 else 1,
		}, {
			UIGradient = e("UIGradient", {
				Color = if props.IsSelected
					then GradientTokens.GOLD_STROKE
					else GradientTokens.GOLD_STROKE_SUBTLE,
			}),
		}),

		SlotIndex = e("TextLabel", {
			AnchorPoint = Vector2.new(0, 0),
			BackgroundTransparency = 1,
			Font = Typography.Font.Bold,
			Position = UDim2.fromScale(0.08, 0.06),
			Size = UDim2.fromScale(0.3, 0.2),
			Text = tostring(props.SlotData.SlotIndex),
			TextColor3 = Colors.Text.Muted,
			TextSize = Typography.FontSize.Caption,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),

		Label = e("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Font = Typography.Font.Bold,
			Position = UDim2.fromScale(0.5, 0.45),
			Size = UDim2.fromScale(0.85, 0.35),
			Text = labelText,
			TextColor3 = if slot.IsEmpty then Colors.Text.Muted else Colors.Text.Primary,
			TextSize = Typography.FontSize.Small,
			TextWrapped = true,
		}),

		Sublabel = if sublabelText
			then e("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				Font = Typography.Font.Body,
				Position = UDim2.fromScale(0.5, 0.72),
				Size = UDim2.fromScale(0.85, 0.2),
				Text = sublabelText,
				TextColor3 = if slot.IsMaxLevel
					then Colors.Accent.Yellow
					else Colors.Text.Muted,
				TextSize = Typography.FontSize.Caption,
				TextWrapped = true,
			})
			else nil,
	})
end

local function ZoneSlotGrid(props: TZoneSlotGridProps)
	local slots = SlotViewModel.buildSlotGrid(props.ZoneName, props.PlayerBuildings)

	local gridChildren: { [string]: any } = {
		UIGridLayout = e("UIGridLayout", {
			CellSize = UDim2.fromScale(0.46, 0.22),
			CellPadding = UDim2.fromScale(0.04, 0.02),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Top,
		}),
		UIPadding = e("UIPadding", {
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 8),
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
		}),
	}

	for i, slot in slots do
		gridChildren["Slot_" .. tostring(i)] = e(SlotCard, {
			SlotData = slot,
			IsSelected = props.SelectedSlot == slot.SlotIndex,
			LayoutOrder = slot.SlotIndex,
			OnActivated = function()
				props.OnSelectSlot(slot.SlotIndex)
			end,
		})
	end

	return e("ScrollingFrame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		CanvasSize = UDim2.new(),
		ClipsDescendants = true,
		Position = UDim2.fromScale(0.5, 0.5),
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Colors.Accent.Yellow,
		Size = UDim2.fromScale(1, 1),
	}, gridChildren)
end

return ZoneSlotGrid
