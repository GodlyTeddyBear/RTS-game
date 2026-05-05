--!strict

local Constants = require(script.Parent.Constants)

export type TSectionRefs = {
	Frame: Frame,
	Body: Frame,
	ToggleButton: TextButton,
}

export type TUIRefs = {
	Root: Frame,
	ScrollingFrame: ScrollingFrame,
	ListLayout: UIListLayout,
	StatusLabel: TextLabel,
	SelectionSummaryLabel: TextLabel,
	AssetSearchBox: TextBox,
	AssetNameBox: TextBox,
	AssetListFrame: Frame,
	AssetListLayout: UIListLayout,
	RecentAssetsFrame: Frame,
	RecentAssetsLayout: UIListLayout,
	FolderNameBox: TextBox,
	FolderPresetButtonsFrame: Frame,
	FolderPresetButtonsLayout: UIGridLayout,
	PresetSettingsBox: TextBox,
	SelectionButtonsFrame: Frame,
	PropertyButtonsFrame: Frame,
	EnsureAssetRootButton: TextButton,
	SaveSelectionButton: TextButton,
	WrapSelectionButton: TextButton,
	SavePresetsButton: TextButton,
	DuplicateSelectionButton: TextButton,
	AnchoredOnButton: TextButton,
	AnchoredOffButton: TextButton,
	CollideOnButton: TextButton,
	CollideOffButton: TextButton,
	QueryOnButton: TextButton,
	QueryOffButton: TextButton,
	TouchOnButton: TextButton,
	TouchOffButton: TextButton,
	Transparency0Button: TextButton,
	Transparency25Button: TextButton,
	Transparency50Button: TextButton,
	Transparency100Button: TextButton,
	MaterialPlasticButton: TextButton,
	MaterialConcreteButton: TextButton,
	MaterialMetalButton: TextButton,
	ColorStoneButton: TextButton,
	ColorWhiteButton: TextButton,
	ColorBlackButton: TextButton,
	SectionRefs: { [string]: TSectionRefs },
}

local PluginUI = {}

local function bindLayoutHeight(frame: Frame, layout: UIGridLayout)
	local function updateHeight()
		frame.Size = UDim2.new(1, 0, 0, layout.AbsoluteContentSize.Y)
	end

	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateHeight)
	updateHeight()
end

local function createCorner(radius: number): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	return corner
end

local function createStroke(parent: Instance, color: Color3)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
end

local function createTextButton(name: string, text: string, parent: Instance, isAccent: boolean?): TextButton
	local theme = Constants.Theme

	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = UDim2.new(1, 0, 0, 28)
	button.AutoButtonColor = true
	button.Text = text
	button.TextColor3 = theme.Text
	button.TextSize = 14
	button.Font = Enum.Font.Gotham
	button.BackgroundColor3 = if isAccent then theme.Accent else theme.PanelAlt
	button.BorderSizePixel = 0
	button.Parent = parent

	createCorner(6).Parent = button
	createStroke(button, if isAccent then theme.AccentAlt else theme.Border)

	return button
end

local function createTextLabel(name: string, text: string, parent: Instance, size: UDim2, textColor: Color3?): TextLabel
	local theme = Constants.Theme

	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = size
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.TextColor3 = textColor or theme.Text
	label.TextSize = 14
	label.Font = Enum.Font.Gotham
	label.Parent = parent

	return label
end

local function createTextBox(name: string, placeholderText: string, parent: Instance): TextBox
	local theme = Constants.Theme

	local textBox = Instance.new("TextBox")
	textBox.Name = name
	textBox.Size = UDim2.new(1, 0, 0, 30)
	textBox.BackgroundColor3 = theme.Input
	textBox.BorderSizePixel = 0
	textBox.Text = ""
	textBox.PlaceholderText = placeholderText
	textBox.PlaceholderColor3 = theme.MutedText
	textBox.TextColor3 = theme.Text
	textBox.TextSize = 14
	textBox.Font = Enum.Font.Gotham
	textBox.ClearTextOnFocus = false
	textBox.Parent = parent

	createCorner(6).Parent = textBox
	createStroke(textBox, theme.Border)

	return textBox
end

local function createSection(name: string, title: string, parent: Instance): TSectionRefs
	local theme = Constants.Theme

	local frame = Instance.new("Frame")
	frame.Name = name .. "Section"
	frame.Size = UDim2.new(1, 0, 0, 60)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.BackgroundColor3 = theme.Panel
	frame.BorderSizePixel = 0
	frame.Parent = parent

	createCorner(8).Parent = frame
	createStroke(frame, theme.Border)

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.Parent = frame

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 8)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = frame

	local toggleButton = Instance.new("TextButton")
	toggleButton.Name = "Toggle"
	toggleButton.Size = UDim2.new(1, 0, 0, 28)
	toggleButton.AutoButtonColor = true
	toggleButton.BackgroundColor3 = theme.PanelAlt
	toggleButton.BorderSizePixel = 0
	toggleButton.Font = Enum.Font.GothamBold
	toggleButton.TextColor3 = theme.Text
	toggleButton.TextSize = 14
	toggleButton.TextXAlignment = Enum.TextXAlignment.Left
	toggleButton.Text = "[-] " .. title
	toggleButton.Parent = frame

	createCorner(6).Parent = toggleButton
	createStroke(toggleButton, theme.Border)

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.Size = UDim2.new(1, 0, 0, 0)
	body.AutomaticSize = Enum.AutomaticSize.Y
	body.BackgroundTransparency = 1
	body.Parent = frame

	local bodyLayout = Instance.new("UIListLayout")
	bodyLayout.Padding = UDim.new(0, 8)
	bodyLayout.SortOrder = Enum.SortOrder.LayoutOrder
	bodyLayout.Parent = body

	return {
		Frame = frame,
		Body = body,
		ToggleButton = toggleButton,
	}
end

function PluginUI.Build(widget: DockWidgetPluginGui): TUIRefs
	local theme = Constants.Theme

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = theme.Background
	root.BorderSizePixel = 0
	root.Parent = widget

	local scrollingFrame = Instance.new("ScrollingFrame")
	scrollingFrame.Name = "ScrollingFrame"
	scrollingFrame.Size = UDim2.new(1, 0, 1, -36)
	scrollingFrame.CanvasSize = UDim2.fromOffset(0, 0)
	scrollingFrame.ScrollBarThickness = 6
	scrollingFrame.BackgroundTransparency = 1
	scrollingFrame.BorderSizePixel = 0
	scrollingFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scrollingFrame.Parent = root

	local scrollingPadding = Instance.new("UIPadding")
	scrollingPadding.PaddingTop = UDim.new(0, 12)
	scrollingPadding.PaddingBottom = UDim.new(0, 12)
	scrollingPadding.PaddingLeft = UDim.new(0, 12)
	scrollingPadding.PaddingRight = UDim.new(0, 12)
	scrollingPadding.Parent = scrollingFrame

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 10)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = scrollingFrame

	local statusLabel = createTextLabel("StatusLabel", "Ready.", root, UDim2.new(1, -24, 0, 28), theme.MutedText)
	statusLabel.Position = UDim2.new(0, 12, 1, -30)
	statusLabel.TextYAlignment = Enum.TextYAlignment.Center
	statusLabel.TextWrapped = false

	local overviewSection = createSection("Overview", "Overview", scrollingFrame)
	local selectionSummaryLabel = createTextLabel(
		"SelectionSummaryLabel",
		"Selection: 0",
		overviewSection.Body,
		UDim2.new(1, 0, 0, 40),
		theme.MutedText
	)

	local librarySection = createSection("Library", "Library", scrollingFrame)
	local assetSearchBox = createTextBox("AssetSearchBox", "Search saved assets...", librarySection.Body)
	local assetNameBox = createTextBox("AssetNameBox", "Optional asset name for save...", librarySection.Body)
	local libraryButtonsFrame = Instance.new("Frame")
	libraryButtonsFrame.Name = "LibraryButtonsFrame"
	libraryButtonsFrame.Size = UDim2.new(1, 0, 0, 28)
	libraryButtonsFrame.BackgroundTransparency = 1
	libraryButtonsFrame.Parent = librarySection.Body

	local libraryButtonsLayout = Instance.new("UIListLayout")
	libraryButtonsLayout.Parent = libraryButtonsFrame
	libraryButtonsLayout.Padding = UDim.new(0, 8)
	libraryButtonsLayout.FillDirection = Enum.FillDirection.Horizontal
	libraryButtonsLayout.SortOrder = Enum.SortOrder.LayoutOrder

	local ensureRootButton = createTextButton("EnsureAssetRootButton", "Create Asset Root", libraryButtonsFrame, false)
	ensureRootButton.Size = UDim2.new(0.5, -4, 1, 0)

	local saveSelectionButton = createTextButton("SaveSelectionButton", "Save Selection", libraryButtonsFrame, true)
	saveSelectionButton.Size = UDim2.new(0.5, -4, 1, 0)

	createTextLabel("RecentAssetsLabel", "Recent Assets", librarySection.Body, UDim2.new(1, 0, 0, 18))

	local recentAssetsFrame = Instance.new("Frame")
	recentAssetsFrame.Name = "RecentAssetsFrame"
	recentAssetsFrame.Size = UDim2.new(1, 0, 0, 0)
	recentAssetsFrame.AutomaticSize = Enum.AutomaticSize.Y
	recentAssetsFrame.BackgroundTransparency = 1
	recentAssetsFrame.Parent = librarySection.Body

	local recentAssetsLayout = Instance.new("UIListLayout")
	recentAssetsLayout.Padding = UDim.new(0, 6)
	recentAssetsLayout.Parent = recentAssetsFrame

	createTextLabel("AssetListLabel", "Library Assets", librarySection.Body, UDim2.new(1, 0, 0, 18))

	local assetListFrame = Instance.new("Frame")
	assetListFrame.Name = "AssetListFrame"
	assetListFrame.Size = UDim2.new(1, 0, 0, 0)
	assetListFrame.AutomaticSize = Enum.AutomaticSize.Y
	assetListFrame.BackgroundTransparency = 1
	assetListFrame.Parent = librarySection.Body

	local assetListLayout = Instance.new("UIListLayout")
	assetListLayout.Padding = UDim.new(0, 6)
	assetListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	assetListLayout.Parent = assetListFrame

	local foldersSection = createSection("Folders", "Folders", scrollingFrame)
	local folderNameBox = createTextBox("FolderNameBox", "Folder name...", foldersSection.Body)

	local folderButtonsFrame = Instance.new("Frame")
	folderButtonsFrame.Name = "FolderButtonsFrame"
	folderButtonsFrame.Size = UDim2.new(1, 0, 0, 28)
	folderButtonsFrame.BackgroundTransparency = 1
	folderButtonsFrame.Parent = foldersSection.Body

	local wrapSelectionButton = createTextButton("WrapSelectionButton", "Wrap Selection In Folder", folderButtonsFrame, true)
	wrapSelectionButton.Size = UDim2.new(1, 0, 1, 0)

	createTextLabel("PresetLabel", "Preset Folder Names", foldersSection.Body, UDim2.new(1, 0, 0, 18))

	local folderPresetButtonsFrame = Instance.new("Frame")
	folderPresetButtonsFrame.Name = "FolderPresetButtonsFrame"
	folderPresetButtonsFrame.Size = UDim2.new(1, 0, 0, 0)
	folderPresetButtonsFrame.AutomaticSize = Enum.AutomaticSize.Y
	folderPresetButtonsFrame.BackgroundTransparency = 1
	folderPresetButtonsFrame.Parent = foldersSection.Body

	local folderPresetButtonsLayout = Instance.new("UIGridLayout")
	folderPresetButtonsLayout.CellPadding = UDim2.fromOffset(6, 6)
	folderPresetButtonsLayout.CellSize = UDim2.new(0.5, -3, 0, 28)
	folderPresetButtonsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	folderPresetButtonsLayout.Parent = folderPresetButtonsFrame
	bindLayoutHeight(folderPresetButtonsFrame, folderPresetButtonsLayout)

	local settingsSection = createSection("Settings", "Settings", scrollingFrame)
	local presetSettingsBox = createTextBox("PresetSettingsBox", "Comma-separated preset names...", settingsSection.Body)
	local savePresetsButton = createTextButton("SavePresetsButton", "Save Presets", settingsSection.Body, true)

	local selectionSection = createSection("Selection", "Selection", scrollingFrame)
	local selectionButtonsFrame = Instance.new("Frame")
	selectionButtonsFrame.Name = "SelectionButtonsFrame"
	selectionButtonsFrame.Size = UDim2.new(1, 0, 0, 0)
	selectionButtonsFrame.AutomaticSize = Enum.AutomaticSize.Y
	selectionButtonsFrame.BackgroundTransparency = 1
	selectionButtonsFrame.Parent = selectionSection.Body

	local selectionButtonsLayout = Instance.new("UIGridLayout")
	selectionButtonsLayout.CellPadding = UDim2.fromOffset(6, 6)
	selectionButtonsLayout.CellSize = UDim2.new(0.5, -3, 0, 28)
	selectionButtonsLayout.Parent = selectionButtonsFrame
	bindLayoutHeight(selectionButtonsFrame, selectionButtonsLayout)

	local duplicateSelectionButton = createTextButton("DuplicateSelectionButton", "Duplicate", selectionButtonsFrame, false)

	local propertiesSection = createSection("Properties", "Properties", scrollingFrame)
	local propertyButtonsFrame = Instance.new("Frame")
	propertyButtonsFrame.Name = "PropertyButtonsFrame"
	propertyButtonsFrame.Size = UDim2.new(1, 0, 0, 0)
	propertyButtonsFrame.AutomaticSize = Enum.AutomaticSize.Y
	propertyButtonsFrame.BackgroundTransparency = 1
	propertyButtonsFrame.Parent = propertiesSection.Body

	local propertyButtonsLayout = Instance.new("UIGridLayout")
	propertyButtonsLayout.CellPadding = UDim2.fromOffset(6, 6)
	propertyButtonsLayout.CellSize = UDim2.new(0.5, -3, 0, 28)
	propertyButtonsLayout.Parent = propertyButtonsFrame
	bindLayoutHeight(propertyButtonsFrame, propertyButtonsLayout)

	local propertyButtonSpecs = {
		{ Name = "AnchoredOnButton", Text = "Anchored On" },
		{ Name = "AnchoredOffButton", Text = "Anchored Off" },
		{ Name = "CollideOnButton", Text = "CanCollide On" },
		{ Name = "CollideOffButton", Text = "CanCollide Off" },
		{ Name = "QueryOnButton", Text = "CanQuery On" },
		{ Name = "QueryOffButton", Text = "CanQuery Off" },
		{ Name = "TouchOnButton", Text = "CanTouch On" },
		{ Name = "TouchOffButton", Text = "CanTouch Off" },
		{ Name = "Transparency0Button", Text = "Transparency 0" },
		{ Name = "Transparency25Button", Text = "Transparency .25" },
		{ Name = "Transparency50Button", Text = "Transparency .50" },
		{ Name = "Transparency100Button", Text = "Transparency 1" },
		{ Name = "MaterialPlasticButton", Text = "SmoothPlastic" },
		{ Name = "MaterialConcreteButton", Text = "Concrete" },
		{ Name = "MaterialMetalButton", Text = "Metal" },
		{ Name = "ColorStoneButton", Text = "Stone Grey" },
		{ Name = "ColorWhiteButton", Text = "White" },
		{ Name = "ColorBlackButton", Text = "Black" },
	}

	local propertyButtonsByName: { [string]: TextButton } = {}

	for _, propertyButtonSpec in propertyButtonSpecs do
		propertyButtonsByName[propertyButtonSpec.Name] =
			createTextButton(propertyButtonSpec.Name, propertyButtonSpec.Text, propertyButtonsFrame, false)
	end

	return {
		Root = root,
		ScrollingFrame = scrollingFrame,
		ListLayout = listLayout,
		StatusLabel = statusLabel,
		SelectionSummaryLabel = selectionSummaryLabel,
		AssetSearchBox = assetSearchBox,
		AssetNameBox = assetNameBox,
		AssetListFrame = assetListFrame,
		AssetListLayout = assetListLayout,
		RecentAssetsFrame = recentAssetsFrame,
		RecentAssetsLayout = recentAssetsLayout,
		FolderNameBox = folderNameBox,
		FolderPresetButtonsFrame = folderPresetButtonsFrame,
		FolderPresetButtonsLayout = folderPresetButtonsLayout,
		PresetSettingsBox = presetSettingsBox,
		SelectionButtonsFrame = selectionButtonsFrame,
		PropertyButtonsFrame = propertyButtonsFrame,
		EnsureAssetRootButton = ensureRootButton,
		SaveSelectionButton = saveSelectionButton,
		WrapSelectionButton = wrapSelectionButton,
		SavePresetsButton = savePresetsButton,
		DuplicateSelectionButton = duplicateSelectionButton,
		AnchoredOnButton = assert(propertyButtonsByName.AnchoredOnButton),
		AnchoredOffButton = assert(propertyButtonsByName.AnchoredOffButton),
		CollideOnButton = assert(propertyButtonsByName.CollideOnButton),
		CollideOffButton = assert(propertyButtonsByName.CollideOffButton),
		QueryOnButton = assert(propertyButtonsByName.QueryOnButton),
		QueryOffButton = assert(propertyButtonsByName.QueryOffButton),
		TouchOnButton = assert(propertyButtonsByName.TouchOnButton),
		TouchOffButton = assert(propertyButtonsByName.TouchOffButton),
		Transparency0Button = assert(propertyButtonsByName.Transparency0Button),
		Transparency25Button = assert(propertyButtonsByName.Transparency25Button),
		Transparency50Button = assert(propertyButtonsByName.Transparency50Button),
		Transparency100Button = assert(propertyButtonsByName.Transparency100Button),
		MaterialPlasticButton = assert(propertyButtonsByName.MaterialPlasticButton),
		MaterialConcreteButton = assert(propertyButtonsByName.MaterialConcreteButton),
		MaterialMetalButton = assert(propertyButtonsByName.MaterialMetalButton),
		ColorStoneButton = assert(propertyButtonsByName.ColorStoneButton),
		ColorWhiteButton = assert(propertyButtonsByName.ColorWhiteButton),
		ColorBlackButton = assert(propertyButtonsByName.ColorBlackButton),
		SectionRefs = {
			Overview = overviewSection,
			Library = librarySection,
			Folders = foldersSection,
			Selection = selectionSection,
			Properties = propertiesSection,
			Settings = settingsSection,
		},
	}
end

function PluginUI.SetSectionOpen(sectionRef: TSectionRefs, title: string, isOpen: boolean)
	sectionRef.Body.Visible = isOpen
	sectionRef.ToggleButton.Text = (if isOpen then "[-] " else "[+] ") .. title
end

function PluginUI.CreateRowButton(name: string, text: string, parent: Instance, isAccent: boolean?): TextButton
	return createTextButton(name, text, parent, isAccent)
end

function PluginUI.CreateMutedLabel(name: string, text: string, parent: Instance): TextLabel
	return createTextLabel(name, text, parent, UDim2.new(1, 0, 0, 18), Constants.Theme.MutedText)
end

return PluginUI
