--!strict

local Constants = require(script.Constants)
local PluginUI = require(script.PluginUI)
local SettingsStore = require(script.SettingsStore)
local HistoryAdapter = require(script.HistoryAdapter)
local SelectionHelper = require(script.SelectionHelper)
local AssetLibraryService = require(script.AssetLibraryService)
local FolderService = require(script.FolderService)
local PropertyService = require(script.PropertyService)
local SelectionActionService = require(script.SelectionActionService)

local toolbar = plugin:CreateToolbar(Constants.ToolbarName)
local toggleButton = toolbar:CreateButton(
	Constants.ButtonId,
	Constants.ButtonTooltip,
	Constants.ButtonIcon
)
toggleButton.ClickableWhenViewportHidden = true

local widgetInfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Right,
	false,
	false,
	Constants.DefaultWidgetSize.X,
	Constants.DefaultWidgetSize.Y,
	Constants.MinWidgetSize.X,
	Constants.MinWidgetSize.Y
)

local widget = plugin:CreateDockWidgetPluginGuiAsync(Constants.WidgetId, widgetInfo)
widget.Title = Constants.WidgetTitle

local settingsStore = SettingsStore.new(plugin)
local historyAdapter = HistoryAdapter.new()
local assetLibraryService = AssetLibraryService.new(settingsStore, historyAdapter)
local folderService = FolderService.new(historyAdapter)
local propertyService = PropertyService.new(historyAdapter)
local selectionActionService = SelectionActionService.new(historyAdapter)
local uiRefs = PluginUI.Build(widget)

local statusClearThread: thread? = nil
local refreshSelectionSummary = function() end
local refreshSectionState = function() end
local refreshRecentAssets = function() end
local refreshLibrary = function() end
local refreshFolderPresets = function() end

local SECTION_TITLES = {
	Library = "Library",
	Folders = "Folders",
	Selection = "Selection",
	Properties = "Properties",
	Settings = "Settings",
}

local MATERIAL_BUTTONS = {
	MaterialPlasticButton = Enum.Material.SmoothPlastic,
	MaterialConcreteButton = Enum.Material.Concrete,
	MaterialMetalButton = Enum.Material.Metal,
}

local COLOR_BUTTONS = {
	ColorStoneButton = { Color = Color3.fromRGB(163, 162, 165), Name = "Stone Grey" },
	ColorWhiteButton = { Color = Color3.fromRGB(242, 243, 243), Name = "White" },
	ColorBlackButton = { Color = Color3.fromRGB(17, 17, 17), Name = "Black" },
}

local function setStatus(message: string, isError: boolean?)
	uiRefs.StatusLabel.Text = message
	uiRefs.StatusLabel.TextColor3 = if isError then Constants.Theme.Danger else Constants.Theme.MutedText

	if statusClearThread ~= nil then
		task.cancel(statusClearThread)
	end

	statusClearThread = task.delay(Constants.StatusDuration, function()
		uiRefs.StatusLabel.Text = "Ready."
		uiRefs.StatusLabel.TextColor3 = Constants.Theme.MutedText
		statusClearThread = nil
	end)
end

local function applyResult(result)
	setStatus(result.Message, not result.Success)
	refreshLibrary()
	refreshSelectionSummary()

	if result.Success and result.Path ~= nil then
		settingsStore:PushRecentAsset(result.Path)
		refreshRecentAssets()
	end
end

refreshSelectionSummary = function()
	local selectionSummary = SelectionHelper.GetSummary()
	if selectionSummary.Count == 0 then
		uiRefs.SelectionSummaryLabel.Text = "Selection: 0"
		return
	end

	local previewNames = {}
	for index, selectionName in selectionSummary.Names do
		if index > 4 then
			break
		end
		table.insert(previewNames, selectionName)
	end

	local suffix = if selectionSummary.Count > #previewNames then " ..." else ""
	uiRefs.SelectionSummaryLabel.Text = ("Selection: %d\n%s%s"):format(
		selectionSummary.Count,
		table.concat(previewNames, ", "),
		suffix
	)
end

local function getSectionOpen(sectionName: string): boolean
	local sectionState = settingsStore:GetSectionState()

	if sectionName == "Library" then
		return sectionState.Library
	elseif sectionName == "Folders" then
		return sectionState.Folders
	elseif sectionName == "Selection" then
		return sectionState.Selection
	elseif sectionName == "Properties" then
		return sectionState.Properties
	elseif sectionName == "Settings" then
		return sectionState.Settings
	end

	return true
end

refreshSectionState = function()
	for sectionName, sectionRef in uiRefs.SectionRefs do
		if sectionName ~= "Overview" then
			local isOpen = getSectionOpen(sectionName)
			local sectionTitle = SECTION_TITLES[sectionName]
			if sectionTitle ~= nil then
				PluginUI.SetSectionOpen(sectionRef, sectionTitle, isOpen)
			end
		end
	end
end

local function clearChildren(parent: Instance)
	for _, child in parent:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIGridLayout") then
			child:Destroy()
		end
	end
end

refreshRecentAssets = function()
	clearChildren(uiRefs.RecentAssetsFrame)

	local recentAssets = settingsStore:GetRecentAssets()
	if #recentAssets == 0 then
		PluginUI.CreateMutedLabel("NoRecentAssetsLabel", "No recent assets yet.", uiRefs.RecentAssetsFrame)
		return
	end

	for _, assetPath in recentAssets do
		local assetButton = PluginUI.CreateRowButton("RecentAsset", assetPath, uiRefs.RecentAssetsFrame, false)
		assetButton.MouseButton1Click:Connect(function()
			applyResult(assetLibraryService:InsertAsset(assetPath))
		end)
	end
end

refreshLibrary = function()
	clearChildren(uiRefs.AssetListFrame)

	local assetEntries = assetLibraryService:GetAssetEntries(uiRefs.AssetSearchBox.Text)
	if #assetEntries == 0 then
		PluginUI.CreateMutedLabel("NoAssetsLabel", "No saved models matched the current search.", uiRefs.AssetListFrame)
		return
	end

	for _, assetEntry in assetEntries do
		local assetButton = PluginUI.CreateRowButton("AssetButton", assetEntry.Path, uiRefs.AssetListFrame, false)
		assetButton.MouseButton1Click:Connect(function()
			applyResult(assetLibraryService:InsertAsset(assetEntry.Path))
		end)
	end
end

refreshFolderPresets = function()
	clearChildren(uiRefs.FolderPresetButtonsFrame)

	for _, presetName in settingsStore:GetFolderPresets() do
		local presetButton = PluginUI.CreateRowButton("PresetButton", presetName, uiRefs.FolderPresetButtonsFrame, false)
		presetButton.MouseButton1Click:Connect(function()
			uiRefs.FolderNameBox.Text = presetName
			applyResult(folderService:WrapSelection(presetName))
		end)
	end
end

local function setWidgetEnabled(isEnabled: boolean)
	widget.Enabled = isEnabled
	toggleButton:SetActive(isEnabled)
	settingsStore:SetIsOpen(isEnabled)
end

local function toggleSection(sectionName: string)
	settingsStore:SetSectionState(sectionName, not getSectionOpen(sectionName))
	refreshSectionState()
end

local function parsePresetSettings(): { string }
	local presetNames = {}

	for presetName in string.gmatch(uiRefs.PresetSettingsBox.Text, "([^,]+)") do
		table.insert(presetNames, presetName)
	end

	return presetNames
end

local function connectSectionToggles()
	for sectionName, sectionRef in uiRefs.SectionRefs do
		if sectionName ~= "Overview" then
			sectionRef.ToggleButton.MouseButton1Click:Connect(function()
				toggleSection(sectionName)
			end)
		end
	end
end

local function connectOverview()
	uiRefs.EnsureAssetRootButton.MouseButton1Click:Connect(function()
		assetLibraryService:EnsureAssetRoot()
		setStatus("Ensured ReplicatedStorage." .. settingsStore:GetAssetRootName() .. ".", false)
		refreshLibrary()
	end)

	uiRefs.SaveSelectionButton.MouseButton1Click:Connect(function()
		applyResult(assetLibraryService:SaveSelectionToLibrary(uiRefs.AssetNameBox.Text))
	end)
end

local function connectFolderActions()
	uiRefs.WrapSelectionButton.MouseButton1Click:Connect(function()
		applyResult(folderService:WrapSelection(uiRefs.FolderNameBox.Text))
	end)
end

local function connectSelectionActions()
	uiRefs.DuplicateSelectionButton.MouseButton1Click:Connect(function()
		applyResult(selectionActionService:DuplicateSelection())
	end)
end

local function connectPropertyActions()
	local anchoredOnButton = uiRefs.AnchoredOnButton
	local anchoredOffButton = uiRefs.AnchoredOffButton
	local collideOnButton = uiRefs.CollideOnButton
	local collideOffButton = uiRefs.CollideOffButton
	local queryOnButton = uiRefs.QueryOnButton
	local queryOffButton = uiRefs.QueryOffButton
	local touchOnButton = uiRefs.TouchOnButton
	local touchOffButton = uiRefs.TouchOffButton
	local transparency0Button = uiRefs.Transparency0Button
	local transparency25Button = uiRefs.Transparency25Button
	local transparency50Button = uiRefs.Transparency50Button
	local transparency100Button = uiRefs.Transparency100Button

	anchoredOnButton.MouseButton1Click:Connect(function()
		applyResult(propertyService:SetAnchored(true))
	end)
	anchoredOffButton.MouseButton1Click:Connect(function()
		applyResult(propertyService:SetAnchored(false))
	end)
	collideOnButton.MouseButton1Click:Connect(function()
		applyResult(propertyService:SetCanCollide(true))
	end)
	collideOffButton.MouseButton1Click:Connect(function()
		applyResult(propertyService:SetCanCollide(false))
	end)
	queryOnButton.MouseButton1Click:Connect(function()
		applyResult(propertyService:SetCanQuery(true))
	end)
	queryOffButton.MouseButton1Click:Connect(function()
		applyResult(propertyService:SetCanQuery(false))
	end)
	touchOnButton.MouseButton1Click:Connect(function()
		applyResult(propertyService:SetCanTouch(true))
	end)
	touchOffButton.MouseButton1Click:Connect(function()
		applyResult(propertyService:SetCanTouch(false))
	end)
	transparency0Button.MouseButton1Click:Connect(function()
		applyResult(propertyService:SetTransparency(0))
	end)
	transparency25Button.MouseButton1Click:Connect(function()
		applyResult(propertyService:SetTransparency(0.25))
	end)
	transparency50Button.MouseButton1Click:Connect(function()
		applyResult(propertyService:SetTransparency(0.5))
	end)
	transparency100Button.MouseButton1Click:Connect(function()
		applyResult(propertyService:SetTransparency(1))
	end)

	local materialButtonsByName: { [string]: TextButton } = {
		MaterialPlasticButton = uiRefs.MaterialPlasticButton,
		MaterialConcreteButton = uiRefs.MaterialConcreteButton,
		MaterialMetalButton = uiRefs.MaterialMetalButton,
	}

	for buttonName, material in MATERIAL_BUTTONS do
		local materialButton = materialButtonsByName[buttonName]
		materialButton.MouseButton1Click:Connect(function()
			applyResult(propertyService:SetMaterial(material))
		end)
	end

	local colorButtonsByName: { [string]: TextButton } = {
		ColorStoneButton = uiRefs.ColorStoneButton,
		ColorWhiteButton = uiRefs.ColorWhiteButton,
		ColorBlackButton = uiRefs.ColorBlackButton,
	}

	for buttonName, colorData in COLOR_BUTTONS do
		local colorButton = colorButtonsByName[buttonName]
		colorButton.MouseButton1Click:Connect(function()
			applyResult(propertyService:SetColor(colorData.Color, colorData.Name))
		end)
	end
end

local function connectSettingsActions()
	uiRefs.SavePresetsButton.MouseButton1Click:Connect(function()
		settingsStore:SetFolderPresets(parsePresetSettings())
		refreshFolderPresets()
		setStatus("Updated folder presets.", false)
	end)
end

uiRefs.AssetSearchBox:GetPropertyChangedSignal("Text"):Connect(function()
	refreshLibrary()
end)

uiRefs.PresetSettingsBox.Text = table.concat(settingsStore:GetFolderPresets(), ", ")

widget:GetPropertyChangedSignal("Enabled"):Connect(function()
	toggleButton:SetActive(widget.Enabled)
	settingsStore:SetIsOpen(widget.Enabled)
end)

toggleButton.Click:Connect(function()
	setWidgetEnabled(not widget.Enabled)
end)

game:GetService("Selection").SelectionChanged:Connect(function()
	refreshSelectionSummary()
end)

connectSectionToggles()
connectOverview()
connectFolderActions()
connectSelectionActions()
connectPropertyActions()
connectSettingsActions()

refreshSelectionSummary()
refreshSectionState()
refreshLibrary()
refreshRecentAssets()
refreshFolderPresets()
setWidgetEnabled(settingsStore:GetIsOpen())
