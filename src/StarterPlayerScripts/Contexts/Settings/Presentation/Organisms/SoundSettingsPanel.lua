--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local Contexts = script.Parent.Parent.Parent.Parent
local Text = require(Contexts.App.Presentation.Atoms.Text)
local Colors = require(Contexts.App.Config.ColorTokens)

local VolumeStepControl = require(script.Parent.Parent.Molecules.VolumeStepControl)
local SoundEnabledToggle = require(script.Parent.Parent.Molecules.SoundEnabledToggle)

export type TSoundSettingsPanelProps = {
	ViewModel: any,
	OnSetVolume: (key: string, value: number) -> (),
	OnSetEnabled: (enabled: boolean) -> (),
}

local STEP = 0.1

local function _BuildRows(props: TSoundSettingsPanelProps)
	local children = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 10),
		}),
	}

	children.Toggle = e(SoundEnabledToggle, {
		Enabled = props.ViewModel.SoundEnabled,
		LayoutOrder = 1,
		OnToggle = function()
			props.OnSetEnabled(not props.ViewModel.SoundEnabled)
		end,
	})

	for index, row in props.ViewModel.SoundRows do
		children["Volume" .. row.Key] = e(VolumeStepControl, {
			Label = row.Label,
			Value = row.Value,
			DisplayValue = row.DisplayValue,
			LayoutOrder = index + 1,
			OnDecrease = function()
				props.OnSetVolume(row.Key, row.Value - STEP)
			end,
			OnIncrease = function()
				props.OnSetVolume(row.Key, row.Value + STEP)
			end,
		})
	end

	return children
end

local function SoundSettingsPanel(props: TSoundSettingsPanelProps)
	return e("Frame", {
		Size = UDim2.fromScale(0.62, 0.76),
		Position = UDim2.fromScale(0.5, 0.56),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Colors.Surface.Primary,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
	}, {
		Corner = e("UICorner", {
			CornerRadius = UDim.new(0, 8),
		}),
		Padding = e("UIPadding", {
			PaddingLeft = UDim.new(0, 20),
			PaddingRight = UDim.new(0, 20),
			PaddingTop = UDim.new(0, 18),
			PaddingBottom = UDim.new(0, 18),
		}),
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 12),
		}),
		Title = e(Text, {
			Text = "Sound",
			Size = UDim2.fromScale(1, 0.09),
			LayoutOrder = 1,
			Variant = "heading",
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			TextScaled = true,
		}),
		Controls = e("Frame", {
			Size = UDim2.fromScale(1, 0.86),
			LayoutOrder = 2,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, _BuildRows(props)),
	})
end

return SoundSettingsPanel
