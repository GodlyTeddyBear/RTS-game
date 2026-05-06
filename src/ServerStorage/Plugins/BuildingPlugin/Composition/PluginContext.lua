--!strict

-- Modules
local Constants = require(script.Parent.Parent.Constants)
local AppController = require(script.Parent.Parent.Contexts.App.AppController)
local ChangeHistoryAdapter = require(script.Parent.Parent.Contexts.App.Infrastructure.Services.ChangeHistoryAdapter)
local PluginDataTransferService = require(script.Parent.Parent.Contexts.App.Infrastructure.Services.PluginDataTransferService)
local PluginSettingsService = require(script.Parent.Parent.Contexts.App.Infrastructure.Services.PluginSettingsService)
local WaypointService = require(script.Parent.Parent.Contexts.Waypoints.Infrastructure.Services.WaypointService)
local AssetLibraryService = require(script.Parent.Parent.Contexts.Assets.Infrastructure.Services.AssetLibraryService)
local FolderService = require(script.Parent.Parent.Contexts.Building.Infrastructure.Services.FolderService)
local OrganizationService = require(script.Parent.Parent.Contexts.Organization.Infrastructure.Services.OrganizationService)
local PropertyService = require(script.Parent.Parent.Contexts.Building.Infrastructure.Services.PropertyService)
local SelectionActionService =
	require(script.Parent.Parent.Contexts.Building.Infrastructure.Services.SelectionActionService)
local SelectionService = require(script.Parent.Parent.Contexts.Building.Infrastructure.Services.SelectionService)

local PluginContext = {}
PluginContext.__index = PluginContext

function PluginContext.new(pluginInstance: Plugin)
	local self = setmetatable({}, PluginContext)

	-- Create plugin chrome
	local toolbar = pluginInstance:CreateToolbar(Constants.ToolbarName)
	local toggleButton = toolbar:CreateButton(Constants.ButtonId, Constants.ButtonTooltip, Constants.ButtonIcon)
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

	local widget = pluginInstance:CreateDockWidgetPluginGuiAsync(Constants.WidgetId, widgetInfo)
	widget.Title = Constants.WidgetTitle

	-- Wire services
	local settingsService = PluginSettingsService.new(pluginInstance)
	local dataTransferService = PluginDataTransferService.new(settingsService)
	settingsService:SetOnSettingsSaved(function()
		dataTransferService:SyncCurrentData()
	end)

	local services = {
		History = ChangeHistoryAdapter,
		Selection = SelectionService,
		Settings = settingsService,
		DataTransfer = dataTransferService,
		Waypoints = WaypointService.new(settingsService),
		Assets = AssetLibraryService.new(settingsService, ChangeHistoryAdapter, SelectionService),
		Folder = FolderService.new(ChangeHistoryAdapter, SelectionService),
		Organization = OrganizationService.new(ChangeHistoryAdapter, SelectionService, settingsService),
		Property = PropertyService.new(ChangeHistoryAdapter, SelectionService),
		SelectionActions = SelectionActionService.new(ChangeHistoryAdapter, SelectionService),
	}

	self.Plugin = pluginInstance
	self.ToggleButton = toggleButton
	self.Widget = widget
	self.Services = services
	self.Controller = AppController.new(self)

	return self
end

function PluginContext:Start()
	print("Starting plugin")
	self.Controller:Start()
end

function PluginContext:Destroy()
	self.Controller:Destroy()
end

return PluginContext
