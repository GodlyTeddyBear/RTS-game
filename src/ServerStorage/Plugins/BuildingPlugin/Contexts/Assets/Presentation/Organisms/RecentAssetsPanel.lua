--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local StudioComponents = require(ReplicatedStorage.Packages.StudioComponents)
local SectionPanel = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.SectionPanel)

type TRecentAssetsPanelProps = {
	SectionId: string,
	IsExpanded: boolean,
	OnExpandedChanged: (sectionId: string, isExpanded: boolean) -> (),
	RecentAssets: { string },
	OnInsertAsset: (assetPath: string) -> (),
}

local function RecentAssetsPanel(props: TRecentAssetsPanelProps)
	local children: { [string]: React.ReactNode } = {}

	if #props.RecentAssets == 0 then
		children.Empty = React.createElement(StudioComponents.Label, {
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, 24),
			Text = "No recent assets yet.",
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
		})
	else
		for index, assetPath in ipairs(props.RecentAssets) do
			children["Asset" .. tostring(index)] = React.createElement(StudioComponents.Button, {
				LayoutOrder = index,
				OnActivated = function()
					props.OnInsertAsset(assetPath)
				end,
				Size = UDim2.new(1, 0, 0, 24),
				Text = assetPath,
			})
		end
	end

	return React.createElement(SectionPanel, {
		SectionId = props.SectionId,
		LayoutOrder = 3,
		Title = "Recent Assets",
		IsExpanded = props.IsExpanded,
		OnExpandedChanged = props.OnExpandedChanged,
	}, children)
end

return RecentAssetsPanel
