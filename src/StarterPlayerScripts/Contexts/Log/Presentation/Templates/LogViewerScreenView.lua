--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement
local useState = React.useState

local LogEntryViewModel = require(script.Parent.Parent.Parent.Application.ViewModels.LogEntryViewModel)
local LogViewerViewModel = require(script.Parent.Parent.Parent.Application.ViewModels.LogViewerViewModel)
local LogEntryRow = require(script.Parent.Parent.Organisms.LogEntryRow)

local BACKGROUND_COLOR = Color3.fromRGB(18, 18, 22)
local HEADER_COLOR = Color3.fromRGB(28, 28, 34)
local CLEAR_BUTTON_COLOR = Color3.fromRGB(60, 30, 30)
local CLEAR_FILTERED_BUTTON_COLOR = Color3.fromRGB(40, 45, 70)
local CLEAR_TEXT_COLOR = Color3.fromRGB(255, 100, 100)
local CLEAR_FILTERED_TEXT_COLOR = Color3.fromRGB(180, 200, 255)
local TAB_ACTIVE_COLOR = Color3.fromRGB(50, 50, 65)
local TAB_INACTIVE_COLOR = Color3.fromRGB(28, 28, 34)
local TAB_TEXT_ACTIVE = Color3.fromRGB(220, 220, 220)
local TAB_TEXT_INACTIVE = Color3.fromRGB(100, 100, 120)
local HEADER_HEIGHT = 36
local FILTER_ROW_HEIGHT = 28
local FILTER_LABEL_WIDTH = 74

local POPUP_BG         = Color3.fromRGB(18, 18, 22)
local POPUP_HEADER_BG  = Color3.fromRGB(28, 28, 34)
local POPUP_BORDER     = Color3.fromRGB(50, 50, 60)
local POPUP_TEXT_DIM   = Color3.fromRGB(120, 120, 140)
local POPUP_TEXT_BODY  = Color3.fromRGB(220, 220, 220)
local POPUP_CLOSE_BG   = Color3.fromRGB(60, 30, 30)
local POPUP_CLOSE_TEXT = Color3.fromRGB(255, 100, 100)

type TFilterOption = LogViewerViewModel.TFilterOption
type TViewData = LogViewerViewModel.TLogViewerViewData
type TLogEntryViewData = LogEntryViewModel.TLogEntryViewData

type TLogViewerScreenViewProps = {
	viewData: TViewData,
	activeLevel: string,
	activeCategory: string,
	activeContext: string,
	onSelectLevel: (string) -> (),
	onSelectCategory: (string) -> (),
	onSelectContext: (string) -> (),
	onClearAll: () -> (),
	onClearFiltered: () -> (),
}

local function createFilterRow(
	title: string,
	layoutOrder: number,
	options: { TFilterOption },
	activeValue: string,
	onSelect: (string) -> ()
): any
	local children: { [string]: any } = {
		Label = e("TextLabel", {
			Size = UDim2.fromOffset(FILTER_LABEL_WIDTH, FILTER_ROW_HEIGHT),
			BackgroundTransparency = 1,
			Text = title,
			TextColor3 = Color3.fromRGB(130, 130, 145),
			TextSize = 12,
			Font = Enum.Font.GothamBold,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 1,
		}),
		Buttons = e("ScrollingFrame", {
			Size = UDim2.new(1, -FILTER_LABEL_WIDTH, 1, 0),
			Position = UDim2.fromOffset(FILTER_LABEL_WIDTH, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AutomaticCanvasSize = Enum.AutomaticSize.X,
			CanvasSize = UDim2.new(),
			ScrollingDirection = Enum.ScrollingDirection.X,
			ScrollBarThickness = 0,
			LayoutOrder = 2,
		}, (function()
			local buttonChildren: { [string]: any } = {
				Layout = e("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 4),
				}),
				Padding = e("UIPadding", {
					PaddingLeft = UDim.new(0, 2),
					PaddingRight = UDim.new(0, 8),
				}),
			}
			for index, option in ipairs(options) do
				local isActive = option.value == activeValue
				local buttonText = string.format("%s (%d)", option.label, option.count)
				local width = math.clamp(42 + string.len(buttonText) * 6, 80, 180)
				buttonChildren["Option_" .. option.value] = e("TextButton", {
					Size = UDim2.fromOffset(width, FILTER_ROW_HEIGHT - 4),
					BackgroundColor3 = if isActive then TAB_ACTIVE_COLOR else TAB_INACTIVE_COLOR,
					BorderSizePixel = 0,
					Text = buttonText,
					TextColor3 = if isActive then TAB_TEXT_ACTIVE else TAB_TEXT_INACTIVE,
					TextSize = 12,
					Font = Enum.Font.GothamBold,
					LayoutOrder = index,
					[React.Event.Activated] = function()
						onSelect(option.value)
					end,
				}, {
					UICorner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
				})
			end
			return buttonChildren
		end)()),
	}
	return e("Frame", {
		Size = UDim2.new(1, 0, 0, FILTER_ROW_HEIGHT),
		BackgroundColor3 = HEADER_COLOR,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
	}, children)
end

local function renderDetailPopup(vd: TLogEntryViewData, onClose: () -> ()): any
	local bodyChildren: { [string]: any } = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
		Padding = e("UIPadding", {
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
			PaddingTop = UDim.new(0, 10),
			PaddingBottom = UDim.new(0, 10),
		}),
	}

	local order = 1

	bodyChildren["LabelRow"] = e("TextLabel", {
		Text = vd.label,
		Size = UDim2.new(1, 0, 0, 16),
		BackgroundTransparency = 1,
		TextColor3 = POPUP_TEXT_DIM,
		TextSize = 11,
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = false,
		LayoutOrder = order,
	})
	order += 1

	bodyChildren["MessageRow"] = e("TextLabel", {
		Text = vd.message,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		TextColor3 = POPUP_TEXT_BODY,
		TextSize = 13,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		LayoutOrder = order,
	})
	order += 1

	if vd.errType then
		bodyChildren["ErrTypeRow"] = e("TextLabel", {
			Text = "Error type: " .. vd.errType,
			Size = UDim2.new(1, 0, 0, 14),
			BackgroundTransparency = 1,
			TextColor3 = Color3.fromRGB(255, 100, 100),
			TextSize = 11,
			Font = Enum.Font.Gotham,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = order,
		})
		order += 1
	end

	bodyChildren["Divider1"] = e("Frame", {
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = POPUP_BORDER,
		BorderSizePixel = 0,
		LayoutOrder = order,
	})
	order += 1

	if vd.hasData and vd.dataDisplay then
		bodyChildren["DataHeader"] = e("TextLabel", {
			Text = "DATA",
			Size = UDim2.new(1, 0, 0, 14),
			BackgroundTransparency = 1,
			TextColor3 = POPUP_TEXT_DIM,
			TextSize = 10,
			Font = Enum.Font.GothamBold,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = order,
		})
		order += 1

		bodyChildren["DataContent"] = e("TextLabel", {
			Text = vd.dataDisplay,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			TextColor3 = POPUP_TEXT_BODY,
			TextSize = 12,
			Font = Enum.Font.Code,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true,
			RichText = false,
			LayoutOrder = order,
		})
		order += 1
	end

	if vd.hasTraceback and vd.traceback then
		if vd.hasData then
			bodyChildren["Divider2"] = e("Frame", {
				Size = UDim2.new(1, 0, 0, 1),
				BackgroundColor3 = POPUP_BORDER,
				BorderSizePixel = 0,
				LayoutOrder = order,
			})
			order += 1
		end

		bodyChildren["TraceHeader"] = e("TextLabel", {
			Text = "TRACEBACK",
			Size = UDim2.new(1, 0, 0, 14),
			BackgroundTransparency = 1,
			TextColor3 = POPUP_TEXT_DIM,
			TextSize = 10,
			Font = Enum.Font.GothamBold,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = order,
		})
		order += 1

		bodyChildren["TraceContent"] = e("TextLabel", {
			Text = vd.traceback,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			TextColor3 = Color3.fromRGB(255, 160, 100),
			TextSize = 11,
			Font = Enum.Font.Code,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true,
			RichText = false,
			LayoutOrder = order,
		})
	end

	-- Backdrop is a full-screen TextButton that intercepts all input and closes on click.
	-- Panel sits on top at a high ZIndex. Both are direct children of the root ScreenGui
	-- frame (outside the ScrollingFrame) so clipping cannot affect them.
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0, 0),
		BackgroundTransparency = 1,
		ZIndex = 500,
	}, {
		Backdrop = e("TextButton", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			BackgroundTransparency = 0.5,
			BorderSizePixel = 0,
			Text = "",
			ZIndex = 500,
			[React.Event.Activated] = onClose,
		}),

		Panel = e("Frame", {
			Size = UDim2.fromScale(0.5, 0.55),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = POPUP_BG,
			BorderSizePixel = 0,
			ZIndex = 501,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
			Stroke = e("UIStroke", {
				Color = POPUP_BORDER,
				Thickness = 1,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),

			Header = e("Frame", {
				Size = UDim2.new(1, 0, 0, 36),
				BackgroundColor3 = POPUP_HEADER_BG,
				BorderSizePixel = 0,
				ZIndex = 502,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
				-- Covers the rounded bottom corners so only the top corners are rounded
				BottomFill = e("Frame", {
					Size = UDim2.fromScale(1, 0.5),
					Position = UDim2.fromScale(0.5, 1),
					AnchorPoint = Vector2.new(0.5, 1),
					BackgroundColor3 = POPUP_HEADER_BG,
					BorderSizePixel = 0,
					ZIndex = 502,
				}),
				Title = e("TextLabel", {
					Size = UDim2.fromScale(0.6, 1),
					Position = UDim2.fromScale(0, 0.5),
					AnchorPoint = Vector2.new(0, 0.5),
					BackgroundTransparency = 1,
					Text = "Log Entry Detail",
					TextColor3 = POPUP_TEXT_BODY,
					TextSize = 14,
					Font = Enum.Font.GothamBold,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Center,
					ZIndex = 502,
				}),
				LevelBadge = e("TextLabel", {
					Size = UDim2.fromOffset(64, 20),
					Position = UDim2.new(1, -100, 0.5, 0),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Text = vd.levelTag,
					TextColor3 = vd.levelColor,
					TextSize = 12,
					Font = Enum.Font.GothamBold,
					TextXAlignment = Enum.TextXAlignment.Center,
					ZIndex = 502,
				}),
				CloseButton = e("TextButton", {
					Size = UDim2.fromOffset(28, 20),
					Position = UDim2.new(1, -24, 0.5, 0),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 = POPUP_CLOSE_BG,
					BorderSizePixel = 0,
					Text = "X",
					TextColor3 = POPUP_CLOSE_TEXT,
					TextSize = 12,
					Font = Enum.Font.GothamBold,
					ZIndex = 502,
					[React.Event.Activated] = onClose,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
				}),
			}),

			Body = e("ScrollingFrame", {
				Size = UDim2.new(1, 0, 1, -36),
				Position = UDim2.fromOffset(0, 36),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollBarThickness = 4,
				ScrollBarImageColor3 = POPUP_BORDER,
				ClipsDescendants = true,
				ZIndex = 502,
			}, bodyChildren),
		}),
	})
end

local function LogViewerScreenView(props: TLogViewerScreenViewProps)
	local openViewData, setOpenViewData = useState(nil :: TLogEntryViewData?)

	local rowChildren: { [string]: any } = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 2),
		}),
		Padding = e("UIPadding", {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 4),
		}),
	}

	for i, entry in ipairs(props.viewData.filteredLogs) do
		local key = "Entry_" .. tostring(entry.id)
		local vd = LogEntryViewModel.fromEntry(entry)
		rowChildren[key] = e(LogEntryRow, {
			ViewData = vd,
			LayoutOrder = i,
			OnOpenPopup = function(clickedVd: TLogEntryViewData)
				setOpenViewData(clickedVd)
			end,
		})
	end

	local scrollTop = HEADER_HEIGHT + FILTER_ROW_HEIGHT * 3

	return e("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		Modal = true,
		AutoButtonColor = false,
	}, {
		Panel = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = BACKGROUND_COLOR,
			BorderSizePixel = 0,
		}, {
			Header = e("Frame", {
				Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
				BackgroundColor3 = HEADER_COLOR,
				BorderSizePixel = 0,
			}, {
				Title = e("TextLabel", {
					Size = UDim2.new(1, -256, 1, 0),
					Position = UDim2.fromOffset(12, 0),
					BackgroundTransparency = 1,
					Text = "Log Viewer",
					TextColor3 = Color3.fromRGB(220, 220, 220),
					TextSize = 16,
					Font = Enum.Font.GothamBold,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Center,
				}),
				ClearFilteredButton = e("TextButton", {
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -96, 0.5, 0),
					Size = UDim2.fromOffset(116, 24),
					BackgroundColor3 = CLEAR_FILTERED_BUTTON_COLOR,
					BorderSizePixel = 0,
					Text = "Clear Filtered",
					TextColor3 = CLEAR_FILTERED_TEXT_COLOR,
					TextSize = 13,
					Font = Enum.Font.GothamBold,
					[React.Event.Activated] = props.onClearFiltered,
				}, {
					UICorner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
				}),
				ClearButton = e("TextButton", {
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -8, 0.5, 0),
					Size = UDim2.fromOffset(80, 24),
					BackgroundColor3 = CLEAR_BUTTON_COLOR,
					BorderSizePixel = 0,
					Text = "Clear",
					TextColor3 = CLEAR_TEXT_COLOR,
					TextSize = 14,
					Font = Enum.Font.GothamBold,
					[React.Event.Activated] = props.onClearAll,
				}, {
					UICorner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
				}),
			}),
			Filters = e("Frame", {
				Position = UDim2.fromOffset(0, HEADER_HEIGHT),
				Size = UDim2.new(1, 0, 0, FILTER_ROW_HEIGHT * 3),
				BackgroundColor3 = HEADER_COLOR,
				BorderSizePixel = 0,
			}, {
				Layout = e("UIListLayout", {
					FillDirection = Enum.FillDirection.Vertical,
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				LevelRow = createFilterRow("Level", 1, props.viewData.levelOptions, props.activeLevel, props.onSelectLevel),
				CategoryRow = createFilterRow(
					"Category",
					2,
					props.viewData.categoryOptions,
					props.activeCategory,
					props.onSelectCategory
				),
				ContextRow = createFilterRow(
					"Context",
					3,
					props.viewData.contextOptions,
					props.activeContext,
					props.onSelectContext
				),
			}),
			ScrollContainer = e("ScrollingFrame", {
				Position = UDim2.fromOffset(0, scrollTop),
				Size = UDim2.new(1, 0, 1, -scrollTop),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				CanvasSize = UDim2.new(),
				ScrollBarThickness = 4,
				ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100),
				ClipsDescendants = true,
			}, rowChildren),
		}),

		-- Rendered outside Panel so it is not clipped by the ScrollingFrame.
		DetailPopup = if openViewData ~= nil then renderDetailPopup(openViewData, function()
			setOpenViewData(nil)
		end) else nil,
	})
end

return LogViewerScreenView
