--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local Text = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Text)
local LogEntryViewModel = require(script.Parent.Parent.Parent.Application.ViewModels.LogEntryViewModel)

export type TLogEntryRowProps = {
	ViewData: LogEntryViewModel.TLogEntryViewData,
	LayoutOrder: number?,
	OnOpenPopup: ((vd: LogEntryViewModel.TLogEntryViewData) -> ())?,
}

local ROW_HEIGHT = 22
local TIME_WIDTH = 60
local LEVEL_WIDTH = 70
local LABEL_WIDTH = 220
local FONT_SIZE = 13

local INDICATOR_COLOR = Color3.fromRGB(100, 200, 255)

local function LogEntryRow(props: TLogEntryRowProps)
	local vd = props.ViewData

	local hasExtra = vd.hasData or vd.hasTraceback
	local indicatorOffset = if hasExtra then 26 else 0

	return e("TextButton", {
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = props.LayoutOrder,
		[React.Event.Activated] = if hasExtra and props.OnOpenPopup then function()
			props.OnOpenPopup(vd)
		end else nil,
	}, {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),

		Time = e(Text, {
			Text = vd.displayTime,
			Size = UDim2.new(0, TIME_WIDTH, 1, 0),
			TextColor3 = Color3.fromRGB(120, 120, 120),
			TextSize = FONT_SIZE,
			LayoutOrder = 1,
		}),

		Level = e(Text, {
			Text = vd.levelTag,
			Size = UDim2.new(0, LEVEL_WIDTH, 1, 0),
			TextColor3 = vd.levelColor,
			TextSize = FONT_SIZE,
			LayoutOrder = 2,
		}),

		Label = e(Text, {
			Text = vd.label,
			Size = UDim2.new(0, LABEL_WIDTH, 1, 0),
			TextColor3 = Color3.fromRGB(220, 220, 220),
			TextSize = FONT_SIZE,
			LayoutOrder = 3,
		}),

		Message = e(Text, {
			Text = vd.message,
			Size = UDim2.new(1, -(TIME_WIDTH + LEVEL_WIDTH + LABEL_WIDTH + 18 + indicatorOffset), 1, 0),
			TextColor3 = Color3.fromRGB(180, 180, 180),
			TextSize = FONT_SIZE,
			TextWrapped = false,
			LayoutOrder = 4,
		}),

		Indicator = if hasExtra then e("TextLabel", {
			Text = "[+]",
			Size = UDim2.new(0, 20, 1, 0),
			TextColor3 = INDICATOR_COLOR,
			TextSize = FONT_SIZE,
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			LayoutOrder = 5,
		}) else nil,
	})
end

return LogEntryRow
