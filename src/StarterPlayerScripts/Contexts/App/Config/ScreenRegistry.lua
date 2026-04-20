--!strict
--[=[
	@class ScreenRegistry
	Map of screen names to screen component modules, used by the router to render screens by name.
	@client
]=]

local HomeScreen = require(script.Parent.Parent.Presentation.Screens.HomeScreen)
local GameView = require(script.Parent.Parent.Presentation.Screens.GameView)
local StatisticsScreen = require(script.Parent.Parent.Presentation.Screens.StatisticsScreen)
local UpgradePresentation = require(script.Parent.Parent.Parent.Upgrade.Presentation)
local InventoryPresentation = require(script.Parent.Parent.Parent.Inventory.Presentation)
local SettingsPresentation = require(script.Parent.Parent.Parent.Settings.Presentation)
local WorkerPresentation = require(script.Parent.Parent.Parent.Worker.Presentation)
local ForgePresentation = require(script.Parent.Parent.Parent.Forge.Presentation)
local BreweryPresentation = require(script.Parent.Parent.Parent.Brewery.Presentation)
local TailoringPresentation = require(script.Parent.Parent.Parent.Tailoring.Presentation)
local ShopPresentation = require(script.Parent.Parent.Parent.Shop.Presentation)
local BuildingPresentation = require(script.Parent.Parent.Parent.Building.Presentation)
local GuildPresentation = require(script.Parent.Parent.Parent.Guild.Presentation)
local CommissionPresentation = require(script.Parent.Parent.Parent.Commission.Presentation)
local QuestPresentation = require(script.Parent.Parent.Parent.Quest.Presentation)
local TaskPresentation = require(script.Parent.Parent.Parent.Task.Presentation)
local RemoteLotPresentation = require(script.Parent.Parent.Parent.RemoteLot.Presentation)

return table.freeze({
	Home = HomeScreen,
	Game = GameView,
	Upgrades = UpgradePresentation.UpgradeScreen,
	Statistics = StatisticsScreen,
	Inventory = InventoryPresentation.InventoryScreen,
	Settings = SettingsPresentation.SettingsScreen,
	Workers = WorkerPresentation.WorkersScreen,
	Forge = ForgePresentation.ForgeScreen,
	Brewery = BreweryPresentation.BreweryScreen,
	Tailoring = TailoringPresentation.TailoringScreen,
	Buildings = BuildingPresentation.BuildingScreen,
	Shop = ShopPresentation.ShopScreen,
	Guild = GuildPresentation.GuildScreen,
	AdventurerDetail = GuildPresentation.AdventurerDetailScreen,
	CommissionBoard = CommissionPresentation.CommissionBoardScreen,
	Tasks = TaskPresentation.TaskLogScreen,
	QuestBoard = QuestPresentation.QuestBoardScreen,
	QuestPartySelection = QuestPresentation.QuestPartySelectionScreen,
	QuestExpeditionResult = QuestPresentation.QuestExpeditionResultScreen,
	LandCustomizer = RemoteLotPresentation.LandCustomizerScreen,
})
