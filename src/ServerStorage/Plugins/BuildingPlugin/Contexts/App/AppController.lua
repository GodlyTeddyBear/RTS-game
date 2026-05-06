--!strict

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Selection = game:GetService("Selection")

-- Modules
local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local StudioComponents = require(ReplicatedStorage.Packages.StudioComponents)

local AppAtom = require(script.Parent.Infrastructure.AppAtom)
local PluginServicesProvider = require(script.Parent.Infrastructure.PluginServicesProvider)
local AssetsAtom = require(script.Parent.Parent.Assets.Infrastructure.AssetsAtom)
local SettingsAtom = require(script.Parent.Parent.Settings.Infrastructure.SettingsAtom)
local BuildingAtom = require(script.Parent.Parent.Building.Infrastructure.BuildingAtom)
local App = require(script.Parent.Presentation.App)

type TPluginContext = {
	Plugin: Plugin,
	ToggleButton: PluginToolbarButton,
	Widget: DockWidgetPluginGui,
	Services: any,
}

local AppController = {}
AppController.__index = AppController

function AppController.new(pluginContext: TPluginContext)
	local self = setmetatable({}, AppController)
	self.PluginContext = pluginContext
	self.Connections = {}
	self.Root = nil
	return self
end

function AppController:Start()
	-- Mount the React app once and keep the widget content controlled by plugin state.
	self.Root = ReactRoblox.createRoot(self.PluginContext.Widget)
	self.Root:render(self:_CreateRootElement())

	self:_ConnectSignals()
	self:_RefreshAllState()
	self:_SetWidgetEnabled(self.PluginContext.Services.Settings:GetIsOpen())
end

function AppController:Destroy()
	for _, connection in self.Connections do
		connection:Disconnect()
	end

	if self.Root ~= nil then
		self.Root:unmount()
		self.Root = nil
	end
end

function AppController:_CreateRootElement()
	return React.createElement(StudioComponents.PluginProvider, {
		Plugin = self.PluginContext.Plugin,
	}, {
		Services = React.createElement(PluginServicesProvider, {
			Services = self.PluginContext.Services,
		}, {
			App = React.createElement(App),
		}),
	})
end

function AppController:_ConnectSignals()
	table.insert(self.Connections, self.PluginContext.ToggleButton.Click:Connect(function()
		self:_SetWidgetEnabled(not self.PluginContext.Widget.Enabled)
	end))

	table.insert(self.Connections, self.PluginContext.Widget:GetPropertyChangedSignal("Enabled"):Connect(function()
		local isEnabled = self.PluginContext.Widget.Enabled
		self.PluginContext.ToggleButton:SetActive(isEnabled)
		self.PluginContext.Services.Settings:SetIsOpen(isEnabled)
		AppAtom.SetWidgetEnabled(isEnabled)

		if isEnabled then
			self:_RefreshAllState()
		end
	end))

	table.insert(self.Connections, Selection.SelectionChanged:Connect(function()
		self:_RefreshBuildingState()
	end))
end

function AppController:_SetWidgetEnabled(isEnabled: boolean)
	self.PluginContext.Widget.Enabled = isEnabled
	self.PluginContext.ToggleButton:SetActive(isEnabled)
	self.PluginContext.Services.Settings:SetIsOpen(isEnabled)
	AppAtom.SetWidgetEnabled(isEnabled)
end

function AppController:_RefreshAllState()
	self:_RefreshBuildingState()
	self:_RefreshAssetsState()
	self:_RefreshSettingsState()
end

function AppController:_RefreshBuildingState()
	BuildingAtom.SetSelectionSummary(self.PluginContext.Services.Selection.GetSummary())
end

function AppController:_RefreshAssetsState()
	local assetsState = AssetsAtom.GetState()
	AssetsAtom.SetAssetRootExists(self.PluginContext.Services.Assets:GetAssetRoot() ~= nil)
	local recentAssetEntries = self.PluginContext.Services.Assets:GetAssetEntries(nil)
	local recentAssetPaths = {}
	for _, assetEntry in recentAssetEntries do
		table.insert(recentAssetPaths, assetEntry.Path)
	end

	AssetsAtom.SetRecentAssets(recentAssetPaths)
	AssetsAtom.SetAssetEntries(self.PluginContext.Services.Assets:GetAssetEntries(assetsState.SearchText))
end

function AppController:_RefreshSettingsState()
	local folderPresets = self.PluginContext.Services.Settings:GetFolderPresets()
	SettingsAtom.SetFolderPresets(folderPresets)
	SettingsAtom.SetPresetText(table.concat(folderPresets, ", "))
	SettingsAtom.SetSectionExpansionById(self.PluginContext.Services.Settings:GetSectionExpansionById())
end

return AppController
