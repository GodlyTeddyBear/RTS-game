--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local StudioComponents = require(ReplicatedStorage.Packages.StudioComponents)
local SectionPanel = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.SectionPanel)
local TextBlock = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.TextBlock)

type TAssetRootPanelProps = {
	SectionId: string,
	IsExpanded: boolean,
	OnExpandedChanged: (sectionId: string, isExpanded: boolean) -> (),
	AssetRootExists: boolean,
	AssetRootStatusText: string,
	OnCreateAssetRoot: () -> (),
}

local function AssetRootPanel(props: TAssetRootPanelProps)
	local children: { [string]: React.ReactNode } = {
		Status = React.createElement(TextBlock, {
			LayoutOrder = 1,
			Text = props.AssetRootStatusText,
		}),
	}

	if not props.AssetRootExists then
		children.CreateRoot = React.createElement(StudioComponents.MainButton, {
			LayoutOrder = 2,
			OnActivated = props.OnCreateAssetRoot,
			Size = UDim2.new(1, 0, 0, 24),
			Text = "Create Asset Root",
		})
	end

	return React.createElement(SectionPanel, {
		SectionId = props.SectionId,
		LayoutOrder = 1,
		Title = "Asset Root",
		IsExpanded = props.IsExpanded,
		OnExpandedChanged = props.OnExpandedChanged,
	}, children)
end

return AssetRootPanel
