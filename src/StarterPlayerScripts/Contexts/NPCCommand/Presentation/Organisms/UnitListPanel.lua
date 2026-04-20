--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement
local useRef = React.useRef

local useHoverSpring = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useHoverSpring)
local AnimationTokens = require(script.Parent.Parent.Parent.Parent.App.Config.AnimationTokens)
local NPCCommandTypes = require(script.Parent.Parent.Parent.Types.NPCCommandTypes)

local UNIT_INTERACTION = AnimationTokens.Interaction.SlotCell

local GOTHIC_BOLD = Font.new(
	"rbxasset://fonts/families/GothicA1.json",
	Enum.FontWeight.Bold,
	Enum.FontStyle.Normal
)

local COLOR_GOLD = Color3.fromRGB(212, 175, 55)
local COLOR_BORDER_DEFAULT = Color3.fromRGB(135, 135, 135)
local CORNER_DEFAULT = UDim.new(0, 2)
local CORNER_SELECTED = UDim.new(0.25, 0)

local PANEL_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(4, 4, 4)),
	ColorSequenceKeypoint.new(0.519231, Color3.fromRGB(26, 19, 19)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(4, 4, 4)),
})

-- Entry height constants (pixels), matched to import proportions
local ENTRY_NAME_HEIGHT = 32
local ENTRY_STATUS_HEIGHT = 20
local ENTRY_PADDING = 2
local ENTRY_HEIGHT = ENTRY_NAME_HEIGHT + ENTRY_STATUS_HEIGHT + ENTRY_PADDING

type TNPCUnitEntryProps = {
	entry: NPCCommandTypes.TNPCEntry,
	layoutOrder: number,
	onToggleRosterUnit: (npcId: string) -> (),
}

local function NPCUnitEntry(props: TNPCUnitEntryProps)
	local entry = props.entry
	local isSelected = entry.isSelected
	local hpFillScale = math.clamp(entry.HPPercent, 0, 1)
	local hpValueText = tostring(math.floor(hpFillScale * 100))

	local buttonRef = useRef(nil :: TextButton?)
	local hover = useHoverSpring(buttonRef :: any, UNIT_INTERACTION)

	return e("Frame", {
		BackgroundTransparency = 1,
		LayoutOrder = props.layoutOrder,
		Size = UDim2.new(0.91776, 0, 0, ENTRY_HEIGHT),
	}, {
		Button = e("TextButton", {
			ref = buttonRef,
			AnchorPoint = Vector2.new(0.5, 0.5),
			AutoButtonColor = false,
			BackgroundColor3 = Color3.fromRGB(80, 40, 40),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			Text = "",
			[React.Event.MouseEnter] = hover.onMouseEnter,
			[React.Event.MouseLeave] = hover.onMouseLeave,
			[React.Event.Activated] = hover.onActivated(function()
				props.onToggleRosterUnit(entry.NPCId)
			end),
		}, {
		UICorner = e("UICorner", {
			CornerRadius = UDim.new(0, 2),
		}),
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, ENTRY_PADDING),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),

		NameArea = e("Frame", {
			BackgroundColor3 = Color3.fromRGB(33, 32, 32),
			BorderSizePixel = 0,
			ClipsDescendants = true,
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, ENTRY_NAME_HEIGHT),
		}, {
			UIStroke = e("UIStroke", {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				BorderStrokePosition = Enum.BorderStrokePosition.Inner,
				Color = if isSelected then COLOR_GOLD else COLOR_BORDER_DEFAULT,
				Thickness = 1,
			}),
			UICorner = e("UICorner", {
				CornerRadius = if isSelected then CORNER_SELECTED else CORNER_DEFAULT,
			}),

			Person = e("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = GOTHIC_BOLD,
				Position = UDim2.fromScale(0.5, 0.25),
				Size = UDim2.fromScale(0.94, 0.38),
				Text = entry.DisplayName,
				TextColor3 = Color3.new(1, 1, 1),
				TextSize = 11,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
			}, {
				UIStroke = e("UIStroke", {
					LineJoinMode = Enum.LineJoinMode.Miter,
					Thickness = 1.5,
				}),
			}),

			Bar = e("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(51, 14, 14),
				BorderSizePixel = 0,
				ClipsDescendants = true,
				Position = UDim2.fromScale(0.5, 0.75),
				Size = UDim2.fromScale(0.8, 0.3),
			}, {
				UIStroke = e("UIStroke", {
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					BorderStrokePosition = Enum.BorderStrokePosition.Inner,
					Color = Color3.fromRGB(103, 24, 24),
					Thickness = 1,
				}),
				UICorner = e("UICorner", {
					CornerRadius = UDim.new(0, 2),
				}),
				Fill = e("Frame", {
					AnchorPoint = Vector2.new(0, 0.5),
					BackgroundColor3 = Color3.fromRGB(255, 49, 49),
					BorderSizePixel = 0,
					Position = UDim2.fromScale(0, 0.5),
					Size = UDim2.fromScale(hpFillScale, 1),
				}),
				HPLabel = e("TextLabel", {
					AnchorPoint = Vector2.new(0, 0.5),
					BackgroundTransparency = 1,
					FontFace = GOTHIC_BOLD,
					Position = UDim2.fromScale(0.05, 0.5),
					Size = UDim2.fromScale(0.25, 1),
					Text = "HP",
					TextColor3 = Color3.new(1, 1, 1),
					TextSize = 9,
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 2,
				}),
				HPValue = e("TextLabel", {
					AnchorPoint = Vector2.new(1, 0.5),
					BackgroundTransparency = 1,
					FontFace = GOTHIC_BOLD,
					Position = UDim2.fromScale(0.98, 0.5),
					Size = UDim2.fromScale(0.47, 0.92),
					Text = hpValueText,
					TextColor3 = Color3.new(1, 1, 1),
					TextSize = 9,
					TextWrapped = true,
					ZIndex = 2,
				}),
			}),
		}),

		-- Width matches import's StatusContainerScroll (70.251% of entry)
		StatusStrip = e("Frame", {
			BackgroundColor3 = Color3.fromRGB(33, 32, 32),
			BorderSizePixel = 0,
			ClipsDescendants = true,
			LayoutOrder = 2,
			Size = UDim2.new(0.70251, 0, 0, ENTRY_STATUS_HEIGHT),
		}, {
			UIStroke = e("UIStroke", {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				BorderStrokePosition = Enum.BorderStrokePosition.Inner,
				Color = if isSelected then COLOR_GOLD else COLOR_BORDER_DEFAULT,
				Thickness = 1,
			}),
			UICorner = e("UICorner", {
				CornerRadius = if isSelected then CORNER_SELECTED else CORNER_DEFAULT,
			}),
		}),
	}),
	})
end

export type TUnitListPanelProps = {
	rosterNPCs: { NPCCommandTypes.TNPCEntry },
	onToggleRosterUnit: (npcId: string) -> (),
}

local function UnitListPanel(props: TUnitListPanelProps)
	local scrollChildren: { [string]: any } = {
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		UIPadding = e("UIPadding", {
			PaddingBottom = UDim.new(0, 4),
			PaddingTop = UDim.new(0, 4),
		}),
	}

	if #props.rosterNPCs == 0 then
		scrollChildren["EmptyLabel"] = e("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			FontFace = GOTHIC_BOLD,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.9, 0.2),
			Text = "No units",
			TextColor3 = Color3.fromRGB(135, 135, 135),
			TextSize = 10,
			TextWrapped = true,
		})
	else
		for i, entry in ipairs(props.rosterNPCs) do
			scrollChildren["Entry_" .. entry.NPCId] = e(NPCUnitEntry, {
				entry = entry,
				layoutOrder = i,
				onToggleRosterUnit = props.onToggleRosterUnit,
			})
		end
	end

	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ClipsDescendants = true,
		Position = UDim2.fromScale(0.05782, 0.82422),
		Size = UDim2.fromScale(0.11563, 0.35156),
	}, {
		UIGradient = e("UIGradient", {
			Color = PANEL_GRADIENT,
			Rotation = -140.856,
		}),
		UIStroke = e("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			BorderStrokePosition = Enum.BorderStrokePosition.Inner,
			Color = Color3.fromRGB(135, 135, 135),
			Thickness = 4,
		}),
		UICorner = e("UICorner", {
			CornerRadius = UDim.new(0, 10),
		}),
		UnitScroll = e("ScrollingFrame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			CanvasSize = UDim2.new(),
			Position = UDim2.fromScale(0.5, 0.5),
			ScrollBarThickness = 2,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			Size = UDim2.fromScale(0.91291, 0.93889),
		}, scrollChildren),
	})
end

return UnitListPanel
