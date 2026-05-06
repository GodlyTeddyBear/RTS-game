--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local StudioComponents = require(ReplicatedStorage.Packages.StudioComponents)
local SectionPanel = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.SectionPanel)

type TFolderToolsPanelProps = {
	SectionId: string,
	IsExpanded: boolean,
	OnExpandedChanged: (sectionId: string, isExpanded: boolean) -> (),
	FolderName: string,
	FolderPresets: { string },
	OnFolderNameChanged: (folderName: string) -> (),
	OnUseFolderPreset: (folderName: string) -> (),
	OnWrapSelection: () -> (),
}

local function FolderToolsPanel(props: TFolderToolsPanelProps)
	local children: { [string]: React.ReactNode } = {
		Input = React.createElement(StudioComponents.TextInput, {
			ClearTextOnFocus = false,
			LayoutOrder = 1,
			OnChanged = props.OnFolderNameChanged,
			PlaceholderText = "Folder name...",
			Size = UDim2.new(1, 0, 0, 24),
			Text = props.FolderName,
		}),
		Action = React.createElement(StudioComponents.MainButton, {
			LayoutOrder = 2,
			OnActivated = props.OnWrapSelection,
			Size = UDim2.new(1, 0, 0, 24),
			Text = "Wrap Selection In Folder",
		}),
	}

	if #props.FolderPresets > 0 then
		children.PresetLabel = React.createElement(StudioComponents.Label, {
			LayoutOrder = 3,
			Size = UDim2.new(1, 0, 0, 24),
			Text = "Preset Folder Names",
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
		})

		for index, presetName in ipairs(props.FolderPresets) do
			children["Preset" .. tostring(index)] = React.createElement(StudioComponents.Button, {
				LayoutOrder = 3 + index,
				OnActivated = function()
					props.OnUseFolderPreset(presetName)
				end,
				Size = UDim2.new(1, 0, 0, 24),
				Text = presetName,
			})
		end
	end

	return React.createElement(SectionPanel, {
		SectionId = props.SectionId,
		LayoutOrder = 2,
		Title = "Folder Tools",
		IsExpanded = props.IsExpanded,
		OnExpandedChanged = props.OnExpandedChanged,
	}, children)
end

return FolderToolsPanel
